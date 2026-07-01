import Foundation

/// Pure aggregation + retention over the persisted `CleanEvent` log (PID-53.2).
/// No side effects — the app-side `CleanLogStore` owns disk I/O and calls into
/// here (mirroring `DockerCore` ↔ `DockerService`). The PID-53.3 "Cleaned" tab
/// renders `stats(...)`; `capped(...)` bounds the log file's growth on write.
public enum CleanLog {

    /// One `(kind, count)` pair in the top-kinds ranking. A named struct (not a
    /// tuple) so `Stats` gets synthesized `Equatable` for straightforward tests.
    public struct KindCount: Equatable {
        public let kind: String
        public let count: Int

        public init(kind: String, count: Int) {
            self.kind = kind
            self.count = count
        }
    }

    /// Aggregated value stats over a rolling window — what the "Cleaned" tab surfaces.
    public struct Stats: Equatable {
        /// Number of confirmed cleans within the window.
        public let count: Int
        /// Sum of `rssKB` over the windowed events — the "RAM reclaimed" figure.
        public let ramReclaimedKB: Int
        /// Kinds ranked by frequency (descending), ties broken by kind name (ascending)
        /// for deterministic ordering.
        public let topKinds: [KindCount]

        public init(count: Int, ramReclaimedKB: Int, topKinds: [KindCount]) {
            self.count = count
            self.ramReclaimedKB = ramReclaimedKB
            self.topKinds = topKinds
        }
    }

    /// Count-cap retention: keep the newest `cap` events, dropping the oldest.
    /// Events are ordered newest-last by `timestamp` before trimming, so callers
    /// need not pre-sort. A non-positive `cap` yields an empty log; a log already
    /// within `cap` is returned sorted but otherwise unchanged.
    public static func capped(_ events: [CleanEvent], cap: Int) -> [CleanEvent] {
        guard cap > 0 else { return [] }
        let ordered = events.sorted { $0.timestamp < $1.timestamp }
        guard ordered.count > cap else { return ordered }
        return Array(ordered.suffix(cap))
    }

    /// Aggregate value stats over the `[now - window, now]` window (inclusive of the
    /// lower bound). Events outside the window are ignored. `window` is in seconds
    /// (e.g. `7 * 86400` for "this week").
    public static func stats(from events: [CleanEvent], now: Date, window: TimeInterval) -> Stats {
        let cutoff = now.addingTimeInterval(-window)
        let windowed = events.filter { $0.timestamp >= cutoff && $0.timestamp <= now }

        let ram = windowed.reduce(0) { $0 + $1.rssKB }

        var frequency: [String: Int] = [:]
        for event in windowed { frequency[event.kind, default: 0] += 1 }
        let topKinds = frequency
            .map { KindCount(kind: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.kind < $1.kind }

        return Stats(count: windowed.count, ramReclaimedKB: ram, topKinds: topKinds)
    }
}
