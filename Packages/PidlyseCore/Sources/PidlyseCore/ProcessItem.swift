import Foundation

/// Descriptive classification of a matched process. Drives the human-readable
/// label and feeds the risk tier. A process that matches no `ProcessKind` is
/// not a stray candidate and is excluded from scan results.
public enum ProcessKind: String, CaseIterable {
    case docker
    case uvicorn
    case npm
    case pytest
    case vitest
    case vite
    case jest
    case playwrightTest
    case playwrightMCP
    case chromeHelper
    case bun
    case node
    // Expanded built-in kinds (PID-54.2). Dev servers / build tools / local
    // infra, each slotted before the generic node/npm fallbacks in `detectKind`.
    case nextjs
    case astro
    case cargo
    case goRun
    case electron
    case llmServer
    case mcpServer
    // User-defined custom-rule match (PID-54.3). Sentinel kind — the friendly
    // per-rule label rides on `ProcessItem.customLabel`, not on this enum. Always
    // classified needsReview; excluded from the Settings "Scanned kinds" toggles.
    case custom

    /// Short, user-facing label shown in the popover row.
    public var label: String {
        switch self {
        case .docker:         return "Docker"
        case .uvicorn:        return "uvicorn"
        case .npm:            return "npm"
        case .pytest:         return "pytest"
        case .vitest:         return "vitest"
        case .vite:           return "Vite"
        case .jest:           return "Jest"
        case .playwrightTest: return "Playwright test"
        case .playwrightMCP:  return "playwright-mcp"
        case .chromeHelper:   return "Chrome (playwright-mcp)"
        case .bun:            return "Bun"
        case .node:           return "Node"
        case .nextjs:         return "Next.js"
        case .astro:          return "Astro"
        case .cargo:          return "cargo"
        case .goRun:          return "go run"
        case .electron:       return "Electron (dev)"
        case .llmServer:      return "LLM server"
        case .mcpServer:      return "MCP server"
        case .custom:         return "Custom rules"
        }
    }
}

/// How risky it is to kill a process. The display gradient (PID-003 may render
/// all three); the kill-action `Bucket` is derived from it.
public enum RiskTier: Comparable {
    case easy       // obvious stray — orphaned, old, no terminal
    case moderate   // probably stray, but verify
    case high       // real dev infra (docker / uvicorn) or actively managed
}

/// The two kill-action buckets — the only classification the kill flow acts on.
/// Per AGENTS.md: never auto-kill; `safe` items still require an explicit click.
public enum Bucket {
    case safe
    case needsReview
}

/// A process's start time, used as an identity token to detect PID reuse: if the
/// original process exits and the kernel recycles its PID for an unrelated process,
/// the start time differs. Captured at scan time (carried on `ProcessItem`) and
/// re-read at kill time so the kill path can confirm the PID still maps to the
/// *same* process. Lives here in `PidlyseCore` so `ProcessItem` can hold it; the
/// `sysctl` reader that produces it is `KillCore.startTime(of:)` (moved into the
/// core with the kill path, PID-57.2). (PID-18.3, PID-35.3)
public struct ProcStartTime: Equatable, Hashable {
    public let sec: Int
    public let usec: Int

    public init(sec: Int, usec: Int) {
        self.sec = sec
        self.usec = usec
    }
}

