import Foundation

/// Pure grammar for the `pidlyse://` URL scheme (PID-58.2). Lives in
/// `PidlyseCore` — not the app target — so `PidlyseTests` can cover the parse
/// via `make test`, mirroring the `CLICore` (cli-companion) precedent. The
/// app's `AppDelegate.application(_:open:)` owns the impure side (routing a
/// parsed verb to `ScanEngine.cleanAllSafe` / `rescan`).
///
/// External launchers (a browser, a `.desktop`-style opener, `open pidlyse://…`)
/// trigger these verbs; the launcher invocation *is* the explicit user action
/// that the "never kill without explicit user action" non-negotiable requires,
/// and `clean` is bounded to the safe-minus-protected sweep set (never
/// `needsReview`) — see PID-58.1 discovery / PID-35.1 security baseline.
public enum URLScheme {

    /// The registered scheme (matches `CFBundleURLSchemes` in `Info.plist`).
    public static let scheme = "pidlyse"

    /// The `pidlyse://` verb surface.
    public enum Command: Equatable {
        /// `pidlyse://clean` — run the headless "Clean all safe" sweep directly
        /// and post a result notification.
        case clean
        /// `pidlyse://scan` — clear the session's dismissed set and re-enumerate
        /// (headless; the manual ↺ equivalent).
        case scan
    }

    /// Parse a `pidlyse://` URL into a verb, or `nil` for a foreign scheme or an
    /// unknown verb. The verb is read from the host (`pidlyse://clean`) with a
    /// fallback to the first path component (`pidlyse:clean`), case-insensitively,
    /// so both authority and opaque forms route. Any trailing path / query is
    /// ignored — the verb is the whole grammar today.
    public static func parse(_ url: URL) -> Command? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        // `pidlyse://clean` → host "clean"; `pidlyse:clean` → empty host, path "clean".
        let verb = (url.host ?? url.path.split(separator: "/").first.map(String.init) ?? "")
            .lowercased()
        switch verb {
        case "clean": return .clean
        case "scan": return .scan
        default: return nil
        }
    }
}
