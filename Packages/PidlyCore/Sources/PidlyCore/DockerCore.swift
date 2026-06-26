import Foundation

/// Pure Docker output parsing — mirrors `ScanCore` (pure, injectable,
/// unit-testable). The app-side `DockerService` owns the impure `docker`
/// shell-outs and feeds raw `docker ps` output here; this type holds no
/// side effects so the parsing is covered by unit tests.
public enum DockerCore {
    /// Tab-separated field order this parser expects, produced by
    /// `docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"`.
    /// Kept here so `DockerService` and the tests share one source of truth.
    public static let psFormat = "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

    /// Parse `docker ps --format` output (one container per line) into typed
    /// `Container` values. Blank and malformed lines are dropped.
    public static func parsePS(_ output: String) -> [Container] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    /// Parse one tab-separated `docker ps` line into a `Container`, or `nil` if
    /// it has fewer than five fields or an empty container ID. A trailing empty
    /// ports field is expected (containers with no published ports) and kept.
    public static func parseLine(_ line: String) -> Container? {
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 5 else { return nil }
        let id = fields[0].trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return nil }
        return Container(id: id,
                         name: fields[1],
                         image: fields[2],
                         status: fields[3],
                         ports: fields[4])
    }
}
