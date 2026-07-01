import Foundation

/// A command-substring ignore, optionally scoped to a working-directory tree. A bare
/// rule (`pathPrefix == nil`) hides every matching process — the classic global
/// `ignoredNames` behavior, applied inside `ScanCore.enumerate`. A scoped rule
/// (`substring @ prefix`) hides matches only when the process's resolved cwd sits under
/// `prefix`; because `enumerate` has no cwd, scoped rules are applied downstream by
/// `ScanCore.applyScopedIgnores` once the scan's cwd map is resolved. Editor grammar:
/// `substring @ path-prefix`, one rule per line, mirroring the Ignored-processes and
/// Custom-rules editors. (PID-54.4)
public struct IgnoreRule: Equatable {
    /// Case-insensitive command substring to match.
    public let substring: String
    /// The `~`-abbreviated project tree the rule is scoped to, or `nil` for a global
    /// ignore that applies regardless of working directory.
    public let pathPrefix: String?

    public init(substring: String, pathPrefix: String? = nil) {
        self.substring = substring
        self.pathPrefix = pathPrefix
    }

    /// The scope delimiter (` @ `) separating the substring from its path prefix.
    private static let delimiter = " @ "

    /// Parse one editor line. `substring @ prefix` yields a scoped rule; a bare
    /// `substring` yields a global rule. Splits on the *first* ` @ ` so a prefix may
    /// itself contain the delimiter. An empty substring returns `nil` (blank lines are
    /// dropped, mirroring the other editors); an empty prefix degrades to a global rule.
    public static func parse(_ line: String) -> IgnoreRule? {
        if let r = line.range(of: delimiter) {
            let substring = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
            let prefix = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !substring.isEmpty else { return nil }
            return IgnoreRule(substring: substring, pathPrefix: prefix.isEmpty ? nil : prefix)
        }
        let substring = line.trimmingCharacters(in: .whitespaces)
        guard !substring.isEmpty else { return nil }
        return IgnoreRule(substring: substring, pathPrefix: nil)
    }

    /// Render a rule back to its `substring [@ prefix]` editor / persistence line.
    public static func serialize(_ rule: IgnoreRule) -> String {
        guard let prefix = rule.pathPrefix else { return rule.substring }
        return "\(rule.substring)\(delimiter)\(prefix)"
    }
}
