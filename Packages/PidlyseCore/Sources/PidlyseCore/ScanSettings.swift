import Foundation

/// The `UserDefaults` keys of the scan-relevant settings (PID-079.7) — the one
/// definition the app writes through and both the app and the CLI read through, so
/// a renamed key cannot leave the CLI scanning with different rules than the app.
/// The strings are persisted user data: `ScanSettingsTests` pins them.
public enum SettingsKey {
    public static let elapsedThreshold = "elapsedThreshold"
    public static let ignoredNames = "ignoredNames"
    public static let disabledKinds = "disabledKinds"
    public static let customRules = "customRules"
    public static let protectedProjects = "protectedProjects"
}

/// The scan-relevant settings as saved in a defaults domain, read raw: the app's
/// editors bind the raw lines, so parsing happens in `request`, not here. App-only
/// settings (`scanInterval`, `notificationsEnabled`) stay out — the CLI has no use
/// for them.
public struct ScanSettings: Equatable {
    /// `nil` = never saved (or saved as `<= 0`), so the consumer keeps its default.
    public var elapsedThreshold: TimeInterval?
    public var ignoredNames: [String]
    public var disabledKinds: Set<ProcessKind>
    public var customRules: [CustomRule]
    public var protectedProjects: [String]

    public init(elapsedThreshold: TimeInterval? = nil,
                ignoredNames: [String] = [],
                disabledKinds: Set<ProcessKind> = [],
                customRules: [CustomRule] = [],
                protectedProjects: [String] = []) {
        self.elapsedThreshold = elapsedThreshold
        self.ignoredNames = ignoredNames
        self.disabledKinds = disabledKinds
        self.customRules = customRules
        self.protectedProjects = protectedProjects
    }

    public static func load(from defaults: UserDefaults) -> ScanSettings {
        let threshold = defaults.double(forKey: SettingsKey.elapsedThreshold)
        return ScanSettings(
            elapsedThreshold: threshold > 0 ? threshold : nil,
            ignoredNames: defaults.stringArray(forKey: SettingsKey.ignoredNames) ?? [],
            disabledKinds: Set((defaults.stringArray(forKey: SettingsKey.disabledKinds) ?? [])
                .compactMap(ProcessKind.init(rawValue:))),
            customRules: (defaults.stringArray(forKey: SettingsKey.customRules) ?? [])
                .compactMap(CustomRule.parse),
            protectedProjects: defaults.stringArray(forKey: SettingsKey.protectedProjects) ?? [])
    }

    /// The scan these settings describe. No dismissals — those are session-only (app).
    public var request: ScanRequest {
        ScanRequest(elapsedThreshold: elapsedThreshold ?? ScanCore.defaultElapsedThreshold,
                    ignoreRules: ignoredNames.compactMap(IgnoreRule.parse),
                    disabledKinds: disabledKinds,
                    customRules: customRules)
    }
}
