import AppKit
import Combine
import PidlyseCore
import SwiftUI

/// Owns Pidlyse's menu bar presence. Pidlyse retired SwiftUI's `MenuBarExtra` in favor
/// of an AppKit `NSStatusItem` so the icon can respond to right-click — `MenuBarExtra`
/// surfaces only left-click. The popover content reuses the SwiftUI `MenuBarView`
/// (hosted in an `NSHostingController`); the icon is drawn natively on the status
/// button (template image + colored count title) so it highlights correctly and
/// adapts to the menu bar appearance. Left-click toggles the popover; right-click
/// shows a minimal context menu (Quit).
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Single shared scan engine — also read by the `Settings` scene in `PidlyseApp`.
    let engine = ScanEngine()

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    /// Self-managed Settings window (see `openSettings()`). Retained so repeated
    /// opens reuse the same window instead of spawning duplicates.
    private var settingsWindow: NSWindow?

    /// Last stray count (`safe + review`) the icon rendered. Used to fire a one-shot
    /// attention pulse only when the count *increases* (a new stray appeared), not on
    /// every redraw — a continuously animating menu bar icon would be distracting.
    private var lastStrayCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.delegate = self
        let hosting = NSHostingController(
            rootView: MenuBarView(engine: engine, openSettings: { [weak self] in self?.openSettings() })
        )
        // Let SwiftUI's intrinsic size drive the popover so it tracks runtime
        // content-height changes — most starkly when the last stray closes and
        // `MenuBarView` collapses from its fixed-height list to the empty state.
        // The popover's width is fixed (see `MenuBarView`), so height changes never
        // shift the `.minY` arrow horizontally.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        // Redraw the icon whenever the engine's scan state changes. `receive(on:)`
        // defers to the next main-loop tick so the @Published values are already
        // applied when `updateIcon` reads them.
        updateIcon()
        cancellable = engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateIcon() }

        // Populate the shared engine before an external clean action can inspect
        // its otherwise-empty cold-launch snapshot.
        engine.scan()
    }

    /// Route `pidlyse://` URL opens to engine actions (PID-58.2). The `pidlyse`
    /// scheme is registered via `CFBundleURLTypes` in `Info.plist`; for an
    /// `LSUIElement` status-item app the open lands on the delegate with no window.
    /// The pure verb parse lives in `PidlyseCore.URLScheme`; foreign schemes and
    /// unknown verbs are ignored silently (no error surface for a drive-by URL).
    /// `clean` runs the headless safe sweep directly and posts a result
    /// notification — the launcher invocation is the explicit user action, and the
    /// sweep is bounded to safe-minus-protected (never Needs Review). `scan`
    /// re-enumerates (the manual ↺ equivalent).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch URLScheme.parse(url) {
            case .clean:
                engine.afterInitialScan { [weak self] in
                    self?.engine.cleanAllSafe { report in
                        self?.engine.fireCleanResultNotification(report)
                    }
                }
            case .scan:
                engine.rescan()
            case nil:
                continue
            }
        }
    }

    /// Native menu bar icon: spinner while scanning, filled cpu + count badge when
    /// strays exist, outline cpu when clean. Badge is red for safe-to-kill count,
    /// yellow when only review items exist. The cpu glyph is a template image
    /// (auto-adapts to light/dark menu bar); the count keeps its color. When the
    /// stray count rises, the icon fires a one-shot pulse (see `pulse(_:)`).
    private func updateIcon() {
        // Freeze the menu-bar icon while the popover is open. The `.variableLength`
        // status button resizes as the count badge gains/loses digits (and flips to
        // the spinner during the open-triggered rescan); since `NSPopover` anchors to
        // the button at show time and the button is right-edge-pinned, any width change
        // slides the icon's center and drifts the popover's arrow off it. Holding the
        // icon still keeps the open popover rock-steady — the live list inside still
        // reflects removals. `popoverDidClose` resyncs the icon once it closes.
        guard !popover.isShown else { return }
        guard let button = statusItem?.button else { return }
        let safe = engine.items.filter { $0.bucket == .safe }.count
        let review = engine.items.filter { $0.bucket == .needsReview }.count

        let symbol: String
        let badge: (count: Int, color: NSColor)?
        if engine.isScanning {
            symbol = "arrow.2.circlepath"; badge = nil
        } else if safe > 0 {
            symbol = "cpu.fill"; badge = (safe, .systemRed)
        } else if review > 0 {
            symbol = "cpu.fill"; badge = (review, .systemYellow)
        } else {
            symbol = "cpu"; badge = nil
        }

        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pidlyse")
        image?.isTemplate = true
        button.image = image

        if let badge {
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(
                string: " \(badge.count)",
                attributes: [
                    .foregroundColor: badge.color,
                    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                ]
            )
        } else {
            button.imagePosition = .imageOnly
            button.attributedTitle = NSAttributedString(string: "")
        }

        // Pulse once when a new stray appears (count rises), drawing the eye to the
        // icon without the distraction of continuous motion. Decreases/no-change stay quiet.
        let strayCount = safe + review
        if strayCount > lastStrayCount {
            pulse(button)
        }
        lastStrayCount = strayCount
    }

    /// One-shot attention pulse: a quick alpha dip-and-restore "breath" on the status
    /// button. Skipped when the system Reduce Motion setting is on — the glyph + badge
    /// still convey the state without motion.
    private func pulse(_ button: NSStatusBarButton) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            button.animator().alphaValue = 0.25
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                button.animator().alphaValue = 1.0
            }
        })
    }

    /// Left-click toggles the popover; right-click (or two-finger tap) shows the
    /// context menu. The mouse-up button is read from the current event.
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // The hosting controller is created once at launch, so the popover's
            // `onAppear` does not run on later opens. Re-read the shared clean log
            // here so a CLI append is visible without relaunching (PID-079.2).
            engine.cleanLog.reload()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // An `NSStatusItem` click doesn't activate the app, so the popover window
            // never becomes key on open — keyboard events (Esc to dismiss, ⌘⌫ to kill
            // the sole safe row) leak to the previously-active app, and `.transient`
            // click-outside dismissal stays dormant until the user first clicks inside.
            // Activate + key the popover window so all three work immediately (PID-50.7).
            NSApp.activate()
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// Presents the Settings UI in a self-managed AppKit window.
    ///
    /// Pidlyse is an `LSUIElement` accessory app driven from an `NSStatusItem`,
    /// so the popover's `MenuBarView` lives in a standalone `NSHostingController`
    /// outside the SwiftUI `App` scene graph. From there, none of the sanctioned
    /// ways to open the SwiftUI `Settings` scene present reliably: the deprecated
    /// `@Environment(\.openSettings)` action is a no-op, the `showSettingsWindow:`
    /// selector no-ops on macOS 14 ("Please use SettingsLink"), and `SettingsLink`
    /// fires but never surfaces a window. Hosting `SettingsView` in a window we own
    /// sidesteps the scene machinery entirely and gives reliable activation/focus.
    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(engine: engine)))
            window.title = "Pidlyse Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            // A `.grouped` Form has no intrinsic height, so the hosting controller's
            // fitting size collapses the window to its title bar. Give it an explicit
            // content size tall enough to show all sections without scrolling;
            // `.resizable` lets the user adjust if content ever clips.
            window.setContentSize(NSSize(width: 360, height: 620))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit Pidlyse",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 5),
            in: button
        )
    }
}

extension AppDelegate: NSPopoverDelegate {
    /// Resync the menu-bar icon once the popover closes. `updateIcon` is frozen
    /// while the popover is shown (see its guard), so the icon catches up to the
    /// current scan state — count badge, spinner, or clean glyph — on close.
    func popoverDidClose(_ notification: Notification) {
        updateIcon()
    }
}
