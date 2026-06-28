import AppKit
import Combine
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
        popover.contentViewController = NSHostingController(rootView: MenuBarView(engine: engine))

        // Redraw the icon whenever the engine's scan state changes. `receive(on:)`
        // defers to the next main-loop tick so the @Published values are already
        // applied when `updateIcon` reads them.
        updateIcon()
        cancellable = engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateIcon() }
    }

    /// Native menu bar icon: spinner while scanning, filled cpu + count badge when
    /// strays exist, outline cpu when clean. Badge is red for safe-to-kill count,
    /// yellow when only review items exist. The cpu glyph is a template image
    /// (auto-adapts to light/dark menu bar); the count keeps its color. When the
    /// stray count rises, the icon fires a one-shot pulse (see `pulse(_:)`).
    private func updateIcon() {
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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
