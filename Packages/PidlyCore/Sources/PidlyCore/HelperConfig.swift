import Foundation

/// Scan configuration shared between the Pidly app and the LaunchAgent helper
/// (PID-EPIC-27). The app persists these knobs to `UserDefaults`; the background
/// helper runs in its own process and cannot read the app's defaults, so it reads
/// them from a JSON file in Application Support instead. Mirrors the PID-025
/// `ports.json` pattern: a pure, injectable decode that falls back to defaults
/// when the file is absent or malformed, so a missing config never blocks a scan.
/// The app writes this file in PID-27.5/.6; this struct owns the read side both
/// processes share.
public struct HelperConfig: Codable, Equatable {
    /// Elapsed-time threshold (seconds) above which a process counts as "old".
    public var elapsedThreshold: TimeInterval
    /// Command-substring filters to hide from results (case-insensitive).
    public var ignoredNames: [String]
    /// Whether the helper should surface new-stray notifications. The helper only
    /// reads this flag here; posting lands in PID-27.5.
    public var notificationsEnabled: Bool

    public init(elapsedThreshold: TimeInterval = ScanCore.defaultElapsedThreshold,
                ignoredNames: [String] = [],
                notificationsEnabled: Bool = false) {
        self.elapsedThreshold = elapsedThreshold
        self.ignoredNames = ignoredNames
        self.notificationsEnabled = notificationsEnabled
    }

    /// Defaults used when no config file exists yet (matches the app's first-run state).
    public static let `default` = HelperConfig()

    /// Shared config file: `~/Library/Application Support/Pidly/config.json` — the
    /// same directory PID-025's `ports.json` lives in.
    public static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pidly/config.json")
    }

    /// Pure decode: absent or malformed JSON yields `.default`. All-or-nothing —
    /// a partial object (missing keys) also falls back. Injectable for unit tests.
    public static func decode(_ json: Data?) -> HelperConfig {
        guard let data = json,
              let config = try? JSONDecoder().decode(HelperConfig.self, from: data)
        else { return .default }
        return config
    }

    /// Read + decode the shared config file, falling back to `.default`.
    public static func load() -> HelperConfig {
        decode(try? Data(contentsOf: fileURL))
    }
}
