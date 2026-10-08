import Darwin
import Foundation

/// Shared subprocess primitive for the whole codebase. Spawns `path` with
/// `args`, drains stdout on a side queue *while* the child runs (so a full
/// pipe cannot deadlock `wait`), and reports whether the process exited 0.
///
/// A caller passes its own deadline (`Budget`). On expiry the child is
/// SIGTERM'd, then SIGKILL'd if it is still alive, and this returns
/// `("", false)` — partial stdout is discarded so a parser never sees a
/// truncated `ps` / `lsof` table. Launch failure is the same tuple.
///
/// Owns the *how* of shelling out (the `Process`/`Pipe` dance); callers own the
/// *what* (which binary, which args, how to parse, which budget). Consolidated
/// here by PID-042; the deadline is PID-079.3.
public enum Shell {
    /// Per-tool deadlines. Healthy runs finish far sooner; the bound exists so
    /// a wedged `docker` daemon or a stuck `lsof` cannot pin a scan.
    public enum Budget {
        public static let ps: TimeInterval = 10
        public static let lsof: TimeInterval = 20
        public static let docker: TimeInterval = 20
    }

    /// Test-only. When set, `run` uses this deadline instead of the caller's.
    /// `0` forces the expiry path (spawn, terminate, `("", false)`).
    static var deadlineOverride: TimeInterval? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _deadlineOverride }
        set { stateLock.lock(); _deadlineOverride = newValue; stateLock.unlock() }
    }

    /// Test-only. Invoked with the child pid after a successful launch.
    static var launchObserver: ((Int32) -> Void)? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _launchObserver }
        set { stateLock.lock(); _launchObserver = newValue; stateLock.unlock() }
    }

    private static let stateLock = NSLock()
    private static var _deadlineOverride: TimeInterval?
    private static var _launchObserver: ((Int32) -> Void)?

    private static let termGrace: TimeInterval = 0.25
    private static let killGrace: TimeInterval = 0.5

    /// Returns stdout as UTF-8 (`""` on launch failure or expiry) and whether
    /// the process exited with status 0 (`false` on launch failure or expiry).
    @discardableResult
    public static func run(_ path: String, _ args: [String], timeout: TimeInterval) -> (output: String, ok: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        // Discard stderr via the null device, not an undrained Pipe(): we only ever
        // read stdout, so a captured-but-unread stderr pipe could fill its ~64 KB
        // buffer and wedge the child forever. /dev/null can't fill. (PID-35.2)
        task.standardError = FileHandle.nullDevice

        let exited = DispatchGroup()
        exited.enter()
        let leaveOnce = OnceLeave(exited)
        task.terminationHandler = { _ in leaveOnce.leave() }

        let collected = StdoutBox()
        let drained = DispatchGroup()
        drained.enter()
        // Drain concurrently. Reading only after the child exits deadlocks once
        // stdout fills the pipe; reading on this thread with no deadline cannot
        // be interrupted. The side queue unblocks when the write end closes.
        DispatchQueue.global(qos: .userInitiated).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            collected.set(data)
            drained.leave()
        }

        do {
            try task.run()
        } catch {
            leaveOnce.leave()
            try? pipe.fileHandleForWriting.close()
            _ = drained.wait(timeout: .now() + killGrace)
            return ("", false)
        }
        launchObserver?(task.processIdentifier)

        let limit = deadlineOverride ?? timeout
        if limit <= 0 || exited.wait(timeout: .now() + limit) == .timedOut {
            stop(task, exited)
            _ = drained.wait(timeout: .now() + killGrace)
            return ("", false)
        }

        if drained.wait(timeout: .now() + killGrace) == .timedOut {
            return ("", false)
        }
        let text = String(data: collected.get(), encoding: .utf8) ?? ""
        return (text, task.terminationStatus == 0)
    }

    /// SIGTERM, then SIGKILL of the direct pid if it is still alive. Callers exec
    /// the tool itself (`ps`, `lsof`, `docker`), so there is no grandchild to
    /// reap. `setpgid` after `Process.run()` returns is too late (the child has
    /// already exec'd) and is not attempted. A stale `isRunning` can in theory
    /// SIGKILL a reused pid; the check is the only guard, and the window is the
    /// grace below.
    ///
    /// The caller then waits one more `killGrace` for the stdout drain, so a
    /// timeout can outlive the budget by `termGrace + 2 * killGrace`.
    private static func stop(_ task: Process, _ exited: DispatchGroup) {
        let pid = task.processIdentifier
        if task.isRunning {
            task.terminate()
        }
        if exited.wait(timeout: .now() + termGrace) == .timedOut, task.isRunning, pid > 0 {
            kill(pid, SIGKILL)
            _ = exited.wait(timeout: .now() + killGrace)
        }
    }
}

/// `DispatchGroup.leave` is a crash if it runs twice. The termination handler
/// and the launch-failure path can both observe the end of one child.
private final class OnceLeave: @unchecked Sendable {
    private let lock = NSLock()
    private var left = false
    private let group: DispatchGroup

    init(_ group: DispatchGroup) {
        self.group = group
    }

    func leave() {
        lock.lock()
        let should = !left
        left = true
        lock.unlock()
        if should { group.leave() }
    }
}

private final class StdoutBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
