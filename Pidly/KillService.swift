import Foundation

/// Safe kill wrapper: SIGTERM first, then a SIGKILL fallback after a 2 s grace
/// period if the process is still alive. Per CLAUDE.md the grace period is
/// **never** skipped, and a kill only ever runs from an explicit user action.
/// Kill logic lives here (not `ScanEngine`) per SPEC §"Project Structure".
///
/// Residual for [[PID-004]]: Docker processes should be stopped via `docker
/// stop`, not raw signals; that edge case is deferred. This service sends raw
/// POSIX signals to whatever PID it is handed.
enum KillService {
    /// Grace period between SIGTERM and the SIGKILL fallback.
    static let gracePeriod: TimeInterval = 2

    /// Terminate one process: SIGTERM now, SIGKILL after the grace period if it
    /// is still alive. Returns immediately; the fallback is scheduled
    /// asynchronously and `onComplete` fires on the main queue once resolved.
    static func kill(pid: Int32, onComplete: @escaping () -> Void = {}) {
        Darwin.kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if isAlive(pid) {
                Darwin.kill(pid, SIGKILL)
            }
            DispatchQueue.main.async { onComplete() }
        }
    }

    /// Terminate many processes concurrently (the "Clean all safe" path); each
    /// follows the same SIGTERM → grace → SIGKILL flow. `onComplete` fires once,
    /// on the main queue, after every kill has resolved.
    static func kill(pids: [Int32], onComplete: @escaping () -> Void = {}) {
        guard !pids.isEmpty else { onComplete(); return }
        let group = DispatchGroup()
        for pid in pids {
            group.enter()
            kill(pid: pid) { group.leave() }
        }
        group.notify(queue: .main) { onComplete() }
    }

    /// Whether a process is still alive. `kill(pid, 0)` sends no signal but
    /// returns 0 only while the process exists (−1/ESRCH once it is gone).
    static func isAlive(_ pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }
}
