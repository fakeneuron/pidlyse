import XCTest
@testable import Pidly

final class ScanEngineTests: XCTestCase {

    // MARK: - parsePSLine

    func testParsePSLine_withSpacesInArgs() {
        let line = "  569     1 12-08:33:38 ??       0.1  12345  /Library/Helpers/com.docker.vmnetd --flag a b"
        let parsed = ScanEngine.parsePSLine(line)
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
        let parsed = ScanEngine.parsePSLine(line)
        XCTAssertEqual(parsed?.pid, 2172)
        XCTAssertEqual(parsed?.tty, "ttys001")
        XCTAssertEqual(parsed?.args, "npm run dev")
    }

    func testParsePSLine_rejectsMalformed() {
        XCTAssertNil(ScanEngine.parsePSLine(""))
        XCTAssertNil(ScanEngine.parsePSLine("   "))
        XCTAssertNil(ScanEngine.parsePSLine("123 456 only-three-fields"))
    }

    // MARK: - parseElapsed

    func testParseElapsed_formats() {
        XCTAssertEqual(ScanEngine.parseElapsed("05:23"), TimeInterval(5 * 60 + 23))
        XCTAssertEqual(ScanEngine.parseElapsed("01:05:23"), TimeInterval(3600 + 5 * 60 + 23))
        XCTAssertEqual(ScanEngine.parseElapsed("2-03:04:05"), TimeInterval(2 * 86400 + 3 * 3600 + 4 * 60 + 5))
        XCTAssertEqual(ScanEngine.parseElapsed("42"), TimeInterval(42))
    }

    // MARK: - detectKind

    func testDetectKind_basics() {
        XCTAssertEqual(ScanEngine.detectKind("python -m pytest tests/"), .pytest)
        XCTAssertEqual(ScanEngine.detectKind("node node_modules/.bin/vitest run"), .vitest)
        XCTAssertEqual(ScanEngine.detectKind("node node_modules/.bin/jest --watch"), .jest)
        XCTAssertEqual(ScanEngine.detectKind("uvicorn backend.main:app --reload"), .uvicorn)
        XCTAssertEqual(ScanEngine.detectKind("npm run dev"), .npm)
        XCTAssertEqual(ScanEngine.detectKind("node @playwright/mcp@latest"), .playwrightMCP)
    }

    func testDetectKind_chromeUnderPlaywrightMCP_isChromeHelper() {
        let args = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless " +
                   "--user-data-dir=/Users/me/Library/Caches/ms-playwright-mcp/mcp-chrome-abc"
        XCTAssertEqual(ScanEngine.detectKind(args), .chromeHelper)
    }

    func testDetectKind_normalChrome_isExcluded() {
        let args = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/me/Default"
        XCTAssertNil(ScanEngine.detectKind(args))
    }

    func testDetectKind_unrelated_isNil() {
        XCTAssertNil(ScanEngine.detectKind("/usr/sbin/cfprefsd agent"))
    }

    // MARK: - riskTier / bucket

    func testOrphanedOldPytest_isEasyKill() {
        let tier = ScanEngine.riskTier(kind: .pytest, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .easy)
    }

    func testRecentPytestWithTTY_isNotEasy() {
        // Has a terminal and isn't old → not a strong stray.
        let tier = ScanEngine.riskTier(kind: .pytest, hasTTY: true, isOrphan: false, isOld: false)
        XCTAssertEqual(tier, .moderate)
    }

    func testUvicorn_isHighRisk() {
        // Dev infra is high regardless of stray signals.
        let tier = ScanEngine.riskTier(kind: .uvicorn, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testDocker_isHighRisk() {
        let tier = ScanEngine.riskTier(kind: .docker, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testNpmStrongStray_isModerate_notEasy() {
        let tier = ScanEngine.riskTier(kind: .npm, hasTTY: false, isOrphan: true, isOld: true)
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
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60, psOutput: output)

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
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [4000])
        XCTAssertEqual(items.first?.riskTier, .moderate)
        XCTAssertEqual(items.first?.bucket, .needsReview)
    }

    func testPortRegisteredProcess_alreadyModerate_staysNeedsReview() {
        // Has a TTY → moderate already; port match doesn't change outcome.
        let output = "  3000  2999    00:30 ttys002  0.0  4096   python -m pytest tests/unit"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [3000])
        XCTAssertEqual(items.first?.bucket, .needsReview)
    }

    func testNonRegisteredProcess_easyStaysSafe() {
        // Not in registeredPIDs → no demotion.
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         registeredPIDs: [])
        XCTAssertEqual(items.first?.riskTier, .easy)
        XCTAssertEqual(items.first?.bucket, .safe)
    }

    // MARK: - ignoredNames filtering

    func testEnumerate_ignoredNames_match_filtersProcess() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["pytest"])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_ignoredNames_noMatch_processKept() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["vitest"])
        XCTAssertEqual(items.count, 1)
    }

    func testEnumerate_ignoredNames_caseInsensitive() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: ["PyTest"])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_ignoredNames_empty_noFiltering() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         ignoredNames: [])
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - dismissedPIDs filtering

    func testEnumerate_dismissedPIDs_match_filtersProcess() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         dismissedPIDs: [4000])
        XCTAssertEqual(items.count, 0)
    }

    func testEnumerate_dismissedPIDs_noMatch_processKept() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
                                         psOutput: output,
                                         dismissedPIDs: [9999])
        XCTAssertEqual(items.count, 1)
    }

    func testEnumerate_dismissedPIDs_empty_noFiltering() {
        let output = "  4000     1 01:46:38 ??   0.0  4096   python -m pytest tests/slow"
        let items = ScanEngine.enumerate(elapsedThreshold: 30 * 60,
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
}
