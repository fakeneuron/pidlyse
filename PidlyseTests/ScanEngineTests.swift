import XCTest
import PidlyseCore
@testable import Pidlyse

final class ScanEngineTests: XCTestCase {

    // MARK: - parsePSLine

    func testParsePSLine_withSpacesInArgs() {
        let line = "  569     1 12-08:33:38 ??       0.1  12345  /Library/Helpers/com.docker.vmnetd --flag a b"
        let parsed = ScanCore.parsePSLine(line)
        XCTAssertEqual(parsed?.pid, 569)
        XCTAssertEqual(parsed?.ppid, 1)
        XCTAssertEqual(parsed?.etime, "12-08:33:38")
        XCTAssertEqual(parsed?.tty, "??")
        XCTAssertEqual(parsed?.pcpu, "0.1")
        XCTAssertEqual(parsed?.rss, "12345")
        XCTAssertEqual(parsed?.args, "/Library/Helpers/com.docker.vmnetd --flag a b")
    }

    func testParsePSLine_withRealTTY() {
        let line = " 2172  100    30:13 ttys001  0.0  8192  npm run dev"
        let parsed = ScanCore.parsePSLine(line)
        XCTAssertEqual(parsed?.pid, 2172)
        XCTAssertEqual(parsed?.tty, "ttys001")
        XCTAssertEqual(parsed?.args, "npm run dev")
    }

    // MARK: - isTTYAttached (TTY sentinel SSOT)

    func testIsTTYAttached_sentinelsMeanNoTerminal() {
        for none in ["", "  ", "??", "?", "-", " ?? "] {
            XCTAssertFalse(ProcessItem.isTTYAttached(none), "\(none.debugDescription) should mean no terminal")
        }
    }

    func testIsTTYAttached_realTerminal() {
        XCTAssertTrue(ProcessItem.isTTYAttached("ttys001"))
        XCTAssertTrue(ProcessItem.isTTYAttached(" ttys002 "))
    }

    func testParsePSLine_rejectsMalformed() {
        XCTAssertNil(ScanCore.parsePSLine(""))
        XCTAssertNil(ScanCore.parsePSLine("   "))
        XCTAssertNil(ScanCore.parsePSLine("123 456 only-three-fields"))
    }

    // MARK: - parseElapsed

    func testParseElapsed_formats() {
        XCTAssertEqual(ScanCore.parseElapsed("05:23"), TimeInterval(5 * 60 + 23))
        XCTAssertEqual(ScanCore.parseElapsed("01:05:23"), TimeInterval(3600 + 5 * 60 + 23))
        XCTAssertEqual(ScanCore.parseElapsed("2-03:04:05"), TimeInterval(2 * 86400 + 3 * 3600 + 4 * 60 + 5))
        XCTAssertEqual(ScanCore.parseElapsed("42"), TimeInterval(42))
    }

    // MARK: - detectKind

    func testDetectKind_basics() {
        XCTAssertEqual(ScanCore.detectKind("python -m pytest tests/"), .pytest)
        XCTAssertEqual(ScanCore.detectKind("node node_modules/.bin/vitest run"), .vitest)
        XCTAssertEqual(ScanCore.detectKind("node node_modules/.bin/jest --watch"), .jest)
        XCTAssertEqual(ScanCore.detectKind("uvicorn backend.main:app --reload"), .uvicorn)
        XCTAssertEqual(ScanCore.detectKind("npm run dev"), .npm)
        XCTAssertEqual(ScanCore.detectKind("node @playwright/mcp@latest"), .playwrightMCP)
        // New patterns: vite, bun, node
        XCTAssertEqual(ScanCore.detectKind("node node_modules/.bin/vite --port 5173"), .vite)
        XCTAssertEqual(ScanCore.detectKind("bun run dev"), .bun)
        XCTAssertEqual(ScanCore.detectKind("node server.js"), .node)
        // vitest must still win over vite (order check)
        XCTAssertEqual(ScanCore.detectKind("node node_modules/.bin/vitest run"), .vitest)
    }

    func testDetectKind_bundle_notBun() {
        // Ruby bundler must not match the bun guard.
        XCTAssertNil(ScanCore.detectKind("bundle install"))
        XCTAssertNil(ScanCore.detectKind("/usr/local/bin/bundle install"))
    }

    func testDetectKind_bareNode_isNode() {
        // No trailing space — bare command (== "node") and path-only (/node) forms.
        XCTAssertEqual(ScanCore.detectKind("node"), .node)
        XCTAssertEqual(ScanCore.detectKind("/usr/local/bin/node"), .node)
    }

