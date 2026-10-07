import Foundation
import PidlyseCore

/// SwiftUI-facing async wrappers over the core `DockerService` (which moved
/// into `PidlyseCore` for the cli-companion, PID-EPIC-57): each runs the
/// blocking docker shell-out off the main queue and delivers on the main queue
/// so the Containers panel can load/refresh without freezing the popover.
/// Keeps the shell-out inside `DockerService` (the view never touches `docker`
/// or `DispatchQueue`), per AGENTS.md.
extension DockerService {
    /// Async wrapper over `listContainers()`.
    static func list(onComplete: @escaping ([Container]) -> Void) {
        DispatchQueue.global().async {
            let containers = listContainers()
            DispatchQueue.main.async { onComplete(containers) }
        }
    }

    /// One-shot CPU/memory sample for all running containers via
    /// `docker stats --no-stream`, keyed by short container ID. Blocks ~1-2 s
    /// while Docker samples a CPU window, so it runs off the main queue and
    /// delivers on the main queue (same shape as `list(onComplete:)`); empty
    /// map when Docker is absent or the command fails. Fetched once per
    /// load/refresh — no polling timer. The pure parse lives in
    /// `DockerCore.parseStats`.
    static func stats(onComplete: @escaping ([String: ContainerStats]) -> Void) {
        DispatchQueue.global().async {
            let result = run(["stats", "--no-stream", "--format", DockerCore.statsFormat])
            let stats = result.ok ? DockerCore.parseStats(result.output) : [:]
            DispatchQueue.main.async { onComplete(stats) }
        }
    }

    // MARK: - Container actions (explicit-click only, per AGENTS.md)

    /// Restart a running container via `docker restart` (SIGTERM + 10 s grace,
    /// same semantic as `docker stop` but the container comes back up). Runs off
    /// the main queue; `onComplete` delivers the refreshed list on the main queue.
    /// Explicit-click only, per AGENTS.md.
    static func restart(_ id: String, onComplete: @escaping ([Container]) -> Void = { _ in }) {
        performThenRefresh([["restart", id]], onComplete: onComplete)
    }

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
    /// queue. Explicit-click only, per AGENTS.md.
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
