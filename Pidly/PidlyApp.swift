import SwiftUI

@main
struct PidlyApp: App {
    /// The menu bar item, popover, and scan engine are owned by `AppDelegate`
    /// (an AppKit `NSStatusItem` bridge — see AppDelegate.swift). This scene only
    /// declares the `Settings` window, which reads the delegate's shared engine.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(engine: appDelegate.engine)
        }
    }
}