    func testDetectKind_nodeBunTokenBoundary_noSubstringFalsePositives() {
        // PID-046: node/bun route through the shared `hasTokenBoundary` helper, so an
        // executable that merely ends with or contains the token (without a word
        // boundary) is not misclassified.
        XCTAssertNil(ScanCore.detectKind("/usr/bin/fake-node"))
        XCTAssertNil(ScanCore.detectKind("some-node tool"))
        XCTAssertNil(ScanCore.detectKind("/opt/embun"))
        XCTAssertNil(ScanCore.detectKind("inode"))
        // Legitimate matches still fire.
        XCTAssertEqual(ScanCore.detectKind("node server.js"), .node)
        XCTAssertEqual(ScanCore.detectKind("bun run dev"), .bun)
    }

    func testDetectKind_chromeUnderPlaywrightMCP_isChromeHelper() {
        let args = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless " +
                   "--user-data-dir=/Users/me/Library/Caches/ms-playwright-mcp/mcp-chrome-abc"
        XCTAssertEqual(ScanCore.detectKind(args), .chromeHelper)
    }

    func testDetectKind_normalChrome_isExcluded() {
        let args = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/me/Default"
        XCTAssertNil(ScanCore.detectKind(args))
    }

    func testDetectKind_unrelated_isNil() {
        XCTAssertNil(ScanCore.detectKind("/usr/sbin/cfprefsd agent"))
    }

    func testDetectKind_pnpmIsNotNpm() {
        // pnpm contains "npm" as a substring — the token-boundary guard must prevent a match.
        XCTAssertNil(ScanCore.detectKind("pnpm run dev"))
        XCTAssertNil(ScanCore.detectKind("pnpm install"))
    }

    func testDetectKind_jestPathIsNotJest() {
        // A user project directory named "jest-examples" must not match the jest guard.
        XCTAssertNil(ScanCore.detectKind("/Users/user/jest-examples/server start"))
    }

    // MARK: - riskTier / bucket

    func testOrphanedOldPytest_isEasyKill() {
        let tier = ScanCore.riskTier(kind: .pytest, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .easy)
    }

    func testRecentPytestWithTTY_isNotEasy() {
        // Has a terminal and isn't old → not a strong stray.
        let tier = ScanCore.riskTier(kind: .pytest, hasTTY: true, isOrphan: false, isOld: false)
        XCTAssertEqual(tier, .moderate)
    }

