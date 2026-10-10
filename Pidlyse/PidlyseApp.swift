import AppIntents
import AppKit
import PidlyseCore
import SwiftUI

@main
struct PidlyseApp: App {
    /// The menu bar item, popover, and scan engine are owned by `AppDelegate`
    /// (an AppKit `NSStatusItem` bridge — see AppDelegate.swift). This scene only
    /// declares the `Settings` window, which reads the delegate's shared engine.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // An `App` must declare at least one `Scene`, so this `Settings` scene is a
    // required-but-inert placeholder. The real Settings UI opens via
    // `AppDelegate.openSettings()` (a self-managed window) — for an `LSUIElement`
    // status-item app the SwiftUI `Settings` scene never surfaces reliably (see
    // PID-032 / the `openSettings()` doc comment).
    var body: some Scene {
        Settings {
            SettingsView(engine: appDelegate.engine)
        }
    }
}

// MARK: - Shortcuts bridge (PID-58.3)

/// The running app's shared `ScanEngine`, reached from an `AppIntent`. Intents are
/// instantiated by the system and run in the app process (macOS launches the
/// `LSUIElement` app in the background if it isn't already up), so `NSApp.delegate`
/// is the live `AppDelegate` that owns the engine — the same engine the popover and
/// `pidlyse://` routing use. Nil only in the impossible case of a missing delegate.
@MainActor
private func sharedEngine() -> ScanEngine? {
    (NSApp.delegate as? AppDelegate)?.engine
}

/// "Clean safe strays" — the Shortcuts/Spotlight parallel of the popover's "Clean
/// all" and `pidlyse://clean` (PID-58.2). Rides the engine's `cleanAllSafe` action
/// (safe bucket minus protected projects, clean-log append, rescan), so it can never
/// touch Needs Review or protected work. It waits for the launch scan when invoked
/// on a cold app, so it never treats the initial empty snapshot as a clean result.
/// The returned dialog is the intent's feedback channel, so —
/// unlike `pidlyse://clean`, which has no return path — it posts no notification.
struct CleanSafeStraysIntent: AppIntent {
    static var title: LocalizedStringResource = "Clean Safe Strays"
    static var description = IntentDescription(
        "Kill every safe-to-clean stray process (safe bucket minus protected projects) — the same set as the popover's Clean all."
    )
    /// Menu-bar utility: run headless, never foreground the app.
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let report: KillReport = await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let engine = sharedEngine() else {
                    continuation.resume(returning: KillReport(items: [], phases: [:]))
                    return
                }
                engine.afterInitialScan {
                    engine.cleanAllSafe { continuation.resume(returning: $0) }
                }
            }
        }
        let dialog: IntentDialog = report.requested == 0
            ? "No unprotected safe-to-clean processes."
            : "\(report.summaryLine)."
        return .result(dialog: dialog)
    }
}

/// "Scan now" — the Shortcuts/Spotlight parallel of the manual ↺ and `pidlyse://scan`
/// (PID-58.2): clears the session's dismissed PIDs and re-enumerates. Fire-and-forget;
/// the scan runs async on the engine, so the dialog confirms the trigger, not a count.
struct ScanNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Now"
    static var description = IntentDescription("Rescan for stray processes now.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { sharedEngine()?.rescan() }
        return .result(dialog: "Rescanning for strays.")
    }
}

/// Registers Pidlyse's intents with Shortcuts, Spotlight, and Raycast (which lists
/// Shortcuts) — one AppIntents surface covers all three launchers (PID-58.1). Phrases
/// need `\(.applicationName)` so the system can disambiguate spoken invocations.
struct PidlyseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CleanSafeStraysIntent(),
            phrases: [
                "Clean safe strays with \(.applicationName)",
                "Clean strays with \(.applicationName)",
            ],
            shortTitle: "Clean Safe Strays",
            systemImageName: "trash"
        )
        AppShortcut(
            intent: ScanNowIntent(),
            phrases: [
                "Scan now with \(.applicationName)",
                "Rescan with \(.applicationName)",
            ],
            shortTitle: "Scan Now",
            systemImageName: "arrow.2.circlepath"
        )
    }
}