/// One process surfaced by the scan engine.
public struct ProcessItem: Identifiable {
    public let pid: Int32
    public let ppid: Int32
    /// Full command line (`ps` args column).
    public let command: String
    /// The process's real argv, one element per argument, when it was read at scan
    /// time and agreed with `command`; `nil` otherwise. `command` is `ps`'s
    /// space-joined, unquoted string, so only this keeps a path containing a space
    /// whole — `displayName` tokenises from it when present. (PID-087)
    public let argv: [String]?
    /// Elapsed run time.
    public let elapsed: TimeInterval
    /// Controlling terminal as reported by `ps` (`??` = none).
    public let tty: String
    public let kind: ProcessKind
    /// The friendly label from the matched user rule when `kind == .custom`;
    /// `nil` for built-in kinds. Feeds `displayLabel`. (PID-54.3)
    public let customLabel: String?
    public let riskTier: RiskTier
    /// CPU usage percentage from `ps pcpu` column.
    public let cpuPercent: Double
    /// Resident set size in KB from `ps rss` column.
    public let rssKB: Int
    /// Process start-time identity token captured at scan, or `nil` when not
    /// captured (tests, or a sysctl miss). The kill path re-verifies it before the
    /// initial SIGTERM to refuse killing a PID recycled since the scan. (PID-35.3)
    public let startTime: ProcStartTime?
    /// The user id that owns the process, captured at scan time, or `nil` when it
    /// wasn't resolved (no provider injected — e.g. unit tests). Pidlyse runs
    /// unprivileged, so a uid other than the current user's means every signal we
    /// could send hits EPERM: the row is unkillable and says so instead of offering
    /// a dead-end button. `nil` means "unknown", which never removes an
    /// affordance. (PID-62.3)
    public let uid: uid_t?
    /// The other scanned processes folded into this row by `ScanCore.collapseTrees`
    /// (PID-62.4) — descendants of this row's root that live and die with it, in
    /// breadth-first order. Empty for a standalone process. Each keeps its own
    /// pid/startTime/uid so the group kill can signal and verify every member.
    public let members: [ProcessItem]

    public init(pid: Int32, ppid: Int32, command: String, elapsed: TimeInterval,
                tty: String, kind: ProcessKind, riskTier: RiskTier,
                cpuPercent: Double, rssKB: Int, startTime: ProcStartTime? = nil,
                customLabel: String? = nil, uid: uid_t? = nil, members: [ProcessItem] = [],
                argv: [String]? = nil) {
        self.pid = pid
        self.ppid = ppid
        self.command = command
        self.argv = argv
        self.elapsed = elapsed
        self.tty = tty
        self.kind = kind
        self.customLabel = customLabel
        self.riskTier = riskTier
        self.cpuPercent = cpuPercent
        self.rssKB = rssKB
        self.startTime = startTime
        self.uid = uid
        self.members = members
    }

    public var id: Int32 { pid }

    // MARK: - Derived signals (also surfaced by PID-008 "why is this here?")

    /// `safe` only for the easy tier; everything else needs explicit review.
    public var bucket: Bucket { riskTier == .easy ? .safe : .needsReview }

    /// User-facing label: the matched custom rule's friendly label when present,
    /// else the built-in `kind.label`. Display consumers (popover row descriptor,
    /// notifications, clean log) prefer this over `kind.label`. (PID-54.3)
    public var displayLabel: String { customLabel ?? kind.label }

    /// Compact display label shown in the popover row. Absolute-path executables
    /// format as `parentDir/executableName` (e.g. `bin/uvicorn`); bare-word
    /// commands show just the first token (e.g. `npm`).
    public var displayPath: String {
        let firstToken = command.split(separator: " ", maxSplits: 1)
            .first.map(String.init) ?? command
        guard firstToken.hasPrefix("/") else { return firstToken }
        let url = URL(fileURLWithPath: firstToken)
        let execName = url.lastPathComponent
        let parentName = url.deletingLastPathComponent().lastPathComponent
        guard !parentName.isEmpty, parentName != "/" else { return execName }
        return "\(parentName)/\(execName)"
    }

    /// What the process *is*, read from its command — the popover row's lead
    /// (PID-086.3). A custom rule's label wins; otherwise a friendly dev-server
    /// name (`Vite dev server`), the bin plus its subcommand (`wrangler dev`,
    /// `npm run dev`), or a script's basename (`import-scraper.js`). Interpreters,
    /// their flags and leading `VAR=value` env are skipped, a `sh -c` shell names
    /// what it runs, and a script inside `node_modules/<pkg>/` names its package.
    /// A group row's `command` is its representative's (`ScanCore.collapseTrees`),
    /// so a group names itself after the real process.
    public var displayName: String {
        if let customLabel { return customLabel }
        // A Chrome helper's executable path contains spaces, so tokens can't name it.
        if kind == .chromeHelper { return kind.label }
        return Self.name(of: command, argv: argv) ?? kind.label
    }

