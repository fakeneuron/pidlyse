import XCTest
@testable import PidlyseCore

/// Tests for the PID-036.2 ppid→parent-command resolver: looks the parent up by PID
/// within the scan result set, returning its `displayPath` or nil when the parent
/// isn't itself a candidate (the graceful-degrade case the UI relies on).
final class ScanCoreParentResolutionTests: XCTestCase {

    private func item(pid: Int32, ppid: Int32, command: String) -> ProcessItem {
        ProcessItem(pid: pid, ppid: ppid, command: command, elapsed: 0,
                    tty: "??", kind: .node, riskTier: .high, cpuPercent: 0, rssKB: 0)
    }

    func testParentCommand_parentInSet_returnsParentDisplayPath() {
        let parent = item(pid: 200, ppid: 1, command: "/usr/local/bin/npm run dev")
        let child = item(pid: 300, ppid: 200, command: "node node_modules/.bin/vite")
        let resolved = ScanCore.parentCommand(ofPPID: child.ppid, in: [parent, child])
        XCTAssertEqual(resolved, "bin/npm")
    }

    func testParentCommand_parentNotACandidate_returnsNil() {
        // Parent (a shell) isn't a scanned candidate → graceful degrade to nil.
        let child = item(pid: 300, ppid: 999, command: "node server.js")
        XCTAssertNil(ScanCore.parentCommand(ofPPID: child.ppid, in: [child]))
    }

    func testParentCommand_launchd_returnsNil() {
        // ppid 1 = launchd; orphans surface via isOrphan, not as a parent hint.
        let child = item(pid: 300, ppid: 1, command: "node server.js")
        XCTAssertNil(ScanCore.parentCommand(ofPPID: child.ppid, in: [child]))
    }
}
