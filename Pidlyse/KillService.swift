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

    // MARK: - Public kill API

    /// Terminate one process. Docker items whose PID is a container root process
    /// route through `docker stop` first; docker daemon/helper PIDs and all other
    /// processes use SIGTERM → grace → SIGKILL. EPERM is handled silently:
    /// `onComplete` fires and the next rescan reflects the unchanged process.
    /// `onComplete` always fires on the main queue.
    static func kill(_ item: ProcessItem, onComplete: @escaping () -> Void = {}) {
        if item.kind == .docker {
            DispatchQueue.global().async {
                if dockerStopByPID(item.pid) {
                    DispatchQueue.main.async { onComplete() }
                    return
                }
                killPosix(item.pid, expected: item.startTime, onComplete: onComplete)
            }
            return
        }
        killPosix(item.pid, expected: item.startTime, onComplete: onComplete)
    }

    /// Terminate many processes concurrently; each follows the same per-item
    /// routing. `onComplete` fires once, on the main queue, after every kill
    /// has resolved.
    static func kill(_ items: [ProcessItem], onComplete: @escaping () -> Void = {}) {
        guard !items.isEmpty else { onComplete(); return }
        let group = DispatchGroup()
        for item in items {
            group.enter()
            kill(item) { group.leave() }
        }
        group.notify(queue: .main) { onComplete() }
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
                                  onComplete: @escaping () -> Void) {
        // Re-verify identity before SIGTERM: a PID recycled between the scan (when
        // `expected` was captured) and this click would otherwise take the signal.
        let current = startTime(of: pid)
        guard shouldSendSIGTERM(expected: expected, current: current) else {
            // Recycled or gone since the scan — don't signal a bystander. Fire
            // onComplete so the caller rescans and the stale row drops away.
            DispatchQueue.main.async { onComplete() }
            return
        }
        let result = Darwin.kill(pid, SIGTERM)
        if result == -1 && errno == EPERM {
            // Process is owned by another user (e.g. root Docker daemon).
            // Fire onComplete so the caller rescans; the process will reappear,
            // indicating to the user that it cannot be killed without privileges.
            DispatchQueue.main.async { onComplete() }
            return
        }
        // Reuse the just-read token as the SIGKILL-escalation snapshot (it matched
        // `expected`, so the PID still maps to the scanned process at SIGTERM time).
        let startSnapshot = current
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if shouldEscalateToSIGKILL(snapshot: startSnapshot, current: startTime(of: pid)) {
                Darwin.kill(pid, SIGKILL)
            }
            DispatchQueue.main.async { onComplete() }
        }
    }

    // MARK: - Docker stop path

    /// Try to stop the container whose root PID (`State.Pid`) matches `pid` via
    /// `docker stop`. Succeeds only when `pid` is a container's init process on
    /// the host; Docker daemon and helper PIDs never match and fall through to
    /// POSIX signals. Returns `true` if a container was found and stopped. The
    /// Docker CLI access is delegated to `DockerService` (shared with the
    /// container panel).
    private static func dockerStopByPID(_ pid: Int32) -> Bool {
        guard DockerService.isInstalled,
              let containerID = findContainerID(for: pid),
              DockerService.run(["stop", containerID]).ok else {
            return false
        }
        return true
    }

    /// Return the container ID of the running container whose root PID matches
    /// `pid`, or `nil` if no match is found. Resolves all running containers in
    /// a single `docker inspect` call (vs. one per container) to avoid O(N) CLI
    /// round-trips when many containers are running.
    private static func findContainerID(for pid: Int32) -> String? {
        let listOutput = DockerService.run(["ps", "-q"]).output
        let ids = listOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard !ids.isEmpty else { return nil }
        // Bulk inspect: each output line is "<full-id>\t<State.Pid>"; docker prints
        // nothing for IDs it can't resolve, so we parse by content, not by index.
        let inspectOutput = DockerService.run(["inspect", "--format", "{{.Id}}\t{{.State.Pid}}"] + ids).output
        for line in inspectOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t").map(String.init)
            guard parts.count == 2,
                  let containerPID = Int32(parts[1]),
                  containerPID == pid else { continue }
            return parts[0]
        }
        return nil
    }
}