    func testUvicorn_isHighRisk() {
        // Dev infra is high regardless of stray signals.
        let tier = ScanCore.riskTier(kind: .uvicorn, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testDocker_isHighRisk() {
        let tier = ScanCore.riskTier(kind: .docker, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testNode_isHighRisk() {
        // Bare node is always high risk, like docker/uvicorn.
        let tier = ScanCore.riskTier(kind: .node, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testNpmStrongStray_isModerate_notEasy() {
        let tier = ScanCore.riskTier(kind: .npm, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .moderate)
    }

    func testViteStrongStray_isModerate() {
        // npm-tier: strongStray → moderate, not easy.
        let tier = ScanCore.riskTier(kind: .vite, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .moderate)
    }

    func testViteNotStrongStray_isHigh() {
        let tier = ScanCore.riskTier(kind: .vite, hasTTY: true, isOrphan: false, isOld: false)
        XCTAssertEqual(tier, .high)
    }

    func testBunStrongStray_isModerate() {
        // npm-tier: strongStray → moderate.
        let tier = ScanCore.riskTier(kind: .bun, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .moderate)
    }

    // MARK: - bucket derivation + end-to-end enumerate

    func testBucketDerivation() {
        let easy = ProcessItem(pid: 1, ppid: 1, command: "pytest", elapsed: 9999,
                               tty: "??", kind: .pytest, riskTier: .easy, cpuPercent: 0, rssKB: 0)
        let high = ProcessItem(pid: 2, ppid: 1, command: "uvicorn", elapsed: 9999,
                               tty: "??", kind: .uvicorn, riskTier: .high, cpuPercent: 0, rssKB: 0)
        XCTAssertEqual(easy.bucket, .safe)
        XCTAssertEqual(high.bucket, .needsReview)
    }

    func testEnumerate_classifiesInjectedOutput() {
        let output = """
          569     1 12-08:33:38 ??   0.0  4096   /Applications/Docker.app/Contents/MacOS/com.docker.backend
         2172     1    45:00 ??   0.1  8192   npm run dev
         3000  2999    00:30 ttys002  0.0  4096   python -m pytest tests/unit
         4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow
         9999     1 00:10 ??   0.0  1024   /usr/sbin/cfprefsd agent
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output)

        // cfprefsd matches nothing → excluded; the other four are candidates.
        XCTAssertEqual(items.count, 4)

        let docker = items.first { $0.pid == 569 }
        XCTAssertEqual(docker?.kind, .docker)
        XCTAssertEqual(docker?.bucket, .needsReview)

        // Orphaned, old (1h46m), no TTY pytest → easy → safe.
        let strayPytest = items.first { $0.pid == 4000 }
        XCTAssertEqual(strayPytest?.kind, .pytest)
        XCTAssertEqual(strayPytest?.riskTier, .easy)
        XCTAssertEqual(strayPytest?.bucket, .safe)

        // Recent pytest with a TTY → not a strong stray → needsReview.
        let activePytest = items.first { $0.pid == 3000 }
        XCTAssertEqual(activePytest?.bucket, .needsReview)
    }

    // MARK: - Port registry demotion

    func testPortRegisteredProcess_demotedFromEasyToNeedsReview() {
        // Would be easy (orphaned, old, no TTY pytest) but pid 4000 is on a registered port.
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [4000])
        XCTAssertEqual(items.first?.riskTier, .moderate)
        XCTAssertEqual(items.first?.bucket, .needsReview)
    }

    func testPortRegisteredProcess_alreadyModerate_staysNeedsReview() {
        // Has a TTY → moderate already; port match doesn't change outcome.
        let output = "  3000  2999    00:30 ttys002  0.0  4096   python -m pytest tests/unit"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [3000])
        XCTAssertEqual(items.first?.bucket, .needsReview)
    }

    func testNonRegisteredProcess_easyStaysSafe() {
        // Not in registeredPIDs → no demotion.
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [])
        XCTAssertEqual(items.first?.riskTier, .easy)
        XCTAssertEqual(items.first?.bucket, .safe)
    }

    // MARK: - ignoredNames filtering

    func testEnumerate_ignoredNames_match_filtersProcess() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["pytest"])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_ignoredNames_noMatch_processKept() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["vitest"])
        XCTAssertEqual(items.count, 1)
    }

    func testEnumerate_ignoredNames_caseInsensitive() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["PyTest"])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_ignoredNames_empty_noFiltering() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: [])
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - disabledKinds filtering

    func testEnumerate_disabledKinds_match_filtersProcess() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         disabledKinds: [.pytest])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_disabledKinds_noMatch_processKept() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         disabledKinds: [.vitest])
        XCTAssertEqual(items.count, 1)
    }

    func testEnumerate_disabledKinds_empty_noFiltering() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         disabledKinds: [])
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - dismissedPIDs filtering

    func testEnumerate_dismissedPIDs_match_filtersProcess() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         dismissedPIDs: [4000])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_dismissedPIDs_noMatch_processKept() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         dismissedPIDs: [9999])
        XCTAssertEqual(items.count, 1)
    }

    func testEnumerate_dismissedPIDs_empty_noFiltering() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         dismissedPIDs: [])
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - displayPath

    private func item(command: String) -> ProcessItem {
        ProcessItem(pid: 1, ppid: 1, command: command, elapsed: 0,
                    tty: "??", kind: .pytest, riskTier: .easy, cpuPercent: 0, rssKB: 0)
    }

    func testDisplayPath_absolutePathWithArgs_showsParentSlashExec() {
        XCTAssertEqual(item(command: "/usr/local/bin/uvicorn main:app --reload").displayPath,
                       "bin/uvicorn")
    }

    func testDisplayPath_bareWordCommand_showsFirstToken() {
        XCTAssertEqual(item(command: "npm run dev").displayPath, "npm")
    }

    func testDisplayPath_absoluteNoArgs_showsParentSlashExec() {
        XCTAssertEqual(item(command: "/Applications/Docker.app/Contents/MacOS/com.docker.backend").displayPath,
                       "MacOS/com.docker.backend")
    }

    func testDisplayPath_singleAbsolutePath_showsExecName() {
        XCTAssertEqual(item(command: "/uvicorn").displayPath, "uvicorn")
    }

    // MARK: - PortRegistry.parsePIDAndPort

    func testParsePIDAndPort_registeredPort_returnsPID() {
        // 3001 is siteguy's frontend port — in registeredPorts.
        let line = "node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)"
        let pid = PortRegistry.parsePIDAndPort(line)
        XCTAssertEqual(pid, 1234)
    }

    func testParsePIDAndPort_unregisteredPort_returnsNil() {
        let line = "ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)"
        XCTAssertNil(PortRegistry.parsePIDAndPort(line))
    }

    func testParsePIDAndPort_headerLine_returnsNil() {
        let line = "COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME"
        XCTAssertNil(PortRegistry.parsePIDAndPort(line))
    }

    // MARK: - PortRegistry.listeningPIDs

    func testListeningPIDs_multiLine_returnsAllRegisteredPIDs() {
        // Two different PIDs on two different registered ports.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        python     5678 user  11u  IPv4 0x0  0t0  TCP *:5173 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234, 5678])
    }

    func testListeningPIDs_duplicatePID_deduplicates() {
        // Same PID listening on two registered ports → appears only once in the result.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        node       1234 user  23u  IPv4 0x0  0t0  TCP *:3002 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234])
    }

    func testListeningPIDs_headerLine_skipped() {
        // Header line ("COMMAND PID …") must not contribute a PID.
        let output = """
        COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        """
        let pids = PortRegistry.listeningPIDs(lsofOutput: output)
        XCTAssertEqual(pids, [1234])
    }

    // MARK: - PortRegistry.parseListenerLine

    func testParseListenerLine_registeredPort_returnsPIDAndPort() {
        let line = "node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)"
        let match = PortRegistry.parseListenerLine(line)
        XCTAssertEqual(match?.pid, 1234)
        XCTAssertEqual(match?.port, 3001)
    }

    func testParseListenerLine_unregisteredPort_returnsNil() {
        let line = "ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)"
        XCTAssertNil(PortRegistry.parseListenerLine(line))
    }

    // MARK: - PortRegistry.listeningPorts (PID-036.2 — PID→port map)

    func testListeningPorts_multiLine_mapsEachPIDToItsPort() {
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        python     5678 user  11u  IPv4 0x0  0t0  TCP *:5173 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001], 5678: [5173]])
    }

    func testListeningPorts_samePIDmultiplePorts_accumulates() {
        // One PID listening on two registered ports → both collected under that PID.
        let output = """
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        node       1234 user  23u  IPv4 0x0  0t0  TCP *:3002 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001, 3002]])
    }

    func testListeningPorts_headerAndUnregistered_skipped() {
        let output = """
        COMMAND    PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
        node       1234 user  22u  IPv4 0x0  0t0  TCP *:3001 (LISTEN)
        ruby       5678 user  11u  IPv4 0x0  0t0  TCP *:9999 (LISTEN)
        """
        let ports = PortRegistry.listeningPorts(lsofOutput: output)
        XCTAssertEqual(ports, [1234: [3001]])
    }

    func testListeningPorts_empty_returnsEmpty() {
        XCTAssertTrue(PortRegistry.listeningPorts(lsofOutput: "").isEmpty)
    }

    // MARK: - PortRegistry.registeredPorts (anti-drift canary)

    /// Tripwire for the manually-synced port table. `registeredPorts` mirrors
    /// `~/.claude/CLAUDE.md` §"Localhost Port Registry" by hand; if an edit
    /// accidentally drops or corrupts a known port, this assertion fails under
    /// `make test`. Each port is an anchor for an active project — keep this
    /// canary in sync when the global table changes.
    func testRegisteredPorts_canaryKnownPorts() {
        let known: [Int] = [
            5182,   // InvisiPaw frontend
            8001,   // InvisiPaw backend
            3001,   // siteguy frontend
            4000,   // marscharts frontend
            5120,   // flowtron/viz
            5899,   // stockshock frontend
            8005,   // bidviz backend
            3002,   // fakeneuron
            4321,   // spinalcord
            5184,   // wandora frontend
            5183,   // delparte
            3003,   // blastimage
            5185,   // finanal frontend
        ]
        for port in known {
            XCTAssertTrue(PortRegistry.registeredPorts.contains(port),
                          "registeredPorts is missing known port \(port) — manual sync table drifted from ~/.claude/CLAUDE.md")
        }
    }

    // MARK: - PortRegistry.mergedPorts (PID-025 user override merge)

    func testMergedPorts_unionAddsUserPorts() {
        // Keyed-by-project JSON adds two ports not in the built-in set.
        let json = #"{"newproj": [9100, 9200]}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: json)
        XCTAssertEqual(merged, [3001, 8003, 9100, 9200])
    }

    func testMergedPorts_flattensMultipleProjects() {
        // Port lists across multiple project keys are flattened into one set.
        let json = #"{"siteguy": [3001, 8003], "bidviz": [5181, 8005]}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [1111], userJSON: json)
        XCTAssertEqual(merged, [1111, 3001, 8003, 5181, 8005])
    }

    func testMergedPorts_nilJSON_returnsBuiltInUnchanged() {
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: nil)
        XCTAssertEqual(merged, [3001, 8003])
    }

    func testMergedPorts_malformedJSON_fallsBackToBuiltIn() {
        // Garbage / wrong-shape JSON must not throw or empty the registry.
        let json = #"{ not valid json "#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001, 8003], userJSON: json)
        XCTAssertEqual(merged, [3001, 8003])
    }

    func testMergedPorts_wrongShapeJSON_fallsBackToBuiltIn() {
        // Valid JSON but not [String: [Int]] (a flat array) → built-ins unchanged.
        let json = #"[3001, 8003]"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [5500], userJSON: json)
        XCTAssertEqual(merged, [5500])
    }

    func testMergedPorts_emptyObject_returnsBuiltInUnchanged() {
        let json = #"{}"#.data(using: .utf8)
        let merged = PortRegistry.mergedPorts(builtIn: [3001], userJSON: json)
        XCTAssertEqual(merged, [3001])
    }
}

/// Tests for the PID-reuse guard added in PID-18.3: the SIGKILL fallback fires
/// only when the post-grace start time matches the pre-SIGTERM snapshot.
final class KillServiceTests: XCTestCase {

    private let a = KillService.ProcStartTime(sec: 1000, usec: 500)

    // MARK: - shouldEscalateToSIGKILL decision matrix

    func testShouldEscalate_sameStartTime_escalates() {
        // PID still maps to the same process → SIGKILL is safe.
        let same = KillService.ProcStartTime(sec: 1000, usec: 500)
        XCTAssertTrue(KillService.shouldEscalateToSIGKILL(snapshot: a, current: same))
    }

    func testShouldEscalate_differentStartTime_doesNotEscalate() {
        // PID recycled for a different process → must NOT SIGKILL the bystander.
        let reused = KillService.ProcStartTime(sec: 2000, usec: 0)
        XCTAssertFalse(KillService.shouldEscalateToSIGKILL(snapshot: a, current: reused))
    }

    func testShouldEscalate_differingOnlyByMicroseconds_doesNotEscalate() {
        // Identity requires both fields equal; same second, different usec → mismatch.
        let nearMiss = KillService.ProcStartTime(sec: 1000, usec: 501)
        XCTAssertFalse(KillService.shouldEscalateToSIGKILL(snapshot: a, current: nearMiss))
    }

    func testShouldEscalate_currentGone_doesNotEscalate() {
        // Process already exited during the grace period → nothing to kill.
        XCTAssertFalse(KillService.shouldEscalateToSIGKILL(snapshot: a, current: nil))
    }

    func testShouldEscalate_snapshotMissing_doesNotEscalate() {
        // Identity never established at SIGTERM time → conservative: do not escalate.
        XCTAssertFalse(KillService.shouldEscalateToSIGKILL(snapshot: nil, current: a))
    }

    func testShouldEscalate_bothMissing_doesNotEscalate() {
        XCTAssertFalse(KillService.shouldEscalateToSIGKILL(snapshot: nil, current: nil))
    }

    // MARK: - startTime(of:) liveness reader

    func testStartTime_currentProcess_isNonNil() {
        XCTAssertNotNil(KillService.startTime(of: getpid()))
    }

    func testStartTime_currentProcess_isStable() {
        // Reading the same live PID twice yields the same identity token.
        XCTAssertEqual(KillService.startTime(of: getpid()), KillService.startTime(of: getpid()))
    }

    func testStartTime_nonexistentPID_isNil() {
        // Beyond any assignable PID (kern.maxproc) → kernel returns no process.
        XCTAssertNil(KillService.startTime(of: 2_000_000_000))
    }

    // MARK: - shouldSendSIGTERM decision matrix (PID-35.3 — pre-SIGTERM identity guard)

    func testShouldSendSIGTERM_sameStartTime_sends() {
        // PID still maps to the scanned process → safe to SIGTERM.
        let same = KillService.ProcStartTime(sec: 1000, usec: 500)
        XCTAssertTrue(KillService.shouldSendSIGTERM(expected: a, current: same))
    }

    func testShouldSendSIGTERM_recycledPID_doesNotSend() {
        // PID recycled between scan and click → must NOT SIGTERM the bystander.
        let reused = KillService.ProcStartTime(sec: 2000, usec: 0)
        XCTAssertFalse(KillService.shouldSendSIGTERM(expected: a, current: reused))
    }

    func testShouldSendSIGTERM_differingOnlyByMicroseconds_doesNotSend() {
        let nearMiss = KillService.ProcStartTime(sec: 1000, usec: 501)
        XCTAssertFalse(KillService.shouldSendSIGTERM(expected: a, current: nearMiss))
    }

    func testShouldSendSIGTERM_processGoneSinceScan_doesNotSend() {
        // Had a scan-time token but the PID is gone now → nothing to kill.
        XCTAssertFalse(KillService.shouldSendSIGTERM(expected: a, current: nil))
    }

    func testShouldSendSIGTERM_noScanToken_sends() {
        // No identity captured at scan → legacy fallback: send (never worse than
        // pre-PID-35.3, and a wiring miss can't silently no-op every kill).
        XCTAssertTrue(KillService.shouldSendSIGTERM(expected: nil, current: a))
        XCTAssertTrue(KillService.shouldSendSIGTERM(expected: nil, current: nil))
    }
}

/// Tests for the pure `docker ps` parser added in PID-28.2. The impure
/// `DockerService` shell-out is not unit-tested (mirrors `ScanCore.runPS`).
final class DockerCoreTests: XCTestCase {

    // MARK: - parseLine

    func testParseLine_fullRow() {
        let line = "abc123\tpg-db\tpostgres:16\tUp 3 minutes\t0.0.0.0:5432->5432/tcp"
        let c = DockerCore.parseLine(line)
        XCTAssertEqual(c?.id, "abc123")
        XCTAssertEqual(c?.name, "pg-db")
        XCTAssertEqual(c?.image, "postgres:16")
        XCTAssertEqual(c?.status, "Up 3 minutes")
        XCTAssertEqual(c?.ports, "0.0.0.0:5432->5432/tcp")
    }

    func testParseLine_emptyPorts_kept() {
        // Container with no published ports → trailing empty field, still valid.
        let line = "def456\tworker\talpine:latest\tUp 10 seconds\t"
        let c = DockerCore.parseLine(line)
        XCTAssertEqual(c?.id, "def456")
        XCTAssertEqual(c?.ports, "")
    }

    func testParseLine_tooFewFields_isNil() {
        XCTAssertNil(DockerCore.parseLine("abc123\tname\timage\tUp"))
    }

    func testParseLine_emptyID_isNil() {
        XCTAssertNil(DockerCore.parseLine("\tname\timage\tUp 1 minute\t8080/tcp"))
    }

    func testParseLine_blank_isNil() {
        XCTAssertNil(DockerCore.parseLine(""))
    }

    // MARK: - parsePS

    func testParsePS_multipleContainers() {
        let output = """
        abc123\tpg-db\tpostgres:16\tUp 3 minutes\t0.0.0.0:5432->5432/tcp
        def456\tredis\tredis:7\tUp 1 hour\t6379/tcp
        """
        let containers = DockerCore.parsePS(output)
        XCTAssertEqual(containers.count, 2)
        XCTAssertEqual(containers[0].name, "pg-db")
        XCTAssertEqual(containers[1].image, "redis:7")
    }

    func testParsePS_skipsBlankAndMalformedLines() {
        let output = """
        abc123\tpg-db\tpostgres:16\tUp 3 minutes\t5432/tcp

        garbage-no-tabs
        """
        let containers = DockerCore.parsePS(output)
        XCTAssertEqual(containers.count, 1)
        XCTAssertEqual(containers.first?.id, "abc123")
    }

    func testParsePS_empty_returnsEmpty() {
        XCTAssertTrue(DockerCore.parsePS("").isEmpty)
    }

    // MARK: - parseContainerOwners

    func testParseContainerOwners_mapsPIDToName_stripsLeadingSlash() {
        // `docker inspect {{.Name}}` carries a leading slash; it must be stripped.
        let output = "12345\t/pg-db\n67890\t/redis"
        let owners = DockerCore.parseContainerOwners(output)
        XCTAssertEqual(owners, [12345: "pg-db", 67890: "redis"])
    }

    func testParseContainerOwners_skipsPIDZero() {
        // State.Pid 0 = container not running → owns no host process.
        let owners = DockerCore.parseContainerOwners("0\t/stopped\n12345\t/live")
        XCTAssertEqual(owners, [12345: "live"])
    }

    func testParseContainerOwners_skipsMalformedAndBlankLines() {
        let output = "12345\t/ok\nno-tab-here\n\tabc\nnotanumber\t/x"
        let owners = DockerCore.parseContainerOwners(output)
        XCTAssertEqual(owners, [12345: "ok"])
    }

    func testParseContainerOwners_empty_returnsEmpty() {
        XCTAssertTrue(DockerCore.parseContainerOwners("").isEmpty)
    }
}

/// Tests for the pure docker-binary trust policy added in PID-35.3 (F2). The impure
/// `isTrustedExecutable` filesystem read is not unit-tested (mirrors `ScanCore.runPS`).
final class DockerServiceTests: XCTestCase {

    private let user: UInt32 = 501

    func testTrust_rootOwned_notWorldWritable_trusted() {
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o755, currentUID: user))
    }

