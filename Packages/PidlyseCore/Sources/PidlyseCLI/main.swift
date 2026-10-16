import Foundation
import PidlyseCore

// pidlyse — terminal companion to the Pidlyse menu bar app (PID-EPIC-57).
// A thin impure shell over PidlyseCore: reads the app's defaults domain for
// full rule parity, runs the same core ScanPipeline as the app, and routes kills
// through the same KillCore path (SIGTERM → 2 s grace → SIGKILL, identity
// guards, docker-stop routing) the app uses. One-shot by design — it never
// kills without an explicit `clean` / `kill` invocation, and confirmed kills
// append to the same clean-log the app's "Cleaned" tab reads.
//
// The pure command grammar + table formatting live in PidlyseCore.CLICore
// (tested from PidlyseCoreTests); only orchestration and I/O live here.

/// The app's preferences domain (its bundle identifier) — the CLI reads the
/// same settings the app's Settings window writes, so the two surfaces can
/// never disagree on what counts as a stray.
private let defaultsDomain = "com.fakeneuron.pidlyse"

/// The scan-relevant slice of the app's settings, read once per invocation.
/// `scanInterval` / `notificationsEnabled` are app-lifecycle settings with no
/// CLI meaning; the app's `dismissedPIDs` are session-only (never persisted),
/// so a one-shot CLI correctly has no dismissed set.
private struct Settings {
    let request: ScanRequest
    let protectedProjects: [String]

    static func load() -> Settings {
        let saved = UserDefaults(suiteName: defaultsDomain).map(ScanSettings.load(from:)) ?? ScanSettings()
        return Settings(request: saved.request, protectedProjects: saved.protectedProjects)
    }
}

/// One completed scan through the shared core `ScanPipeline` (PID-079.6) — the
/// same call the app's `ScanEngine` makes, minus the process table only the app's
/// inspector reads. `protectedPIDs` is the protected overlay resolved eagerly (the
/// CLI has no reactive layer to defer it to).
private struct ScanResult {
    let items: [ProcessItem]
    let cwds: [Int32: ProcessCwd]
    let containerOwners: [Int32: String]
    let protectedPIDs: Set<Int32>
}

private func runScan(_ settings: Settings) -> ScanResult {
    let snapshot = ScanPipeline.run(settings.request, includeProcessTable: false)
    let protectedPIDs = Set(snapshot.items.filter {
        ScanPipeline.isProtected($0, cwds: snapshot.cwds, protectedProjects: settings.protectedProjects)
    }.map { $0.pid })
    return ScanResult(items: snapshot.items, cwds: snapshot.cwds,
                      containerOwners: snapshot.containerOwners, protectedPIDs: protectedPIDs)
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

/// Append confirmed kills to the shared clean-log — same rule as
/// `ScanEngine.recordCleaned`: only `.confirmed` outcomes are logged (PID-53.2),
/// each built by the shared `CleanEvent(item:cwd:)` (PID-079.6).
private func recordCleaned(_ items: [ProcessItem],
                           outcomes: [Int32: KillCore.KillOutcome],
                           cwds: [Int32: ProcessCwd]) {
    let events = items.filter { outcomes[$0.pid] == .confirmed }.map { item in
        CleanEvent(item: item, cwd: cwds[item.pid])
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
    // The app's "Clean all" sweep set: safe bucket, minus protected (PID-54.4), minus
    // foreign-owned processes no signal of ours can reach (PID-62.3). The app also
    // excludes known respawners, which a one-shot CLI has no session memory of — the
    // respawn half of the overlay stays app-only (PID-62.1 clarification #4). The
    // predicate itself is the app's, shared through core (PID-079.6).
    let currentUID = getuid()
    let sweepable = scan.items.filter {
        $0.bucket == .safe
            && ScanPipeline.isSweepable(
                isProtected: scan.protectedPIDs.contains($0.pid),
                killability: Killability.derive(for: $0, containerOwners: scan.containerOwners,
                                                currentUID: currentUID,
                                                killDenied: false, isRespawner: false, manager: nil))
    }
    guard !sweepable.isEmpty else {
        print("Nothing to clean — no unprotected, killable safe-bucket processes.")
        return 0
    }
    let outcomes = killAll(sweepable, containerOwners: scan.containerOwners)
    recordCleaned(sweepable, outcomes: outcomes, cwds: scan.cwds)
    // Same phase labels and tally as the app (PID-62.5). No respawn check: a
    // one-shot CLI has no follow-up scan or session memory to detect one.
    let phases = outcomes.mapValues(KillPhase.init)
    for item in sweepable {
        let phase = phases[item.pid]
        let mark = (phase == .gone ? "✓ " : "✗ ") + (phase?.label ?? "?").padding(toLength: 10, withPad: " ", startingAt: 0)
        print("\(mark)  \(item.pid)  \(item.displayLabel)  \(scan.cwds[item.pid]?.label ?? item.displayPath)")
    }
    let report = KillReport(items: sweepable, phases: phases)
    print(report.summaryLine)
    return CLICore.cleanExitStatus(report: report)
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
    case .unkillable:
        printErr("pidlyse: PID \(pid) is owned by another user — pidlyse never escalates, so no signal of ours reaches it")
        return 1
    case .notKilled:
        printErr("pidlyse: PID \(pid) not killed — gone or recycled since the scan")
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
