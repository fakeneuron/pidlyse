import Foundation
import PidlyCore

/// Shared app-side access to the Docker CLI: path resolution, a single
/// shell-out primitive, and a running-container listing. Owns the impure
/// `docker` invocations (extracted from `KillService`) so the kill path and the
/// upcoming container panel share one code path; the pure parsing lives in
/// `PidlyCore.DockerCore` (mirrors the `ScanEngine` / `ScanCore` split).
enum DockerService {
    /// Path to the Docker CLI, or `nil` if not installed.
    static func cliPath() -> String? {
        let candidates = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Whether the Docker CLI is available on this machine.
    static var isInstalled: Bool { cliPath() != nil }

    /// Shell out to the Docker CLI, reading stdout to EOF before `waitUntilExit`
    /// to prevent pipe-buffer deadlock. Returns stdout as UTF-8 and whether the
    /// process exited with status 0; `("", false)` when Docker is not installed
    /// or the launch fails.
    @discardableResult
    static func run(_ args: [String]) -> (output: String, ok: Bool) {
        guard let docker = cliPath() else { return ("", false) }
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

    /// List running containers via `docker ps`. Returns an empty array when
    /// Docker is absent or the command fails.
    static func listContainers() -> [Container] {
        let result = run(["ps", "--format", DockerCore.psFormat])
        guard result.ok else { return [] }
        return DockerCore.parsePS(result.output)
    }

    // MARK: - Container actions (explicit-click only, per CLAUDE.md)

    /// Stop a running container via `docker stop` (Docker's own graceful
    /// SIGTERM → 10 s → SIGKILL). Runs off the main queue; `onComplete`
    /// delivers the refreshed running-container list on the main queue so the
    /// caller can re-render. Only ever invoked from an explicit user action —
    /// there is no auto-action path.
    static func stop(_ id: String, onComplete: @escaping ([Container]) -> Void = { _ in }) {
        performThenRefresh([["stop", id]], onComplete: onComplete)
    }

    /// Remove a container via `docker stop` then `docker rm`. The panel lists
    /// running containers only, so removal stops the container gracefully first
    /// (honoring the grace period — no force `-f`) before deleting it. Runs off
    /// the main queue; `onComplete` delivers the refreshed list on the main
    /// queue. Explicit-click only, per CLAUDE.md.
    static func remove(_ id: String, onComplete: @escaping ([Container]) -> Void = { _ in }) {
        performThenRefresh([["stop", id], ["rm", id]], onComplete: onComplete)
    }

    /// Run each docker invocation in sequence on a background queue, then
    /// re-list running containers and deliver the result on the main queue.
    private static func performThenRefresh(_ commands: [[String]],
                                           onComplete: @escaping ([Container]) -> Void) {
        DispatchQueue.global().async {
            for args in commands { run(args) }
            let containers = listContainers()
            DispatchQueue.main.async { onComplete(containers) }
        }
    }
}
