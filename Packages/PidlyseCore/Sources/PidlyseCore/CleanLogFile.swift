import Foundation

/// Shared clean-log disk I/O: load, atomic save, and append-with-cap for the
/// confirmed-clean JSON at `~/Library/Application Support/Pidlyse/clean-log.json`.
/// Extracted from the app-side `CleanLogStore` when the cli-companion became the
/// second writer (PID-57.3) — one encoder/decoder definition so the two
/// consumers can't drift formats, the same rationale that moved the impure
/// `DockerService` into core (PID-57.2). The app's `CleanLogStore` keeps the
/// `@Published` binding + main-thread lifecycle and delegates here; the CLI
/// appends directly via `append(_:)`.
public enum CleanLogFile {

    /// Retention ceiling shared by both writers: the newest `retentionCap`
    /// events are kept on write.
    public static let retentionCap = 1000

    /// The default on-disk log location, alongside `PortRegistry`'s `ports.json`.
    public static let defaultFileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pidlyse/clean-log.json")
    }()

    /// Decode the log, applying count-cap retention. A read/decode failure
    /// yields an empty log — the store is advisory, never fatal to a consumer.
    public static func load(from url: URL = defaultFileURL, cap: Int = retentionCap) -> [CleanEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder().decode([CleanEvent].self, from: data)
        else { return [] }
        return CleanLog.capped(decoded, cap: cap)
    }

    /// Persist `events` (pretty-printed, sorted keys, ISO-8601 dates — the
    /// on-disk format contract), creating the directory if needed. Atomic write.
    public static func save(_ events: [CleanEvent], to url: URL = defaultFileURL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(events) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Load-append-save convenience for one-shot writers (the CLI): appends
    /// `newEvents`, applies the cap, persists, and returns the resulting log.
    /// An empty append is a no-op read (nothing rewritten on disk).
    @discardableResult
    public static func append(_ newEvents: [CleanEvent],
                              at url: URL = defaultFileURL,
                              cap: Int = retentionCap) -> [CleanEvent] {
        let existing = load(from: url, cap: cap)
        guard !newEvents.isEmpty else { return existing }
        let merged = CleanLog.capped(existing + newEvents, cap: cap)
        save(merged, to: url)
        return merged
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
