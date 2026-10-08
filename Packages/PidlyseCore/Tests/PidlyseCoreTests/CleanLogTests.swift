import XCTest
@testable import PidlyseCore

/// Tests for the PID-53.2 clean-log data layer: the pure `CleanLog` aggregation
/// (rolling-window stats + count-cap retention) and `CleanEvent` Codable round-trip.
/// The impure `CleanLogStore` disk I/O is not unit-tested (mirrors `ScanCore.runPS`).
final class CleanLogTests: XCTestCase {

    /// `t(0)` is the reference "now"; negative offsets are the past (seconds).
    private func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_000_000 + seconds) }

    private func event(_ kind: String, rssKB: Int, at seconds: TimeInterval) -> CleanEvent {
        CleanEvent(kind: kind, projectLabel: "proj", rssKB: rssKB, timestamp: t(seconds))
    }

    // MARK: - capped (count retention)

    func testCapped_keepsNewestN_dropsOldest() {
        // Deliberately out of order — capped sorts by timestamp before trimming.
        let events = [event("a", rssKB: 1, at: -30),
                      event("b", rssKB: 2, at: -10),
                      event("c", rssKB: 3, at: -20)]
        let capped = CleanLog.capped(events, cap: 2)
        // Newest two are b (-10) and c (-20); a (-30) is dropped. Result is oldest-first.
        XCTAssertEqual(capped.map { $0.kind }, ["c", "b"])
    }

    func testCapped_underCap_returnsAllSorted() {
        let events = [event("b", rssKB: 2, at: -10), event("a", rssKB: 1, at: -30)]
        XCTAssertEqual(CleanLog.capped(events, cap: 10).map { $0.kind }, ["a", "b"])
    }

    func testCapped_nonPositiveCap_returnsEmpty() {
        XCTAssertTrue(CleanLog.capped([event("a", rssKB: 1, at: 0)], cap: 0).isEmpty)
    }

    func testCapped_empty_returnsEmpty() {
        XCTAssertTrue(CleanLog.capped([], cap: 5).isEmpty)
    }

    // MARK: - stats (rolling window)

    func testStats_windowsOutOldEvents() {
        let events = [event("pytest", rssKB: 100, at: -60),      // in window
                      event("pytest", rssKB: 200, at: -600),     // outside 5-min window
                      event("npm", rssKB: 50, at: -30)]          // in window
        let stats = CleanLog.stats(from: events, now: t(0), window: 300)
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.ramReclaimedKB, 150)
    }

    func testStats_topKinds_rankedByFrequencyThenName() {
        let events = [event("npm", rssKB: 1, at: -10),
                      event("pytest", rssKB: 1, at: -20),
                      event("pytest", rssKB: 1, at: -30),
                      event("bun", rssKB: 1, at: -40)]           // ties npm at count 1
        let stats = CleanLog.stats(from: events, now: t(0), window: 300)
        // pytest (2) first; then the count-1 tie bun/npm broken alphabetically.
        XCTAssertEqual(stats.topKinds, [
            CleanLog.KindCount(kind: "pytest", count: 2),
            CleanLog.KindCount(kind: "bun", count: 1),
            CleanLog.KindCount(kind: "npm", count: 1),
        ])
    }

    func testStats_boundaryEventAtCutoff_included() {
        // An event exactly `window` seconds old sits on the inclusive lower bound.
        let stats = CleanLog.stats(from: [event("npm", rssKB: 10, at: -300)], now: t(0), window: 300)
        XCTAssertEqual(stats.count, 1)
    }

    func testStats_empty_returnsZeroes() {
        let stats = CleanLog.stats(from: [], now: t(0), window: 300)
        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.ramReclaimedKB, 0)
        XCTAssertTrue(stats.topKinds.isEmpty)
    }

    // MARK: - CleanEvent Codable

    func testCleanEvent_codableRoundTrip_iso8601() throws {
        let original = event("vite", rssKB: 4096, at: -120)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(CleanEvent.self, from: encoder.encode(original))
        XCTAssertEqual(restored, original)
    }
}
