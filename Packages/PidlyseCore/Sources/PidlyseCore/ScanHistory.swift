import Foundation

/// Pure, in-memory rolling-window cache of per-process CPU samples across scans
/// (PID-55.2). Generalizes `ScanEngine.previousPIDs` (depth-1) into a bounded
/// depth-N window per process, keyed by (PID + `ProcStartTime`) so a recycled PID
/// starts a fresh series instead of corrupting the previous process's history.
///
/// Value-semantics and side-effect-free — the app-side `ScanEngine` owns the
/// single mutable instance and feeds it each scan (mirroring the `CleanLog`
/// pure-type ↔ `CleanLogStore` impure-store split, but with no disk: a CPU sample
/// from before an app restart is meaningless, so history lives for the session
/// only). Exposes the "sustained low CPU across the window" query that PID-55.3's
/// idle-dev-signal consumes; never touches `ScanCore.riskTier` / `bucket` / the
/// kill bar — signal only.
public struct ScanHistory: Equatable {

    // MARK: - Tunable defaults (PID-55.3 may override at the call site)

    /// How many recent scans of CPU samples to retain per process.
    public static let defaultWindowDepth = 5
    /// A sample below this percentage counts as "low" (idle) CPU.
    public static let defaultLowCPUThreshold = 1.0
    /// Fewest samples a series needs before a "sustained low CPU" verdict —
    /// stops a just-appeared process from being prematurely flagged idle.
    public static let defaultMinimumSamples = 3

    // MARK: - Identity + input

    /// PID-reuse-safe series key. Two observations of the same PID with different
    /// start times are distinct series; a `nil` start time (tests / a sysctl miss)
    /// collapses to one series per PID — acceptable degradation, matching how the
    /// kill path treats a missing token as a legacy fallback.
    public struct Key: Hashable {
        public let pid: Int32
        public let startTime: ProcStartTime?

        public init(pid: Int32, startTime: ProcStartTime?) {
            self.pid = pid
            self.startTime = startTime
        }
    }

    /// One process's CPU sample from a single scan.
    public struct Observation {
        public let pid: Int32
        public let startTime: ProcStartTime?
        public let cpuPercent: Double

        public init(pid: Int32, startTime: ProcStartTime?, cpuPercent: Double) {
            self.pid = pid
            self.startTime = startTime
            self.cpuPercent = cpuPercent
        }

        fileprivate var key: Key { Key(pid: pid, startTime: startTime) }
    }

    // MARK: - State

    /// Depth of the rolling window (samples retained per series).
    public let windowDepth: Int
    /// Per-identity CPU series, oldest-first, each capped to `windowDepth`.
    private var series: [Key: [Double]]

    public init(windowDepth: Int = ScanHistory.defaultWindowDepth) {
        self.windowDepth = windowDepth
        self.series = [:]
    }

    // MARK: - Recording

    /// Fold one scan's observations into a new history: each observed identity's
    /// series gains this scan's sample (capped to `windowDepth`, oldest dropped),
    /// and identities absent from `observations` are pruned. Pruning keeps the
    /// cache bounded to live processes and means a recycled PID (new start time,
    /// new key) begins with an empty series. Pure — returns a new value.
    public func recording(_ observations: [Observation]) -> ScanHistory {
        var next: [Key: [Double]] = [:]
        next.reserveCapacity(observations.count)
        for obs in observations {
            var samples = series[obs.key] ?? []
            samples.append(obs.cpuPercent)
            if samples.count > windowDepth {
                samples.removeFirst(samples.count - windowDepth)
            }
            next[obs.key] = samples
        }
        var copy = self
        copy.series = next
        return copy
    }

    // MARK: - Queries

    /// The retained CPU series for an identity, oldest-first (empty if unseen).
    public func samples(pid: Int32, startTime: ProcStartTime?) -> [Double] {
        series[Key(pid: pid, startTime: startTime)] ?? []
    }

    /// True when the identity's series has at least `minimumSamples` samples and
    /// every one is below `threshold` — the "sustained low CPU across the window"
    /// signal PID-55.3 folds into its idle-dev-server verdict.
    public func isSustainedLowCPU(pid: Int32,
                                  startTime: ProcStartTime?,
                                  threshold: Double = ScanHistory.defaultLowCPUThreshold,
                                  minimumSamples: Int = ScanHistory.defaultMinimumSamples) -> Bool {
        let samples = self.samples(pid: pid, startTime: startTime)
        guard samples.count >= minimumSamples else { return false }
        return samples.allSatisfy { $0 < threshold }
    }
}
