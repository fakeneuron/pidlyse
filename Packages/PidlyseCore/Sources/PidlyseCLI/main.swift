import Foundation
import PidlyseCore

// pidlyse — terminal companion to the Pidlyse menu bar app (PID-EPIC-57).
// A thin impure shell over PidlyseCore: reads the app's defaults domain for
// full rule parity, replicates ScanEngine's scan pipeline, and routes kills
// through the same KillCore path (SIGTERM → 2 s grace → SIGKILL, identity
// guards, docker-stop routing) the app uses. One-shot by design — it never
// kills without an explicit `clean` / `kill` invocation, and confirmed kills
// append to the same clean-log the app's "Cleaned" tab reads.
//
// The pure command grammar + table formatting live in PidlyseCore.CLICore
// (tested from PidlyseTests); only orchestration and I/O live here.

/// The app's preferences domain (its bundle identifier) — the CLI reads the
/// same settings the app's Settings window writes, so the two surfaces can
/// never disagree on what counts as a stray.
private let defaultsDomain = "com.fakeneuron.pidlyse"

/// The scan-relevant slice of the app's settings, read once per invocation.
/// `scanInterval` / `notificationsEnabled` are app-lifecycle settings with no
/// CLI meaning; the app's `dismissedPIDs` are session-only (never persisted),
/// so a one-shot CLI correctly has no dismissed set.
private struct Settings {
    let elapsedThreshold: TimeInterval
    let globalIgnores: [String]
    let scopedIgnores: [IgnoreRule]
    let disabledKinds: Set<ProcessKind>
    let customRules: [CustomRule]
    let protectedProjects: [String]

    static func load() -> Settings {
        let ud = UserDefaults(suiteName: defaultsDomain)
        let savedThreshold = ud?.double(forKey: "elapsedThreshold") ?? 0
        // Same split as ScanEngine.scan(): global substrings filter inside
        // `enumerate`; scoped `substring @ prefix` rules need the cwd map and
        // apply as a post-filter (PID-54.4).
        let ignoreRules = (ud?.stringArray(forKey: "ignoredNames") ?? []).compactMap(IgnoreRule.parse)
        return Settings(
            elapsedThreshold: savedThreshold > 0 ? savedThreshold : ScanCore.defaultElapsedThreshold,
            globalIgnores: ignoreRules.filter { $0.pathPrefix == nil }.map { $0.substring },
            scopedIgnores: ignoreRules.filter { $0.pathPrefix != nil },
            disabledKinds: Set((ud?.stringArray(forKey: "disabledKinds") ?? []).compactMap(ProcessKind.init(rawValue:))),
            customRules: (ud?.stringArray(forKey: "customRules") ?? []).compactMap(CustomRule.parse),
            protectedProjects: ud?.stringArray(forKey: "protectedProjects") ?? [])
    }
}

/// One completed scan, in ScanEngine.scan()'s pipeline order: port listeners →
/// container owners → enumerate (with the PID-35.3 start-time token) → cwd
/// resolution → scoped ignores. `protectedPIDs` is the view-side protected
/// overlay resolved eagerly (the CLI has no reactive layer to defer it to).
private struct ScanResult {
    let items: [ProcessItem]
    let cwds: [Int32: ProcessCwd]
    let containerOwners: [Int32: String]
    let protectedPIDs: Set<Int32>
}

private func runScan(_ settings: Settings) -> ScanResult {
    let portMap = PortRegistry.listeningPorts()
    let owners = DockerService.containerOwners()
    let result = ScanCore.enumerate(elapsedThreshold: settings.elapsedThreshold,
                                    registeredPIDs: Set(portMap.keys),
                                    ignoredNames: settings.globalIgnores,
                                    disabledKinds: settings.disabledKinds,
                                    customRules: settings.customRules,
                                    startTimeProvider: KillCore.startTime)
    let cwdMap = CwdResolver.processCwds(forPIDs: result.map { $0.pid })
    let filtered = ScanCore.applyScopedIgnores(result, cwds: cwdMap, rules: settings.scopedIgnores)
    let protectedPIDs = Set(filtered.filter { item in
        guard let cwd = cwdMap[item.pid]?.fullPath else { return false }
        return settings.protectedProjects.contains { CwdResolver.isUnderPrefix(cwd, $0) }
    }.map { $0.pid })
    return ScanResult(items: filtered, cwds: cwdMap, containerOwners: owners, protectedPIDs: protectedPIDs)
}

