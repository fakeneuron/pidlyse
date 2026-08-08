import Foundation

/// Shared synchronous kill path: SIGTERM first, then a SIGKILL fallback after a
/// 2 s grace period if the process is still alive, then a **death check** that
/// confirms the process is actually gone before reporting success (PID-62.2).
/// Docker processes route through `docker stop` (graceful container shutdown)
/// before falling back to signals. EPERM is detected and reported as
/// `.notKilled` (the process stays visible to callers, indicating it's
/// unkillable by the current user).
///
/// The call shape is deliberately **blocking** — `kill` sleeps through the
/// grace period on the calling thread — so a run-loop-free consumer (the
/// cli-companion binary, PID-EPIC-57) can use it directly. The app's
/// `KillService` wraps it in queue hops for the SwiftUI side.
///
/// Per CLAUDE.md: the grace period is never skipped, and a kill only ever runs
/// from an explicit user action.
public enum KillCore {
    /// Grace period between SIGTERM and the SIGKILL fallback.
    public static let gracePeriod: TimeInterval = 2

    /// Settle time between the SIGKILL fallback and the death check. SIGKILL can't
    /// be caught, but teardown isn't instantaneous — probing immediately would read
    /// a dying process as alive. Only the SIGKILL branch pays it: a process that
    /// exited during the grace period is already observed gone. (PID-62.2)
    public static let verificationDelay: TimeInterval = 0.2

    /// Outcome of a kill attempt, threaded out so the clean log records only real
    /// deaths (PID-53.2). `confirmed` = the process is **verified gone** (absent,
    /// PID recycled, or an unreaped zombie) after the grace period, or `docker stop`
    /// succeeded. `survived` = our signals landed but the process is still running
    /// under the same identity after the SIGKILL fallback — rare (uninterruptible
    /// state), and the honest answer where the old contract claimed success
    /// (PID-62.2). `notKilled` = the two paths where nothing of ours killed
    /// anything: the PID was recycled/gone before SIGTERM (identity guard refused),
    /// or SIGTERM hit EPERM (foreign owner, e.g. the root Docker daemon).
    ///
    /// Only `confirmed` is logged as a clean — excluding the other two keeps
    /// "RAM reclaimed" honest. A process that *does* die but comes back under a new
    /// PID is still `confirmed` here; that is respawn, tracked by `RespawnHistory`.
    public enum KillOutcome {
        case confirmed
        case survived
        case notKilled
    }

    // MARK: - Public kill API

    /// Terminate one process, blocking through the grace period. Docker items
    /// whose PID maps to a container root process (per the scan-time
    /// `containerOwners` map) route through `docker stop` first; docker
    /// daemon/helper PIDs and all other processes use SIGTERM → grace → SIGKILL.
    /// `containerOwners` is the scan-time owner cache; an empty map (its default)
    /// means no container resolution is available and docker items fall through
    /// to POSIX.
    public static func kill(_ item: ProcessItem, containerOwners: [Int32: String] = [:]) -> KillOutcome {
        if item.kind == .docker, dockerStopByName(containerOwners[item.pid]) {
            return .confirmed
        }
        return killPosix(item.pid, expected: item.startTime)
    }

    // MARK: - Process identity (PID-reuse guard)

    /// Read a process's start time (`kinfo_proc.kp_proc.p_starttime`) via `sysctl`,
    /// or `nil` if the process no longer exists or can't be queried (the kernel
    /// returns a zero-length result for an unknown PID). A zombie still has a
    /// process-table entry, so this reports its original start time — the death
    /// check below is what treats that state as dead. (PID-18.3, PID-35.3)
    public static func startTime(of pid: Int32) -> ProcStartTime? {
        procInfo(of: pid).map { ProcStartTime(sec: Int($0.kp_proc.p_starttime.tv_sec),
                                              usec: Int($0.kp_proc.p_starttime.tv_usec)) }
    }

