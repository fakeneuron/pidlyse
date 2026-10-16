import XCTest
@testable import PidlyseCore

/// Tests for the PID-52.2 full-ancestry resolver: parses the whole `ps` process
/// table (incl. non-stray shells / launchd) and walks any process's chain to launchd.
final class AncestryResolverTests: XCTestCase {

    // MARK: - parseLine (pid ppid tty comm)

    func testParseLine_compactsExecutablePath() {
        let parsed = AncestryResolver.parseLine("  300   200 ttys004  /opt/homebrew/bin/node")
        XCTAssertEqual(parsed?.pid, 300)
        XCTAssertEqual(parsed?.node, ProcessNode(ppid: 200, label: "node", tty: "ttys004"))
    }

    func testParseLine_commWithSpaces_keepsLeafWithSpaces() {
        // App-bundle helpers carry spaces in the executable path; comm is everything
        // after the ppid, and its last path component keeps the space.
        let parsed = AncestryResolver.parseLine("500 400 ?? /Applications/Visual Studio Code.app/Contents/MacOS/Code Helper")
        XCTAssertEqual(parsed?.pid, 500)
        XCTAssertEqual(parsed?.node, ProcessNode(ppid: 400, label: "Code Helper", isApp: true))
    }

    func testParseLine_bareName_passesThrough() {
        XCTAssertEqual(AncestryResolver.parseLine("1 0 ?? launchd")?.node,
                       ProcessNode(ppid: 0, label: "launchd"))
    }

    func testParseLine_malformed_returnsNil() {
        XCTAssertNil(AncestryResolver.parseLine("notapid 200 ?? /bin/zsh"))
        XCTAssertNil(AncestryResolver.parseLine("300 /bin/zsh"))        // missing ppid + tty fields
        XCTAssertNil(AncestryResolver.parseLine("300 200 ?? "))         // empty comm
    }

    // MARK: - processTable

    func testProcessTable_buildsPIDKeyedMap() {
        let ps = "1 0 ?? /sbin/launchd\n200 1 ttys001 /bin/zsh\n300 200 ttys001 /opt/homebrew/bin/node\n"
        let table = AncestryResolver.processTable(psOutput: ps)
        XCTAssertEqual(table.count, 3)
        XCTAssertEqual(table[300], ProcessNode(ppid: 200, label: "node", tty: "ttys001"))
        XCTAssertEqual(table[1], ProcessNode(ppid: 0, label: "launchd"))
    }

    // MARK: - ancestorChain (walk to launchd)

    func testAncestorChain_walksNearestParentToLaunchd() {
        let table: [Int32: ProcessNode] = [
            1: ProcessNode(ppid: 0, label: "launchd"),
            100: ProcessNode(ppid: 1, label: "login"),
            200: ProcessNode(ppid: 100, label: "zsh"),
            300: ProcessNode(ppid: 200, label: "node"),
        ]
        // A process whose ppid is 200 chains node's parent-side up to launchd.
        XCTAssertEqual(AncestryResolver.ancestorChain(ofPPID: 200, in: table),
                       ["zsh", "login", "launchd"])
    }

    func testAncestorChain_orphan_resolvesLaunchd() {
        // ppid 1 (reparented orphan) → the chain is just launchd, not empty.
        let table: [Int32: ProcessNode] = [1: ProcessNode(ppid: 0, label: "launchd")]
        XCTAssertEqual(AncestryResolver.ancestorChain(ofPPID: 1, in: table), ["launchd"])
    }

    func testAncestorChain_missingAncestor_stopsGracefully() {
        // Parent isn't in the table (raced-away process) → empty chain, no line rendered.
        XCTAssertEqual(AncestryResolver.ancestorChain(ofPPID: 999, in: [:]), [])
    }

    func testAncestorChain_cycle_staysBounded() {
        // A pathological cycle must not loop forever; the `seen` guard stops it.
        let table: [Int32: ProcessNode] = [
            10: ProcessNode(ppid: 20, label: "a"),
            20: ProcessNode(ppid: 10, label: "b"),
        ]
        let chain = AncestryResolver.ancestorChain(ofPPID: 10, in: table)
        XCTAssertEqual(chain, ["a", "b"])
    }
}
