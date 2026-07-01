import Foundation
import PidlyseCore

/// Safe kill wrapper: SIGTERM first, then a SIGKILL fallback after a 2 s grace
/// period if the process is still alive. Docker processes route through
/// `docker stop` (graceful container shutdown) before falling back to signals.
/// EPERM is detected and handled as a silent rescan (the process stays visible,
/// indicating it's unkillable by the current user).
///
/// Per CLAUDE.md: the grace period is never skipped, and a kill only ever runs
/// from an explicit user action. Kill logic lives here (not `ScanEngine`).
enum KillService {
    /// Grace period between SIGTERM and the SIGKILL fallback.
    static let gracePeriod: TimeInterval = 2

    /// Outcome of a kill attempt, threaded out so the clean log records only real
    /// deaths (PID-53.2). `confirmed` = we sent SIGTERM (→ process died, or was
    /// force-SIGKILL'd post-grace) or `docker stop` succeeded. `notKilled` = the
    /// two paths where nothing of ours killed anything: the PID was recycled/gone
    /// before SIGTERM (identity guard refused), or SIGTERM hit EPERM (foreign owner,
    /// e.g. the root Docker daemon). Excluding those keeps "RAM reclaimed" honest.
    enum KillOutcome {
        case confirmed
        case notKilled
    }

    // MARK: - Public kill API

    /// Terminate one process. Docker items whose PID maps to a container root
    /// process (per the scan-time `containerOwners` map) route through
    /// `docker stop` first; docker daemon/helper PIDs and all other processes
    /// use SIGTERM → grace → SIGKILL. EPERM is handled silently: `onComplete`
    /// fires and the next rescan reflects the unchanged process. `onComplete`
    /// always fires on the main queue. `containerOwners` is the
    /// `ScanEngine.containerOwners` cache; an empty map (its default) means no
    /// container resolution is available and docker items fall through to POSIX.
    static func kill(_ item: ProcessItem, containerOwners: [Int32: String] = [:],
                     onComplete: @escaping (KillOutcome) -> Void = { _ in }) {
        if item.kind == .docker {
            DispatchQueue.global().async {
                if dockerStopByName(containerOwners[item.pid]) {
                    DispatchQueue.main.async { onComplete(.confirmed) }
                    return
                }
                killPosix(item.pid, expected: item.startTime, onComplete: onComplete)
            }
            return
        }
        killPosix(item.pid, expected: item.startTime, onComplete: onComplete)
    }

    /// Terminate many processes concurrently; each follows the same per-item
    /// routing and shares the same scan-time `containerOwners` map. `onComplete`
    /// fires once, on the main queue, after every kill has resolved.
    static func kill(_ items: [ProcessItem], containerOwners: [Int32: String] = [:],
                     onComplete: @escaping ([Int32: KillOutcome]) -> Void = { _ in }) {
        guard !items.isEmpty else { onComplete([:]); return }
        let group = DispatchGroup()
        // Every per-item `onComplete` fires on the main queue (see the four dispatch
        // points below), so this dictionary is mutated single-threaded — no lock needed.
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

    // MARK: - Process identity (PID-reuse guard)

    /// The process-identity token. Defined in `PidlyseCore` so `ProcessItem` can
    /// carry a scan-time snapshot; aliased here so `KillService.ProcStartTime` and
    /// the `sysctl` reader below keep their existing call shape. (PID-18.3, PID-35.3)
    typealias ProcStartTime = PidlyseCore.ProcStartTime

    /// Read a process's start time (`kinfo_proc.kp_proc.p_starttime`) via `sysctl`,
    /// or `nil` if the process no longer exists or can't be queried (the kernel
    /// returns a zero-length result for an unknown PID).
    static func startTime(of pid: Int32) -> ProcStartTime? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0, size > 0 else { return nil }
        let tv = info.kp_proc.p_starttime
        return ProcStartTime(sec: Int(tv.tv_sec), usec: Int(tv.tv_usec))
    }

    /// Whether the SIGKILL fallback should fire after the grace period. SIGKILL
    /// only when both readings are present AND identical: a missing `current`
    /// means the process already exited (nothing to kill), and a mismatch means
    /// the PID was recycled for a different process (killing it would hit an
    /// innocent bystander). A missing `snapshot` — identity never established at
    /// SIGTERM time — is treated conservatively as "do not escalate".
    static func shouldEscalateToSIGKILL(snapshot: ProcStartTime?, current: ProcStartTime?) -> Bool {
        guard let snapshot, let current else { return false }
        return snapshot == current
    }

    /// Whether the *initial* SIGTERM should fire, given the scan-time identity token
    /// (`expected`, carried on the `ProcessItem`) and the start time re-read now
    /// (`current`). Guards the scan→click window the SIGKILL-escalation check can't
    /// see: a PID recycled between the scan and the user's click would map to an
    /// unrelated process. Rules:
    /// - `expected == nil` (no scan-time token captured) → send (legacy behavior;
    ///   nothing to enforce against, so this is never worse than pre-PID-35.3).
    /// - `expected` set, `current == nil` → don't send (the process is gone).
    /// - both set → send only when identical (same process as scanned).
    static func shouldSendSIGTERM(expected: ProcStartTime?, current: ProcStartTime?) -> Bool {
        guard let expected else { return true }
        guard let current else { return false }
        return expected == current
    }

    // MARK: - POSIX signal path

    private static func killPosix(_ pid: Int32, expected: ProcStartTime?,
                                  onComplete: @escaping (KillOutcome) -> Void) {
        // Re-verify identity before SIGTERM: a PID recycled between the scan (when
        // `expected` was captured) and this click would otherwise take the signal.
        let current = startTime(of: pid)
        guard shouldSendSIGTERM(expected: expected, current: current) else {
            // Recycled or gone since the scan — don't signal a bystander. Fire
            // onComplete so the caller rescans and the stale row drops away. Nothing
            // of ours killed anything → notKilled (not logged).
            DispatchQueue.main.async { onComplete(.notKilled) }
            return
        }
        let result = Darwin.kill(pid, SIGTERM)
        if result == -1 && errno == EPERM {
            // Process is owned by another user (e.g. root Docker daemon).
            // Fire onComplete so the caller rescans; the process will reappear,
            // indicating to the user that it cannot be killed without privileges.
            // We killed nothing → notKilled.
            DispatchQueue.main.async { onComplete(.notKilled) }
            return
        }
        // SIGTERM was delivered: the process either exits on it or is force-SIGKILL'd
        // after the grace period below → confirmed either way (PID-53.2).
        // Reuse the just-read token as the SIGKILL-escalation snapshot (it matched
        // `expected`, so the PID still maps to the scanned process at SIGTERM time).
        let startSnapshot = current
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if shouldEscalateToSIGKILL(snapshot: startSnapshot, current: startTime(of: pid)) {
                Darwin.kill(pid, SIGKILL)
            }
            DispatchQueue.main.async { onComplete(.confirmed) }
        }
    }

    // MARK: - Docker stop path

    /// Try to stop a container by name via `docker stop`. `name` is the scan-time
    /// `containerOwners` lookup for the killed PID — non-`nil` only when the PID
    /// matched a running container's root process at scan time; Docker daemon and
    /// helper PIDs (and unmatched PIDs) pass `nil` and fall through to POSIX
    /// signals. Returns `true` if the container was stopped. The Docker CLI access
    /// is delegated to `DockerService` (shared with the container panel).
    private static func dockerStopByName(_ name: String?) -> Bool {
        guard let name, DockerService.isInstalled,
              DockerService.run(["stop", name]).ok else {
            return false
        }
        return true
    }
}