    func testTrust_currentUserOwned_notWorldWritable_trusted() {
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: user, permissions: 0o755, currentUID: user))
    }

    func testTrust_groupWritable_stillTrusted() {
        // Lenient policy: group-writable is allowed (e.g. /usr/local/bin admin group
        // on Intel) — only world-writable and foreign ownership are rejected.
        XCTAssertTrue(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o775, currentUID: user))
    }

    func testTrust_worldWritable_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o757, currentUID: user))
    }

    func testTrust_rootOwnedButWorldWritable_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 0, permissions: 0o777, currentUID: user))
    }

    func testTrust_foreignOwner_rejected() {
        XCTAssertFalse(DockerService.isTrustedOwnership(ownerUID: 999, permissions: 0o755, currentUID: user))
    }
}

/// Test for the PID-35.3 scan-time start-time capture: an injected provider
/// populates `ProcessItem.startTime`; the default (no provider) leaves it `nil`.
final class ScanCoreStartTimeTests: XCTestCase {

    private let line = "1234 1 10:00 ?? 0.0 1000 pytest tests/"

    func testEnumerate_withProvider_populatesStartTime() {
        let token = ProcStartTime(sec: 42, usec: 7)
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line,
                                       registeredPIDs: [],
                                       startTimeProvider: { _ in token })
        XCTAssertEqual(items.first?.startTime, token)
    }

    func testEnumerate_withoutProvider_startTimeNil() {
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: line,
                                       registeredPIDs: [])
        XCTAssertNil(items.first?.startTime)
    }
}

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

