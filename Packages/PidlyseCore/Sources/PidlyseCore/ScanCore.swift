import Foundation

/// Pure scan core: enumerate running processes, match stray candidates, and
/// classify each into a descriptive `kind` + `riskTier` (→ derived
/// `safe`/`needsReview` bucket). Side-effect-light and injectable (all inputs
/// can be supplied for unit testing), so both the Pidlyse app's `ScanEngine`
/// `ObservableObject` and the LaunchAgent helper (PID-EPIC-27) share one
/// classification path. The app-side timer / persistence / notification
/// lifecycle lives in `ScanEngine`, not here.
public enum ScanCore {
    public static let defaultElapsedThreshold: TimeInterval = 30 * 60

    // MARK: - Enumeration

    /// Parse + classify `ps` output into stray candidates. `psOutput`,
    /// `registeredPIDs`, `ignoredNames`, and `dismissedPIDs` are injectable
    /// for unit testing. When `registeredPIDs` is nil the live `lsof` query runs.
    /// Items whose command args contain any `ignoredNames` entry, whose PID is
    /// in `dismissedPIDs`, or whose `kind` is in `disabledKinds`, are dropped.
    public static func enumerate(elapsedThreshold: TimeInterval = defaultElapsedThreshold,
                                 psOutput: String? = nil,
                                 registeredPIDs: Set<Int32>? = nil,
                                 ignoredNames: [String] = [],
                                 dismissedPIDs: Set<Int32> = [],
                                 disabledKinds: Set<ProcessKind> = [],
                                 customRules: [CustomRule] = [],
                                 startTimeProvider: ((Int32) -> ProcStartTime?)? = nil,
                                 uidProvider: ((Int32) -> uid_t?)? = nil) -> [ProcessItem] {
        let output = psOutput ?? runPS()
        let portPIDs = registeredPIDs ?? PortRegistry.listeningPIDs()
        var all = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { makeItem(from: String($0), elapsedThreshold: elapsedThreshold,
                                   registeredPIDs: portPIDs, customRules: customRules,
                                   startTimeProvider: startTimeProvider,
                                   uidProvider: uidProvider) }
        if !ignoredNames.isEmpty {
            all = all.filter { item in
                !ignoredNames.contains { prefix in
                    item.command.localizedCaseInsensitiveContains(prefix)
                }
            }
        }
        if !dismissedPIDs.isEmpty {
            all = all.filter { !dismissedPIDs.contains($0.pid) }
        }
        // Filter disabled kinds *after* the wrapper collapse: a merged wrapper row
        // takes its `kind` from the meaningful child (`npm run dev` → `.vite`), so
        // judging the final, displayed kind matches what the user sees in the row.
        let collapsed = collapseWrappers(all)
        guard !disabledKinds.isEmpty else { return collapsed }
        return collapsed.filter { !disabledKinds.contains($0.kind) }
    }

    // MARK: - Wrapper collapse (PID-039)

    /// Fold each npm/npx *wrapper* parent and its single scanned child into one
    /// row. A wrapper (`npm run dev`, `npm exec @playwright/mcp`) is just a
    /// launcher whose meaningful payload is the child it spawned (vite, the
    /// playwright-mcp node process); surfacing both reads as a duplicate — the
    /// same `npm` appearing as its own row and again under its child. The merged
    /// row takes its **identity** (pid/ppid/tty/startTime/uid — i.e. the kill target,
    /// the PID-reuse guard, and the owner) from the wrapper root, so killing it tears down
    /// the whole subtree; but its **kind/command/riskTier** come from the child,
    /// so it groups and labels as the real process. CPU + RAM are summed.
    ///
    /// Only the 1:1 case collapses. A wrapper with zero scanned children (e.g. an
    /// orphaned `npm run dev` whose server already died) or with more than one is
    /// left untouched — that keeps every row's `id` (its pid) unique and the kill
    /// target unambiguous. All observed real trees are 1:1.
    public static func collapseWrappers(_ items: [ProcessItem]) -> [ProcessItem] {
        let childrenByPPID = Dictionary(grouping: items, by: { $0.ppid })
        var consumed = Set<Int32>()
        var mergedByWrapperPID: [Int32: ProcessItem] = [:]
        for wrapper in items where isNpmWrapper(wrapper.command) {
            guard !consumed.contains(wrapper.pid) else { continue }
            let children = (childrenByPPID[wrapper.pid] ?? []).filter { !consumed.contains($0.pid) }
            guard children.count == 1, let child = children.first else { continue }
            consumed.insert(wrapper.pid)
            consumed.insert(child.pid)
            mergedByWrapperPID[wrapper.pid] = ProcessItem(
                pid: wrapper.pid, ppid: wrapper.ppid, command: child.command,
                elapsed: wrapper.elapsed, tty: wrapper.tty, kind: child.kind,
                riskTier: child.riskTier,
                cpuPercent: wrapper.cpuPercent + child.cpuPercent,
                rssKB: wrapper.rssKB + child.rssKB, startTime: wrapper.startTime,
                uid: wrapper.uid)
        }
        guard !consumed.isEmpty else { return items }
        return items.compactMap { item in
            if let merged = mergedByWrapperPID[item.pid] { return merged }
            if consumed.contains(item.pid) { return nil }
            return item
        }
    }

