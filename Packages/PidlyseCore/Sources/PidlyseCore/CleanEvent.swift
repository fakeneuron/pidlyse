import Foundation

/// One confirmed process cleanup, persisted to the on-disk clean log (PID-53.2).
/// A pure `Codable` value type in `PidlyseCore` so the aggregation logic
/// (`CleanLog`) stays unit-testable; the app-side `CleanLogStore` owns the impure
/// disk I/O that reads and writes it (mirroring the `Container` / `DockerCore` /
/// `DockerService` split).
///
/// **Privacy-first (PID-53.1 fork #2):** deliberately stores **no command line** —
/// process args can embed secrets (`--api-key=…`) and the log file is not
/// sandboxed. Only the classification `kind`, a short project label, the memory
/// footprint, and a timestamp are retained.
public struct CleanEvent: Codable, Equatable {
    /// The `ProcessKind` raw value (e.g. `"pytest"`). Stored as the raw string
    /// rather than the enum so the log survives future `ProcessKind` additions;
    /// consumers map back via `ProcessKind(rawValue:)?.label` for display.
    public let kind: String
    /// Short project label captured at scan time (the git-project label from
    /// PID-038, e.g. `bidviz/frontend`), or the executable `displayPath` fallback.
    public let projectLabel: String
    /// Resident set size in KB, captured at scan time — the process's memory
    /// footprint reclaimed by the kill. Summed by `CleanLog` into "RAM reclaimed".
    public let rssKB: Int
    /// When the confirmed kill was recorded.
    public let timestamp: Date

    public init(kind: String, projectLabel: String, rssKB: Int, timestamp: Date) {
        self.kind = kind
        self.projectLabel = projectLabel
        self.rssKB = rssKB
        self.timestamp = timestamp
    }

    /// The event for a confirmed kill of `item`, the one construction path both
    /// writers use (PID-079.6). `cwd` is the scan-time working directory. A
    /// custom-rule match persists its friendly label as `kind`: the Cleaned tab's
    /// `ProcessKind(rawValue:)?.label ?? kind` fallback then shows the user's label.
    /// The project label falls back to the executable `displayPath`.
    public init(item: ProcessItem, cwd: ProcessCwd?, timestamp: Date = Date()) {
        self.init(kind: item.kind == .custom ? item.displayLabel : item.kind.rawValue,
                  projectLabel: cwd?.label ?? item.displayPath,
                  rssKB: item.rssKB,
                  timestamp: timestamp)
    }
}
