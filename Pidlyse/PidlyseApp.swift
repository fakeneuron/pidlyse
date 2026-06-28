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
