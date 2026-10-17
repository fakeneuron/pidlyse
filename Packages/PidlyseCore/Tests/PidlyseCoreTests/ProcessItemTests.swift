import XCTest
@testable import PidlyseCore

final class ProcessItemTests: XCTestCase {

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

    // MARK: - displayName (PID-086.3)

    private func name(_ command: String, kind: ProcessKind = .node, customLabel: String? = nil) -> String {
        ProcessItem(pid: 1, ppid: 1, command: command, elapsed: 0, tty: "??", kind: kind,
                    riskTier: .high, cpuPercent: 0, rssKB: 0, customLabel: customLabel).displayName
    }

    func testDisplayName_friendlyDevServers() {
        XCTAssertEqual(name("node /Users/me/Code/app/frontend/node_modules/.bin/vite"), "Vite dev server")
        XCTAssertEqual(name("node /x/node_modules/.bin/vite --port 5173 --host"), "Vite dev server")
        XCTAssertEqual(name("node /x/node_modules/.bin/next dev -p 3002"), "Next.js dev server")
        XCTAssertEqual(name("node /x/node_modules/.bin/next dev --turbopack -H 127.0.0.1 -p 3003"),
                       "Next.js dev server")
        XCTAssertEqual(name("next-server (v15.5.18)"), "Next.js server")
        XCTAssertEqual(name("node /x/node_modules/.bin/astro dev"), "Astro dev server")
    }

    func testDisplayName_nonDevSubcommandStaysLiteral() {
        XCTAssertEqual(name("node /x/node_modules/.bin/vite build"), "vite build")
        XCTAssertEqual(name("node /x/node_modules/.bin/next start"), "next start")
    }

    func testDisplayName_spacedPath_usesArgvWhenKnown() {
        // `ps` joins argv unquoted, so the path splits at the space; argv keeps it whole.
        let path = "/Users/me/My Project/frontend/node_modules/.bin/vite"
        let spaced = ProcessItem(pid: 1, ppid: 1, command: "node \(path) --port 5173", elapsed: 0,
                                 tty: "??", kind: .vite, riskTier: .high, cpuPercent: 0, rssKB: 0,
                                 argv: ["node", path, "--port", "5173"])
        XCTAssertEqual(spaced.displayName, "Vite dev server")
        let script = ProcessItem(pid: 1, ppid: 1, command: "node /My Apps/api/import-scraper.js", elapsed: 0,
                                 tty: "??", kind: .node, riskTier: .high, cpuPercent: 0, rssKB: 0,
                                 argv: ["node", "/My Apps/api/import-scraper.js"])
        XCTAssertEqual(script.displayName, "import-scraper.js")
    }

    func testDisplayName_spacedPath_survivesLauncherRecursion() {
        let argv = ["uv", "run", "python", "/My Apps/api/worker.py"]
        let item = ProcessItem(pid: 1, ppid: 1, command: argv.joined(separator: " "), elapsed: 0,
                               tty: "??", kind: .node, riskTier: .high, cpuPercent: 0, rssKB: 0,
                               argv: argv)
        XCTAssertEqual(item.displayName, "worker.py")
    }

    func testDisplayName_spacedPath_withoutArgv_fallsBackToPSString() {
        // No argv (foreign-owned, or it disagreed with `ps`): the unquoted string splits
        // at the space — the misnaming argv exists to avoid, kept as the graceful fallback.
        XCTAssertEqual(name("node /My Apps/api/import-scraper.js"), "My")
    }

    func testDisplayName_binPlusSubcommand() {
        XCTAssertEqual(name("node /x/worker/node_modules/.bin/wrangler dev"), "wrangler dev")
        XCTAssertEqual(name("cargo run --release"), "cargo run")
        XCTAssertEqual(name("go run main.go"), "go run")
        XCTAssertEqual(name("ollama serve"), "ollama serve")
        XCTAssertEqual(name("node_modules/.bin/vitest run"), "vitest run")
    }

    func testDisplayName_packageScriptNamesItsPackage() {
        XCTAssertEqual(name("/opt/homebrew/Cellar/node/26.7.0/bin/node --no-warnings "
                            + "/x/worker/node_modules/wrangler/wrangler-dist/cli.js dev"), "wrangler dev")
        XCTAssertEqual(name("node /x/node_modules/@scope/tool/dist/index.js"), "@scope/tool")
    }

