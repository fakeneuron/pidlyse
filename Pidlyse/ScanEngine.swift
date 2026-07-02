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

    /// PID → its process-table node (parent pid + compact executable label) for the
    /// whole system, captured at scan time (PID-52.2). Resolved once per scan via a
    /// single bulk `ps -axo pid=,ppid=,comm=`; consumed by the inspector's parent-chain
    /// hint (`AncestryResolver.ancestorChain`) to walk every ancestor up to launchd —
    /// including non-stray shells / `login` that `ScanCore.parentCommand` can't see.
    /// Empty when nothing resolves. Mirrors `listeningPorts` / `containerOwners` / `cwds`.
    @Published private(set) var processTable: [Int32: ProcessNode] = [:]

    /// PID → its open files + sockets, fetched **on-demand** when a row expands
    /// (PID-52.3) — never during a scan, unlike every map above. Populated lazily by
    /// `loadOpenFiles(for:)` via a single per-PID `lsof -p <pid>`; consumed by the
    /// inspector's open-files list. Cached per session (fetch once per PID, empty
    /// results included) so re-expanding a row doesn't re-spawn `lsof`; bounded to the
    /// rows the user has inspected.
    @Published private(set) var openFiles: [Int32: OpenFileList] = [:]

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

    /// Command-substring ignores, one raw editor line each (case-insensitive). A bare
    /// line hides matches globally; a `substring @ ~/path` line scopes the ignore to one
    /// project tree (`IgnoreRule` grammar, PID-54.4). Persisted to UserDefaults as a
    /// string array; parsed into `IgnoreRule`s at scan time.
    @Published var ignoredNames: [String] = [] {
        didSet {
            UserDefaults.standard.set(ignoredNames, forKey: "ignoredNames")
        }
    }

    /// Project trees whose processes are kept out of the "Clean all" bulk sweep
    /// (marked 🔒, still individually killable) — the protected-list override (PID-54.4).
    /// Each entry is a `~`-abbreviated path prefix; a process is protected when its
    /// resolved cwd sits under any entry (`CwdResolver.isUnderPrefix`). Edited via the
    /// per-row 🔒 toggle or the Settings list. Persisted to UserDefaults as a `[String]`.
    /// Not threaded into the scan — protection is a view-side overlay so lock/un-lock is
    /// instant (no rescan). Empty = nothing protected (the default).
    @Published var protectedProjects: [String] = [] {
        didSet {
            UserDefaults.standard.set(protectedProjects, forKey: "protectedProjects")
        }
    }

    /// Process kinds the user has switched off — skipped during the scan. A
    /// category-level complement to the substring `ignoredNames` ignore. Persisted
    /// to UserDefaults as a `[String]` of `ProcessKind` raw values. Empty = scan
    /// everything (the default).
    @Published var disabledKinds: Set<ProcessKind> = [] {
        didSet {
            UserDefaults.standard.set(disabledKinds.map { $0.rawValue }, forKey: "disabledKinds")
        }
    }

    /// User-defined detection rules (substring → friendly label), consulted ahead
    /// of the built-in kinds and always surfaced in Needs Review (PID-54.3). The
    /// substring-ignore complement to `ignoredNames`: where an ignore *hides* a
    /// match, a custom rule *adds* one. Persisted to UserDefaults as a `[String]`
    /// of `substring = label` lines. Empty = built-in detection only (the default).
    @Published var customRules: [CustomRule] = [] {
        didSet {
            UserDefaults.standard.set(customRules.map(CustomRule.serialize), forKey: "customRules")
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

    /// Persistent log of confirmed cleans (PID-53.2). Owns disk I/O; the pure
    /// aggregation lives in `PidlyseCore.CleanLog`. Exposed so the PID-53.3
    /// "Cleaned" tab can bind to its `events`.
    let cleanLog = CleanLogStore()

    /// PIDs dismissed for this session. Not persisted — cleared on app restart.
    private(set) var dismissedPIDs: Set<Int32> = []

    /// PIDs from the previous completed scan. `nil` = no prior baseline (first scan).
    private var previousPIDs: Set<Int32>?

    /// Rolling-window CPU-sample history across scans (PID-55.2). Fed once per scan
    /// from `filtered`; consulted by `hasSustainedLowCPU(_:)` (the idle-signal query
    /// PID-55.3 surfaces). In-memory for the session; pure logic lives in
    /// `PidlyseCore.ScanHistory`. Signal-only — never influences the kill bar.
    private var scanHistory = ScanHistory()

    private var timer: Timer?

    init() {
        let ud = UserDefaults.standard
        let savedThreshold = ud.double(forKey: "elapsedThreshold")
        let savedInterval = ud.double(forKey: "scanInterval")
        let savedIgnoredNames = ud.stringArray(forKey: "ignoredNames") ?? []
        let savedDisabledKinds = Set((ud.stringArray(forKey: "disabledKinds") ?? []).compactMap(ProcessKind.init(rawValue:)))
        let savedCustomRules = (ud.stringArray(forKey: "customRules") ?? []).compactMap(CustomRule.parse)
        let savedProtectedProjects = ud.stringArray(forKey: "protectedProjects") ?? []
        let savedNotifications = ud.bool(forKey: "notificationsEnabled")

        if savedThreshold > 0 { _elapsedThreshold = Published(wrappedValue: savedThreshold) }
        _ignoredNames = Published(wrappedValue: savedIgnoredNames)
        _disabledKinds = Published(wrappedValue: savedDisabledKinds)
        _customRules = Published(wrappedValue: savedCustomRules)
        _protectedProjects = Published(wrappedValue: savedProtectedProjects)
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
        // Split the ignore editor lines: global substrings hide inside `enumerate`
        // (unchanged path); scoped `substring @ prefix` rules need the cwd map and are
        // applied as a post-filter below (PID-54.4).
        let ignoreRules = ignoredNames.compactMap(IgnoreRule.parse)
        let globalIgnores = ignoreRules.filter { $0.pathPrefix == nil }.map { $0.substring }
        let scopedIgnores = ignoreRules.filter { $0.pathPrefix != nil }
        let disabled = disabledKinds
        let rules = customRules
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
                                            ignoredNames: globalIgnores,
                                            dismissedPIDs: dismissed,
                                            disabledKinds: disabled,
                                            customRules: rules,
                                            startTimeProvider: KillCore.startTime)
            // Resolve each candidate's working directory once per scan (single bulk
            // lsof over the matched PIDs); the row-expansion hint reads it (PID-038).
            let cwdMap = CwdResolver.processCwds(forPIDs: result.map { $0.pid })
            // Apply cwd-scoped ignores now that the cwd map exists — they can't run
            // inside `enumerate` (no cwd there). Global ignores already filtered above.
            let filtered = ScanCore.applyScopedIgnores(result, cwds: cwdMap, rules: scopedIgnores)
            // Resolve the full system process table once per scan (single bulk `ps`);
            // the inspector's parent-chain hint walks it to launchd (PID-52.2).
            let procTable = AncestryResolver.processTable()
            DispatchQueue.main.async {
                let oldPIDs = self?.previousPIDs
                self?.previousPIDs = Set(filtered.map { $0.pid })
                self?.items = filtered
                self?.listeningPorts = portMap
                self?.containerOwners = owners
                self?.cwds = cwdMap
                self?.processTable = procTable
                self?.recordScanHistory(filtered)
                self?.isScanning = false
                self?.fireNotificationIfNeeded(newItems: filtered, previousPIDs: oldPIDs)
            }
        }
    }

    /// Fetch a process's open files on-demand when its inspector expands (PID-52.3).
    /// No-op if already cached (fetch once per PID per session — the guard also stops
    /// a re-expand from re-spawning `lsof`); the single `lsof -p <pid>` runs on a
    /// background queue and publishes on the main thread. Empty results are cached too,
    /// so a fileless process isn't re-queried. Safe to call on every expansion.
    func loadOpenFiles(for pid: Int32) {
        guard openFiles[pid] == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = OpenFilesResolver.openFiles(forPID: pid)
            DispatchQueue.main.async { self?.openFiles[pid] = result }
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

    // MARK: - Clean log (PID-53.2)

    /// Record a single kill's outcome. Logs only `.confirmed` deaths — labelled
    /// from the scan-time `cwds` project label (fallback: `displayPath`). Called
    /// on the main thread from the kill-completion hook **before** the rescan, so
    /// `cwds` still holds the pre-kill label.
    func recordCleaned(_ item: ProcessItem, outcome: KillService.KillOutcome) {
        guard outcome == .confirmed else { return }
        cleanLog.record(makeCleanEvent(item))
    }

    /// Batch variant: record every confirmed kill from a `[pid: outcome]` map,
    /// resolving each pid back to its `ProcessItem` for the kind/rss/label.
    func recordCleaned(_ items: [ProcessItem], outcomes: [Int32: KillService.KillOutcome]) {
        for item in items where outcomes[item.pid] == .confirmed {
            cleanLog.record(makeCleanEvent(item))
        }
    }

    private func makeCleanEvent(_ item: ProcessItem) -> CleanEvent {
        // For a custom-rule match, persist the friendly label as the `kind` string:
        // the Cleaned tab's `ProcessKind(rawValue:)?.label ?? kc.kind` fallback then
        // shows the user's label (an unknown rawValue falls through to the raw string).
        CleanEvent(kind: item.kind == .custom ? item.displayLabel : item.kind.rawValue,
                   projectLabel: cwds[item.pid]?.label ?? item.displayPath,
                   rssKB: item.rssKB,
                   timestamp: Date())
    }

    // MARK: - Scan history (PID-55.2)

    /// Fold the completed scan's CPU samples into the rolling window. Called on the
    /// main thread from the scan-publish block; keys each sample by PID+startTime so
    /// a recycled PID starts a fresh series.
    private func recordScanHistory(_ items: [ProcessItem]) {
        scanHistory = scanHistory.recording(items.map {
            ScanHistory.Observation(pid: $0.pid, startTime: $0.startTime, cpuPercent: $0.cpuPercent)
        })
    }

    /// Whether a process has shown sustained low CPU across the scan-history window
    /// (PID-55.2). The idle-signal query PID-55.3 folds into its "idle dev server"
    /// verdict; advisory only — never influences the risk tier / bucket / kill bar.
    func hasSustainedLowCPU(_ item: ProcessItem) -> Bool {
        scanHistory.isSustainedLowCPU(pid: item.pid, startTime: item.startTime)
    }

    /// Whether a process reads as a confident **idle dev server** (PID-55.3):
    /// sustained low CPU across the scan-history window AND old (past
    /// `elapsedThreshold`) AND no controlling terminal AND an explicit dev-mode
    /// flag in its command (`ScanCore.hasDevModeFlag`). The strict-AND / high-
    /// precision reading resolved in the PID-55.3 discovery. Advisory only —
    /// surfaced in the row inspector's "Why is this here?" expansion; never
    /// influences the risk tier / bucket / kill bar.
    func isIdleDevServer(_ item: ProcessItem) -> Bool {
        hasSustainedLowCPU(item)
            && item.elapsed >= elapsedThreshold
            && !item.hasTTY
            && ScanCore.hasDevModeFlag(item.command)
    }

    // MARK: - Notifications

    private func fireNotificationIfNeeded(newItems: [ProcessItem], previousPIDs: Set<Int32>?) {
        guard notificationsEnabled, let prev = previousPIDs else { return }
        let newStrays = newItems.filter { !prev.contains($0.pid) }
        guard !newStrays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        if newStrays.count == 1 {
            content.title = "New stray process"
            content.body = "\(newStrays[0].displayLabel): \(newStrays[0].displayPath)"
        } else {
            content.title = "\(newStrays.count) new stray processes"
            content.body = newStrays.map { $0.displayLabel }.joined(separator: ", ")
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