final class CwdResolverTests: XCTestCase {

    // MARK: - parseCwds (lsof -Fpn field output)

    func testParseCwds_multiplePIDs_mapsEachToItsCwd() {
        // Two process sets: each `p<pid>` line is followed by its cwd `n<path>` line.
        let lsof = "p200\nn/Users/x/code/bidviz\np300\nn/Users/x/code/foo\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof),
                       [200: "/Users/x/code/bidviz", 300: "/Users/x/code/foo"])
    }

    func testParseCwds_processWithoutNameLine_skipped() {
        // A process set with no following `n` line contributes nothing.
        let lsof = "p200\np300\nn/Users/x/code/foo\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof), [300: "/Users/x/code/foo"])
    }

    func testParseCwds_unparseablePID_dropsAttachedName() {
        // A malformed `p` value leaves currentPID nil → the following name is ignored.
        let lsof = "pXYZ\nn/Users/x/code/foo\np400\nn/Users/x/code/bar\n"
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: lsof), [400: "/Users/x/code/bar"])
    }

    func testParseCwds_empty_returnsEmpty() {
        XCTAssertEqual(CwdResolver.parseCwds(lsofOutput: ""), [:])
    }

    // MARK: - abbreviateHome

    func testAbbreviateHome_pathUnderHome_collapsesToTilde() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x/code/bidviz", home: "/Users/x"),
                       "~/code/bidviz")
    }

    func testAbbreviateHome_exactHome_returnsTilde() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x", home: "/Users/x"), "~")
    }

    func testAbbreviateHome_outsideHome_unchanged() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/opt/homebrew/bin", home: "/Users/x"),
                       "/opt/homebrew/bin")
    }

    func testAbbreviateHome_homePrefixButNotBoundary_unchanged() {
        // "/Users/xavier" must not match home "/Users/x" — boundary is the slash.
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/xavier/code", home: "/Users/x"),
                       "/Users/xavier/code")
    }

    func testAbbreviateHome_emptyHome_unchanged() {
        XCTAssertEqual(CwdResolver.abbreviateHome("/Users/x/code", home: ""), "/Users/x/code")
    }

    // MARK: - projectLabel (git-root → short label)

    func testProjectLabel_cwdIsRepoRoot_returnsRepoName() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/Users/x/code/bidviz",
                                                gitRoot: "/Users/x/code/bidviz"), "bidviz")
    }

    func testProjectLabel_cwdInSubfolder_returnsRepoSlashSubpath() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/Users/x/code/bidviz/frontend",
                                                gitRoot: "/Users/x/code/bidviz"), "bidviz/frontend")
    }

    func testProjectLabel_notInRepo_returnsLeafFolderName() {
        // No git root found → the leaf folder, never the full path (short + readable).
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/opt/homebrew/var", gitRoot: nil), "var")
    }

    func testProjectLabel_nilRoot_emptyCwd_returnsCwd() {
        XCTAssertEqual(CwdResolver.projectLabel(forCwd: "/", gitRoot: nil), "/")
    }

    // MARK: - processCwds (injected lsof + home + gitRootFinder)

    func testProcessCwds_emptyPIDs_returnsEmptyWithoutShellOut() {
        XCTAssertEqual(CwdResolver.processCwds(forPIDs: [], home: "/Users/x"), [:])
    }

    func testProcessCwds_buildsLabelAndAbbreviatedFullPath() {
        let lsof = "p200\nn/Users/x/code/bidviz/frontend\n"
        let result = CwdResolver.processCwds(forPIDs: [200], lsofOutput: lsof, home: "/Users/x",
                                             gitRootFinder: { _ in "/Users/x/code/bidviz" })
        XCTAssertEqual(result, [200: ProcessCwd(label: "bidviz/frontend",
                                                fullPath: "~/code/bidviz/frontend")])
    }

    func testProcessCwds_noGitRoot_labelIsLeafFolder() {
        let lsof = "p200\nn/Users/x/scratch\n"
        let result = CwdResolver.processCwds(forPIDs: [200], lsofOutput: lsof, home: "/Users/x",
                                             gitRootFinder: { _ in nil })
        XCTAssertEqual(result, [200: ProcessCwd(label: "scratch", fullPath: "~/scratch")])
    }
}