/// Kill `items` concurrently and block until every grace period resolves —
/// the CLI's run-loop-free equivalent of KillService's bulk shape (DispatchGroup
/// + global queue), so a multi-item `clean` doesn't serialize 2 s graces.
private func killAll(_ items: [ProcessItem], containerOwners: [Int32: String]) -> [Int32: KillCore.KillOutcome] {
    let group = DispatchGroup()
    let lock = NSLock()
    var outcomes: [Int32: KillCore.KillOutcome] = [:]
    for item in items {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = KillCore.kill(item, containerOwners: containerOwners)
            lock.lock()
            outcomes[item.pid] = outcome
            lock.unlock()
            group.leave()
        }
    }
    group.wait()
    return outcomes
}

/// Append confirmed kills to the shared clean-log — same rules as
/// `ScanEngine.recordCleaned`: only `.confirmed` outcomes are logged
/// (PID-53.2), a custom-rule match persists its friendly label as the kind,
/// and the project label falls back to the executable `displayPath`.
private func recordCleaned(_ items: [ProcessItem],
                           outcomes: [Int32: KillCore.KillOutcome],
                           cwds: [Int32: ProcessCwd]) {
    let events = items.filter { outcomes[$0.pid] == .confirmed }.map { item in
        CleanEvent(kind: item.kind == .custom ? item.displayLabel : item.kind.rawValue,
                   projectLabel: cwds[item.pid]?.label ?? item.displayPath,
                   rssKB: item.rssKB,
                   timestamp: Date())
    }
    CleanLogFile.append(events)
}

private func printErr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

// MARK: - Commands

private func commandList(safeOnly: Bool) -> Int32 {
    let scan = runScan(Settings.load())
    let items = safeOnly ? scan.items.filter { $0.bucket == .safe } : scan.items
    guard !items.isEmpty else {
        print(safeOnly ? "No safe-to-clean processes." : "No stray candidates.")
        return 0
    }
    print(CLICore.listTable(items: items, cwds: scan.cwds, protectedPIDs: scan.protectedPIDs))
    return 0
}

private func commandClean() -> Int32 {
    let scan = runScan(Settings.load())
    // The app's "Clean all" sweep set: safe bucket minus protected (PID-54.4).
    let sweepable = scan.items.filter { $0.bucket == .safe && !scan.protectedPIDs.contains($0.pid) }
    guard !sweepable.isEmpty else {
        print("Nothing to clean — no unprotected safe-bucket processes.")
        return 0
    }
    let outcomes = killAll(sweepable, containerOwners: scan.containerOwners)
    recordCleaned(sweepable, outcomes: outcomes, cwds: scan.cwds)
    for item in sweepable {
        let mark = outcomes[item.pid] == .confirmed ? "✓ killed    " : "✗ not killed"
        print("\(mark)  \(item.pid)  \(item.displayLabel)  \(scan.cwds[item.pid]?.label ?? item.displayPath)")
    }
    let confirmed = sweepable.filter { outcomes[$0.pid] == .confirmed }
    let reclaimedKB = confirmed.reduce(0) { $0 + $1.rssKB }
    print("Cleaned \(confirmed.count)/\(sweepable.count) · \(CLICore.formatRSS(kb: reclaimedKB)) reclaimed")
    return 0
}

private func commandKill(pid: Int32) -> Int32 {
    let scan = runScan(Settings.load())
    // Only scanned candidates are killable: the identity token + classification
    // exist only for items the scan surfaced, and refusing arbitrary PIDs keeps
    // the tool scoped to what `pidlyse list` shows (any bucket — an explicit
    // per-PID kill mirrors the app's per-row kill button, protection included).
    guard let item = scan.items.first(where: { $0.pid == pid }) else {
        printErr("pidlyse: PID \(pid) is not a scan candidate — only processes `pidlyse list` surfaces can be killed")
        return 1
    }
    let outcome = KillCore.kill(item, containerOwners: scan.containerOwners)
    recordCleaned([item], outcomes: [pid: outcome], cwds: scan.cwds)
    switch outcome {
    case .confirmed:
        print("✓ killed  \(pid)  \(item.displayLabel)  \(scan.cwds[pid]?.label ?? item.displayPath)")
        return 0
    case .survived:
        printErr("pidlyse: PID \(pid) survived — SIGTERM and SIGKILL delivered, process still running")
        return 1
    case .notKilled:
        printErr("pidlyse: PID \(pid) not killed — gone, recycled since the scan, or owned by another user")
        return 1
    }
}

// MARK: - Entry

switch CLICore.parse(Array(CommandLine.arguments.dropFirst())) {
case .success(.help):
    print(CLICore.usage)
    exit(0)
case .success(.list(let safeOnly)):
    exit(commandList(safeOnly: safeOnly))
case .success(.clean):
    exit(commandClean())
case .success(.kill(let pid)):
    exit(commandKill(pid: pid))
case .failure(let error):
    printErr("pidlyse: \(CLICore.message(for: error))\n\n\(CLICore.usage)")
    exit(64) // EX_USAGE
}
