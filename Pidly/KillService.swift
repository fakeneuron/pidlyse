import Foundation

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

    /// Terminate one process. Docker items route through `docker stop` first;
    /// all others (and Docker fallback) use SIGTERM → grace → SIGKILL. EPERM
    /// is handled silently: `onComplete` fires and the next rescan reflects the
    /// unchanged process. `onComplete` always fires on the main queue.
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

    /// Whether a process is still alive. `kill(pid, 0)` sends no signal but
    /// returns 0 only while the process exists (−1/ESRCH once it is gone).
    static func isAlive(_ pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0
    }

    // MARK: - POSIX signal path

    private static func killPosix(_ pid: Int32, onComplete: @escaping () -> Void) {
        let result = Darwin.kill(pid, SIGTERM)
        if result == -1 && errno == EPERM {
            // Process is owned by another user (e.g. root Docker daemon).
            // Fire onComplete so the caller rescans; the process will reappear,
            // indicating to the user that it cannot be killed without privileges.
            DispatchQueue.main.async { onComplete() }
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) {
            if isAlive(pid) {
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

    /// Try to stop the container that owns `pid` via `docker stop`. Returns
    /// `true` if a container was found and stopped successfully.
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
        let listTask = Process()
        listTask.executableURL = URL(fileURLWithPath: docker)
        listTask.arguments = ["ps", "-q"]
        let listPipe = Pipe()
        listTask.standardOutput = listPipe
        listTask.standardError = Pipe()
        guard (try? listTask.run()) != nil else { return nil }
        let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
        listTask.waitUntilExit()
        guard let listOutput = String(data: listData, encoding: .utf8) else { return nil }

        for id in listOutput.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) {
            if containerPID(docker: docker, containerID: id) == pid { return id }
        }
        return nil
    }

    /// Return the root PID of a running container via `docker inspect`.
    private static func containerPID(docker: String, containerID: String) -> Int32? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: docker)
        task.arguments = ["inspect", "--format", "{{.State.Pid}}", containerID]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Run `docker stop <containerID>`. Returns `true` on exit status 0.
    private static func dockerStop(docker: String, containerID: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: docker)
        task.arguments = ["stop", containerID]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return false }
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}
