import XCTest
@testable import PidlyseCore

/// Tests for the tree collapse (PID-039 → generalized by PID-62.4): every scanned
/// process whose direct parent is also scanned folds into its topmost scanned
/// ancestor's row — root *identity* (pid → kill target), representative
/// (first non-launcher) *label*, most cautious tier, summed resources.
final class ScanCoreTreeCollapseTests: XCTestCase {

    private func item(pid: Int32, ppid: Int32, command: String, kind: ProcessKind,
                      riskTier: RiskTier = .moderate, cpu: Double = 0, rss: Int = 0,
                      startTime: ProcStartTime? = nil, uid: uid_t? = nil) -> ProcessItem {
        ProcessItem(pid: pid, ppid: ppid, command: command, elapsed: 0, tty: "ttys000",
                    kind: kind, riskTier: riskTier, cpuPercent: cpu, rssKB: rss,
                    startTime: startTime, uid: uid)
    }

    func testCollapse_npmExecPlaywright_mergesKeepingWrapperIdentity() {
        // Both wrapper and child classify as .playwrightMCP (the in-group double).
        let token = ProcStartTime(sec: 11, usec: 22)
        let wrapper = item(pid: 105, ppid: 99945, command: "npm exec @playwright/mcp@latest --headless",
                           kind: .playwrightMCP, cpu: 0.2, rss: 336, startTime: token)
        let child = item(pid: 160, ppid: 105, command: "node /Users/x/.npm/_npx/abc/.bin/playwright-mcp --headless",
                         kind: .playwrightMCP, cpu: 1.0, rss: 80)
        let result = ScanCore.collapseTrees([wrapper, child])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 105)              // identity/kill target = wrapper root
        XCTAssertEqual(result.first?.startTime, token)      // PID-reuse guard validates the root
        XCTAssertEqual(result.first?.kind, .playwrightMCP)
        XCTAssertEqual(result.first?.command, child.command) // label/displayPath = child
        XCTAssertEqual(result.first?.rssKB, 416)            // summed
        XCTAssertEqual(result.first?.cpuPercent ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(result.first?.members.map { $0.pid }, [160])
    }