    /// True when `command` is an npm/npx launcher invocation — the wrapper-process
    /// shape `collapseWrappers` folds into its child. Matches a bare `npm`/`npx`,
    /// a path-qualified launcher (`/usr/local/bin/npm run …`), or the
    /// `npm-cli.js` / `npx-cli.js` form. Deliberately command-based, not
    /// `kind`-based: `npm exec @playwright/mcp` classifies as `.playwrightMCP`
    /// (its args contain `@playwright/mcp`), so the wrapper is not always `.npm`.
    private static func isNpmWrapper(_ command: String) -> Bool {
        let s = command.lowercased()
        return s.hasPrefix("npm ") || s == "npm" || s.contains("/npm ") || s.hasSuffix("/npm")
            || s.hasPrefix("npx ") || s == "npx" || s.contains("/npx ") || s.hasSuffix("/npx")
            || s.contains("npm-cli.js") || s.contains("npx-cli.js")
    }

    /// Build one classified `ProcessItem` from a `ps` line, or `nil` if the line
    /// doesn't parse or matches no known `ProcessKind`.
    /// A process whose PID is in `registeredPIDs` is demoted from `.easy` to `.moderate`
    /// so it always lands in the Needs Review bucket.
    /// `startTimeProvider` and `uidProvider` are the two scan-time identity reads (both
    /// backed by `KillCore`'s single `kinfo_proc` fetch); omitting either leaves the
    /// corresponding `ProcessItem` field `nil`, which every consumer reads as "unknown".
    /// User `customRules` are consulted **ahead of** `detectKind`: a custom-rule
    /// match relabels the process (`.custom` kind + `customLabel`) even when a
    /// built-in kind would also match, and always lands in Needs Review. (PID-54.3)
    public static func makeItem(from line: String, elapsedThreshold: TimeInterval,
                                registeredPIDs: Set<Int32> = [],
                                customRules: [CustomRule] = [],
                                startTimeProvider: ((Int32) -> ProcStartTime?)? = nil,
                                uidProvider: ((Int32) -> uid_t?)? = nil) -> ProcessItem? {
        guard let p = parsePSLine(line) else { return nil }
        let kind: ProcessKind
        let customLabel: String?
        if let rule = CustomRule.firstMatch(p.args, in: customRules) {
            kind = .custom
            customLabel = rule.label
        } else if let detected = detectKind(p.args) {
            kind = detected
            customLabel = nil
        } else {
            return nil
        }

        let elapsed = parseElapsed(p.etime)
        let cpuPercent = Double(p.pcpu) ?? 0.0
        let rssKB = Int(p.rss) ?? 0
        let hasTTY = ProcessItem.isTTYAttached(p.tty)
        let isOrphan = p.ppid == 1
        var tier = riskTier(kind: kind,
                            hasTTY: hasTTY,
                            isOrphan: isOrphan,
                            isOld: elapsed >= elapsedThreshold)
        if registeredPIDs.contains(p.pid) && tier == .easy { tier = .moderate }
        // Capture the scan-time start-time identity token (when a provider is
        // supplied) so the kill path can detect PID reuse before SIGTERM. (PID-35.3)
        let startTime = startTimeProvider.flatMap { $0(p.pid) }
        // Capture the owning uid the same way, so a foreign-owned process can be shown
        // as unkillable without a dead-end click first. (PID-62.3)
        let uid = uidProvider.flatMap { $0(p.pid) }
        return ProcessItem(pid: p.pid, ppid: p.ppid, command: p.args,
                           elapsed: elapsed, tty: p.tty, kind: kind, riskTier: tier,
                           cpuPercent: cpuPercent, rssKB: rssKB, startTime: startTime,
                           customLabel: customLabel, uid: uid)
    }

    // MARK: - Scoped ignores (PID-54.4)