    private static let interpreters: Set<String> = ["node", "deno", "bun", "ruby", "tsx", "ts-node"]
    private static let scriptExtensions: Set<String> = ["js", "mjs", "cjs", "ts", "mts", "py", "rb"]
    /// Interpreter flags that take their value as the next token.
    private static let valueFlags: Set<String> = ["-r", "--require", "--import", "--loader", "-W", "-X"]
    /// Bins whose dev-server invocation reads better as the framework's name. The
    /// key is `bin` or `bin subcommand`.
    private static let friendlyNames: [String: String] = [
        "vite": "Vite dev server", "vite dev": "Vite dev server", "vite serve": "Vite dev server",
        "next dev": "Next.js dev server", "next-server": "Next.js server",
        "astro dev": "Astro dev server",
    ]

    private static func name(of command: String, argv: [String]? = nil) -> String? {
        var tokens = argv ?? command.split(separator: " ").map(String.init)
        // Skip leading `env` / `exec` wrappers (and their flags) and `VAR=value`
        // assignments.
        var afterWrapper = false
        while let first = tokens.first {
            if ["env", "exec"].contains(leaf(first)) {
                afterWrapper = true
            } else if !(isAssignment(first) || (afterWrapper && first.hasPrefix("-"))) {
                break
            }
            tokens.removeFirst()
        }
        guard !tokens.isEmpty else { return nil }
        let first = tokens.removeFirst()
        var program = scriptExtensions.contains(ext(first)) ? scriptName(first) : leaf(first)

        // `sh -c 'cd x && npm run dev'` names the last command it runs.
        if let flag = tokens.first, ScanCore.isShellDashC(program, flag) {
            let script = tokens.dropFirst().joined(separator: " ")
            let last = script.components(separatedBy: "&&").last?
                .components(separatedBy: ";").last ?? script
            return name(of: last.trimmingCharacters(in: .whitespaces))
        }
        // A login shell reports its argv[0] as `-zsh`.
        if program.hasPrefix("-") { program.removeFirst() }

        // `uv run python worker.py` / `poetry run …` name what they run; `uvx ruff` names the tool.
        if ["uv", "poetry"].contains(program), tokens.first == "run", tokens.count > 1 {
            let inner = Array(tokens.dropFirst())
            return name(of: inner.joined(separator: " "), argv: inner)
        }
        if program == "uvx", let tool = tokens.first(where: { !$0.hasPrefix("-") }) {
            return stripVersion(tool)
        }

        if interpreters.contains(program) || program.lowercased().hasPrefix("python") || program == "py" {
            var rest = tokens[...]
            while let flag = rest.first, flag.hasPrefix("-") {
                rest = rest.dropFirst()
                // `python -m pytest` runs a module: it is the program.
                if flag == "-m", let module = rest.first {
                    return withSubcommand(module, rest.dropFirst())
                }
                if valueFlags.contains(flag) { rest = rest.dropFirst() }
            }
            // `bun run dev` / `deno task dev` are subcommands, not scripts.
            if let script = rest.first, isScript(script) {
                return withSubcommand(scriptName(script), rest.dropFirst())
            }
        }
        return withSubcommand(program, tokens[...])
    }

    private static let packageRunners: Set<String> = ["npm", "pnpm", "yarn", "bun"]

