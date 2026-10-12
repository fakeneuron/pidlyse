import Darwin
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

    /// In-process half of the append lock. `flock` is owned by the process on
    /// macOS, so a second thread in this process would not block on the file.
    private static let appendLock = NSLock()

    /// Test-only. When non-zero, `append` sleeps this long after the locked
    /// re-read and before the save, so a unit test can force two load-merge-save
    /// windows to overlap. Production leaves it at 0. Same shape as
    /// `Shell.deadlineOverride`.
    static var overlapDelayForTests: TimeInterval = 0

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

    /// Load-append-save for both writers (the app store and the CLI). Re-reads
    /// inside an exclusive lock so an overlapping app write and CLI write
    /// cannot drop an event. An empty append is a no-op read: nothing is
    /// rewritten, and no lock file is created.
    @discardableResult
    public static func append(_ newEvents: [CleanEvent],
                              at url: URL = defaultFileURL,
                              cap: Int = retentionCap) -> [CleanEvent] {
        guard !newEvents.isEmpty else { return load(from: url, cap: cap) }
        appendLock.lock()
        defer { appendLock.unlock() }
        let fd = acquireAppendLock(for: url)
        defer { releaseAppendLock(fd) }
        let existing = load(from: url, cap: cap)
        if overlapDelayForTests > 0 {
            Thread.sleep(forTimeInterval: overlapDelayForTests)
        }
        let merged = CleanLog.capped(existing + newEvents, cap: cap)
        save(merged, to: url)
        return merged
    }

    /// Exclusive `flock` on the sibling `<log>.lock` file. Returns `-1` when
    /// the lock cannot be taken; the caller still writes, because the log is
    /// advisory. Creates the parent directory so the lock file has a home
    /// before `save` runs.
    private static func acquireAppendLock(for url: URL) -> Int32 {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = url.appendingPathExtension("lock").path
        let fd = path.withCString { open($0, O_CREAT | O_RDWR, mode_t(0o644)) }
        guard fd >= 0 else { return -1 }
        guard flock(fd, LOCK_EX) == 0 else {
            close(fd)
            return -1
        }
        return fd
    }

    private static func releaseAppendLock(_ fd: Int32) {
        guard fd >= 0 else { return }
        flock(fd, LOCK_UN)
        close(fd)
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
