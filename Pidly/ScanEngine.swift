import Foundation
import UserNotifications
import PidlyCore

/// App-side scan lifecycle: owns the auto-scan `Timer`, the published `items`,
/// `UserDefaults`-backed config, the dismissed/previous baselines, and the
/// new-stray notification. The pure enumeration + classification it drives lives
/// in `PidlyCore.ScanCore` (per CLAUDE.md, all scan + classification logic stays
/// in one place).
final class ScanEngine: ObservableObject {
    static let defaultScanInterval: TimeInterval = 120

    @Published private(set) var items: [ProcessItem] = []
    @Published private(set) var isScanning: Bool = false

    /// How often (seconds) the background timer auto-scans. Persisted to UserDefaults.
    @Published var scanInterval: TimeInterval = 120 {
        didSet {
            UserDefaults.standard.set(scanInterval, forKey: "scanInterval")
            startTimer()
        }
    }

    /// Elapsed-time threshold above which a process counts as "old". Persisted to UserDefaults.
    @Published var elapsedThreshold: TimeInterval = 30 * 60 {
        didSet {
            UserDefaults.standard.set(elapsedThreshold, forKey: "elapsedThreshold")
        }
    }

    /// Command-prefix substrings to hide from scan results (case-insensitive).
    /// Persisted to UserDefaults as a string array.
    @Published var ignoredNames: [String] = [] {
        didSet {
            UserDefaults.standard.set(ignoredNames, forKey: "ignoredNames")
        }
    }

    /// When true, fires a macOS system notification when a scan surfaces new stray PIDs.
    /// Persisted to UserDefaults. Permission is requested the first time it is enabled.
    @Published var notificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled && !oldValue {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    if !granted {
                        DispatchQueue.main.async { self?.notificationsEnabled = false }
                    }
                }
            }
        }
    }

    /// PIDs dismissed for this session. Not persisted — cleared on app restart.
    private(set) var dismissedPIDs: Set<Int32> = []

    /// PIDs from the previous completed scan. `nil` = no prior baseline (first scan).
    private var previousPIDs: Set<Int32>?

    private var timer: Timer?

    init() {
        let ud = UserDefaults.standard
        let savedThreshold = ud.double(forKey: "elapsedThreshold")
        let savedInterval = ud.double(forKey: "scanInterval")
        let savedIgnoredNames = ud.stringArray(forKey: "ignoredNames") ?? []
        let savedNotifications = ud.bool(forKey: "notificationsEnabled")

        if savedThreshold > 0 { _elapsedThreshold = Published(wrappedValue: savedThreshold) }
        _ignoredNames = Published(wrappedValue: savedIgnoredNames)
        if savedInterval > 0 { _scanInterval = Published(wrappedValue: savedInterval) }
        if savedNotifications { _notificationsEnabled = Published(wrappedValue: true) }
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Scanning

    /// Kick off a background scan. Debounces if already in-flight.
    /// Must be called from the main thread (timer + SwiftUI actions always are).
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let threshold = elapsedThreshold
        let ignored = ignoredNames
        let dismissed = dismissedPIDs
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = ScanCore.enumerate(elapsedThreshold: threshold, ignoredNames: ignored,
                                            dismissedPIDs: dismissed)
            DispatchQueue.main.async {
                let oldPIDs = self?.previousPIDs
                self?.previousPIDs = Set(result.map { $0.pid })
                self?.items = result
                self?.isScanning = false
                self?.fireNotificationIfNeeded(newItems: result, previousPIDs: oldPIDs)
            }
        }
    }

    /// Hide a process for this session. Removes it from `items` immediately and
    /// excludes it from subsequent scans. A manual rescan (↺) clears the dismissed set.
    func dismiss(_ pid: Int32) {
        dismissedPIDs.insert(pid)
        items = items.filter { $0.pid != pid }
    }

    /// Manual rescan: clears all dismissed PIDs before scanning so previously
    /// hidden items can reappear. Also resets the notification baseline so
    /// re-emerging dismissed processes don't falsely fire as "new" strays.
    func rescan() {
        dismissedPIDs = []
        previousPIDs = nil
        scan()
    }

    // MARK: - Notifications

    private func fireNotificationIfNeeded(newItems: [ProcessItem], previousPIDs: Set<Int32>?) {
        guard notificationsEnabled, let prev = previousPIDs else { return }
        let newStrays = newItems.filter { !prev.contains($0.pid) }
        guard !newStrays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        if newStrays.count == 1 {
            content.title = "New stray process"
            content.body = "\(newStrays[0].kind.label): \(newStrays[0].displayPath)"
        } else {
            content.title = "\(newStrays.count) new stray processes"
            content.body = newStrays.map { $0.kind.label }.joined(separator: ", ")
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }
}
