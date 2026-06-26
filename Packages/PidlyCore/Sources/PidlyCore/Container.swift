import Foundation

/// One running Docker container, parsed from `docker ps` output by `DockerCore`.
/// A pure value type in `PidlyCore` so the parser stays unit-testable; the
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

    public init(id: String, name: String, image: String, status: String, ports: String) {
        self.id = id
        self.name = name
        self.image = image
        self.status = status
        self.ports = ports
    }
}
