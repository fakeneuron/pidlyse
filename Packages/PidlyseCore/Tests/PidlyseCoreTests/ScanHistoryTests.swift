import XCTest
@testable import PidlyseCore

/// Tests for the PID-55.2 pure rolling-window CPU cache: append/cap/prune across
/// scans, PID-reuse-safe keying (PID + start time), and the "sustained low CPU"
/// query. In-memory value type; no `ScanEngine` wiring is exercised here (the
/// impure scan feed mirrors `ScanCore.runPS` — not unit-tested).
final class ScanHistoryTests: XCTestCase {

    private let t1 = ProcStartTime(sec: 1000, usec: 0)
    private let t2 = ProcStartTime(sec: 2000, usec: 0)

    private func obs(_ pid: Int32, _ start: ProcStartTime?, _ cpu: Double) -> ScanHistory.Observation {
        ScanHistory.Observation(pid: pid, startTime: start, cpuPercent: cpu)
    }

    func testRecording_appendsSamplesOldestFirst() {
        var h = ScanHistory(windowDepth: 5)
        h = h.recording([obs(100, t1, 0.1)])
        h = h.recording([obs(100, t1, 0.2)])
        h = h.recording([obs(100, t1, 0.3)])
        XCTAssertEqual(h.samples(pid: 100, startTime: t1), [0.1, 0.2, 0.3])
    }

    func testRecording_capsToWindowDepth_dropsOldest() {
        var h = ScanHistory(windowDepth: 3)
        for cpu in [1.0, 2.0, 3.0, 4.0, 5.0] {
            h = h.recording([obs(100, t1, cpu)])
        }
        // Only the newest 3 survive.
        XCTAssertEqual(h.samples(pid: 100, startTime: t1), [3.0, 4.0, 5.0])
    }

    func testRecording_prunesIdentitiesAbsentFromScan() {
        var h = ScanHistory(windowDepth: 5)
        h = h.recording([obs(100, t1, 0.1), obs(200, t1, 0.2)])
        // Second scan omits pid 200 → its series is dropped.
        h = h.recording([obs(100, t1, 0.1)])
        XCTAssertEqual(h.samples(pid: 100, startTime: t1), [0.1, 0.1])
        XCTAssertEqual(h.samples(pid: 200, startTime: t1), [])
    }

    func testRecording_pidReuse_differentStartTime_isFreshSeries() {
        var h = ScanHistory(windowDepth: 5)
        h = h.recording([obs(100, t1, 0.5)])
        h = h.recording([obs(100, t1, 0.5)])
        // Same PID, new start time → the old series is pruned, a new one begins.
        h = h.recording([obs(100, t2, 9.0)])
        XCTAssertEqual(h.samples(pid: 100, startTime: t1), [])
        XCTAssertEqual(h.samples(pid: 100, startTime: t2), [9.0])
    }

    func testRecording_nilStartTime_collapsesToOneSeriesPerPID() {
        var h = ScanHistory(windowDepth: 5)
        h = h.recording([obs(100, nil, 0.1)])
        h = h.recording([obs(100, nil, 0.2)])
        XCTAssertEqual(h.samples(pid: 100, startTime: nil), [0.1, 0.2])
    }

    func testIsSustainedLowCPU_allBelowThresholdAndEnoughSamples_isTrue() {
        var h = ScanHistory(windowDepth: 5)
        for cpu in [0.1, 0.0, 0.2] { h = h.recording([obs(100, t1, cpu)]) }
        XCTAssertTrue(h.isSustainedLowCPU(pid: 100, startTime: t1, threshold: 1.0, minimumSamples: 3))
    }

    func testIsSustainedLowCPU_oneHighSample_isFalse() {
        var h = ScanHistory(windowDepth: 5)
        for cpu in [0.1, 42.0, 0.2] { h = h.recording([obs(100, t1, cpu)]) }
        XCTAssertFalse(h.isSustainedLowCPU(pid: 100, startTime: t1, threshold: 1.0, minimumSamples: 3))
    }

    func testIsSustainedLowCPU_belowMinimumSamples_isFalse() {
        var h = ScanHistory(windowDepth: 5)
        for cpu in [0.1, 0.2] { h = h.recording([obs(100, t1, cpu)]) }
        // Two low samples, but the minimum is three → not yet a verdict.
        XCTAssertFalse(h.isSustainedLowCPU(pid: 100, startTime: t1, threshold: 1.0, minimumSamples: 3))
    }

    func testIsSustainedLowCPU_thresholdIsStrict() {
        var h = ScanHistory(windowDepth: 5)
        for _ in 0..<3 { h = h.recording([obs(100, t1, 1.0)]) }
        // A sample exactly at the threshold is not "below" it.
        XCTAssertFalse(h.isSustainedLowCPU(pid: 100, startTime: t1, threshold: 1.0, minimumSamples: 3))
    }

    func testIsSustainedLowCPU_unseenIdentity_isFalse() {
        let h = ScanHistory(windowDepth: 5)
        XCTAssertFalse(h.isSustainedLowCPU(pid: 999, startTime: t1, threshold: 1.0, minimumSamples: 1))
    }

    func testDefaults_areExposed() {
        XCTAssertEqual(ScanHistory.defaultWindowDepth, 5)
        XCTAssertEqual(ScanHistory.defaultLowCPUThreshold, 1.0)
        XCTAssertEqual(ScanHistory.defaultMinimumSamples, 3)
    }
}
