import Foundation

/// The settings one scan runs with (PID-079.6). Both consumers build one — the app
/// from its `@Published` settings, the CLI from the app's defaults domain — and hand
/// it to `ScanPipeline.run`, so neither re-derives the ignore split.
public struct ScanRequest {
    public var elapsedThreshold: TimeInterval
    /// Every parsed ignore line, global and cwd-scoped (`IgnoreRule`, PID-54.4).
    public var ignoreRules: [IgnoreRule]
    /// Session-only dismissals (app); a one-shot CLI has none.
    public var dismissedPIDs: Set<Int32>
    public var disabledKinds: Set<ProcessKind>
    public var customRules: [CustomRule]

    public init(elapsedThreshold: TimeInterval = ScanCore.defaultElapsedThreshold,
                ignoreRules: [IgnoreRule] = [],
                dismissedPIDs: Set<Int32> = [],
                disabledKinds: Set<ProcessKind> = [],
                customRules: [CustomRule] = []) {
        self.elapsedThreshold = elapsedThreshold
        self.ignoreRules = ignoreRules
        self.dismissedPIDs = dismissedPIDs
        self.disabledKinds = disabledKinds
        self.customRules = customRules
    }

    /// The bare-substring ignores, which hide matches inside `enumerate`. Scoped
    /// rules need the cwd map, so they apply after it (`ScanCore.applyScopedIgnores`).
    public var globalIgnores: [String] {
        ignoreRules.filter { $0.pathPrefix == nil }.map { $0.substring }
    }
}

/// Everything one scan read from the system (PID-079.6). `items` is final: global
/// and scoped ignores, disabled kinds, and dismissals are already applied — by
/// `ScanPipeline.run`, and by contract by anything else standing in for it (the
/// app's injected `scanSource`), since consumers publish `items` as-is.
public struct ScanSnapshot {
    public var items: [ProcessItem]
    public var listeningPorts: [Int32: Set<Int>]
    public var containerOwners: [Int32: String]
    public var cwds: [Int32: ProcessCwd]
    public var processTable: [Int32: ProcessNode]

    public init(items: [ProcessItem],
                listeningPorts: [Int32: Set<Int>] = [:],
                containerOwners: [Int32: String] = [:],
                cwds: [Int32: ProcessCwd] = [:],
                processTable: [Int32: ProcessNode] = [:]) {
        self.items = items
        self.listeningPorts = listeningPorts
        self.containerOwners = containerOwners
        self.cwds = cwds
        self.processTable = processTable
    }
}

/// The one scan pipeline and the sweep predicates both consumers share (PID-079.6).
/// `ScanEngine` (via its default `scanSource`) and `PidlyseCLI` each make one `run`
/// call, so the two surfaces can't disagree on what a scan finds or what a sweep
/// takes. Session facts only the app holds — respawns, `EPERM` memory, kill phases —
/// layer on top of the shared predicates in `ScanEngine`.
public enum ScanPipeline {

    /// Run one scan against the live system: one `lsof` for registered-port
    /// listeners, one bulk `docker inspect`, one `ps` enumeration, one `lsof` for
    /// cwds, optionally one `ps` for the process table, then the cwd-scoped ignores.
    /// Synchronous; callers own the queue. `includeProcessTable` feeds the stray
    /// verdict's session walk (PID-086.2) and the app's parent-chain hint (PID-52.2);
    /// only a caller that derives neither skips that `ps`.
    public static func run(_ request: ScanRequest, includeProcessTable: Bool = true) -> ScanSnapshot {
        // Resolve the registered-port listeners once: its keys feed the classifier's
        // port-demotion (so `enumerate` doesn't re-run lsof), and the full map drives
        // the per-row port hint (PID-036.3).
        let portMap = PortRegistry.listeningPorts()
        // One bulk inspect per scan; the kill path and the row hint read it instead
        // of a per-click inspect (PID-037.2).
        let owners = DockerService.containerOwners()
        // The start time lets the kill path detect a recycled PID (PID-35.3); the
        // owner uid lets a foreign-owned row show as unkillable pre-click (PID-62.3);
        // the real argv keeps a spaced path whole for the row name (PID-087).
        let items = ScanCore.enumerate(elapsedThreshold: request.elapsedThreshold,
                                       registeredPIDs: Set(portMap.keys),
                                       ignoredNames: request.globalIgnores,
                                       dismissedPIDs: request.dismissedPIDs,
                                       disabledKinds: request.disabledKinds,
                                       customRules: request.customRules,
                                       startTimeProvider: KillCore.startTime,
                                       uidProvider: KillCore.ownerUID,
                                       argvProvider: KillCore.argv)
        // One bulk lsof over the matched PIDs (PID-038).
        let cwdMap = CwdResolver.processCwds(forPIDs: items.map { $0.pid })
        // One bulk `ps` the inspector's parent chain walks to launchd (PID-52.2).
        let procTable = includeProcessTable ? AncestryResolver.processTable() : [:]
        return ScanSnapshot(items: finish(items, cwds: cwdMap, request: request),
                            listeningPorts: portMap, containerOwners: owners,
                            cwds: cwdMap, processTable: procTable)
    }

    /// The pure tail of `run`: the request's cwd-scoped ignores, which need the cwd
    /// map and so can't run inside `enumerate` (global ones already did). Split out
    /// so the tests pin which rules the pipeline applies.
    static func finish(_ items: [ProcessItem], cwds: [Int32: ProcessCwd],
                       request: ScanRequest) -> [ProcessItem] {
        ScanCore.applyScopedIgnores(items, cwds: cwds, rules: request.ignoreRules)
    }

    // MARK: - Sweep predicates

    /// Whether `item`'s resolved cwd sits under a protected project tree (PID-54.4).
    /// A view/sweep overlay, never a classification change. False when the cwd
    /// didn't resolve.
    public static func isProtected(_ item: ProcessItem,
                                   cwds: [Int32: ProcessCwd],
                                   protectedProjects: [String]) -> Bool {
        guard let cwd = cwds[item.pid]?.fullPath else { return false }
        return protectedProjects.contains { CwdResolver.isUnderPrefix(cwd, $0) }
    }

    /// Whether `item`, or any process folded into its row, listens on a registered
    /// port (PID-088). `listeningPorts` is the scan's registered-port map, so a
    /// non-empty entry is the fact. A sweep overlay like `isProtected`, never a
    /// classification change.
    public static func isPortBound(_ item: ProcessItem, listeningPorts: [Int32: Set<Int>]) -> Bool {
        ([item] + item.members).contains { !(listeningPorts[$0.pid] ?? []).isEmpty }
    }

    /// Whether a row belongs in a bulk sweep (PID-086.2): a likely stray
    /// (`StrayVerdict`) that isn't high-risk — real dev infra stays a per-row decision
    /// even when forgotten — isn't protected (PID-54.4), isn't bound to a registered
    /// port (PID-088: a dev server on a reserved port is the stray signal's least
    /// trustworthy case, so it stays a per-row decision too), and is something Pidlyse
    /// can honestly kill (PID-62.3). The bucket no longer gates the sweep; it stays
    /// the kill-safety model inside `riskTier`.
    public static func isSweepable(verdict: StrayVerdict, riskTier: RiskTier,
                                   isProtected: Bool, isPortBound: Bool,
                                   killability: Killability) -> Bool {
        verdict.isStray && riskTier != .high && !isProtected && !isPortBound
            && killability == .killable
    }
}