    /// Drop items hidden by a **scoped** ignore rule — one carrying a `pathPrefix`. An
    /// item is removed when its command contains the rule's substring (case-insensitive)
    /// **and** its resolved cwd sits under the rule's prefix. Global rules
    /// (`pathPrefix == nil`) are handled upstream inside `enumerate` via `ignoredNames`
    /// and skipped here. Applied by `ScanEngine` after `CwdResolver.processCwds`, since
    /// `enumerate` itself has no cwd data. An item whose cwd didn't resolve can't be
    /// scoped, so it's kept (graceful degrade). Pure; `cwds` is the scan's PID→cwd map.
    public static func applyScopedIgnores(_ items: [ProcessItem],
                                          cwds: [Int32: ProcessCwd],
                                          rules: [IgnoreRule]) -> [ProcessItem] {
        let scoped = rules.filter { $0.pathPrefix != nil }
        guard !scoped.isEmpty else { return items }
        return items.filter { item in
            guard let cwd = cwds[item.pid]?.fullPath else { return true }
            return !scoped.contains { rule in
                item.command.localizedCaseInsensitiveContains(rule.substring)
                    && CwdResolver.isUnderPrefix(cwd, rule.pathPrefix!)
            }
        }
    }

    // MARK: - Provenance resolution

    /// Resolve a child's parent to the parent candidate's compact `displayPath`,
    /// looking only within the scan result set. Returns nil when the parent isn't
    /// itself a scanned candidate (a shell, launchd, or any non-stray process) — the
    /// common case, which the UI degrades gracefully (PID-036.3). launchd (`ppid == 1`)
    /// is never resolved: orphans surface via `ProcessItem.isOrphan`, not here.
    public static func parentCommand(ofPPID ppid: Int32, in items: [ProcessItem]) -> String? {
        guard ppid > 1 else { return nil }
        return items.first { $0.pid == ppid }?.displayPath
    }

    // MARK: - Pure parsing helpers

    /// Split a `ps -o pid=,ppid=,etime=,tty=,pcpu=,rss=,args=` line into its fields. The
    /// first six columns are whitespace-delimited; everything after is the
    /// (space-containing) command line.
    public static func parsePSLine(_ line: String) -> (pid: Int32, ppid: Int32, etime: String, tty: String, pcpu: String, rss: String, args: String)? {
        var remainder = Substring(line)
        var fields: [Substring] = []
        for _ in 0..<6 {
            while let c = remainder.first, c == " " || c == "\t" { remainder = remainder.dropFirst() }
            guard let space = remainder.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            fields.append(remainder[..<space])
            remainder = remainder[space...]
        }
        let args = remainder.trimmingCharacters(in: .whitespaces)
        guard let pid = Int32(fields[0]), let ppid = Int32(fields[1]), !args.isEmpty else { return nil }
        return (pid, ppid, String(fields[2]), String(fields[3]), String(fields[4]), String(fields[5]), args)
    }

    /// Parse a `ps` etime string (`[[DD-]HH:]MM:SS`) into seconds.
    public static func parseElapsed(_ etime: String) -> TimeInterval {
        var rest = etime.trimmingCharacters(in: .whitespaces)
        var days = 0
        if let dash = rest.firstIndex(of: "-") {
            days = Int(rest[..<dash]) ?? 0
            rest = String(rest[rest.index(after: dash)...])
        }
        let parts = rest.split(separator: ":").map { Int($0) ?? 0 }
        var hours = 0, minutes = 0, seconds = 0
        switch parts.count {
        case 3: hours = parts[0]; minutes = parts[1]; seconds = parts[2]
        case 2: minutes = parts[0]; seconds = parts[1]
        case 1: seconds = parts[0]
        default: break
        }
        return TimeInterval(((days * 24 + hours) * 60 + minutes) * 60 + seconds)
    }

    /// Map a command line to a `ProcessKind`, or `nil` if it's not a stray
    /// candidate. Order matters: the Chrome-under-`ms-playwright-mcp` case is
    /// tested before the generic playwright-mcp case (its user-data-dir path
    /// contains the `playwright-mcp` substring too).
    public static func detectKind(_ args: String) -> ProcessKind? {
        let s = args.lowercased()

        if s.contains("ms-playwright-mcp") && (s.contains("chrome") || s.contains("chromium")) {
            return .chromeHelper
        }
        if s.contains("@playwright/mcp") || s.contains("playwright-mcp") {
            return .playwrightMCP
        }
        // Generic MCP servers (filesystem/git/etc.) beyond Playwright's — checked
        // after the playwright cases so `@playwright/mcp` keeps its own kind.
        if s.contains("@modelcontextprotocol") || s.contains("mcp-server-") {
            return .mcpServer
        }
        if s.contains("playwright") && s.contains("test") {
            return .playwrightTest
        }
        if hasTokenBoundary(s, "pytest")  { return .pytest }
        if hasTokenBoundary(s, "vitest")  { return .vitest }
        if hasTokenBoundary(s, "vite")    { return .vite }
        if hasTokenBoundary(s, "jest")    { return .jest }
        if hasTokenBoundary(s, "uvicorn") { return .uvicorn }
        if hasTokenBoundary(s, "docker")  { return .docker }
        // Expanded dev-server / build-tool / local-infra kinds (PID-54.2), slotted
        // before the generic node/npm fallbacks so a framework dev server isn't
        // swallowed by `.node`. SvelteKit is intentionally absent — its dev server
        // runs as Vite and is already caught by `.vite`.
        if hasTokenBoundary(s, "next") || s.contains("next-server") { return .nextjs }
        if hasTokenBoundary(s, "astro")  { return .astro }
        if hasTokenBoundary(s, "cargo")  { return .cargo }
        if isGoRun(s)                    { return .goRun }
        if hasTokenBoundary(s, "ollama") || s.contains("llama-server") || s.contains("llama-cli") {
            return .llmServer
        }
        if s.contains("node_modules/electron") || s.contains("node_modules/.bin/electron") {
            return .electron
        }
        if hasTokenBoundary(s, "npm")     { return .npm }
        if hasTokenBoundary(s, "bun")     { return .bun }
        if hasTokenBoundary(s, "node")    { return .node }
        return nil
    }

