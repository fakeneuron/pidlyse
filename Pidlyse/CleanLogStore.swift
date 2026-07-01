import Foundation
import PidlyseCore

/// App-side persistence for the confirmed-clean log (PID-53.2). Owns the impure
/// disk I/O — load, append, save — while the pure model (`CleanEvent`) and the
/// aggregation/retention logic (`CleanLog`) live in `PidlyseCore` (mirroring the
/// `DockerService` ↔ `DockerCore` and `ScanEngine` ↔ `ScanCore` splits).
///
/// Backed by a JSON array at `~/Library/Application Support/Pidlyse/clean-log.json`
/// (same directory as `PortRegistry`'s `ports.json`). `@Published events` lets the
/// PID-53.3 "Cleaned" tab bind directly. A read/decode failure yields an empty log
/// — the store is advisory, never fatal to the app.
final class CleanLogStore: ObservableObject {
    /// Retention ceiling: the newest `retentionCap` events are kept on write.
    static let retentionCap = 1000

    /// Confirmed cleans, oldest-first (append order). Read by the "Cleaned" tab.
    @Published private(set) var events: [CleanEvent] = []

    private let fileURL: URL
    private let cap: Int

    /// The default on-disk log location, alongside `PortRegistry`'s user file.
    static let defaultFileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pidlyse/clean-log.json")
    }()

    /// `fileURL` and `cap` are injectable so the store can be unit-tested against a
    /// temp file without touching the real Application Support log.
    init(fileURL: URL = CleanLogStore.defaultFileURL, cap: Int = CleanLogStore.retentionCap) {
        self.fileURL = fileURL
        self.cap = cap
        events = Self.load(from: fileURL)
    }

    /// Append one confirmed clean, apply count-cap retention, and persist. Called on
    /// the main thread from the kill-completion hook (`ScanEngine.recordCleaned`).
    func record(_ event: CleanEvent) {
        events = CleanLog.capped(events + [event], cap: cap)
        save()
    }

    // MARK: - Disk I/O

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static func load(from url: URL) -> [CleanEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder().decode([CleanEvent].self, from: data)
        else { return [] }
        return CleanLog.capped(decoded, cap: retentionCap)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(events) else { return }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
