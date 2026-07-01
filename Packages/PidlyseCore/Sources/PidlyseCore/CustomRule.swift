import Foundation

/// A user-defined detection rule: a command substring that, when found, surfaces
/// the process under a friendly `label`. Consulted by `ScanCore` **ahead of** the
/// built-in `detectKind` matchers (a custom match relabels even a built-in kind)
/// and always classified into Needs Review — never auto-killable. Deliberately
/// minimal: one substring → one label, no user-set risk tiers or compound
/// conditions. Mirrors the simple `ignoredNames` substring ignore. (PID-54.3)
public struct CustomRule: Equatable {
    /// Case-insensitive command substring to match.
    public let substring: String
    /// Friendly display label shown for matching processes.
    public let label: String

    public init(substring: String, label: String) {
        self.substring = substring
        self.label = label
    }

    /// The editor / persistence line delimiter (`substring = label`).
    private static let delimiter = "="

    /// Parse one editor line of the form `substring = label`. The label is
    /// optional — a bare `substring` line uses the substring as its own label.
    /// Returns `nil` for an empty (or whitespace-only substring) line so blank
    /// lines are dropped, mirroring the `ignoredNames` editor.
    public static func parse(_ line: String) -> CustomRule? {
        let parts = line.split(separator: Character(delimiter), maxSplits: 1,
                               omittingEmptySubsequences: false)
        let substring = parts[0].trimmingCharacters(in: .whitespaces)
        guard !substring.isEmpty else { return nil }
        let rawLabel = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        return CustomRule(substring: substring, label: rawLabel.isEmpty ? substring : rawLabel)
    }

    /// Render a rule back to its `substring = label` editor / persistence line.
    public static func serialize(_ rule: CustomRule) -> String {
        "\(rule.substring) \(delimiter) \(rule.label)"
    }

    /// The first rule whose `substring` appears (case-insensitively) in `command`,
    /// or `nil` if none match. First-wins so earlier editor lines take precedence.
    public static func firstMatch(_ command: String, in rules: [CustomRule]) -> CustomRule? {
        rules.first { command.localizedCaseInsensitiveContains($0.substring) }
    }
}
