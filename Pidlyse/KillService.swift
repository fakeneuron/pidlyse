import Foundation
import PidlyseCore

/// Thin async wrapper over the shared `KillCore` kill path (SIGTERM → 2 s grace
/// → SIGKILL with PID-reuse identity guards, docker-stop routing, EPERM →
/// `.unkillable`). The blocking core call runs on a background queue and every
/// `onComplete` fires on the main queue, so SwiftUI callers never block. All
/// kill semantics live in `PidlyseCore.KillCore` (shared with the
/// cli-companion binary, PID-EPIC-57); this file owns only the queue hops.
///
/// Per CLAUDE.md: the grace period is never skipped, and a kill only ever runs
/// from an explicit user action. Kill logic lives here (not `ScanEngine`).
enum KillService {
    /// Kill outcome, re-exported so `ScanEngine.recordCleaned` keeps its call
    /// shape (PID-53.2 — only `.confirmed` deaths are logged).
    typealias KillOutcome = KillCore.KillOutcome

    /// The process-identity token (PID-18.3, PID-35.3), re-exported for the
    /// existing `KillService.ProcStartTime` call shape.
    typealias ProcStartTime = PidlyseCore.ProcStartTime

    /// Terminate one process. Routing (docker stop vs POSIX signals) and the
    /// grace period happen inside the blocking `KillCore.kill`, dispatched to a
    /// background queue here. `onComplete` always fires on the main queue.
    /// `containerOwners` is the `ScanEngine.containerOwners` cache; an empty map
    /// (its default) means no container resolution is available and docker items
    /// fall through to POSIX.
    static func kill(_ item: ProcessItem, containerOwners: [Int32: String] = [:],
                     onComplete: @escaping (KillOutcome) -> Void = { _ in }) {
        DispatchQueue.global().async {
            let outcome = KillCore.kill(item, containerOwners: containerOwners)
            DispatchQueue.main.async { onComplete(outcome) }
        }
    }

    /// Terminate many processes concurrently; each follows the same per-item
    /// routing and shares the same scan-time `containerOwners` map. `onComplete`
    /// fires once, on the main queue, after every kill has resolved.
    static func kill(_ items: [ProcessItem], containerOwners: [Int32: String] = [:],
                     onComplete: @escaping ([Int32: KillOutcome]) -> Void = { _ in }) {
        guard !items.isEmpty else { onComplete([:]); return }
        let group = DispatchGroup()
        // Every per-item `onComplete` fires on the main queue (the single-item
        // wrapper above), so this dictionary is mutated single-threaded — no lock
        // needed.
        var outcomes: [Int32: KillOutcome] = [:]
        for item in items {
            group.enter()
            kill(item, containerOwners: containerOwners) { outcome in
                outcomes[item.pid] = outcome
                group.leave()
            }
        }
        group.notify(queue: .main) { onComplete(outcomes) }
    }
}
