import Foundation
import UserNotifications
import PidlyseCore

/// App-side scan lifecycle: owns the auto-scan `Timer`, the published `items`,
/// `UserDefaults`-backed config, the dismissed/previous baselines, and the
/// new-stray notification. The pure enumeration + classification it drives lives
/// in `PidlyseCore.ScanCore` (per CLAUDE.md, all scan + classification logic stays
/// in one place).
final class ScanEngine: ObservableObject {
    static let defaultScanInterval: TimeInterval = 120

    @Published private(set) var items: [ProcessItem] = []
    @Published private(set) var isScanning: Bool = false

    /// PID → the registered ports it listens on, captured at scan time for the
    /// per-row provenance hint (PID-036.3). Computed once per scan; its keys are
    /// the same set `enumerate` uses for port-demotion (so no second `lsof` runs).
    @Published private(set) var listeningPorts: [Int32: Set<Int>] = [:]

    /// PID → the Docker container name that owns it, captured at scan time
    /// (PID-037.2). Resolved once per scan via a single bulk `docker inspect`;
    /// consumed by the kill path (`docker stop <name>`, retiring the per-click
    /// `findContainerID` inspect — F9) and the row-expansion ownership hint
    /// (PID-037.3). Empty when Docker is absent. Mirrors `listeningPorts`.
    @Published private(set) var containerOwners: [Int32: String] = [:]

    /// PID → its working-directory provenance (project label + abbreviated full path),
    /// captured at scan time (PID-038). Resolved once per scan via a single bulk `lsof`
    /// over the scanned PIDs; consumed by the row descriptor (showing the git-project
    /// `bidviz`/`bidviz/frontend`) so a bare `npm`/`node` row is identifiable beyond the
    /// executable name. Empty when nothing resolves. Mirrors `listeningPorts` /
    /// `containerOwners`.
    @Published private(set) var cwds: [Int32: ProcessCwd] = [:]

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
            // Resolve the registered-port listeners once: its keys feed the
            // classifier's port-demotion (passed as registeredPIDs so enumerate
            // doesn't re-run lsof), and the full map drives the per-row port hint
            // (PID-036.3).
            let portMap = PortRegistry.listeningPorts()
            // Resolve the Docker container-owner map once per scan (single bulk
            // inspect); the kill path and the row hint read it instead of a
            // per-click inspect (PID-037.2, retiring F9).
            let owners = DockerService.containerOwners()
            // Capture each candidate's start time at scan so the kill path can detect
            // a PID recycled between this scan and a later kill click. (PID-35.3)
            let result = ScanCore.enumerate(elapsedThreshold: threshold,
                                            registeredPIDs: Set(portMap.keys),
                                            ignoredNames: ignored,
                                            dismissedPIDs: dismissed,
                                            startTimeProvider: KillService.startTime)
            // Resolve each candidate's working directory once per scan (single bulk
            // lsof over the matched PIDs); the row-expansion hint reads it (PID-038).
            let cwdMap = CwdResolver.processCwds(forPIDs: result.map { $0.pid })
            DispatchQueue.main.async {
                let oldPIDs = self?.previousPIDs
                self?.previousPIDs = Set(result.map { $0.pid })
                self?.items = result
                self?.listeningPorts = portMap
                self?.containerOwners = owners
                self?.cwds = cwdMap
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
}