    func testCollapse_npmRunDevVite_mergesToSingleViteRow() {
        let wrapper = item(pid: 200, ppid: 1, command: "npm run dev", kind: .npm, rss: 2704)
        let child = item(pid: 300, ppid: 200,
                         command: "node /Users/x/code/bananapeel/frontend/node_modules/.bin/vite",
                         kind: .vite, rss: 12432)
        let result = ScanCore.collapseTrees([wrapper, child])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 200)
        XCTAssertEqual(result.first?.kind, .vite)
        XCTAssertEqual(result.first?.rssKB, 2704 + 12432)
    }

    func testCollapse_loneProcess_unchanged() {
        // Orphaned `npm run dev` whose server died — nothing to fold into.
        let wrapper = item(pid: 200, ppid: 1, command: "npm run dev", kind: .npm)
        let result = ScanCore.collapseTrees([wrapper])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 200)
        XCTAssertEqual(result.first?.kind, .npm)
        XCTAssertTrue(result.first?.members.isEmpty ?? false)
    }

    func testCollapse_shellUvChain_foldsThreeDeepAndLabelsPastLaunchers() {
        // `sh -cu` → `uv run` → python uvicorn (live bidviz shape): both launchers are
        // skipped, so the row labels as the python server but kills from the shell root.
        let sh = item(pid: 99065, ppid: 99054,
                      command: "sh -cu cd backend && uv run uvicorn app:app --port 8005 --reload",
                      kind: .uvicorn, riskTier: .high)
        let uv = item(pid: 99066, ppid: 99065, command: "uv run uvicorn app:app --port 8005 --reload",
                      kind: .uvicorn, riskTier: .high)
        let py = item(pid: 99067, ppid: 99066,
                      command: "/x/backend/.venv/bin/python /x/backend/.venv/bin/uvicorn app:app",
                      kind: .uvicorn, riskTier: .high)
        let result = ScanCore.collapseTrees([sh, uv, py])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 99065)
        XCTAssertEqual(result.first?.command, py.command)
        XCTAssertEqual(result.first?.members.map { $0.pid }, [99066, 99067])
    }

    func testCollapse_fanOut_foldsEveryChildBreadthFirst() {
        // playwright-mcp → Chrome main → helpers: fan-out at the second level.
        let mcp = item(pid: 10, ppid: 5, command: "node /x/.bin/playwright-mcp", kind: .playwrightMCP)
        let chrome = item(pid: 20, ppid: 10, command: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/x/ms-playwright-mcp",
                          kind: .chromeHelper)
        let gpu = item(pid: 30, ppid: 20, command: "Google Chrome Helper (GPU) ms-playwright-mcp", kind: .chromeHelper)
        let renderer = item(pid: 31, ppid: 20, command: "Google Chrome Helper (Renderer) ms-playwright-mcp", kind: .chromeHelper)
        let result = ScanCore.collapseTrees([gpu, mcp, renderer, chrome])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.pid, 10)
        XCTAssertEqual(result.first?.kind, .playwrightMCP)
        XCTAssertEqual(result.first?.members.map { $0.pid }, [20, 30, 31])
    }

    func testCollapse_tierIsMostCautiousMember() {
        // An easy (orphaned) root whose child is only moderate (children are never
        // orphans, or it listens on a registered port) must not stay easy.
        let root = item(pid: 1000, ppid: 1, command: "python -m pytest tests/", kind: .pytest, riskTier: .easy)
        let child = item(pid: 1001, ppid: 1000, command: "python -m pytest --worker 1", kind: .pytest,
                         riskTier: .moderate)
        let result = ScanCore.collapseTrees([root, child])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.riskTier, .moderate)
        XCTAssertEqual(result.first?.bucket, .needsReview)
    }

    func testCollapse_nonLauncherRoot_keepsRootLabel() {
        // `next dev` → `next-server`: the root already does real work, so it labels the row.
        let next = item(pid: 32155, ppid: 32139, command: "node /x/node_modules/.bin/next dev -p 3002", kind: .nextjs)
        let server = item(pid: 32156, ppid: 32155, command: "next-server (v15.5.18)", kind: .nextjs)
        let result = ScanCore.collapseTrees([next, server])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.command, next.command)
    }

    func testCollapse_agentNodeParent_doesNotSwallowMCPChildren() {
        // A node-run agent CLI (.node) starting `npm exec @playwright/mcp`: the MCP
        // server must stay its own killable row, never folded behind the live agent.
        let agent = item(pid: 500, ppid: 400, command: "node /opt/homebrew/bin/codex", kind: .node, riskTier: .high)
        let mcp = item(pid: 600, ppid: 500, command: "npm exec @playwright/mcp@latest --headless",
                       kind: .playwrightMCP, riskTier: .easy)
        let mcpNode = item(pid: 700, ppid: 600, command: "node /x/.bin/playwright-mcp --headless",
                           kind: .playwrightMCP, riskTier: .easy)
        let fs = item(pid: 800, ppid: 500, command: "node /opt/homebrew/bin/mcp-server-filesystem /x",
                      kind: .mcpServer, riskTier: .easy)
        let result = ScanCore.collapseTrees([agent, mcp, mcpNode, fs])
        XCTAssertEqual(result.map { $0.pid }, [500, 600, 800])
        XCTAssertTrue(result[0].members.isEmpty)
        XCTAssertEqual(result[1].members.map { $0.pid }, [700])
        XCTAssertEqual(result[1].riskTier, .easy)
    }

    func testCollapse_nodeWorkerUnderFrameworkServer_folds() {
        let server = item(pid: 36385, ppid: 36363, command: "next-server (v16.3.4)", kind: .nextjs)
        let worker = item(pid: 36388, ppid: 36385, command: "node /x/.next/dev/build/chunks/pool_entry.js", kind: .node)
        XCTAssertEqual(ScanCore.collapseTrees([server, worker]).map { $0.pid }, [36385])
    }

    func testCollapse_dockerNeverGroups() {
        let backend = item(pid: 70626, ppid: 1, command: "/Applications/Docker.app/Contents/MacOS/com.docker.backend",
                           kind: .docker)
        let services = item(pid: 70724, ppid: 70626,
                            command: "/Applications/Docker.app/Contents/MacOS/com.docker.backend services", kind: .docker)
        XCTAssertEqual(ScanCore.collapseTrees([backend, services]).count, 2)
    }

    func testCollapse_unrelatedProcesses_unchanged() {
        let a = item(pid: 3000, ppid: 2999, command: "python -m pytest tests/", kind: .pytest)
        let b = item(pid: 4000, ppid: 3999, command: "node .bin/vite", kind: .vite)
        let result = ScanCore.collapseTrees([a, b])
        XCTAssertEqual(result.map { $0.pid }, [3000, 4000])
    }

    func testCollapse_endToEndThroughEnumerate() {
        // The collapse runs inside enumerate on real `ps`-shaped output.
        let output = """
          105 99945 14:55:40 ttys000 0.0 336 npm exec @playwright/mcp@latest --headless --output-dir /tmp/playwright-mcp
          160   105 14:55:40 ttys000 0.0 80 node /Users/x/.npm/_npx/abc/node_modules/.bin/playwright-mcp --headless
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.pid, 105)
        XCTAssertEqual(items.first?.kind, .playwrightMCP)
    }

    func testEnumerate_isolatedChromeBrood_collapsesUnderPlaywrightMCP() {
        // Isolated-mode Chrome helpers have no ms-playwright-mcp token; they must
        // still classify as .chromeHelper and fold under the mcp row. (PID-071)
        let output = """
          10     5 14:55:40 ?? 0.0 336 node /x/.bin/playwright-mcp --isolated
          20    10 14:55:40 ?? 0.0 80 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-XXXX --no-startup-window
          30    20 14:55:40 ?? 0.0 40 Google Chrome Helper (GPU) --type=gpu-process --user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-XXXX
          31    20 14:55:40 ?? 0.0 40 Google Chrome Helper (Renderer) --type=renderer --user-data-dir=/var/folders/xx/T/playwright_chromiumdev_profile-XXXX
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.pid, 10)
        XCTAssertEqual(items.first?.kind, .playwrightMCP)
        XCTAssertEqual(items.first?.members.map { $0.pid }, [20, 30, 31])
        XCTAssertTrue(items.first?.members.allSatisfy { $0.kind == .chromeHelper } ?? false)
    }

    func testEnumerate_disabledKind_filtersPerProcessBeforeCollapse() {
        // Disabling .npm drops only the wrapper; its vite child survives as its own row.
        let output = """
          200     1 14:55:40 ttys000 0.0 336 npm run dev
          300   200 14:55:40 ttys000 0.0 80 node /x/frontend/node_modules/.bin/vite
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output, disabledKinds: [.npm])
        XCTAssertEqual(items.map { $0.pid }, [300])
        XCTAssertEqual(items.first?.kind, .vite)
    }

    func testEnumerate_dismissedRoot_dropsWholeGroup() {
        // Dismissal filters after the collapse, so the child doesn't resurface alone.
        let output = """
          105 99945 14:55:40 ttys000 0.0 336 npm exec @playwright/mcp@latest --headless
          160   105 14:55:40 ttys000 0.0 80 node /Users/x/.npm/_npx/abc/node_modules/.bin/playwright-mcp --headless
        """
        let items = ScanCore.enumerate(elapsedThreshold: 30 * 60, psOutput: output, dismissedPIDs: [105])
        XCTAssertTrue(items.isEmpty)
    }
}
