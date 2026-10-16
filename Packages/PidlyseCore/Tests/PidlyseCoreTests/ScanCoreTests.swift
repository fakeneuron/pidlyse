import XCTest
@testable import PidlyseCore

final class ScanCoreTests: XCTestCase {

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

    func testDetectKind_chromeUnderIsolatedPlaywrightProfile_isChromeHelper() {
        // `--isolated` playwright-mcp uses browserType.launch(), whose temp
        // user-data-dir is playwright_chromiumdev_profile- (no ms-playwright-mcp).
        let chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome " +
                     "--user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-XXXX " +
                     "--no-startup-window"
        XCTAssertEqual(ScanCore.detectKind(chrome), .chromeHelper)
        let helper = "Google Chrome Helper (GPU) --type=gpu-process " +
                     "--user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-XXXX"
        XCTAssertEqual(ScanCore.detectKind(helper), .chromeHelper)
        let bundled = "/Users/me/Library/Caches/ms-playwright/chromium-1187/chrome-mac/" +
                      "Chromium.app/Contents/MacOS/Chromium " +
                      "--user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-AbC123"
        XCTAssertEqual(ScanCore.detectKind(bundled), .chromeHelper)
    }

    func testDetectKind_normalChrome_isExcluded() {
        let args = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/Users/me/Default"
        XCTAssertNil(ScanCore.detectKind(args))
    }

    func testDetectKind_unrelated_isNil() {
        XCTAssertNil(ScanCore.detectKind("/usr/sbin/cfprefsd agent"))
    }

