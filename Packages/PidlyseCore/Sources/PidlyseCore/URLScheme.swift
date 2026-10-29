import Foundation

/// Pure grammar for the `pidlyse://` URL scheme (PID-58.2). Lives in
/// `PidlyseCore` — not the app target — so `PidlyseCoreTests` can cover the parse
/// via `swift test`, mirroring the `CLICore` (cli-companion) precedent. The
/// app's `AppDelegate.application(_:open:)` owns the impure side (routing a
/// parsed verb to `ScanEngine.rescan`).
///
/// Any web page or local app can open a `pidlyse://` URL with no click inside
/// Pidlyse, so the scheme carries no destructive verb: `pidlyse://clean` was
/// dropped (PID-094, reversing PID-58.1) and now parses as an unknown verb.
/// Kills stay on surfaces the user drives deliberately — the popover, the
/// "Clean Likely Strays" Shortcut, and the `pidlyse` CLI.
public enum URLScheme {

    /// The registered scheme (matches `CFBundleURLSchemes` in `Info.plist`).
    public static let scheme = "pidlyse"

    /// The `pidlyse://` verb surface.
    public enum Command: Equatable {
        /// `pidlyse://scan` — clear the session's dismissed set and re-enumerate
        /// (headless; the manual ↺ equivalent).
        case scan
    }

    /// Parse a `pidlyse://` URL into a verb, or `nil` for a foreign scheme or an
    /// unknown verb. The verb is read from the host (`pidlyse://scan`) with a
    /// fallback to the first path component (`pidlyse:scan`), case-insensitively,
    /// so both authority and opaque forms route. Any trailing path / query is
    /// ignored — the verb is the whole grammar today.
    public static func parse(_ url: URL) -> Command? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        // `pidlyse://scan` → host "scan"; `pidlyse:scan` → empty host, path "scan".
        let verb = (url.host ?? url.path.split(separator: "/").first.map(String.init) ?? "")
            .lowercased()
        switch verb {
        case "scan": return .scan
        default: return nil
        }
    }
}
