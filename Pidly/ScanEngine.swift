import Foundation
import UserNotifications

/// Enumerates running processes, matches stray candidates, and classifies each
/// into a descriptive `kind` + `riskTier` (→ derived `safe`/`needsReview`
/// bucket). All scan + classification logic lives here (per CLAUDE.md) so it
/// stays in one place as the UI (PID-003), kill flow (PID-004), and port
/// registry (PID-005) layer on top.
final class ScanEngine: ObservableObject {
    static let defaultElapsedThreshold: TimeInterval = 30 * 60
    static let defaultScanInterval: TimeInterval = 120

    @Published private(set) var items: [ProcessItem] = []
    @Published private(set) var isScanning: Bool = false

    /// How often (seconds) the background timer auto-scans. Persisted to UserDefaults.
    @Published var scanInterval: TimeInterval = 120 {
        didSet {
            UserDefaults.standard.set(scanInterval, forKey: "scanInterval")
            startTimer()
        }
    }

    /// Elapsed-time threshold above which a process counts as "old". Persisted to UserDefaults.
    @Published var elapsedThreshold: TimeInterval = 30 * 60 {
        didSet {
            UserDefaults.standard.set(elapsedThreshold, forKey: "elapsedThreshold")
        }
    }

    /// Command-prefix substrings to hide from scan results (case-insensitive).
    /// Persisted to UserDefaults as a string array.
    @Published var ignoredNames: [String] = [] {
        didSet {
            UserDefaults.standard.set(ignoredNames, forKey: "ignoredNames")
        }
    }

