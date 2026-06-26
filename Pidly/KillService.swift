import Foundation
import PidlyCore

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
                killPosix(item.pid, onComplete: onComplete)
            }
            return
        }
        killPosix(item.pid, onComplete: onComplete)
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

    /// A process's start time, used as an identity token across the SIGTERM →
    /// SIGKILL grace window. If the original process exits and the kernel recycles
    /// its PID for an unrelated process, the start time differs — so an unchanged
    /// start time confirms the PID still maps to the *same* process.
    struct ProcStartTime: Equatable {
        let sec: Int
        let usec: Int
    }

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

    // MARK: - POSIX signal path

    private static func killPosix(_ pid: Int32, onComplete: @escaping () -> Void) {
        // Snapshot identity before SIGTERM so the grace-period SIGKILL can verify
        // the PID still maps to the same process (guards against PID reuse).
        let startSnapshot = startTime(of: pid)
        let result = Darwin.kill(pid, SIGTERM)
        if result == -1 && errno == EPERM {
            // Process is owned by another user (e.g. root Docker daemon).
            // Fire onComplete so the caller rescans; the process will reappear,
            // indicating to the user that it cannot be killed without privileges.
            DispatchQueue.main.async { onComplete() }
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if shouldEscalateToSIGKILL(snapshot: startSnapshot, current: startTime(of: pid)) {
                Darwin.kill(pid, SIGKILL)
            }
            DispatchQueue.main.async { onComplete() }
        }
    }

    // MARK: - Docker stop path

    /// Return the path to the Docker CLI, or `nil` if not installed.
    private static func dockerCLIPath() -> String? {
        let candidates = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Shell out to the Docker CLI, reading stdout to EOF before `waitUntilExit`
    /// to prevent pipe-buffer deadlock. Returns stdout as UTF-8 ("" on failure)
    /// and whether the process exited with status 0.
    private static func runDocker(_ docker: String, _ args: [String]) -> (output: String, ok: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: docker)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return ("", false) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "", task.terminationStatus == 0)
    }

    /// Try to stop the container whose root PID (`State.Pid`) matches `pid` via
    /// `docker stop`. Succeeds only when `pid` is a container's init process on
    /// the host; Docker daemon and helper PIDs never match and fall through to
    /// POSIX signals. Returns `true` if a container was found and stopped.
    private static func dockerStopByPID(_ pid: Int32) -> Bool {
        guard let docker = dockerCLIPath(),
              let containerID = findContainerID(docker: docker, for: pid),
              dockerStop(docker: docker, containerID: containerID) else {
            return false
        }
        return true
    }

    /// Return the container ID of the running container whose root PID matches
    /// `pid`, or `nil` if no match is found.
    private static func findContainerID(docker: String, for pid: Int32) -> String? {
        let listOutput = runDocker(docker, ["ps", "-q"]).output
        for id in listOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            if containerPID(docker: docker, containerID: id) == pid { return id }
        }
        return nil
    }

    /// Return the root PID of a running container via `docker inspect`
    /// (`State.Pid` — the container's init process as seen on the host).
    private static func containerPID(docker: String, containerID: String) -> Int32? {
        let output = runDocker(docker, ["inspect", "--format", "{{.State.Pid}}", containerID]).output
        return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Run `docker stop <containerID>`. Returns `true` on exit status 0.
    private static func dockerStop(docker: String, containerID: String) -> Bool {
        runDocker(docker, ["stop", containerID]).ok
    }
}
