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
        XCTAssertEqual(CLICore.parse(["list"]), .success(.list(showAll: false)))
        XCTAssertEqual(CLICore.parse(["list", "--all"]), .success(.list(showAll: true)))
    }

    func testParse_list_unexpectedArgument() {
        // `--safe` was retired by PID-086.5 — the bucket no longer gates what `list` shows.
        XCTAssertEqual(CLICore.parse(["list", "--safe"]), .failure(.unexpectedArgument("--safe")))
        XCTAssertEqual(CLICore.parse(["list", "--all", "extra"]), .failure(.unexpectedArgument("extra")))
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
        XCTAssertTrue(lines[0].hasPrefix("NAME"))
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
        // The flag value is long; the name (`app.js`) is short, so only COMMAND is trimmed.
        let long = "--token=" + String(repeating: "x", count: 200)
        let table = CLICore.listTable(items: [item(pid: 100, kind: .node, tier: .high, command: "node app.js " + long)],
                                      commandMax: 40)
        XCTAssertFalse(table.contains(long))
        XCTAssertTrue(table.contains("node app.js --token=" + String(repeating: "x", count: 19) + "…"))
    }

    func testListTable_leadsWithNameAndShowsReason() {
        let items = [item(pid: 100, kind: .node, tier: .high, command: "node /usr/local/bin/vite --port 5173"),
                     item(pid: 200, kind: .pytest, tier: .easy)]
        let table = CLICore.listTable(items: items, verdicts: [100: .sessionEnded])
        let lines = table.split(separator: "\n").map(String.init)
        let header = lines[0]
        XCTAssertTrue(header.range(of: "NAME")!.lowerBound < header.range(of: "PID")!.lowerBound)
        XCTAssertTrue(header.range(of: "PID")!.lowerBound < header.range(of: "REASON")!.lowerBound)
        XCTAssertTrue(lines[1].hasPrefix(items[0].displayName))
        XCTAssertTrue(lines[1].contains("Session ended"))
        // No verdict for 200 → reads as running.
        XCTAssertTrue(lines[2].contains("Running"))
    }

    func testListTable_neverTruncatesName() {
        let long = "node " + String(repeating: "x", count: 120) + ".js"
        let one = item(pid: 100, kind: .node, tier: .high, command: long)
        let table = CLICore.listTable(items: [one], commandMax: 20)
        XCTAssertTrue(table.contains(one.displayName))
    }

    // MARK: - List rows (PID-086.5)

    func testListItems_defaultsToStraysInReasonOrder() {
        let items = [item(pid: 1, kind: .node, tier: .high), item(pid: 2, kind: .node, tier: .high),
                     item(pid: 3, kind: .node, tier: .high), item(pid: 4, kind: .node, tier: .high),
                     item(pid: 5, kind: .node, tier: .high)]
        let verdicts: [Int32: StrayVerdict] = [1: .duplicate, 2: .running, 3: .sessionEnded,
                                               4: .idle, 5: .sessionEnded]
        XCTAssertEqual(CLICore.listItems(items, verdicts: verdicts, showAll: false).map(\.pid), [3, 5, 4, 1])
    }

    func testListItems_allAddsRunningLast() {
        let items = [item(pid: 1, kind: .node, tier: .high), item(pid: 2, kind: .node, tier: .high),
                     item(pid: 3, kind: .node, tier: .high)]
        let verdicts: [Int32: StrayVerdict] = [1: .running, 2: .idle]
        // 3 has no verdict → running; scan order holds within the running group.
        XCTAssertEqual(CLICore.listItems(items, verdicts: verdicts, showAll: true).map(\.pid), [2, 1, 3])
        XCTAssertEqual(CLICore.listItems(items, verdicts: verdicts, showAll: false).map(\.pid), [2])
    }
}
