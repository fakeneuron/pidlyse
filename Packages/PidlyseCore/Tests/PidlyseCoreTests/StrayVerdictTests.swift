import XCTest
@testable import PidlyseCore

/// PID-086.2: the stray verdict — session ended / duplicate / idle / running —
/// derived over a whole scan.
final class StrayVerdictTests: XCTestCase {

    private func item(pid: Int32, ppid: Int32 = 200, command: String = "node vite",
                      elapsed: TimeInterval = 60, tty: String = "??",
                      kind: ProcessKind = .vite) -> ProcessItem {
        ProcessItem(pid: pid, ppid: ppid, command: command, elapsed: elapsed, tty: tty,
                    kind: kind, riskTier: .high, cpuPercent: 0, rssKB: 0)
    }

    private func cwd(_ path: String) -> ProcessCwd {
        ProcessCwd(label: (path as NSString).lastPathComponent, fullPath: path)
    }

    /// launchd ← Terminal.app ← login(tty) ← -zsh(tty) ← 200 — a live terminal tab.
    private let terminalTable: [Int32: ProcessNode] = [
        1: ProcessNode(ppid: 0, label: "launchd"),
        10: ProcessNode(ppid: 1, label: "Terminal", isApp: true),
        11: ProcessNode(ppid: 10, label: "login", tty: "ttys001"),
        12: ProcessNode(ppid: 11, label: "-zsh", tty: "ttys001"),
        200: ProcessNode(ppid: 12, label: "just", tty: "ttys001"),
    ]

    private func verdict(_ row: ProcessItem, others: [ProcessItem] = [],
                         cwds: [Int32: ProcessCwd] = [:],
                         table: [Int32: ProcessNode] = [:],
                         quiet: Bool = false) -> StrayVerdict? {
        StrayVerdict.derive([row] + others, cwds: cwds, processTable: table,
                            isQuiet: { _ in quiet })[row.pid]
    }

    // MARK: - Session ended

    func testOrphan_withoutTTY_isSessionEnded() {
        XCTAssertEqual(verdict(item(pid: 300, ppid: 1)), .sessionEnded)
    }

    func testOrphan_withOwnTTY_isNotSessionEnded() {
        XCTAssertEqual(verdict(item(pid: 300, ppid: 1, tty: "ttys002")), .running)
    }

    func testOrphanedBackgroundShell_isSessionEnded() {
        // An agent session exited: its background zsh was reparented to launchd, and
        // the dev server still has `just` as a live parent beneath it.
        let table: [Int32: ProcessNode] = [
            1: ProcessNode(ppid: 0, label: "launchd"),
            100: ProcessNode(ppid: 1, label: "zsh"),
            200: ProcessNode(ppid: 100, label: "just"),
        ]
        XCTAssertEqual(verdict(item(pid: 300), table: table), .sessionEnded)
    }

    func testTerminalAncestor_anchorsTheSession() {
        XCTAssertEqual(verdict(item(pid: 300), table: terminalTable), .running)
    }

    func testAgentWithTTY_anchorsItsBackgroundShell() {
        // claude(tty) ← zsh(??) ← 200 — the live agent session holds it.
        let table: [Int32: ProcessNode] = [
            1: ProcessNode(ppid: 0, label: "launchd"),
            50: ProcessNode(ppid: 1, label: "-zsh", tty: "ttys020"),
            60: ProcessNode(ppid: 50, label: "claude", tty: "ttys020"),
            200: ProcessNode(ppid: 60, label: "zsh"),
        ]
        XCTAssertEqual(verdict(item(pid: 300), table: table), .running)
    }

    func testAppAncestor_anchorsTheSession() {
        // An MCP server started by a desktop app: no tty anywhere, but the app holds it.
        let table: [Int32: ProcessNode] = [
            1: ProcessNode(ppid: 0, label: "launchd"),
            200: ProcessNode(ppid: 1, label: "Claude", isApp: true),
        ]
        XCTAssertEqual(verdict(item(pid: 300, kind: .mcpServer), table: table), .running)
    }

    func testMissingAncestor_isUnknownNotEnded() {
        XCTAssertEqual(verdict(item(pid: 300), table: [1: ProcessNode(ppid: 0, label: "launchd")]),
                       .running)
    }

    func testAncestorCycle_staysBounded() {
        let table: [Int32: ProcessNode] = [
            200: ProcessNode(ppid: 201, label: "a"),
            201: ProcessNode(ppid: 200, label: "b"),
        ]
        XCTAssertEqual(verdict(item(pid: 300), table: table), .running)
    }

    // MARK: - Duplicate