    func testDetectKind_shellSnapshotWrapper_isNotNpm() {
        // PID-072: Claude Code's sourced shell snapshot inlines prior commands.
        // `npm` inside that text must not classify the wrapper as `.npm`.
        let wrapper = "/bin/zsh -c source /Users/me/.claude/shell-snapshots/" +
            "snapshot-zsh-1.sh && setopt NO_EXTENDED_GLOB && eval 'npm run dev'"
        XCTAssertNil(ScanCore.detectKind(wrapper))
        let bash = "/bin/bash -lc source /tmp/shell-snapshots/snapshot.sh && node server.js"
        XCTAssertNil(ScanCore.detectKind(bash))
        // A real npm (or node) invocation is unchanged, even if its args mention
        // the snapshot directory without being a shell -c wrapper.
        XCTAssertEqual(ScanCore.detectKind("npm run dev"), .npm)
        XCTAssertEqual(ScanCore.detectKind("/usr/local/bin/npm run dev"), .npm)
        XCTAssertEqual(ScanCore.detectKind("npm run dev -- shell-snapshots"), .npm)
        // `/bin/shell-snapshots` contains the characters `/bin/sh`; a real npm
        // argv that mentions that directory and a `-c` flag stays `.npm`.
        XCTAssertEqual(
            ScanCore.detectKind("/usr/local/bin/npm run dev /tmp/bin/shell-snapshots -c build"),
            .npm)
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

    // MARK: - detectKind: expanded kinds (PID-54.2)

    func testDetectKind_nextjs() {
        XCTAssertEqual(ScanCore.detectKind("node /proj/node_modules/.bin/next dev"), .nextjs)
        XCTAssertEqual(ScanCore.detectKind("next dev --port 3000"), .nextjs)
        // The renamed worker process ("next-server (v14.2.3)") is caught too.
        XCTAssertEqual(ScanCore.detectKind("next-server (v14.2.3)"), .nextjs)
        // "next" as a substring of a directory name must not match `.nextjs`
        // (token boundary) — this is a plain node process, so it falls through
        // to the generic `.node` fallback.
        XCTAssertEqual(ScanCore.detectKind("node /app/nextcloud/server.js"), .node)
    }

    func testDetectKind_astro() {
        XCTAssertEqual(ScanCore.detectKind("node /proj/node_modules/.bin/astro dev"), .astro)
        XCTAssertEqual(ScanCore.detectKind("astro dev --host"), .astro)
    }

    func testDetectKind_cargo() {
        XCTAssertEqual(ScanCore.detectKind("cargo run --release"), .cargo)
        XCTAssertEqual(ScanCore.detectKind("/Users/u/.cargo/bin/cargo watch -x run"), .cargo)
    }

    func testDetectKind_goRun_commandFormOnly() {
        XCTAssertEqual(ScanCore.detectKind("go run main.go"), .goRun)
        XCTAssertEqual(ScanCore.detectKind("/usr/local/bin/go run ./cmd/server"), .goRun)
        // Bare `go` / other verbs are intentionally out of scope (too short to
        // token-match; the durable server is a temp binary, not `go`).
        XCTAssertNil(ScanCore.detectKind("go build ./..."))
        XCTAssertNil(ScanCore.detectKind("/usr/local/bin/mongod --config x"))
        XCTAssertNil(ScanCore.detectKind("django-admin runserver"))
    }

    func testDetectKind_llmServer() {
        XCTAssertEqual(ScanCore.detectKind("ollama serve"), .llmServer)
        XCTAssertEqual(ScanCore.detectKind("/usr/local/bin/ollama runner --model llama3"), .llmServer)
        XCTAssertEqual(ScanCore.detectKind("/opt/llama.cpp/llama-server -m model.gguf"), .llmServer)
        XCTAssertEqual(ScanCore.detectKind("/opt/llama.cpp/llama-cli -p hi"), .llmServer)
    }

    func testDetectKind_electron_devScopedOnly() {
        // Project-local electron dev run matches.
        XCTAssertEqual(ScanCore.detectKind("/proj/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron ."), .electron)
        XCTAssertEqual(ScanCore.detectKind("node /proj/node_modules/.bin/electron ."), .electron)
        // Installed Electron apps must NOT surface — no false positives.
        XCTAssertNil(ScanCore.detectKind("/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)"))
        XCTAssertNil(ScanCore.detectKind("/Applications/Slack.app/Contents/MacOS/Slack Helper"))
    }

    func testDetectKind_mcpServer_genericButNotPlaywright() {
        XCTAssertEqual(ScanCore.detectKind("node @modelcontextprotocol/server-filesystem /path"), .mcpServer)
        XCTAssertEqual(ScanCore.detectKind("node /proj/node_modules/mcp-server-git/index.js"), .mcpServer)
        // Playwright's MCP keeps its own kind, not the generic one.
        XCTAssertEqual(ScanCore.detectKind("node @playwright/mcp@latest"), .playwrightMCP)
    }

    // MARK: - hasDevModeFlag (PID-55.3)

    func testHasDevModeFlag_matchesExplicitFlags() {
        XCTAssertTrue(ScanCore.hasDevModeFlag("node node_modules/.bin/vite --watch"))
        XCTAssertTrue(ScanCore.hasDevModeFlag("vite --dev"))
        XCTAssertTrue(ScanCore.hasDevModeFlag("webpack serve --hot"))
        XCTAssertTrue(ScanCore.hasDevModeFlag("uvicorn backend.main:app --reload"))
        // Flag as the trailing token (hasSuffix branch) and case-insensitive.
        XCTAssertTrue(ScanCore.hasDevModeFlag("jest --coverage --WATCH"))
    }

    func testHasDevModeFlag_matchesNodeEnvDevelopment() {
        XCTAssertTrue(ScanCore.hasDevModeFlag("NODE_ENV=development node server.js"))
        XCTAssertTrue(ScanCore.hasDevModeFlag("env NODE_ENV development node server.js"))
        // A production env assignment is not a dev-mode marker.
        XCTAssertFalse(ScanCore.hasDevModeFlag("NODE_ENV=production node server.js"))
    }

    func testHasDevModeFlag_rejectsWordBoundaryFalsePositives() {
        // Token-boundary discipline: `--dev` must not match `--devtools`, and
        // `--no-watch` (watch disabled) must not match `--watch`.
        XCTAssertFalse(ScanCore.hasDevModeFlag("electron . --devtools"))
        XCTAssertFalse(ScanCore.hasDevModeFlag("vite --no-watch"))
        // A bare `dev` / `watch` subcommand is intentionally not a match.
        XCTAssertFalse(ScanCore.hasDevModeFlag("next dev"))
        XCTAssertFalse(ScanCore.hasDevModeFlag("npm run watch"))
        XCTAssertFalse(ScanCore.hasDevModeFlag("node server.js"))
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

    // MARK: - riskTier: expanded kinds (PID-54.2)

    func testLLMServer_isHighRisk() {
        // Local model server is real infra — high regardless of stray signals.
        let tier = ScanCore.riskTier(kind: .llmServer, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .high)
    }

    func testNextjsStrongStray_isModerate_notEasy() {
        // Dev server (vite-tier): strongStray → moderate, never easy.
        let tier = ScanCore.riskTier(kind: .nextjs, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .moderate)
    }

    func testElectronNotStrongStray_isHigh() {
        let tier = ScanCore.riskTier(kind: .electron, hasTTY: true, isOrphan: false, isOld: false)
        XCTAssertEqual(tier, .high)
    }

    func testMcpServerStrongStray_isEasy() {
        // Tooling-tier (like playwright-mcp): an orphaned, old, TTY-less MCP
        // server is a classic stray → easy.
        let tier = ScanCore.riskTier(kind: .mcpServer, hasTTY: false, isOrphan: true, isOld: true)
        XCTAssertEqual(tier, .easy)
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
          569     1 12-08:33:38 ??   0.0  4096   /usr/local/bin/docker compose up
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

    func testDetectKind_dockerDesktopHelpers_areNotCandidates() {
        // Docker Desktop's own processes leave the scan (PID-086.2) — the live scan
        // that filed the epic listed nine of them, wherever the bundle is installed.
        for helper in [
            "/Applications/Docker.app/Contents/MacOS/com.docker.backend services",
            "/Applications/Docker.app/Contents/MacOS/com.docker.virtualization --kernel /x",
            "/Applications/Docker.app/Contents/MacOS/Docker Desktop.app/Contents/MacOS/Docker Desktop",
            "/Users/me/Applications/Docker.app/Contents/MacOS/com.docker.build",
            "/Library/PrivilegedHelperTools/com.docker.vmnetd",
        ] {
            XCTAssertNil(ScanCore.detectKind(helper), helper)
        }
        // The CLI is still Docker.
        XCTAssertEqual(ScanCore.detectKind("/usr/local/bin/docker compose up"), .docker)
        XCTAssertEqual(ScanCore.detectKind("docker run --rm -it alpine"), .docker)
        XCTAssertEqual(ScanCore.detectKind(
            "/Applications/Docker.app/Contents/Resources/bin/docker compose up"), .docker,
                       "CLI tools Docker Desktop ships under Resources/ are not its helpers")
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

    // MARK: - applyScopedIgnores (cwd-scoped ignore post-filter, PID-54.4)

    private func scopeItem(pid: Int32, command: String) -> ProcessItem {
        ProcessItem(pid: pid, ppid: 1, command: command, elapsed: 0,
                    tty: "??", kind: .node, riskTier: .high, cpuPercent: 0, rssKB: 0)
    }

    func testApplyScopedIgnores_hidesMatchUnderPrefix() {
        let items = [scopeItem(pid: 10, command: "node /app/server.js")]
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "bidviz", fullPath: "~/code/bidviz")]
        let rules = [IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz")]
        XCTAssertEqual(ScanCore.applyScopedIgnores(items, cwds: cwds, rules: rules).count, 0)
    }

    func testApplyScopedIgnores_keepsMatchOutsidePrefix() {
        let items = [scopeItem(pid: 10, command: "node /app/server.js")]
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "marscharts", fullPath: "~/code/marscharts")]
        let rules = [IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz")]
        XCTAssertEqual(ScanCore.applyScopedIgnores(items, cwds: cwds, rules: rules).count, 1)
    }

    func testApplyScopedIgnores_keepsWhenCwdUnresolved() {
        let items = [scopeItem(pid: 10, command: "node /app/server.js")]
        let rules = [IgnoreRule(substring: "node", pathPrefix: "~/code/bidviz")]
        XCTAssertEqual(ScanCore.applyScopedIgnores(items, cwds: [:], rules: rules).count, 1)
    }

    func testApplyScopedIgnores_globalRulesIgnoredHere() {
        // A global rule (no prefix) is handled inside enumerate, not by this post-filter.
        let items = [scopeItem(pid: 10, command: "node /app/server.js")]
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "bidviz", fullPath: "~/code/bidviz")]
        let rules = [IgnoreRule(substring: "node", pathPrefix: nil)]
        XCTAssertEqual(ScanCore.applyScopedIgnores(items, cwds: cwds, rules: rules).count, 1)
    }

    func testApplyScopedIgnores_substringMustAlsoMatch() {
        // cwd under prefix but the command lacks the substring → kept.
        let items = [scopeItem(pid: 10, command: "node /app/server.js")]
        let cwds: [Int32: ProcessCwd] = [10: ProcessCwd(label: "bidviz", fullPath: "~/code/bidviz")]
        let rules = [IgnoreRule(substring: "vite", pathPrefix: "~/code/bidviz")]
        XCTAssertEqual(ScanCore.applyScopedIgnores(items, cwds: cwds, rules: rules).count, 1)
    }
}
