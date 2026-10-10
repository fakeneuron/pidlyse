import XCTest
@testable import PidlyseCore

final class CLICoreTests: XCTestCase {

    // MARK: - Command parse (PID-57.3)

    func testParse_emptyArgs_isHelp() {
        XCTAssertEqual(CLICore.parse([]), .success(.help))
    }

    func testParse_helpForms() {
        XCTAssertEqual(CLICore.parse(["help"]), .success(.help))
        XCTAssertEqual(CLICore.parse(["--help"]), .success(.help))
        XCTAssertEqual(CLICore.parse(["-h"]), .success(.help))
    }

    func testParse_list() {
        XCTAssertEqual(CLICore.parse(["list"]), .success(.list(safeOnly: false)))
        XCTAssertEqual(CLICore.parse(["list", "--safe"]), .success(.list(safeOnly: true)))
    }

    func testParse_list_unexpectedArgument() {
        XCTAssertEqual(CLICore.parse(["list", "--all"]), .failure(.unexpectedArgument("--all")))
        XCTAssertEqual(CLICore.parse(["list", "--safe", "extra"]), .failure(.unexpectedArgument("extra")))
    }

    func testParse_clean() {
        XCTAssertEqual(CLICore.parse(["clean"]), .success(.clean))
        XCTAssertEqual(CLICore.parse(["clean", "--force"]), .failure(.unexpectedArgument("--force")))
    }

    func testParse_kill() {
        XCTAssertEqual(CLICore.parse(["kill", "1234"]), .success(.kill(pid: 1234)))
        XCTAssertEqual(CLICore.parse(["kill"]), .failure(.missingPID))
        XCTAssertEqual(CLICore.parse(["kill", "abc"]), .failure(.invalidPID("abc")))
        XCTAssertEqual(CLICore.parse(["kill", "-5"]), .failure(.invalidPID("-5")))
        XCTAssertEqual(CLICore.parse(["kill", "0"]), .failure(.invalidPID("0")))
        XCTAssertEqual(CLICore.parse(["kill", "12", "34"]), .failure(.unexpectedArgument("34")))
    }

    func testParse_unknownCommand() {
        XCTAssertEqual(CLICore.parse(["scan"]), .failure(.unknownCommand("scan")))
    }

    // MARK: - Clean exit status (PID-079.5)

    func testCleanExitStatus_requiresEverySweptItemToBeGone() {
        let gone = item(pid: 100, kind: .pytest, tier: .easy)
        let survived = item(pid: 200, kind: .node, tier: .easy)

        XCTAssertEqual(CLICore.cleanExitStatus(report: KillReport(items: [gone], phases: [100: .gone])), 0)
        XCTAssertEqual(CLICore.cleanExitStatus(report: KillReport(items: [gone, survived], phases: [100: .gone, 200: .survived])), 1)
        XCTAssertEqual(CLICore.cleanExitStatus(report: KillReport(items: [], phases: [:])), 0)
    }

    // MARK: - Formatting

    func testFormatElapsed() {
        XCTAssertEqual(CLICore.formatElapsed(12), "12s")
        XCTAssertEqual(CLICore.formatElapsed(45 * 60), "45m")
        XCTAssertEqual(CLICore.formatElapsed(2 * 3600 + 13 * 60), "2h 13m")
        XCTAssertEqual(CLICore.formatElapsed(3 * 86400 + 4 * 3600), "3d 4h")
    }

    func testFormatRSS() {
        XCTAssertEqual(CLICore.formatRSS(kb: 512), "512 KB")
        XCTAssertEqual(CLICore.formatRSS(kb: 145 * 1024), "145 MB")
        XCTAssertEqual(CLICore.formatRSS(kb: 1_468_006), "1.4 GB")
    }

    func testTruncate() {
        XCTAssertEqual(CLICore.truncate("short", max: 10), "short")
        XCTAssertEqual(CLICore.truncate("abcdefghij", max: 5), "abcd…")
    }

    // MARK: - List table

    private func item(pid: Int32, kind: ProcessKind, tier: RiskTier,
                      command: String = "npm run dev") -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: command, elapsed: 3600, tty: "??",
                    kind: kind, riskTier: tier, cpuPercent: 0.5, rssKB: 2048)
    }

    func testListTable_rendersHeaderAndRows() {
        let items = [item(pid: 100, kind: .pytest, tier: .easy),
                     item(pid: 200, kind: .docker, tier: .high)]
        let cwds: [Int32: ProcessCwd] = [100: ProcessCwd(label: "bidviz", fullPath: "~/code/bidviz", projectRoot: "~/code/bidviz")]
        let table = CLICore.listTable(items: items, cwds: cwds)
        let lines = table.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].contains("PID") && lines[0].contains("BUCKET") && lines[0].contains("COMMAND"))
        XCTAssertTrue(lines[1].contains("100") && lines[1].contains("safe") && lines[1].contains("bidviz"))
        // No cwd resolved for 200 → em-dash placeholder; docker is needsReview.
        XCTAssertTrue(lines[2].contains("200") && lines[2].contains("review") && lines[2].contains("—"))
    }

    func testListTable_marksProtectedRows() {
        let table = CLICore.listTable(items: [item(pid: 100, kind: .pytest, tier: .easy)],
                                      protectedPIDs: [100])
        XCTAssertTrue(table.contains("safe 🔒"))
    }

    func testListTable_truncatesLongCommands() {
        let long = String(repeating: "x", count: 200)
        let table = CLICore.listTable(items: [item(pid: 100, kind: .node, tier: .high, command: long)],
                                      commandMax: 40)
        XCTAssertFalse(table.contains(long))
        XCTAssertTrue(table.contains(String(repeating: "x", count: 39) + "…"))
    }
}
