import Foundation

/// Shared synchronous kill path: SIGTERM first, then a SIGKILL fallback after a
/// 2 s grace period if the process is still alive, then a **death check** that
/// confirms the process is actually gone before reporting success (PID-62.2).
/// Docker processes route through `docker stop` (graceful container shutdown)
/// before falling back to signals. EPERM is detected and reported as
/// `.unkillable` (PID-62.3) — the process belongs to another user and no
/// signal of ours will ever reach it.
///
/// The call shape is deliberately **blocking** — `kill` sleeps through the
/// grace period on the calling thread — so a run-loop-free consumer (the
/// cli-companion binary, PID-EPIC-57) can use it directly. The app's
/// `KillService` wraps it in queue hops for the SwiftUI side.
///
/// Per AGENTS.md: the grace period is never skipped, and a kill only ever runs
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
    /// (PID-62.2). `unkillable` = SIGTERM hit EPERM: the process is owned by another
    /// user (e.g. the root Docker daemon), so no signal of ours will ever reach it
    /// and no amount of retrying changes that (PID-62.3). `notKilled` = the PID was
    /// recycled or gone before SIGTERM and the identity guard refused to signal a
    /// bystander — nothing of ours killed anything, and nothing was wrong either.
    ///
    /// Only `confirmed` is logged as a clean — excluding the other three keeps
    /// "RAM reclaimed" honest. A process that *does* die but comes back under a new
    /// PID is still `confirmed` here; that is respawn, tracked by `RespawnHistory`.
    public enum KillOutcome {
        case confirmed
        case survived
        case unkillable
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
    ///
    /// A group row (`ScanCore.collapseTrees`, PID-62.4) kills its root first, which
    /// takes a well-behaved tree down with it inside the root's grace period. Then
    /// every member runs the same identity-guarded path concurrently: one that
    /// followed its root is already gone and returns at once, and one that didn't
    /// (e.g. under a `sh -c` root that doesn't forward signals) gets its own SIGTERM →
    /// grace → SIGKILL. `groupOutcome` folds the per-member answers into the row's one
    /// outcome.
    public static func kill(_ item: ProcessItem, containerOwners: [Int32: String] = [:]) -> KillOutcome {
        if routesViaDockerStop(item, containerOwners: containerOwners),
           dockerStopByName(containerOwners[item.pid]) {
            return .confirmed
        }
        let root = killPosix(item.pid, expected: item.startTime)
        // An EPERM root is still alive and foreign-owned: signalling its members would
        // only half-kill a tree we've already said we can't kill.
        guard !item.members.isEmpty, root != .unkillable else { return root }
        var memberOutcomes = [KillOutcome](repeating: .notKilled, count: item.members.count)
        memberOutcomes.withUnsafeMutableBufferPointer { outcomes in
            DispatchQueue.concurrentPerform(iterations: item.members.count) { i in
                outcomes[i] = killPosix(item.members[i].pid, expected: item.members[i].startTime)
            }
        }
        return groupOutcome(root: root, members: memberOutcomes)
    }

    /// Fold a group kill's per-process outcomes into the row's one honest answer
    /// (PID-62.4). A member's `notKilled` means it was already gone when its turn came
    /// (it died with its root), which is exactly what a group kill wants. So:
    /// - root `unkillable` → `unkillable` (`kill` never signals the members then);
    /// - else any member still running → `survived`, including an `unkillable`
    ///   (foreign-owned) member: the root died, so remembering the row as unkillable
    ///   would pin that verdict on a dead pid, and the survivor surfaces on its own on
    ///   the next scan with its own owner-derived badge;
    /// - else `confirmed` if anything was verified killed — every member is gone;
    /// - else `notKilled` (the root's identity guard refused and nothing else was
    ///   ours to kill).
    public static func groupOutcome(root: KillOutcome, members: [KillOutcome]) -> KillOutcome {
        if root == .unkillable { return .unkillable }
        let all = [root] + members
        if all.contains(.survived) || all.contains(.unkillable) { return .survived }
        if all.contains(.confirmed) { return .confirmed }
        return .notKilled
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

    /// Read a process's **owning** user id — its *real* uid
    /// (`kinfo_proc.kp_eproc.e_pcred.p_ruid`) — or `nil` if the process no longer
    /// exists or can't be queried. Real, not effective: the kernel lets us signal a
    /// process whose real uid matches ours, so a setuid-root helper we launched
    /// ourselves (effective uid 0, real uid ours) is still killable and must not be
    /// labelled unkillable. Injected into
    /// the scan as `ScanCore`'s `uidProvider` so a row owned by another user can be
    /// shown as unkillable *before* the user clicks a dead-end button — Pidlyse runs
    /// unprivileged, so a uid that isn't ours means every signal we send hits EPERM.
    /// Rides on the same `kinfo_proc` read as `startTime(of:)`. (PID-62.3)
    public static func ownerUID(of pid: Int32) -> uid_t? {
        procInfo(of: pid).map { $0.kp_eproc.e_pcred.p_ruid }
    }

    /// Whether `kill(_:containerOwners:)` stops this item with `docker stop` rather
    /// than a signal — a docker-kind PID that is a container's root process. Such a
    /// kill needs no signal permission, so the killability overlay must not call it
    /// unkillable just because the PID is foreign-owned. (PID-62.3)
    public static func routesViaDockerStop(_ item: ProcessItem, containerOwners: [Int32: String]) -> Bool {
        item.kind == .docker && containerOwners[item.pid] != nil
    }

    /// One `sysctl` read of a PID's process-table entry, or `nil` when the kernel
    /// has no entry for it. Shared by `startTime(of:)`, `ownerUID(of:)`, and the
    /// death check so the `sysctl` call shape lives in one place. (PID-62.2)
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
            // Process is owned by another user (e.g. root Docker daemon). Pidlyse
            // never escalates, so this is permanent, not transient — reported as its
            // own outcome (PID-62.3) so the row can say so and drop its kill button
            // instead of silently reappearing on the next scan.
            return .unkillable
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
