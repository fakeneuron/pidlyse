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
}
