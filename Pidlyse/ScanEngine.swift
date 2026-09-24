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

    /// Session-only respawn cache (PID-62.2). Armed at the kill-completion hook for
    /// every verified death and folded once per scan from `filtered`; consulted by
    /// `isRespawner(_:)`. In-memory for the session; pure logic lives in
    /// `PidlyseCore.RespawnHistory`. Signal-only — never influences the kill bar.
    private var respawnHistory = RespawnHistory()

    /// Identities whose kill came back `EPERM` this session (PID-62.3) — the backstop
    /// half of the unkillable signal, for anything the scan-time uid read missed.
    /// Stores each denied PID's scan-time start time so a recycled PID doesn't inherit
    /// the state; a denial with no start time is not remembered (an unverifiable
    /// identity degrades to killable, never to a sticky dead end). Session-only and deliberately *not* a `PidlyseCore` value type: it
    /// holds no logic, just a fact the engine observed; the derivation that consumes it
    /// is pure and lives in `Killability`.
    private var killDeniedIdentities: [Int32: ProcStartTime] = [:]

    /// The user Pidlyse runs as. Read once — it cannot change during the process's
    /// lifetime — and compared against each row's scan-time owner. (PID-62.3)
    private let currentUID = getuid()

    /// A `scan()` arrived while one was in flight; run one more when it publishes.
    private var rescanQueued = false

    /// Completions waiting on the next scan to *start* (see `scan(then:)`).
    private var completionsForNextScan: [() -> Void] = []

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

    /// Kick off a background scan. Must be called from the main thread (timer +
    /// SwiftUI actions always are). A request that lands while a scan is in flight
    /// isn't dropped: it queues exactly one follow-up scan (PID-62.5), because the
    /// in-flight one may have enumerated before whatever prompted the request — a
    /// kill, most often — and would otherwise leave a stale row up until the next
    /// timer tick. `completion` runs on the main thread after a scan that *started*
    /// after this call has published.
    func scan(then completion: (() -> Void)? = nil) {
        if let completion { completionsForNextScan.append(completion) }
        guard !isScanning else {
            rescanQueued = true
            return
        }
        isScanning = true
        let completions = completionsForNextScan
        completionsForNextScan = []
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
            // a PID recycled between this scan and a later kill click (PID-35.3), and
            // its owning uid so a foreign-owned row can be shown as unkillable before
            // the user clicks a button that can't work (PID-62.3).
            let result = ScanCore.enumerate(elapsedThreshold: threshold,
                                            registeredPIDs: Set(portMap.keys),
                                            ignoredNames: globalIgnores,
                                            dismissedPIDs: dismissed,
                                            disabledKinds: disabled,
                                            customRules: rules,
                                            startTimeProvider: KillCore.startTime,
                                            uidProvider: KillCore.ownerUID)
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
                guard let self else { return }
                // Re-apply dismissals: a row dismissed while this scan ran isn't in
                // the snapshot it started with, and must not come back (PID-62.5).
                let visible = filtered.filter { !self.dismissedPIDs.contains($0.pid) }
                let oldPIDs = self.previousPIDs
                self.previousPIDs = Set(visible.map { $0.pid })
                self.items = visible
                self.listeningPorts = portMap
                self.containerOwners = owners
                self.cwds = cwdMap
                self.processTable = procTable
                self.recordScanHistory(visible)
                // After `cwds` is published — signatures are built from it.
                self.recordRespawnHistory(visible)
                self.isScanning = false
                self.fireNotificationIfNeeded(newItems: visible, previousPIDs: oldPIDs)
                completions.forEach { $0() }
                if self.rescanQueued {
                    self.rescanQueued = false
                    self.scan()
                }
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

    /// Record every outcome from a `[pid: outcome]` map, resolving each pid back to
    /// its `ProcessItem` for the kind/rss/label. Called on the main thread from the
    /// kill-completion hook in `kill(_:completion:)`. `preKillCwds` is the cwd map
    /// captured when the kill began: a scan during the ≥ 2 s kill may already have
    /// dropped a dead process's entry from `cwds`.
    private func recordCleaned(_ items: [ProcessItem], outcomes: [Int32: KillService.KillOutcome],
                               preKillCwds: [Int32: ProcessCwd], killStartedAt: Date) {
        for item in items {
            guard let outcome = outcomes[item.pid] else { continue }
            record(item, outcome: outcome, cwd: preKillCwds[item.pid], killStartedAt: killStartedAt)
        }
    }

    /// What each outcome means to the engine, in one place so the single-item and
    /// batch hooks can't diverge. Only `.confirmed` — verified gone, per `KillCore`'s
    /// death check (PID-62.2) — is logged as a clean and arms respawn watching;
    /// `.unkillable` is remembered so the row can say why it kept its process
    /// (PID-62.3); `.survived` and `.notKilled` are neither a clean nor a permanent
    /// fact about the row, so nothing is recorded.
    private func record(_ item: ProcessItem, outcome: KillService.KillOutcome, cwd: ProcessCwd?,
                        killStartedAt: Date) {
        switch outcome {
        case .confirmed:
            armRespawnWatch(item, cwd: cwd, killStartedAt: killStartedAt)
            cleanLog.record(makeCleanEvent(item, cwd: cwd))
        case .unkillable:
            if let startTime = item.startTime { killDeniedIdentities[item.pid] = startTime }
        case .survived, .notKilled:
            break
        }
    }

    private func makeCleanEvent(_ item: ProcessItem, cwd: ProcessCwd?) -> CleanEvent {
        // For a custom-rule match, persist the friendly label as the `kind` string:
        // the Cleaned tab's `ProcessKind(rawValue:)?.label ?? kc.kind` fallback then
        // shows the user's label (an unknown rawValue falls through to the raw string).
        CleanEvent(kind: item.kind == .custom ? item.displayLabel : item.kind.rawValue,
                   projectLabel: cwd?.label ?? item.displayPath,
                   rssKB: item.rssKB,
                   timestamp: Date())
    }

    // MARK: - Kill lifecycle (PID-62.5)

    /// How long a row keeps showing its kill's final phase ("gone", "didn't die", …)
    /// before it returns to normal — or, for a process that's gone, leaves the list.
    static let killFeedbackLinger: TimeInterval = 3

    /// One row's kill, in flight or just answered. `startTime` is the scan-time
    /// identity, so a recycled PID doesn't inherit the state; `token` identifies the
    /// kill that set it, so an older kill's linger timer can't clear a newer one.
    struct KillStatus {
        let startTime: ProcStartTime?
        let phase: KillPhase
        let token: Int
    }

    /// Per-row kill state, keyed by pid (PID-62.5). Survives intervening scans —
    /// a timer scan landing mid-kill re-lists the row, and the row keeps saying
    /// "killing…". Cleared `killFeedbackLinger` after the final phase.
    @Published private(set) var killStatuses: [Int32: KillStatus] = [:]

    /// Rows whose process is verified gone, kept only for the linger window so the
    /// user sees the verdict before the row leaves (PID-62.5). The popover renders
    /// them beside `items`; they're never counted, swept, or logged.
    @Published private(set) var departedItems: [Int32: ProcessItem] = [:]

    private var killToken = 0

    /// Where `item`'s kill stands, if it has one on this identity.
    func killPhase(for item: ProcessItem) -> KillPhase? {
        guard let status = killStatuses[item.pid], status.startTime == item.startTime else { return nil }
        return status.phase
    }

    /// The one kill path every trigger rides on — row ✕, ⌘⌫, Clean all, and the
    /// headless sweep (PID-62.5). Marks each row `.killing`, kills through
    /// `KillService` (SIGTERM → 2 s → SIGKILL, verified), logs confirmed deaths and
    /// arms respawn watches, then rescans and checks each verified death against
    /// its pre-kill respawn count: back already means `.respawned`, not `.gone`.
    /// `completion` gets the honest tally on the main thread once that scan has
    /// published. Must be called on the main thread; never kills without an
    /// explicit trigger.
    func kill(_ targets: [ProcessItem], completion: @escaping (KillReport) -> Void = { _ in }) {
        guard !targets.isEmpty else {
            completion(KillReport(items: [], phases: [:]))
            return
        }
        killToken += 1
        let token = killToken
        let startedAt = Date()
        // Snapshot the cwds now: a scan during the kill can drop a dead process's
        // entry, which would strip the cwd from its signature and clean-log label.
        let preKillCwds = cwds.filter { pid, _ in targets.contains { $0.pid == pid } }
        let signatures = Dictionary(uniqueKeysWithValues: targets.map {
            ($0.pid, signature(for: $0, cwd: preKillCwds[$0.pid]))
        })
        targets.forEach { setKillPhase(.killing, for: $0, token: token) }
        KillService.kill(targets, containerOwners: containerOwners) { [weak self] outcomes in
            guard let self else { return }
            // Before arming and before the rescan, so the counts don't yet include
            // this kill.
            let baselines = Dictionary(uniqueKeysWithValues: Set(signatures.values).map {
                ($0, self.respawnHistory.respawnCount(for: $0))
            })
            self.recordCleaned(targets, outcomes: outcomes, preKillCwds: preKillCwds, killStartedAt: startedAt)
            var phases = outcomes.mapValues(KillPhase.init)
            for item in targets {
                guard let phase = phases[item.pid] else { continue }
                self.setKillPhase(phase, for: item, token: token)
                if phase.isDeparted { self.departedItems[item.pid] = item }
            }
            self.scan { [weak self] in
                guard let self else { return }
                // Each new respawn is attributed to one killed row: two identical
                // processes killed together share one watch, so a single comeback
                // raises the count once and must not mark both rows respawned.
                var unclaimed = Dictionary(uniqueKeysWithValues: Set(signatures.values).map {
                    ($0, self.respawnHistory.respawnCount(for: $0) - (baselines[$0] ?? 0))
                })
                for item in targets where phases[item.pid] == .gone {
                    guard let signature = signatures[item.pid], unclaimed[signature, default: 0] > 0 else { continue }
                    unclaimed[signature, default: 0] -= 1
                    phases[item.pid] = .respawned
                    self.setKillPhase(.respawned, for: item, token: token)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.killFeedbackLinger) { [weak self] in
                    self?.clearKillFeedback(targets, token: token)
                }
                completion(KillReport(items: targets, phases: phases))
            }
        }
    }

    private func setKillPhase(_ phase: KillPhase, for item: ProcessItem, token: Int) {
        killStatuses[item.pid] = KillStatus(startTime: item.startTime, phase: phase, token: token)
    }

    /// Drop the feedback a kill left behind, unless a newer kill of the same row
    /// has since replaced it.
    private func clearKillFeedback(_ targets: [ProcessItem], token: Int) {
        for item in targets where killStatuses[item.pid]?.token == token {
            killStatuses[item.pid] = nil
            departedItems[item.pid] = nil
        }
    }

    // MARK: - Headless clean action (PID-58.2)

    /// Whether `item`'s resolved working directory sits under a protected project
    /// tree (PID-54.4) — the engine-side SSOT for the protected overlay. Both the
    /// popover ("Clean all") and the headless sweep read it, so the predicate can't
    /// drift between surfaces. False when the cwd didn't resolve.
    func isProtected(_ item: ProcessItem) -> Bool {
        guard let cwd = cwds[item.pid]?.fullPath else { return false }
        return protectedProjects.contains { CwdResolver.isUnderPrefix(cwd, $0) }
    }

    /// Whether `item` belongs in a bulk sweep at all: not protected (PID-54.4), and
    /// something Pidlyse can honestly kill (PID-62.3). The engine-side SSOT for the
    /// sweep predicate — `sweepableSafeItems` below and the popover's filtered variant
    /// both call it, so a row that shows no kill button can't still be swept by
    /// "Clean all" — nor can a row showing its kill's phase in place of the button.
    func isSweepable(_ item: ProcessItem) -> Bool {
        // A row already being killed — or just answered — isn't swept again (PID-62.5).
        !isProtected(item) && killability(item) == .killable && killPhase(for: item) == nil
    }

    /// The "Clean all safe" sweep set: safe bucket minus protected projects
    /// (PID-54.4) and minus rows we can't honestly kill (PID-62.3). Engine-side SSOT
    /// shared by the popover button (which folds in its quick-filter on top) and every
    /// external trigger (URL scheme, AppIntents) — the same set the CLI's
    /// `commandClean()` derives.
    var sweepableSafeItems: [ProcessItem] {
        items.filter { $0.bucket == .safe && isSweepable($0) }
    }

    /// Headless "Clean all safe": kill the sweepable set through the one kill path
    /// and report what actually happened. The shared action layer every external
    /// trigger rides on (PID-58.2) — the same set the CLI's `commandClean()` derives.
    /// Must be called on the main thread; `completion` fires on the main thread once
    /// every kill is verified and the follow-up scan has published.
    func cleanAllSafe(completion: @escaping (KillReport) -> Void = { _ in }) {
        kill(sweepableSafeItems, completion: completion)
    }

    /// Post a system notification summarising a headless clean (PID-58.2). Unlike
    /// the new-stray notification, this is the *only* feedback channel for a
    /// headless `pidlyse://clean`, so it always posts and requests authorization
    /// on demand if not yet determined — independent of the `notificationsEnabled`
    /// setting (which stays scoped to new-stray scan notifications). Silently
    /// no-ops if the user has denied notifications.
    func fireCleanResultNotification(_ report: KillReport) {
        let content = UNMutableNotificationContent()
        if report.requested == 0 {
            content.title = "Nothing to clean"
            content.body = "No unprotected safe-to-clean processes."
        } else {
            content.title = report.headline
            content.body = report.details
        }
        content.sound = .default

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let post = {
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                center.add(request)
            }
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { post() }
                }
            } else {
                post()
            }
        }
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

    // MARK: - Respawn detection (PID-62.2)

    /// A process's logical identity, built from its command line plus the scan-time
    /// working directory. Single source of the signature so the kill hook and the
    /// scan feed can't derive it differently.
    private func signature(for item: ProcessItem) -> RespawnHistory.Signature {
        signature(for: item, cwd: cwds[item.pid])
    }

    /// The same signature from an explicit cwd — the kill path passes the one it
    /// snapshotted before signalling (PID-62.5).
    private func signature(for item: ProcessItem, cwd: ProcessCwd?) -> RespawnHistory.Signature {
        RespawnHistory.Signature(command: item.command, cwd: cwd?.fullPath)
    }

    /// Start watching for a verified-dead process coming back under a new PID.
    /// Called from `recordCleaned` on the main thread with the cwd snapshotted when
    /// the kill began, so the signature matches what the process had before it died.
    private func armRespawnWatch(_ item: ProcessItem, cwd: ProcessCwd?, killStartedAt: Date) {
        respawnHistory = respawnHistory.recordingKill(signature: signature(for: item, cwd: cwd),
                                                      pid: item.pid,
                                                      startTime: item.startTime,
                                                      at: killStartedAt)
    }

    /// Fold the completed scan into the respawn cache — a watched signature seen
    /// again under a different identity counts as a respawn. Called on the main
    /// thread from the scan-publish block, after `cwds` is published.
    private func recordRespawnHistory(_ items: [ProcessItem]) {
        respawnHistory = respawnHistory.recording(items.map {
            RespawnHistory.Observation(pid: $0.pid,
                                       startTime: $0.startTime,
                                       signature: signature(for: $0))
        }, at: Date())
    }

    /// Whether this process has already come back after a verified kill this session
    /// (PID-62.2) — something restarts it, so killing it again won't stick. Advisory
    /// only; `PID-62.3` / `PID-62.5` own how it reaches the user. Never influences
    /// the risk tier / bucket / kill bar.
    func isRespawner(_ item: ProcessItem) -> Bool {
        respawnHistory.isRespawner(signature(for: item))
    }

    // MARK: - Killability overlay (PID-62.3)

    /// Whether an actual kill attempt on *this* identity came back `EPERM` this
    /// session. Identity-checked against the scan-time start time, so a recycled PID
    /// starts clean rather than inheriting the previous occupant's verdict.
    private func wasKillDenied(_ item: ProcessItem) -> Bool {
        guard let denied = killDeniedIdentities[item.pid] else { return false }
        return denied == item.startTime
    }

    /// Whether Pidlyse can honestly offer to kill this row — and if not, why, in a
    /// sentence the user can act on (PID-62.3). Folds the scan-time owner uid, the
    /// session's observed `EPERM`s, the respawn signal (PID-62.2), and the
    /// container/ancestor attribution into the pure `PidlyseCore.Killability`
    /// derivation. An **overlay**: it removes an affordance and adds an explanation,
    /// but never touches the risk tier, the bucket, or the classification.
    func killability(_ item: ProcessItem) -> Killability {
        let respawner = isRespawner(item)
        // A container root stopped via `docker stop` needs no signal permission, so
        // its owner uid says nothing about whether the kill will work. A group row
        // answers for every member it would kill (PID-62.4).
        let ownerUID = KillCore.routesViaDockerStop(item, containerOwners: containerOwners)
            ? nil : Killability.groupOwnerUID(item, currentUID: currentUID)
        // Attribution is only needed for the respawner sentence, so the common
        // killable row doesn't pay for an ancestor walk.
        let manager = respawner
            ? Killability.manager(ancestors: AncestryResolver.ancestorChain(ofPPID: item.ppid,
                                                                           in: processTable),
                                  containerOwner: containerOwners[item.pid])
            : nil
        return Killability.derive(ownerUID: ownerUID,
                                  currentUID: currentUID,
                                  killDenied: wasKillDenied(item),
                                  isRespawner: respawner,
                                  manager: manager)
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
