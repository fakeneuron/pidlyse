import Foundation

/// One running Docker container, parsed from `docker ps` output by `DockerCore`.
/// A pure value type in `PidlyseCore` so the parser stays unit-testable; the
/// app-side `DockerService` owns the impure `docker` shell-outs that produce it
/// (mirroring the `ProcessItem` / `ScanCore` / `ScanEngine` split).
public struct Container: Identifiable, Equatable {
    /// Short container ID (`docker ps` `{{.ID}}`).
    public let id: String
    /// Human-readable container name (`{{.Names}}`).
    public let name: String
    /// Image reference, e.g. `postgres:16` (`{{.Image}}`).
    public let image: String
    /// Status column, e.g. `Up 3 minutes` (`{{.Status}}`).
    public let status: String
    /// Raw published-ports column, e.g. `0.0.0.0:5432->5432/tcp` (`{{.Ports}}`);
    /// empty when the container publishes no ports.
    public let ports: String
    /// Compose project the container belongs to
    /// (`{{.Label "com.docker.compose.project"}}`), or `nil` for containers
    /// not started by Docker Compose (the label renders empty).
    public let composeProject: String?

    public init(id: String, name: String, image: String, status: String, ports: String,
                composeProject: String?) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
        self.composeProject = composeProject
    }
}

/// One-shot CPU/memory sample for a running container, parsed from
/// `docker stats --no-stream` output by `DockerCore.parseStats`. Display
/// strings, not numbers — nothing sorts or thresholds on them, so Docker's
/// own formatting is kept as-is.
public struct ContainerStats: Equatable {
    /// CPU percentage column, e.g. `0.15%` (`{{.CPUPerc}}`).
    public let cpu: String
    /// Used-memory half of `{{.MemUsage}}`, e.g. `45.2MiB` — the parser
    /// strips the ` / limit` tail to keep rows compact.
    public let memory: String

    public init(cpu: String, memory: String) {
        self.cpu = cpu
        self.memory = memory
    }
}
