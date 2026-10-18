import Darwin
import XCTest
@testable import PidlyseCore

final class ShellTests: XCTestCase {

    override func tearDown() {
        Shell.deadlineOverride = nil
        Shell.launchObserver = nil
        super.tearDown()
    }

    /// `kill(pid, 0)` is the existence check. ESRCH means that pid is gone,
    /// which is what "terminate on expiry" has to show — a fast return is not
    /// enough, because the reap waits themselves fit under a loose time bound.
    private func assertDead(_ pid: Int32) {
        XCTAssertGreaterThan(pid, 0)
        let alive = kill(pid, 0)
        let err = errno
        XCTAssertEqual(alive, -1)
        XCTAssertEqual(err, ESRCH)
    }

    func testBudgets_matchPerToolDeadlines() {
        XCTAssertEqual(Shell.Budget.ps, 10)
        XCTAssertEqual(Shell.Budget.lsof, 20)
        XCTAssertEqual(Shell.Budget.docker, 20)
    }

    func testRun_echoWithinBudget_returnsStdout() {
        let result = Shell.run("/bin/echo", ["ok"], timeout: Shell.Budget.ps)
        XCTAssertEqual(result.output, "ok\n")
        XCTAssertTrue(result.ok)
    }

    func testRun_nonzeroExit_keepsStdout() {
        let result = Shell.run("/bin/sh", ["-c", "echo out; exit 3"], timeout: Shell.Budget.ps)
        XCTAssertEqual(result.output, "out\n")
        XCTAssertFalse(result.ok)
    }

    func testRun_missingBinary_returnsEmptyFalse() {
        let result = Shell.run("/no/such/pidlyse-bin", [], timeout: 1)
        XCTAssertEqual(result.output, "")
        XCTAssertFalse(result.ok)
    }

    func testRun_sleepPastDeadline_killsTheChild() {
        var pid: Int32 = -1
        Shell.launchObserver = { pid = $0 }
        let start = Date()
        let result = Shell.run("/bin/sleep", ["30"], timeout: 0.4)
        XCTAssertEqual(result.output, "")
        XCTAssertFalse(result.ok)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        assertDead(pid)
    }

    func testRun_discardsPartialStdoutOnExpiry() {
        var pid: Int32 = -1
        Shell.launchObserver = { pid = $0 }
        let start = Date()
        // `exec` replaces the shell, so the launched pid is the sleeper. A bare
        // `sleep` after `echo` would be a grandchild `stop` might not reap.
        let result = Shell.run("/bin/sh", ["-c", "echo partial; exec sleep 30"], timeout: 0.4)
        XCTAssertEqual(result.output, "")
        XCTAssertFalse(result.ok)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        assertDead(pid)
    }

    func testRunReporting_finishedSeparatesNonzeroExitFromNoAnswer() {
        // PID-090: exit 1 with no output still finished; expiry and launch failure didn't.
        let quiet = Shell.runReporting("/bin/sh", ["-c", "exit 1"], timeout: Shell.Budget.ps)
        XCTAssertEqual(quiet.output, "")
        XCTAssertFalse(quiet.ok)
        XCTAssertTrue(quiet.finished)
        XCTAssertFalse(Shell.runReporting("/bin/sleep", ["30"], timeout: 0.4).finished)
        XCTAssertFalse(Shell.runReporting("/no/such/pidlyse-bin", [], timeout: 1).finished)
    }

    func testRun_deadlineOverrideZero_discardsAFastCommand() {
        Shell.deadlineOverride = 0
        let result = Shell.run("/bin/echo", ["ok"], timeout: Shell.Budget.ps)
        XCTAssertEqual(result.output, "")
        XCTAssertFalse(result.ok)
    }
}