    func testDisplayName_scriptBasename() {
        XCTAssertEqual(name("node --env-file=.env import-scraper.js"), "import-scraper.js")
        XCTAssertEqual(name("node -r dotenv/config scripts/seed.mjs"), "seed.mjs")
        XCTAssertEqual(name("NODE_ENV=development node server.js"), "server.js")
        XCTAssertEqual(name("/Users/me/bin/sync.js --once"), "sync.js")
        XCTAssertEqual(name("python3 manage.py runserver"), "manage.py runserver")
    }

    func testDisplayName_packageRunners() {
        XCTAssertEqual(name("npm run dev", kind: .npm), "npm run dev")
        XCTAssertEqual(name("bun run dev", kind: .bun), "bun run dev")
        XCTAssertEqual(name("npm exec @playwright/mcp@0.0.79 --headless --isolated --output-dir /tmp/x",
                            kind: .playwrightMCP), "@playwright/mcp")
        XCTAssertEqual(name("npx cowsay@1 hi", kind: .npm), "cowsay")
        XCTAssertEqual(name("node /Users/me/.npm/_npx/5169/node_modules/.bin/playwright-mcp --headless",
                            kind: .playwrightMCP), "playwright-mcp")
    }

    func testDisplayName_pythonModuleAndVenvBins() {
        XCTAssertEqual(name("python -m pytest tests/", kind: .pytest), "pytest")
        XCTAssertEqual(name("/x/.venv/bin/python3 /x/.venv/bin/uvicorn main:app --reload", kind: .uvicorn),
                       "uvicorn")
        XCTAssertEqual(name("uvicorn backend.main:app --port 8005", kind: .uvicorn), "uvicorn")
    }

    func testDisplayName_shellWrapperNamesWhatItRuns() {
        XCTAssertEqual(name("sh -cu cd worker && npm run dev", kind: .npm), "npm run dev")
        XCTAssertEqual(name("/bin/zsh -c pnpm install; vite", kind: .vite), "Vite dev server")
    }

    func testDisplayName_flagValuesAreNotSubcommands() {
        XCTAssertEqual(name("npm --prefix frontend run dev", kind: .npm), "npm run dev")
        XCTAssertEqual(name("npm --silent run dev", kind: .npm), "npm run dev")
        XCTAssertEqual(name("node /x/node_modules/.bin/vite --mode staging"), "Vite dev server")
        XCTAssertEqual(name("python3 -W ignore server.py"), "server.py")
    }

    func testDisplayName_wrappersAndEnvAreSkipped() {
        XCTAssertEqual(name("PATH=/opt/bin:/usr/bin node server.js"), "server.js")
        XCTAssertEqual(name("/usr/bin/env node app.js"), "app.js")
        XCTAssertEqual(name("env -i FOO=1 vite", kind: .vite), "Vite dev server")
        XCTAssertEqual(name("sh -c cd worker && exec npm run dev", kind: .npm), "npm run dev")
        XCTAssertEqual(name("-zsh -c vite", kind: .vite), "Vite dev server")
    }

    func testDisplayName_frameworkPythonAndUvRunners() {
        XCTAssertEqual(name("/opt/homebrew/Python.framework/Versions/3.12/Resources/Python.app/Contents/MacOS/Python "
                            + "-m uvicorn app:main", kind: .uvicorn), "uvicorn")
        XCTAssertEqual(name("uv run python worker.py"), "worker.py")
        XCTAssertEqual(name("uvx ruff@0.6 server"), "ruff")
    }

    func testDisplayName_scopedPackageDirectory() {
        XCTAssertEqual(name("node /x/node_modules/@modelcontextprotocol/server-filesystem /tmp", kind: .mcpServer),
                       "@modelcontextprotocol/server-filesystem")
    }

    func testDisplayName_customLabelWins() {
        XCTAssertEqual(name("node worker.js", kind: .custom, customLabel: "Queue worker"), "Queue worker")
    }

    func testDisplayName_chromeHelperUsesKindLabel() {
        XCTAssertEqual(name("/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Helper "
                            + "--user-data-dir=/x/ms-playwright-mcp", kind: .chromeHelper),
                       "Chrome (playwright-mcp)")
    }

    func testDisplayName_bareInterpreterAndEmpty() {
        XCTAssertEqual(name("node"), "node")
        XCTAssertEqual(name("   ", kind: .node), "Node")
    }
}