/// Tests for the PID-039 wrapper collapse: an npm/npx launcher and its single
/// scanned child fold into one row that keeps the wrapper's *identity* (pid →
/// kill target) but the child's *kind/command* (label). Only the 1:1 case folds.
final class ScanCoreWrapperCollapseTests: XCTestCase {

    private func item(pid: Int32, ppid: Int32, command: String, kind: ProcessKind,
                      riskTier: RiskTier = .moderate, cpu: Double = 0, rss: Int = 0,
                      startTime: ProcStartTime? = nil) -> ProcessItem {
        ProcessItem(pid: pid, ppid: ppid, command: command, elapsed: 0, tty: "ttys000",
                    kind: kind, riskTier: riskTier, cpuPercent: cpu, rssKB: rss, startTime: startTime)
    }

    func testCollapse_npmExecPlaywright_mergesKeepingWrapperIdentity() {
        // Both wrapper and child classify as .playwrightMCP (the in-group double).
        let token = ProcStartTime(sec: 11, usec: 22)
        let wrapper = item(pid: 105, ppid: 99945, command: "npm exec @playwright/mcp@latest --headless",
                           kind: .playwrightMCP, cpu: 0.2, rss: 336, startTime: token)
        let child = item(pid: 160, ppid: 105, command: "node /Users/x/.npm/_npx/abc/.bin/playwright-mcp --headless",
                         kind: .playwrightMCP, cpu: 1.0, rss: 80)
        let result = ScanCore.collapseWrappers([wrapper, child])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 105)              // identity/kill target = wrapper root
        XCTAssertEqual(result.first?.startTime, token)      // PID-reuse guard validates the root
        XCTAssertEqual(result.first?.kind, .playwrightMCP)
        XCTAssertEqual(result.first?.command, child.command) // label/displayPath = child
        XCTAssertEqual(result.first?.rssKB, 416)            // summed
        XCTAssertEqual(result.first?.cpuPercent ?? 0, 1.2, accuracy: 0.0001)
    }

    func testCollapse_npmRunDevVite_mergesToSingleViteRow() {
        let wrapper = item(pid: 200, ppid: 1, command: "npm run dev", kind: .npm, rss: 2704)
        let child = item(pid: 300, ppid: 200,
                         command: "node /Users/x/code/bananapeel/frontend/node_modules/.bin/vite",
                         kind: .vite, rss: 12432)
        let result = ScanCore.collapseWrappers([wrapper, child])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 200)
        XCTAssertEqual(result.first?.kind, .vite)
        XCTAssertEqual(result.first?.rssKB, 2704 + 12432)
    }

    func testCollapse_wrapperWithNoScannedChild_unchanged() {
        // Orphaned `npm run dev` whose server died — nothing to fold into.
        let wrapper = item(pid: 200, ppid: 1, command: "npm run dev", kind: .npm)
        let result = ScanCore.collapseWrappers([wrapper])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 200)
        XCTAssertEqual(result.first?.kind, .npm)
    }

    func testCollapse_wrapperWithTwoScannedChildren_unchanged() {
        // >1 scanned child → leave untouched (unique row ids, unambiguous kill).
        let wrapper = item(pid: 200, ppid: 1, command: "npm run dev", kind: .npm)
        let viteChild = item(pid: 300, ppid: 200, command: "node .bin/vite", kind: .vite)
        let vitestChild = item(pid: 400, ppid: 200, command: "node .bin/vitest run", kind: .vitest)
        let result = ScanCore.collapseWrappers([wrapper, viteChild, vitestChild])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.map { $0.pid }), [200, 300, 400])
    }

    func testCollapse_nonWrapperParentWithChild_unchanged() {
        // A pytest parent is not an npm/npx launcher → no collapse.
        let parent = item(pid: 3000, ppid: 2999, command: "python -m pytest tests/", kind: .pytest)
        let child = item(pid: 3001, ppid: 3000, command: "node .bin/vite", kind: .vite)
        let result = ScanCore.collapseWrappers([parent, child])
        XCTAssertEqual(result.count, 2)
    }

    func testCollapse_endToEndThroughEnumerate() {
        // The collapse runs as the final enumerate step on real `ps`-shaped output.
        let output = """
          105 99945 14:55:40 ttys000 0.0 336 npm exec @playwright/mcp@latest --headless --output-dir /tmp/playwright-mcp
          160   105 14:55:40 ttys000 0.0 80 node /Users/x/.npm/_npx/abc/node_modules/.bin/playwright-mcp --headless
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.pid, 105)
        XCTAssertEqual(items.first?.kind, .playwrightMCP)
    }
}
