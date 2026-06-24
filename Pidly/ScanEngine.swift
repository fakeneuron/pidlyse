import Foundation

/// Enumerates running processes, matches stray candidates, and classifies each
/// into a descriptive `kind` + `riskTier` (→ derived `safe`/`needsReview`
/// bucket). All scan + classification logic lives here (per CLAUDE.md) so it
/// stays in one place as the UI (PID-003), kill flow (PID-004), and port
/// registry (PID-005) layer on top.
final class ScanEngine: ObservableObject {
    /// Default "old enough to be stale" threshold. Made configurable in PID-006.
    static let defaultElapsedThreshold: TimeInterval = 30 * 60

    @Published private(set) var items: [ProcessItem] = []

    /// Elapsed-time threshold above which a process counts as "old". Settings
    /// panel (PID-006) will drive this; constant default for now.
    var elapsedThreshold: TimeInterval

    init(elapsedThreshold: TimeInterval = ScanEngine.defaultElapsedThreshold) {
        self.elapsedThreshold = elapsedThreshold
    }

    /// Run a scan and publish the results. Synchronous for now; background
    /// dispatch + the periodic timer are PID-006 concerns.
    func scan() {
        items = Self.enumerate(elapsedThreshold: elapsedThreshold)
    }

    // MARK: - Enumeration

    /// Parse + classify `ps` output into stray candidates. `psOutput` and
    /// `registeredPIDs` are injectable so the pure pipeline can be unit-tested
    /// without shelling out. When `registeredPIDs` is nil the live `lsof` query runs.
    static func enumerate(elapsedThreshold: TimeInterval = defaultElapsedThreshold,
                          psOutput: String? = nil,
                          registeredPIDs: Set<Int32>? = nil) -> [ProcessItem] {
        let output = psOutput ?? runPS()
        let portPIDs = registeredPIDs ?? PortRegistry.listeningPIDs()
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { makeItem(from: String($0), elapsedThreshold: elapsedThreshold,
                                   registeredPIDs: portPIDs) }
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
        // Build a draft to reuse ProcessItem's signal logic, then stamp the tier.
        let draft = ProcessItem(pid: p.pid, ppid: p.ppid, command: p.args,
                                elapsed: elapsed, tty: p.tty, kind: kind, riskTier: .moderate)
        var tier = riskTier(kind: kind,
                            hasTTY: draft.hasTTY,
                            isOrphan: draft.isOrphan,
                            isOld: elapsed >= elapsedThreshold)
        if registeredPIDs.contains(p.pid) && tier == .easy { tier = .moderate }
        return ProcessItem(pid: p.pid, ppid: p.ppid, command: p.args,
                           elapsed: elapsed, tty: p.tty, kind: kind, riskTier: tier)
    }

    // MARK: - Pure parsing helpers

    /// Split a `ps -o pid=,ppid=,etime=,tty=,args=` line into its fields. The
    /// first four columns are whitespace-delimited; everything after is the
    /// (space-containing) command line.
    static func parsePSLine(_ line: String) -> (pid: Int32, ppid: Int32, etime: String, tty: String, args: String)? {
        var remainder = Substring(line)
        var fields: [Substring] = []
        for _ in 0..<4 {
            while let c = remainder.first, c == " " || c == "\t" { remainder = remainder.dropFirst() }
            guard let space = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            fields.append(remainder[..<space])
            remainder = remainder[space...]
        }
        let args = remainder.trimmingCharacters(in: .whitespaces)
        guard let pid = Int32(fields[0]), let ppid = Int32(fields[1]), !args.isEmpty else { return nil }
        return (pid, ppid, String(fields[2]), String(fields[3]), args)
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
        if s.contains("jest") { return .jest }
        if s.contains("uvicorn") { return .uvicorn }
        if s.contains("docker") { return .docker }
        if s.contains("npm") { return .npm }
        return nil
    }

    /// Risk tier = base risk by kind, adjusted by stray signals. A process is a
    /// "strong stray" only when it has no terminal, is orphaned, and is old.
    static func riskTier(kind: ProcessKind, hasTTY: Bool, isOrphan: Bool, isOld: Bool) -> RiskTier {
        // Real dev infra — never an easy kill regardless of signals.
        if kind == .docker || kind == .uvicorn { return .high }

        let strongStray = !hasTTY && isOrphan && isOld
        switch kind {
        case .pytest, .vitest, .jest, .playwrightTest, .playwrightMCP, .chromeHelper:
            return strongStray ? .easy : .moderate
        case .npm:
            return strongStray ? .moderate : .high
        case .docker, .uvicorn:
            return .high   // handled above; keeps the switch exhaustive
        }
    }

    // MARK: - Process enumeration

    /// Shell out to `/bin/ps` for all processes with the columns the classifier
    /// needs. Reads to EOF before `waitUntilExit` to avoid a full-pipe deadlock.
    static func runPS() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axww", "-o", "pid=,ppid=,etime=,tty=,args="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