    /// One `sysctl` read of a PID's process-table entry, or `nil` when the kernel
    /// has no entry for it. Shared by `startTime(of:)` and the death check so the
    /// `sysctl` call shape lives in one place. (PID-62.2)
    private static func procInfo(of pid: Int32) -> kinfo_proc? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0, size > 0 else { return nil }
        return info
    }

    /// Whether the SIGKILL fallback should fire after the grace period. SIGKILL
    /// only when both readings are present AND identical: a missing `current`
    /// means the process already exited (nothing to kill), and a mismatch means
    /// the PID was recycled for a different process (killing it would hit an
    /// innocent bystander). A missing `snapshot` — identity never established at
    /// SIGTERM time — is treated conservatively as "do not escalate".
    public static func shouldEscalateToSIGKILL(snapshot: ProcStartTime?, current: ProcStartTime?) -> Bool {
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
    public static func shouldSendSIGTERM(expected: ProcStartTime?, current: ProcStartTime?) -> Bool {
        guard let expected else { return true }
        guard let current else { return false }
        return expected == current
    }

    // MARK: - Death check (PID-62.2)

    /// Whether the process we signalled is *still running*, given the identity token
    /// captured at SIGTERM time (`snapshot`) and the process-table state read after
    /// the SIGKILL fallback. The decision half of the death check, kept pure so the
    /// truth table is testable without spawning processes:
    /// - `current == nil` → no process-table entry at all → dead.
    /// - `isZombie` → exited, just not yet reaped by its parent → dead. (Without
    ///   this a zombie's unchanged start time would read as a false `survived`.)
    /// - `snapshot == nil` → identity was never established (legacy no-token path),
    ///   so existence is all we can honestly assert → still running.
    /// - both present → still running only if it's the *same* process; a different
    ///   start time means ours died and the kernel recycled the PID.
    public static func isStillRunning(snapshot: ProcStartTime?,
                                      current: ProcStartTime?,
                                      isZombie: Bool) -> Bool {
        guard let current, !isZombie else { return false }
        guard let snapshot else { return true }
        return snapshot == current
    }

    /// Impure half of the death check: read the PID's process-table entry once and
    /// feed `isStillRunning`. `SZOMB` (`<sys/proc.h>`) is the exited-but-unreaped
    /// state; `p_stat` imports as `Int8`, so the constant is compared numerically.
    private static func isStillRunning(_ pid: Int32, snapshot: ProcStartTime?) -> Bool {
        guard let info = procInfo(of: pid) else {
            return isStillRunning(snapshot: snapshot, current: nil, isZombie: false)
        }
        let current = ProcStartTime(sec: Int(info.kp_proc.p_starttime.tv_sec),
                                    usec: Int(info.kp_proc.p_starttime.tv_usec))
        return isStillRunning(snapshot: snapshot,
                              current: current,
                              isZombie: info.kp_proc.p_stat == Int8(SZOMB))
    }

    // MARK: - POSIX signal path

    private static func killPosix(_ pid: Int32, expected: ProcStartTime?) -> KillOutcome {
        // Re-verify identity before SIGTERM: a PID recycled between the scan (when
        // `expected` was captured) and this click would otherwise take the signal.
        let current = startTime(of: pid)
        guard shouldSendSIGTERM(expected: expected, current: current) else {
            // Recycled or gone since the scan — don't signal a bystander. The caller
            // rescans and the stale row drops away. Nothing of ours killed anything
            // → notKilled (not logged).
            return .notKilled
        }
        let result = Darwin.kill(pid, SIGTERM)
        if result == -1 && errno == EPERM {
            // Process is owned by another user (e.g. root Docker daemon). The caller
            // rescans; the process will reappear, indicating to the user that it
            // cannot be killed without privileges. We killed nothing → notKilled.
            return .notKilled
        }
        // SIGTERM was delivered. Reuse the just-read token as the SIGKILL-escalation
        // snapshot (it matched `expected`, so the PID still maps to the scanned
        // process at SIGTERM time).
        let startSnapshot = current
        Thread.sleep(forTimeInterval: gracePeriod)
        guard shouldEscalateToSIGKILL(snapshot: startSnapshot, current: startTime(of: pid)) else {
            // Nothing left to escalate against — the process exited during the grace
            // period, or the PID was recycled, which means ours is gone either way.
            return .confirmed
        }
        Darwin.kill(pid, SIGKILL)
        // Verify rather than assume: pre-PID-62.2 this returned `.confirmed` on the
        // strength of having sent the signal. A kill affordance is a promise, so the
        // outcome now reports what a re-read of the process table actually shows.
        Thread.sleep(forTimeInterval: verificationDelay)
        return isStillRunning(pid, snapshot: startSnapshot) ? .survived : .confirmed
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
