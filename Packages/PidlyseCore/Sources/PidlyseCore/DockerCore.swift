import Foundation

/// Pure Docker output parsing — mirrors `ScanCore` (pure, injectable,
/// unit-testable). The app-side `DockerService` owns the impure `docker`
/// shell-outs and feeds raw `docker ps` output here; this type holds no
/// side effects so the parsing is covered by unit tests.
public enum DockerCore {
    /// Tab-separated field order this parser expects, produced by
    /// `docker ps --format` with ID / Names / Image / Status / Ports plus the
    /// compose-project label (empty for non-compose containers). Kept here so
    /// `DockerService` and the tests share one source of truth.
    public static let psFormat = "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Label \"com.docker.compose.project\"}}"

    /// Tab-separated field order for the scan-time owner cache, produced by
    /// `docker inspect --format "{{.State.Pid}}\t{{.Name}}"`. Resolves each
    /// running container's host root PID to its name so the kill path and the
    /// row-expansion hint can map a scanned PID back to its owning container
    /// without a per-click inspect. Kept here as the shared source of truth.
    public static let inspectOwnerFormat = "{{.State.Pid}}\t{{.Name}}"

    /// Tab-separated field order for the one-shot per-container stats sample,
    /// produced by `docker stats --no-stream --format
    /// "{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}"`. Kept here so `DockerService`
    /// and the tests share one source of truth.
    public static let statsFormat = "{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}"

    /// Parse `docker ps --format` output (one container per line) into typed
    /// `Container` values. Blank and malformed lines are dropped.
    public static func parsePS(_ output: String) -> [Container] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    /// Parse one tab-separated `docker ps` line into a `Container`, or `nil` if
    /// it has fewer than six fields or an empty container ID. Empty trailing
    /// fields are expected and kept: ports (no published ports) stays empty, and
    /// an empty compose-project label (non-compose container) maps to `nil`.
    public static func parseLine(_ line: String) -> Container? {
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 6 else { return nil }
        let id = fields[0].trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return nil }
        let project = fields[5].trimmingCharacters(in: .whitespaces)
        return Container(id: id,
                         name: fields[1],
                         image: fields[2],
                         status: fields[3],
                         ports: fields[4],
                         composeProject: project.isEmpty ? nil : project)
    }

    /// Parse `docker inspect --format inspectOwnerFormat` output (one container
    /// per line, `<State.Pid>\t<Name>`) into a host-PID → container-name map.
    /// Lines with a missing/unparseable PID, a PID of 0 (the container isn't
    /// running, so it owns no host process), or fewer than two fields are
    /// dropped. The `{{.Name}}` field carries a leading `/` (unlike
    /// `docker ps {{.Names}}`), so it is stripped to match the panel's naming.
    public static func parseContainerOwners(_ output: String) -> [Int32: String] {
        var owners: [Int32: String] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 2,
                  let pid = Int32(fields[0].trimmingCharacters(in: .whitespaces)),
                  pid != 0 else { continue }
            let name = fields[1].trimmingCharacters(in: .whitespaces)
                .drop(while: { $0 == "/" })
            guard !name.isEmpty else { continue }
            owners[pid] = String(name)
        }
        return owners
    }

    /// Parse `docker stats --no-stream --format statsFormat` output (one
    /// container per line, `<ID>\t<CPUPerc>\t<MemUsage>`) into an ID-keyed
    /// stats map, joinable onto `parsePS` containers by short ID (`{{.ID}}`
    /// emits the same 12-char form in both commands). `{{.MemUsage}}` renders
    /// as `used / limit`; only the used half is kept. Lines with fewer than
    /// three fields or an empty ID are dropped.
    public static func parseStats(_ output: String) -> [String: ContainerStats] {
        var stats: [String: ContainerStats] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 3 else { continue }
            let id = fields[0].trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty else { continue }
            let cpu = fields[1].trimmingCharacters(in: .whitespaces)
            let memory = fields[2].components(separatedBy: " / ")[0]
                .trimmingCharacters(in: .whitespaces)
            stats[id] = ContainerStats(cpu: cpu, memory: memory)
        }
        return stats
    }
}