    func testOlderSameCommandSameCwd_isDuplicate_newerRuns() {
        let old = item(pid: 300, elapsed: 5000)
        let new = item(pid: 301, elapsed: 100)
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        let verdicts = StrayVerdict.derive([old, new], cwds: cwds, processTable: terminalTable,
                                           isQuiet: { _ in false })
        XCTAssertEqual(verdicts[300], .duplicate)
        XCTAssertEqual(verdicts[301], .running)
    }

    func testDifferentCwd_isNotDuplicate() {
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app/frontend")]
        XCTAssertEqual(verdict(item(pid: 300, elapsed: 5000), others: [item(pid: 301, elapsed: 100)],
                               cwds: cwds, table: terminalTable), .running)
    }

    func testUnresolvedCwd_isNeverDuplicate() {
        // `npm run dev` with no cwd could be any project — not evidence of a copy.
        XCTAssertEqual(verdict(item(pid: 300, elapsed: 5000), others: [item(pid: 301, elapsed: 100)],
                               table: terminalTable), .running)
    }

    func testSameAge_isNotDuplicate() {
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        XCTAssertEqual(verdict(item(pid: 300, elapsed: 100), others: [item(pid: 301, elapsed: 100)],
                               cwds: cwds, table: terminalTable), .running)
    }

    func testOlderCopyWithItsOwnTerminal_isNotDuplicate() {
        // Two watch-mode runners in two open terminals: both in use.
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        XCTAssertEqual(verdict(item(pid: 300, elapsed: 5000, tty: "ttys001"),
                               others: [item(pid: 301, elapsed: 100, tty: "ttys002")],
                               cwds: cwds, table: terminalTable), .running)
    }

    func testDifferentTempScripts_areNotDuplicates() {
        // Respawn signatures strip temp paths; duplicate identity must not.
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        XCTAssertEqual(verdict(item(pid: 300, command: "node /tmp/build-a.js", elapsed: 5000),
                               others: [item(pid: 301, command: "node /tmp/watch-b.js", elapsed: 100)],
                               cwds: cwds, table: terminalTable), .running)
    }

    func testSessionTooling_isNeverDuplicate() {
        // Two agent sessions in one project each run their own playwright-mcp.
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        let mcp = { (pid: Int32, elapsed: TimeInterval) in
            self.item(pid: pid, command: "node playwright-mcp", elapsed: elapsed, kind: .playwrightMCP)
        }
        XCTAssertEqual(verdict(mcp(300, 5000), others: [mcp(301, 100)], cwds: cwds, table: terminalTable),
                       .running)
    }

    // MARK: - Idle

    func testQuietOldNoTTY_isIdle() {
        XCTAssertEqual(verdict(item(pid: 300, elapsed: StrayVerdict.idleAge), table: terminalTable, quiet: true),
                       .idle)
    }

    func testIdle_needsEveryCondition() {
        let old = StrayVerdict.idleAge + 1
        XCTAssertEqual(verdict(item(pid: 300, elapsed: old), table: terminalTable, quiet: false), .running,
                       "busy CPU")
        XCTAssertEqual(verdict(item(pid: 300, elapsed: StrayVerdict.idleAge - 1), table: terminalTable,
                               quiet: true), .running, "too young")
        XCTAssertEqual(verdict(item(pid: 300, elapsed: old, tty: "ttys001"), table: terminalTable,
                               quiet: true), .running, "has its own terminal")
        XCTAssertEqual(verdict(item(pid: 300, elapsed: old, kind: .playwrightMCP), table: terminalTable,
                               quiet: true), .running, "session tooling")
    }

    // MARK: - Precedence + presentation

    func testPrecedence_sessionEnded_thenDuplicate_thenIdle() {
        let cwds: [Int32: ProcessCwd] = [300: cwd("~/code/app"), 301: cwd("~/code/app")]
        let old = StrayVerdict.idleAge + 1
        // Orphaned, duplicated and idle at once → session ended.
        XCTAssertEqual(verdict(item(pid: 300, ppid: 1, elapsed: old), others: [item(pid: 301, elapsed: 100)],
                               cwds: cwds, quiet: true), .sessionEnded)
        // Attached, duplicated and idle → duplicate.
        XCTAssertEqual(verdict(item(pid: 300, elapsed: old), others: [item(pid: 301, elapsed: 100)],
                               cwds: cwds, table: terminalTable, quiet: true), .duplicate)
    }

    func testIsStrayAndLabels() {
        XCTAssertTrue(StrayVerdict.sessionEnded.isStray)
        XCTAssertTrue(StrayVerdict.duplicate.isStray)
        XCTAssertTrue(StrayVerdict.idle.isStray)
        XCTAssertFalse(StrayVerdict.running.isStray)
        XCTAssertEqual([StrayVerdict.sessionEnded, .duplicate, .idle, .running].map(\.label),
                       ["Session ended", "Duplicate", "Idle", "Running"])
    }
}
