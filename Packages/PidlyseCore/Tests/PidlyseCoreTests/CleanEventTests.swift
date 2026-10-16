import XCTest
@testable import PidlyseCore

// MARK: - Clean event construction (PID-079.6)

/// The one path both clean-log writers (app kill hook, CLI) build an event from.
final class CleanEventTests: XCTestCase {

    private let stamp = Date(timeIntervalSince1970: 1_000)

    func testBuiltInKind_storesRawValueAndProjectLabel() {
        let item = ProcessItem(pid: 10, ppid: 1, command: "/usr/local/bin/node server.js", elapsed: 0,
                               tty: "??", kind: .node, riskTier: .easy, cpuPercent: 0, rssKB: 2048)
        let event = CleanEvent(item: item, cwd: ProcessCwd(label: "bidviz/frontend", fullPath: "~/code/bidviz/frontend"),
                               timestamp: stamp)
        XCTAssertEqual(event, CleanEvent(kind: ProcessKind.node.rawValue, projectLabel: "bidviz/frontend",
                                         rssKB: 2048, timestamp: stamp))
    }

    func testCustomRule_storesFriendlyLabelAsKind() {
        let item = ProcessItem(pid: 10, ppid: 1, command: "my-tool --watch", elapsed: 0, tty: "??",
                               kind: .custom, riskTier: .high, cpuPercent: 0, rssKB: 1,
                               customLabel: "My tool")
        XCTAssertEqual(CleanEvent(item: item, cwd: nil, timestamp: stamp).kind, "My tool")
    }

    func testUnresolvedCwd_fallsBackToDisplayPath() {
        let item = ProcessItem(pid: 10, ppid: 1, command: "/usr/local/bin/npm run dev", elapsed: 0,
                               tty: "??", kind: .node, riskTier: .easy, cpuPercent: 0, rssKB: 1)
        XCTAssertEqual(CleanEvent(item: item, cwd: nil, timestamp: stamp).projectLabel, "bin/npm")
    }
}
