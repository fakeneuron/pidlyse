import Foundation
import PidlyseCore

/// App-side lifecycle for the confirmed-clean log (PID-53.2): the `@Published`
/// binding the PID-53.3 "Cleaned" tab reads, over the shared disk I/O in
/// `PidlyseCore.CleanLogFile` (extracted there when the cli-companion became
/// the second writer, PID-57.3). The pure model (`CleanEvent`) and the
/// aggregation/retention logic (`CleanLog`) also live in core (mirroring the
/// `KillService` ↔ `KillCore` and `ScanEngine` ↔ `ScanCore` splits).
///
/// Backed by a JSON array at `~/Library/Application Support/Pidlyse/clean-log.json`
/// (same directory as `PortRegistry`'s `ports.json`). A read/decode failure yields
/// an empty log — the store is advisory, never fatal to the app.
final class CleanLogStore: ObservableObject {
    /// Confirmed cleans, oldest-first (append order). Read by the "Cleaned" tab.
    @Published private(set) var events: [CleanEvent] = []

    private let fileURL: URL
    private let cap: Int
    /// Serial so two kill-hook records append in order. `CleanLogFile.append`
    /// blocks in `flock` on this queue, never on the main thread (PID-085).
    private let appendQueue = DispatchQueue(label: "com.fakeneuron.pidlyse.clean-log")

    /// `fileURL` and `cap` are injectable so the store can be unit-tested against a
    /// temp file without touching the real Application Support log.
    init(fileURL: URL = CleanLogFile.defaultFileURL, cap: Int = CleanLogFile.retentionCap) {
        self.fileURL = fileURL
        self.cap = cap
        events = CleanLogFile.load(from: fileURL, cap: cap)
    }

    /// Append one confirmed clean by re-reading the shared file, merging, capping,
    /// and saving (`CleanLogFile.append`). Returns immediately. The blocking
    /// `flock` runs on `appendQueue`. The published log is replaced on the main
    /// queue with a fresh load, so a `reload()` that already observed a newer
    /// disk snapshot is not overwritten by this append's older return value.
    /// A CLI write that landed before that load stays in the published log.
    /// Called on the main thread from the kill-completion hook
    /// (`ScanEngine.recordCleaned`).
    func record(_ event: CleanEvent) {
        let fileURL = fileURL
        let cap = cap
        appendQueue.async { [weak self] in
            let merged = CleanLogFile.append([event], at: fileURL, cap: cap)
            DispatchQueue.main.async {
                guard let self else { return }
                let loaded = CleanLogFile.load(from: fileURL, cap: cap)
                // `load` collapses a missing or unreadable file to []. That is
                // not a reason to blank a log this append just wrote.
                self.events = (loaded.isEmpty && !merged.isEmpty) ? merged : loaded
            }
        }
    }

    /// Replace the published log with whatever is on disk. Called when the
    /// menu-bar popover opens so a CLI clean shows up without relaunching.
    func reload() {
        events = CleanLogFile.load(from: fileURL, cap: cap)
    }
}