    /// True when `s` is an explicit `go run …` launcher. Bare `go` is too short
    /// and common to token-match safely, and the durable server `go run` spawns
    /// is a temp binary — so we key on the launcher command form. (PID-54.2)
    private static func isGoRun(_ s: String) -> Bool {
        s.hasPrefix("go run ") || s.contains("/go run ")
    }

    /// True when `token` appears at a word boundary in `s` — preceded by the
    /// start of string, a slash, a period, or a space; followed by the end of
    /// string, a slash, a period, or a space. Prevents tokens like "npm" from
    /// matching "pnpm", or "jest" from matching "/path/jest-examples/server".
    private static func hasTokenBoundary(_ s: String, _ token: String) -> Bool {
        // Standalone command: "npm run dev" / "uvicorn …" / bare "bun"
        if s.hasPrefix(token + " ") || s == token { return true }
        // Path segment: "/usr/bin/npm …" or "node_modules/.bin/jest --watch"
        if s.contains("/" + token + " ") || s.hasSuffix("/" + token) { return true }
        // Reverse-DNS component: "com.docker.backend"
        if s.contains("." + token + ".") || s.hasSuffix("." + token) { return true }
        // Argument position: "python -m pytest tests/"
        if s.contains(" " + token + " ") || s.hasSuffix(" " + token) { return true }
        return false
    }

    // MARK: - Dev-mode flag parse (PID-55.3)

    /// True when `command` carries an explicit dev-mode marker — a long-running
    /// watch / dev / hot-reload flag or an inline `NODE_ENV=development` env
    /// assignment. Folded (with sustained-low-CPU + age + no-TTY) into the
    /// "idle dev server" signal surfaced in the row inspector. **Signal-only** —
    /// never feeds `riskTier` / `bucket` / the kill bar.
    ///
    /// Deliberately high-precision: only explicit `--`-flag and env-var forms
    /// match — a bare `dev` / `watch` *subcommand* (`next dev`) does not — and it
    /// reuses `detectKind`'s `hasTokenBoundary` discipline so `--dev` doesn't
    /// match `--devtools` (nor `--no-watch` match `--watch`).
    public static func hasDevModeFlag(_ command: String) -> Bool {
        let s = command.lowercased()
        if s.contains("node_env=development") || s.contains("node_env development") { return true }
        for flag in ["--watch", "--dev", "--hot", "--reload"] where hasTokenBoundary(s, flag) {
            return true
        }
        return false
    }

    /// Risk tier = base risk by kind, adjusted by stray signals. A process is a
    /// "strong stray" only when it has no terminal, is orphaned, and is old.
    public static func riskTier(kind: ProcessKind, hasTTY: Bool, isOrphan: Bool, isOld: Bool) -> RiskTier {
        // Real dev infra — never an easy kill regardless of signals.
        if kind == .docker || kind == .uvicorn || kind == .node || kind == .llmServer { return .high }

        let strongStray = !hasTTY && isOrphan && isOld
        switch kind {
        case .pytest, .vitest, .jest, .playwrightTest, .playwrightMCP, .chromeHelper, .mcpServer:
            return strongStray ? .easy : .moderate
        case .npm, .vite, .bun, .nextjs, .astro, .cargo, .goRun, .electron:
            return strongStray ? .moderate : .high
        case .custom:
            return .moderate   // user-defined match: never easy → always needsReview
        case .docker, .uvicorn, .node, .llmServer:
            return .high   // handled above; keeps the switch exhaustive
        }
    }

    // MARK: - Process enumeration

    public static func runPS() -> String {
        Shell.run("/bin/ps", ["-axww", "-o", "pid=,ppid=,etime=,tty=,pcpu=,rss=,args="]).output
    }
}