    /// `bin` plus at most one subcommand word, mapped through `friendlyNames`. A
    /// package runner's `run` / `exec` (and `npx`) keep their target (`npm run dev`,
    /// `@playwright/mcp`).
    private static func withSubcommand(_ program: String, _ rest: ArraySlice<String>) -> String {
        // Positional args only. A `--long` flag without `=` usually takes the next
        // token as its value (`npm --prefix frontend run dev`, `vite --mode staging`).
        var args: [String] = []
        var skipValue = false
        for token in rest {
            if token.hasPrefix("-") {
                skipValue = token.hasPrefix("--") && !token.contains("=")
                continue
            }
            if skipValue { skipValue = false; continue }
            args.append(token)
        }
        if program == "npx", let target = args.first { return stripVersion(target) }
        // A runner's `run` / `exec` is found among all non-flag tokens, so a boolean
        // flag before it (`npm --silent run dev`) can't hide it.
        let positional = rest.filter { !$0.hasPrefix("-") }
        if packageRunners.contains(program),
           let i = positional.firstIndex(where: { $0 == "run" || $0 == "exec" }), i + 1 < positional.endIndex {
            let target = positional[i + 1]
            return positional[i] == "exec" ? stripVersion(target) : "\(program) run \(target)"
        }
        guard let sub = args.first, isWord(sub) else { return friendlyNames[program] ?? program }
        let joined = "\(program) \(sub)"
        return friendlyNames[joined] ?? joined
    }

    /// A path token that names a script: it has a path separator or a script extension.
    private static func isScript(_ token: String) -> Bool {
        token.contains("/") || scriptExtensions.contains(ext(token))
    }

    /// A script's name: the package for a file inside `node_modules/<pkg>/` (so
    /// `wrangler/wrangler-dist/cli.js` reads `wrangler`), else the file's basename
    /// (`node_modules/.bin/vite` → `vite`).
    private static func scriptName(_ path: String) -> String {
        if let range = path.range(of: "node_modules/", options: .backwards) {
            let parts = path[range.upperBound...].split(separator: "/").map(String.init)
            if let pkg = parts.first, pkg != ".bin", parts.count > 1 {
                return pkg.hasPrefix("@") ? "\(pkg)/\(parts[1])" : pkg
            }
        }
        return leaf(path)
    }

    private static func leaf(_ token: String) -> String {
        AncestryResolver.compactLabel(token)
    }

    private static func ext(_ token: String) -> String {
        (token as NSString).pathExtension.lowercased()
    }

    /// A leading `NAME=value` environment assignment (`PATH=/x:/y` included).
    private static func isAssignment(_ token: String) -> Bool {
        guard let eq = token.firstIndex(of: "="), eq != token.startIndex else { return false }
        return token[..<eq].allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
    }

    /// A subcommand word: lowercase letters, digits and hyphens, starting with a letter.
    private static func isWord(_ token: String) -> Bool {
        guard let first = token.first, first.isLowercase, first.isLetter else { return false }
        return token.allSatisfy { ($0.isLowercase && $0.isLetter) || $0.isNumber || $0 == "-" }
    }

    /// `@playwright/mcp@0.0.79` → `@playwright/mcp`; `cowsay@1` → `cowsay`.
    private static func stripVersion(_ spec: String) -> String {
        guard let at = spec.lastIndex(of: "@"), at != spec.startIndex else { return spec }
        return String(spec[..<at])
    }

    /// True when a `ps` tty field denotes an attached controlling terminal.
    /// `??`, `?`, `-`, and empty all mean "no terminal". Static so callers
    /// (e.g. `ScanCore.makeItem`) can classify a raw field before a
    /// `ProcessItem` exists — single source of truth for the sentinel set.
    public static func isTTYAttached(_ tty: String) -> Bool {
        let t = tty.trimmingCharacters(in: .whitespaces)
        return !(t.isEmpty || t == "??" || t == "?" || t == "-")
    }

    /// True when the process has no controlling terminal — a stray indicator.
    public var hasTTY: Bool { Self.isTTYAttached(tty) }

    /// On macOS a process whose parent has died is reparented to launchd (pid 1).
    public var isOrphan: Bool { ppid == 1 }
}
