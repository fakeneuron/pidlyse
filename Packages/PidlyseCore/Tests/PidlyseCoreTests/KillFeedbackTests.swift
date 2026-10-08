import XCTest
@testable import PidlyseCore

// MARK: - Kill feedback (PID-62.5)

final class KillFeedbackTests: XCTestCase {

    private func proc(_ pid: Int32, rssKB: Int = 0) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: "node x", elapsed: 0, tty: "??", kind: .node,
                    riskTier: .easy, cpuPercent: 0, rssKB: rssKB)
    }

    func testPhase_fromEveryOutcome() {
        XCTAssertEqual(KillPhase(.confirmed), .gone)
        XCTAssertEqual(KillPhase(.survived), .survived)
        XCTAssertEqual(KillPhase(.unkillable), .unkillable)
        XCTAssertEqual(KillPhase(.notKilled), .skipped)
    }

    func testPhase_onlyGoneAndRespawnedAreDeparted() {
        XCTAssertTrue(KillPhase.gone.isDeparted)
        XCTAssertTrue(KillPhase.respawned.isDeparted)
        for phase: KillPhase in [.killing, .survived, .unkillable, .skipped] {
            XCTAssertFalse(phase.isDeparted, "\(phase)")
        }
    }

    func testReport_countsEachPhase_andRespawnedIsNotCleaned() {
        let items = (1...6).map { proc(Int32($0), rssKB: 1024) }
        let phases: [Int32: KillPhase] = [1: .gone, 2: .gone, 3: .respawned, 4: .survived, 5: .unkillable, 6: .skipped]
        let report = KillReport(items: items, phases: phases)
        XCTAssertEqual(report.requested, 6)
        XCTAssertEqual(report.gone, 2)
        XCTAssertEqual(report.respawned, 1)
        XCTAssertEqual(report.survived, 1)
        XCTAssertEqual(report.unkillable, 1)
        XCTAssertEqual(report.skipped, 1)
    }

    func testReport_reclaimedCountsOnlyRowsThatStayedGone() {
        // A respawned process's memory came straight back; a survivor never freed any.
        let items = [proc(1, rssKB: 2048), proc(2, rssKB: 4096), proc(3, rssKB: 8192)]
        let report = KillReport(items: items, phases: [1: .gone, 2: .respawned, 3: .survived])
        XCTAssertEqual(report.reclaimedKB, 2048)
    }

    func testReport_missingOrInFlightPhase_countsOnlyAsRequested() {
        let report = KillReport(items: [proc(1), proc(2)], phases: [2: .killing])
        XCTAssertEqual(report.requested, 2)
        XCTAssertEqual(report.gone + report.respawned + report.survived + report.unkillable + report.skipped, 0)
    }

    func testSummaryLine_allGone_isHeadlinePlusReclaimed() {
        let report = KillReport(items: [proc(1, rssKB: 2048), proc(2, rssKB: 1024)], phases: [1: .gone, 2: .gone])
        XCTAssertEqual(report.summaryLine, "Cleaned 2 of 2 \u{00B7} 3 MB reclaimed")
    }

    func testSummaryLine_namesEveryNonCleanOutcome() {
        let items = (1...5).map { proc(Int32($0)) }
        let report = KillReport(items: items, phases: [1: .gone, 2: .respawned, 3: .survived, 4: .unkillable, 5: .skipped])
        XCTAssertEqual(report.headline, "Cleaned 1 of 5")
        XCTAssertEqual(report.details,
                       "1 respawned \u{00B7} 1 didn\u{2019}t die \u{00B7} 1 can\u{2019}t kill \u{00B7} 1 skipped")
    }

    func testSummaryLine_nothingFreed_omitsReclaimed() {
        let report = KillReport(items: [proc(1, rssKB: 0)], phases: [1: .survived])
        XCTAssertEqual(report.summaryLine, "Cleaned 0 of 1 \u{00B7} 1 didn\u{2019}t die")
    }

    func testReport_empty() {
        let report = KillReport(items: [], phases: [:])
        XCTAssertEqual(report.requested, 0)
        XCTAssertEqual(report.summaryLine, "Cleaned 0 of 0")
    }
}