    /// When true, fires a macOS system notification when a scan surfaces new stray PIDs.
    /// Persisted to UserDefaults. Permission is requested the first time it is enabled.
    @Published var notificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled && !oldValue {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    if !granted {
                        DispatchQueue.main.async { self?.notificationsEnabled = false }
                    }
                }
            }
        }
    }

    /// PIDs dismissed for this session. Not persisted — cleared on app restart.
    private(set) var dismissedPIDs: Set<Int32> = []

    /// PIDs from the previous completed scan. `nil` = no prior baseline (first scan).
    private var previousPIDs: Set<Int32>?

    private var timer: Timer?

    init() {
        let ud = UserDefaults.standard
        let savedThreshold = ud.double(forKey: "elapsedThreshold")
        let savedInterval = ud.double(forKey: "scanInterval")
        let savedIgnoredNames = ud.stringArray(forKey: "ignoredNames") ?? []
        let savedNotifications = ud.bool(forKey: "notificationsEnabled")

        if savedThreshold > 0 { _elapsedThreshold = Published(wrappedValue: savedThreshold) }
        _ignoredNames = Published(wrappedValue: savedIgnoredNames)
        if savedInterval > 0 { _scanInterval = Published(wrappedValue: savedInterval) }
        if savedNotifications { _notificationsEnabled = Published(wrappedValue: true) }
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Scanning

    /// Kick off a background scan. Debounces if already in-flight.
    /// Must be called from the main thread (timer + SwiftUI actions always are).
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let threshold = elapsedThreshold
        let ignored = ignoredNames
        let dismissed = dismissedPIDs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Self.enumerate(elapsedThreshold: threshold, ignoredNames: ignored,
                                        dismissedPIDs: dismissed)
            DispatchQueue.main.async {
                let oldPIDs = self?.previousPIDs
                self?.previousPIDs = Set(result.map { $0.pid })
                self?.items = result
                self?.isScanning = false
                self?.fireNotificationIfNeeded(newItems: result, previousPIDs: oldPIDs)
            }
        }
    }

    /// Hide a process for this session. Removes it from `items` immediately and
    /// excludes it from subsequent scans. A manual rescan (↺) clears the dismissed set.
    func dismiss(_ pid: Int32) {
        dismissedPIDs.insert(pid)
        items = items.filter { $0.pid != pid }
    }

    /// Manual rescan: clears all dismissed PIDs before scanning so previously
    /// hidden items can reappear. Also resets the notification baseline so
    /// re-emerging dismissed processes don't falsely fire as "new" strays.
    func rescan() {
        dismissedPIDs = []
        previousPIDs = nil
        scan()
    }

    // MARK: - Notifications

    private func fireNotificationIfNeeded(newItems: [ProcessItem], previousPIDs: Set<Int32>?) {
        guard notificationsEnabled, let prev = previousPIDs else { return }
        let newStrays = newItems.filter { !prev.contains($0.pid) }
        guard !newStrays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        if newStrays.count == 1 {
            content.title = "New stray process"
            content.body = "\(newStrays[0].kind.label): \(newStrays[0].displayPath)"
        } else {
            content.title = "\(newStrays.count) new stray processes"
            content.body = newStrays.map { $0.kind.label }.joined(separator: ", ")
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    // MARK: - Enumeration

    /// Parse + classify `ps` output into stray candidates. `psOutput`,
    /// `registeredPIDs`, `ignoredNames`, and `dismissedPIDs` are injectable
    /// for unit testing. When `registeredPIDs` is nil the live `lsof` query runs.
    /// Items whose command args contain any `ignoredNames` entry, or whose PID is
    /// in `dismissedPIDs`, are dropped.
    static func enumerate(elapsedThreshold: TimeInterval = defaultElapsedThreshold,
                          psOutput: String? = nil,
                          registeredPIDs: Set<Int32>? = nil,
                          ignoredNames: [String] = [],
                          dismissedPIDs: Set<Int32> = []) -> [ProcessItem] {
        let output = psOutput ?? runPS()
        let portPIDs = registeredPIDs ?? PortRegistry.listeningPIDs()
        var all = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { makeItem(from: String($0), elapsedThreshold: elapsedThreshold,
                                   registeredPIDs: portPIDs) }
        if !ignoredNames.isEmpty {
            all = all.filter { item in
                !ignoredNames.contains { prefix in
                    item.command.localizedCaseInsensitiveContains(prefix)
                }
            }
        }
        if !dismissedPIDs.isEmpty {
            all = all.filter { !dismissedPIDs.contains($0.pid) }
        }
        return all
    }

    /// Build one classified `ProcessItem` from a `ps` line, or `nil` if the line
    /// doesn't parse or matches no known `ProcessKind`.
    /// A process whose PID is in `registeredPIDs` is demoted from `.easy` to `.moderate`
    /// so it always lands in the Needs Review bucket.
    static func makeItem(from line: String, elapsedThreshold: TimeInterval,
                         registeredPIDs: Set<Int32> = []) -> ProcessItem? {
        guard let p = parsePSLine(line) else { return nil }
        guard let kind = detectKind(p.args) else { return nil }

        let elapsed = parseElapsed(p.etime)
        let cpuPercent = Double(p.pcpu) ?? 0.0
        let rssKB = Int(p.rss) ?? 0
        let t = p.tty.trimmingCharacters(in: .whitespaces)
        let hasTTY = !(t.isEmpty || t == "??" || t == "?" || t == "-")
        let isOrphan = p.ppid == 1
        var tier = riskTier(kind: kind,
                            hasTTY: hasTTY,
                            isOrphan: isOrphan,
                            isOld: elapsed >= elapsedThreshold)
        if registeredPIDs.contains(p.pid) && tier == .easy { tier = .moderate }
        return ProcessItem(pid: p.pid, ppid: p.ppid, command: p.args,
                           elapsed: elapsed, tty: p.tty, kind: kind, riskTier: tier,
                           cpuPercent: cpuPercent, rssKB: rssKB)
    }

    // MARK: - Pure parsing helpers

    /// Split a `ps -o pid=,ppid=,etime=,tty=,pcpu=,rss=,args=` line into its fields. The
    /// first six columns are whitespace-delimited; everything after is the
    /// (space-containing) command line.
    static func parsePSLine(_ line: String) -> (pid: Int32, ppid: Int32, etime: String, tty: String, pcpu: String, rss: String, args: String)? {
        var remainder = Substring(line)
        var fields: [Substring] = []
        for _ in 0..<6 {
            while let c = remainder.first, c == " " || c == "\t" { remainder = remainder.dropFirst() }
            guard let space = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            fields.append(remainder[..<space])
            remainder = remainder[space...]
        }
        let args = remainder.trimmingCharacters(in: .whitespaces)
        guard let pid = Int32(fields[0]), let ppid = Int32(fields[1]), !args.isEmpty else { return nil }
        return (pid, ppid, String(fields[2]), String(fields[3]), String(fields[4]), String(fields[5]), args)
    }

    /// Parse a `ps` etime string (`[[DD-]HH:]MM:SS`) into seconds.
    static func parseElapsed(_ etime: String) -> TimeInterval {
        var rest = etime.trimmingCharacters(in: .whitespaces)
        var days = 0
        if let dash = rest.firstIndex(of: "-") {
            days = Int(rest[..<dash]) ?? 0
            rest = String(rest[rest.index(after: dash)...])
        }
        let parts = rest.split(separator: ":").map { Int($0) ?? 0 }
        var hours = 0, minutes = 0, seconds = 0
        switch parts.count {
        case 3: hours = parts[0]; minutes = parts[1]; seconds = parts[2]
        case 2: minutes = parts[0]; seconds = parts[1]
        case 1: seconds = parts[0]
        default: break
        }
        return TimeInterval(((days * 24 + hours) * 60 + minutes) * 60 + seconds)
    }

    /// Map a command line to a `ProcessKind`, or `nil` if it's not a stray
    /// candidate. Order matters: the Chrome-under-`ms-playwright-mcp` case is
    /// tested before the generic playwright-mcp case (its user-data-dir path
    /// contains the `playwright-mcp` substring too).
    static func detectKind(_ args: String) -> ProcessKind? {
        let s = args.lowercased()

        if s.contains("ms-playwright-mcp") && (s.contains("chrome") || s.contains("chromium")) {
            return .chromeHelper
        }
        if s.contains("@playwright/mcp") || s.contains("playwright-mcp") {
            return .playwrightMCP
        }
        if s.contains("playwright") && s.contains("test") {
            return .playwrightTest
        }
        if s.contains("pytest") { return .pytest }
        if s.contains("vitest") { return .vitest }
        if s.contains("vite") { return .vite }
        if s.contains("jest") { return .jest }
        if s.contains("uvicorn") { return .uvicorn }
        if s.contains("docker") { return .docker }
        if s.contains("npm") { return .npm }
        if s.hasPrefix("bun ") || s == "bun" || s.contains("/bun ") || s.hasSuffix("/bun") { return .bun }
        if s.contains("node ") || s.hasSuffix("node") { return .node }
        return nil
    }

    /// Risk tier = base risk by kind, adjusted by stray signals. A process is a
    /// "strong stray" only when it has no terminal, is orphaned, and is old.
    static func riskTier(kind: ProcessKind, hasTTY: Bool, isOrphan: Bool, isOld: Bool) -> RiskTier {
        // Real dev infra — never an easy kill regardless of signals.
        if kind == .docker || kind == .uvicorn || kind == .node { return .high }

        let strongStray = !hasTTY && isOrphan && isOld
        switch kind {
        case .pytest, .vitest, .jest, .playwrightTest, .playwrightMCP, .chromeHelper:
            return strongStray ? .easy : .moderate
        case .npm, .vite, .bun:
            return strongStray ? .moderate : .high
        case .docker, .uvicorn, .node:
            return .high   // handled above; keeps the switch exhaustive
        }
    }

    // MARK: - Process enumeration

    /// Shell out to an executable, reading stdout to EOF before `waitUntilExit`
    /// to prevent pipe-buffer deadlock. Returns stdout as UTF-8 ("" on failure).
    private static func runShell(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch { return "" }
    }

    static func runPS() -> String {
        runShell("/bin/ps", ["-axww", "-o", "pid=,ppid=,etime=,tty=,pcpu=,rss=,args="])
    }
}
