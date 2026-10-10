# Pidlyse — Technical Specification

## Overview

A native macOS menu bar app for Apple Silicon that surfaces stray and zombie processes and lets you kill them with one click. No Electron, no Node — Swift + SwiftUI only.

---

## Tech Stack

- **Language / UI**: Swift + SwiftUI, macOS 14+ target
- **Menu bar**: AppKit `NSStatusItem` bridge (managed by `AppDelegate`) hosting SwiftUI views — left-click opens the popover, right-click shows a Quit menu. (`MenuBarExtra` was retired in PID-023 because it exposes only left-click.)
- **Process enumeration**: `ps -axww` shell-out (column-formatted); port-listener detection via `lsof -nPi -sTCP:LISTEN`. (`sysctl` is used in `KillCore` for the PID-reuse start-time guard, not for enumeration.)
- **No helper daemon** for v1. XPC service / `launchd` plist deferred to post-v1 if background scanning proves necessary.

---

## Project Structure

```
Pidlyse/
  Pidlyse.xcodeproj
  Packages/
    PidlyseCore/                  # pure, injectable, unit-tested core (SPM package)
      Sources/PidlyseCore/
        ScanCore.swift            # ps parse + stray detection + risk-tier classification
        ProcessItem.swift         # model: pid, ppid, command, elapsed, tty, kind, riskTier, cpu%, rss, owning uid; derived bucket
        PortRegistry.swift        # compiled port table + user-override merge + lsof listener parse
        CwdResolver.swift         # lsof cwd parse + git-root project label & root path (row descriptor + protect scope)
        AncestryResolver.swift    # pure `ps -axo pid/ppid/comm` parse; `processTable(psOutput:)` + `ancestorChain(ofPPID:in:)` cycle-guarded walk to launchd
        OpenFilesResolver.swift   # on-demand `lsof -p <pid>` parse; `OpenFile`/`OpenFileList` model + `openFiles(forPID:)` composer; REG+socket filter
        IgnoreRule.swift          # model: command-substring ignore, optionally scoped to a cwd path prefix
        CustomRule.swift          # model: user-defined command-substring rule + friendly label (always Needs Review)
        ScanHistory.swift         # rolling-window per-process CPU cache (PID+startTime keyed) + sustained-low-CPU query
        RespawnHistory.swift      # session-only respawn cache: command-signature normalization + per-identity windowed watches on verified kills
        Killability.swift         # pure killability overlay: killable / unkillable (foreign owner) / respawner derivation + the one explanation sentence
        KillFeedback.swift        # pure kill-feedback vocabulary: KillPhase (per-row lifecycle label) + KillReport (honest Clean-all tally + summary line)
        CleanEvent.swift          # Codable model: kind rawValue, project label, rssKB, timestamp; no command line (privacy-first)
        CleanLog.swift            # pure rolling-window stats (count, RAM reclaimed, top kinds) + count-cap retention
        DockerCore.swift          # pure `docker ps` / `docker stats` output parsing
        Container.swift           # models: Container (id, name, image, status, ports, composeProject) + ContainerStats (cpu, memory)
        DockerService.swift       # impure docker CLI access: trusted-path resolution, shell-out, container listing/owners
        KillCore.swift            # synchronous kill path: SIGTERM → 2 s grace → SIGKILL → death check; PID-reuse identity guards; docker-stop routing
        CleanLogFile.swift        # shared clean-log disk I/O (load / append-capped / atomic save) — one format for both writers
        CLICore.swift             # pure cli-companion command grammar (list/clean/kill/help) + table formatting
        Shell.swift               # shared subprocess primitive (Process/Pipe drain, per-caller deadline) — all shell-out sites delegate
      Sources/PidlyseCLI/
        main.swift                # `pidlyse` executable: defaults-domain settings read, ScanEngine-parity scan pipeline, command dispatch
      Tests/PidlyseCoreTests/     # one XCTest file per core type; `swift test --package-path Packages/PidlyseCore`
  Pidlyse/
    PidlyseApp.swift          # @main; required (inert) Settings scene + NSApplicationDelegateAdaptor
    AppDelegate.swift         # NSStatusItem bridge: icon, popover, right-click Quit, self-managed Settings window
    MenuBarView.swift         # popover UI — Processes/Containers toggle + process list
    ContainersView.swift      # popover UI — read-only running-container list (one-shot CPU/mem sample, compose-project grouping)
    CleanedView.swift         # popover UI — "Cleaned" tab: kill-history stats (count, RAM reclaimed, top kinds)
    ScanEngine.swift          # app-side scan lifecycle: timer, persistence, notifications (drives ScanCore)
    CleanLogStore.swift       # app-side @Published binding for kill history; wired from ScanEngine, disk I/O delegated to core CleanLogFile
    DockerService+Async.swift # SwiftUI-facing async wrappers over the core DockerService (main-queue delivery)
    KillService.swift         # thin async wrapper over KillCore (background-queue kill, main-queue callbacks)
    SettingsView.swift        # scan interval, thresholds, ignored substrings (+ per-project scoping), custom rules, protected projects, launch-at-login, notifications
  PidlyseTests/                 # Xcode unit-test target for app-lifecycle tests; core suite lives in PidlyseCoreTests
  logo.png                    # master brand/icon source (532×543 RGBA); wired into AppIcon.appiconset as 7 PNG sizes (16–1024px)
  brand/                       # public identity kit (BRAND.md blurb, logo.svg/favicon.svg hand-redrawn from logo.png, PROMPTS.md provenance) — natabula fleet-brand standard
```

---

## Scan Engine

Runs on a configurable timer (default: every 2 min). Shells out to `ps -axww -o pid=,ppid=,etime=,tty=,pcpu=,rss=,args=` to enumerate processes. Matches against a pattern set:

| Pattern | `kind` | Category |
|---------|--------|----------|
| *user-defined substring* (Settings → Custom rules) | `custom` | Consulted **ahead of** all built-ins; carries the user's friendly label, always Needs Review |
| `playwright-mcp` / `@playwright/mcp` | `playwrightMCP` | Orphaned MCP browser tooling |
| `@modelcontextprotocol` / `mcp-server-*` | `mcpServer` | Orphaned MCP servers (filesystem/git/etc.) |
| `pytest`, `vitest`, `jest`, `playwright test` | `pytest` / `vitest` / `jest` / `playwrightTest` | Hung test runners |
| Chrome processes under `ms-playwright-mcp/` user-data dirs, or Playwright's isolated temp profile (`playwright_chromiumdev_profile`) | `chromeHelper` | Zombie browser helpers |
| `docker` (daemon + helpers) | `docker` | Real dev infra — never an easy kill |
| `uvicorn` | `uvicorn` | Backend dev server — never an easy kill |
| `next` / `next-server` | `nextjs` | Next.js dev server |
| `astro` | `astro` | Astro dev server |
| `cargo` | `cargo` | Rust build/run tool |
| `go run …` (command form only) | `goRun` | Go run launcher |
| `node_modules/electron` (project-local) | `electron` | Electron dev app (installed Electron apps excluded) |
| `ollama`, `llama-server` / `llama-cli` | `llmServer` | Local LLM server — never an easy kill |
| `npm` | `npm` | Dev tooling / servers |
| `vite` | `vite` | Dev server (Vite) — also catches SvelteKit, which runs on Vite |
| `bun` | `bun` | JS runtime / package manager |
| `node` | `node` | Node.js runtime |

User-defined **custom rules** (one command substring → a friendly label, edited in Settings and persisted to UserDefaults) are consulted before the built-in patterns: a match surfaces the process as `kind == custom` under the user's label and is always classified Needs Review — never auto-killable. A process that matches neither a custom rule nor a built-in `kind` is not a stray candidate and is excluded.

Two user-managed override lists (Settings, UserDefaults) further shape results (PID-54.4):

- **Ignored substrings** hide matching processes. A bare line hides globally; a `substring @ ~/path` line (`IgnoreRule`) scopes the ignore to one project tree, hiding matches only when the resolved cwd sits under that prefix. Global ignores filter inside `enumerate`; scoped ignores apply as a post-filter (`ScanCore.applyScopedIgnores`) once the scan's cwd map is resolved.
- **Protected projects** keep a project tree's processes out of the "Clean all" bulk sweep (marked 🔒, still individually killable). Each entry is a cwd path prefix; a process is protected when its cwd is under any entry (`CwdResolver.isUnderPrefix`). Protection is a display/sweep overlay — it does not change the `kind`/`riskTier` — and is toggled per-row (🔒) or in Settings.

Each match is evaluated on:

- **TTY**: `??` = no controlling terminal → stray indicator
- **Elapsed time**: configurable threshold, default > 30 min
- **Parent PID**: parent dead (reparented to `launchd`, ppid == 1) → orphan

---

## Classification

Each candidate carries a descriptive **`kind`** (see the Scan Engine table) and a 3-level **`riskTier`** — `easy` / `moderate` / `high` — the display gradient (the popover may render all three). The two **kill-action buckets** (`safe` / `needsReview`) are **derived** from the tier and remain the only classification the kill flow acts on:

| `riskTier` | Bucket | When |
|------------|--------|------|
| **easy** | **Safe to kill** | Test runner / playwright-mcp / MCP server / Chrome helper that is a *strong stray*: old elapsed **and** no TTY **and** parent dead |
| **moderate** | **Needs review** | A candidate without all three strong-stray signals (recently started, has a TTY, or parent still alive) |
| **high** | **Needs review** | Real dev infra (`docker`, `uvicorn`, `node`, `llmServer`) — never an easy kill regardless of signals; also the dev-server / build-tool family (`npm`/`vite`/`bun`/`nextjs`/`astro`/`cargo`/`goRun`/`electron`) when not a strong stray |
| **moderate** (fixed) | **Needs review** | User-defined `custom`-rule matches — always Needs Review regardless of stray signals |

`bucket = (riskTier == .easy) ? .safe : .needsReview`. A process is **never auto-killed**; `safe` items still require an explicit click (per AGENTS.md).

Tree collapse ([[PID-039]], [[PID-62.4]]): `ScanCore.collapseTrees` folds every scanned process whose direct parent is also scanned *and belongs with it* (the parent is a launcher, the two share a kind, or the child is a Chrome helper / generic `.node` worker — so a `node`-run agent CLI never swallows the MCP servers it starts) into its topmost linked ancestor, so a chain that lives and dies together (`sh -c npm run dev` → `npm` → `vite`, `uv run` → uvicorn, `next dev` → `next-server`, playwright-mcp → its Chrome brood) is **one row**. The row keeps the root's identity (pid, start-time token, owner — the kill target), labels itself after the first member that isn't a launcher (npm/npx, `sh -c`, `uv run`), takes the **most cautious** `riskTier` of any member, and sums CPU/RAM. The members ride on `ProcessItem.members` and appear as a read-only "group of N" inspector line and a ×N row count. "Clean all", the section counts, the clean log and respawn signatures all see one logical unit. A group is foreign-owned (unkillable) if any member is. Docker processes never group. Disabled kinds filter per process before grouping. Dismissing a group row dismisses the whole group.

Port registry awareness ([[PID-005]]): any process listening on a port in the localhost port registry (natabula `docs/PORT-REGISTRY.md`) is automatically demoted to "needs review" — never auto-killed.

Protected-projects awareness (PID-54.4): a safe process whose working directory sits under a user-protected project tree stays *listed* in the Safe section (badged 🔒) but is excluded from the "Clean all" sweep, the section count, and the reclaimable total — a display/sweep overlay, not a bucket change. Its individual kill button still works.

Killability awareness ([[PID-62.3]]): a row Pidlyse cannot honestly kill carries a killability state (`Killability`) — **unkillable** when the process belongs to another user (owning uid read at scan time from the same `kinfo_proc` `KillCore` uses, with an observed `EPERM` outcome as the backstop; Pidlyse never escalates) or **respawner** when [[PID-62.2]]'s respawn detection saw it come back after a verified kill (attributed to its owning container, else its nearest ancestor). The row stays *listed* in its section, but a badge (🚫 unkillable / ↻ respawner) replaces the ✕ button, its tooltip and a ⓘ inspector line carry the one explanation sentence, and it is excluded from "Clean all", ⌘⌫, the section count, and the reclaimable total through the engine-side `ScanEngine.isSweepable(_:)` predicate the popover shares. Same overlay shape as 🔒 — `riskTier` and `bucket` are untouched. Unkillable outranks respawner; an unresolved uid degrades to killable. The CLI's `clean` excludes foreign-owned rows too; the respawn half stays app-only (a one-shot CLI has no session memory).

---

## Kill Flow

1. User clicks kill button for a safe process.
2. `KillService` sends `SIGTERM` (via the shared `KillCore` in `PidlyseCore`).
3. After 2 s, if process still alive → `SIGKILL` fallback.
4. **Death check** ([[PID-62.2]]): after the `SIGKILL` fallback, `KillCore` re-reads the process table before reporting success. The outcome is `confirmed` only when the process is verified gone — no entry, PID recycled, or an unreaped zombie — and `survived` when it is still running under the same identity. (A process that exits during the grace period needs no probe; it is already observed gone.) Together with `notKilled` (identity guard refused) and `unkillable` (`EPERM` — a foreign owner, [[PID-62.3]]) these are the four honest answers a kill can give, and only `confirmed` is written to the clean log, so the "RAM reclaimed" figure counts real deaths only.
5. **Group rows** ([[PID-62.4]]): the root goes through steps 2–4 first, which takes a well-behaved tree down inside its grace period. Then every member runs the same identity-guarded path concurrently: a member that died with its root is simply gone, and one that didn't (a `sh -c` root doesn't forward signals) gets its own SIGTERM → grace → SIGKILL. An `unkillable` root stops the group kill before any member is signalled. `KillCore.groupOutcome` reports `confirmed` only when every member is verified gone, and `survived` when any member lives on (including a foreign-owned one).
6. Rescan triggered immediately after kill. A scan requested while another is in flight queues one follow-up rather than being dropped, so the killed row can't be left up by a scan that enumerated before the death ([[PID-62.5]]).
7. **Per-row lifecycle** ([[PID-62.5]]): every trigger (row ✕, ⌘⌫, Clean all, headless) runs through `ScanEngine.kill`. The row shows `killing…` in place of its ✕, then the verified verdict as a `KillPhase`: `gone`, `didn't die` (survived), `can't kill` (unkillable), or `skipped` (identity guard refused). After the follow-up scan, a verified death whose signature came back under a new PID reads `respawned` instead of `gone`. The state is keyed by pid + scan-time start time, so an intervening scan doesn't reset it, and a row in any phase is out of the sweep set. It clears ~3 s after the final phase. A gone row lingers dimmed for that window, then leaves the list.

Bulk action: "Clean all" applies the same flow to the sweep set and reports a `KillReport` — `Cleaned N of M` plus any respawned / didn't die / can't kill / skipped counts and the RAM freed by rows that stayed gone. The popover shows it under the Safe header for ~8 s. The `pidlyse://clean` notification, the Shortcuts dialog, and CLI `clean` print the same line (the CLI has no follow-up scan, so it never reports respawns).

**Respawn detection** ([[PID-62.2]]): each verified kill arms its own watch, per killed identity ([[PID-069]]), on that process's *command signature* — its command line (lowercased, whitespace-collapsed, with per-launch temp paths and IPC-handle flags stripped) plus its resolved working directory. If a later scan surfaces that signature under a **different** PID, started after the kill began, within the detection window (default 5 min), something restarted it and killing it again won't stick, so `RespawnHistory` counts it as a respawn. A same-signature sibling that was already running at kill time doesn't count ([[PID-62.5]]), and one new process answers at most one watch, so identical rows killed in separate clicks never share or overwrite a verdict. `ScanEngine.kill` asks per killed identity (`didRespawn`) whether it came back. The ↻ badge (`isRespawner`) stays signature-wide. The cache is a pure value type owned by `ScanEngine` (same split as `ScanHistory`) and is session-only: respawn memory earned before a relaunch says nothing about the current session, so a respawner re-earns its badge after one kill attempt. Signal-only — it never feeds the risk tier, the bucket, or the kill bar.

Dismiss / ignore: snoozes that PID for the session (does not survive restart).

Each process row's descriptor line shows the **project it runs in** — the enclosing git repo (`bidviz`, or `bidviz/frontend` when the process runs in a subfolder) resolved from the process's working directory via `lsof`, so a bare `npm`/`node` is identifiable beyond its executable name. It falls back to the compact executable path when no cwd resolves (with the full path on hover). (PID-038)

"Why is this here?" expands inline classification reasoning: the full command line, the stray signals that fired (no TTY / orphan / old) plus raw `tty · ppid · age`, the full ancestor chain to launchd (`child of X ← … ← launchd`, resolved via `AncestryResolver`), and — when resolvable — provenance hints: the registered port(s) the PID listens on (`:5173 listening`, [[PID-005]] demotion) and the Docker container that owns it (`owned by container <name>`, [[PID-EPIC-037]]). On expand, open files + sockets load on demand via `OpenFilesResolver` (capped at 15 entries, `+N more` when truncated). Hints are omitted when absent. (PID-EPIC-036, [[PID-52]]) When sustained low CPU across recent scans coincides with old + no-TTY + an explicit dev-mode flag in the command, an advisory "idle dev server" line also appears — signal-only, never feeding the risk tier or kill bar. ([[PID-EPIC-55]])

---

## Port Registry

`PortRegistry.swift` holds the canonical compiled port table (a snapshot of natabula `docs/PORT-REGISTRY.md` — project ports only, no Supabase / Docker-infra bands or macOS-reserved ports). Loaded at startup.

**User override file ([[PID-025]]):** at startup the app also reads an optional, user-editable JSON file at `~/Library/Application Support/Pidlyse/ports.json`, keyed by project:

```json
{ "siteguy": [3001, 8003], "bidviz": [5181, 8005] }
```

Its port lists are flattened and **unioned** with the compiled defaults (`effectivePorts = registeredPorts ∪ user ports`) — extend-only: a user can add ports without recompiling but cannot remove a built-in. A missing or malformed file falls back silently to the compiled defaults (the file is advisory, never fatal to a scan). This decouples per-project port additions from the manual PORT-REGISTRY.md ↔ `registeredPorts` sync.

Any process matched whose port appears in the merged registry is demoted to "needs review" regardless of other criteria.

---

## Menu Bar States

| State | Icon | Badge |
|-------|------|-------|
| Clean | ghost/skull outline | none |
| Has safe kills | filled icon | red count |
| Has review items only | filled icon | yellow count |
| Scanning | spinner overlay | — |

> The icon fires a one-shot pulse (alpha dip-and-restore) when the stray count rises
> — drawing the eye to a newly-appeared stray. Suppressed under Reduce Motion. The
> scanning glyph stays static. See PID-026.

---

## Settings Panel

Configurable at runtime (`SettingsView.swift`):

- **Launch at login** — registers a login item via `SMAppService` (opt-in; [[PID-010]]).
- **Notifications** — "Alert on new strays": a system notification when a scan finds processes not seen in the previous scan (opt-in; [[PID-13.5]]).
- **Scan interval** (default: 2 min).
- **Stale-process threshold** for "old" (default: 30 min).
- **Ignored command substrings** — one per line; matching processes are hidden from scan results (persisted via `UserDefaults`). Distinct from the session-only dismiss/snooze in §"Kill Flow".

---

## CLI Companion

`pidlyse` (PID-EPIC-57) — a terminal binary built from the same `PidlyseCore` package (`.executableTarget` `PidlyseCLI`; `make build-cli` / `make install-cli`). Hand-rolled arg parsing, zero external dependencies.

| Command | Does |
|---------|------|
| `pidlyse list [--safe]` | One-shot scan; prints candidates (PID, bucket, kind, age, RAM, project, command). `--safe` filters to the safe bucket; protected rows carry 🔒 |
| `pidlyse clean` | Kills exactly the app's "Clean all" sweep set — safe bucket minus protected projects and foreign-owned rows (respawners stay app-only, [[PID-62.3]]); prints each row's verdict and the shared `KillReport` summary line |
| `pidlyse kill <pid>` | Kills one *scanned candidate* by PID (any bucket, like the app's per-row kill button); refuses PIDs the scan didn't surface |
| `pidlyse help` | Usage (also the bare-invocation default — never scans or kills) |

Full app parity: settings (threshold, ignores incl. scoped, disabled kinds, custom rules, protected projects) are read from the app's defaults domain (`com.fakeneuron.pidlyse`); kills route through the same `KillCore` path (SIGTERM → 2 s grace → SIGKILL, PID-reuse guards, docker-stop routing); confirmed kills append to the shared clean-log (`CleanLogFile`), so CLI cleans show up in the app's "Cleaned" tab. One-shot by design — nothing is ever killed without an explicit `clean` / `kill` invocation.

## Integrations (PID-EPIC-58)

External launchers reach Pidlyse's clean/scan actions through one shared engine-side action layer — `ScanEngine.cleanAllSafe` (the `sweepableSafeItems` set — safe bucket minus protected and minus rows `ScanEngine.isSweepable` rules out ([[PID-62.3]], [[PID-62.5]]) — through `ScanEngine.kill`, clean-log append, rescan) and `ScanEngine.rescan`, the same set the popover "Clean all" and CLI `clean` use. Every trigger is bounded to that sweep set and never touches Needs Review.

| Surface | Entry point | Clean | Scan |
|---------|-------------|-------|------|
| URL scheme | `AppDelegate.application(_:open:)`; pure verb parse in `PidlyseCore.URLScheme` (PID-58.2) | `pidlyse://clean` → sweep + result notification | `pidlyse://scan` → rescan |
| Shortcuts / Spotlight | `AppShortcutsProvider` + two `AppIntent`s in `PidlyseApp.swift` (PID-58.3) | "Clean Safe Strays" → dialog summary | "Scan Now" → rescan |
| Raycast | `integrations/raycast/*.sh` wrapping the installed CLI (PID-58.3) | `pidlyse clean` | `pidlyse list --safe` (view-only) |

The URL scheme and AppIntents run in-app against the live scan. On a cold launch, `pidlyse://clean` and "Clean Safe Strays" wait for the launch scan to publish before consuming `items`; the Raycast scripts shell out to the CLI, which scans fresh per invocation. AppIntents return a dialog as their feedback channel, so — unlike `pidlyse://clean`, which has no return path — they post no notification. AppleScript is deliberately unsupported (`osascript` users have `do shell script "pidlyse clean"`), keeping the PID-35.1 "no NSAppleScript" security baseline intact.

---

## Non-Goals (v1)

- ~~Docker / container management~~ — **delivered post-v1** (PID-EPIC-28): a Processes / Containers segmented toggle whose Containers tab lists running containers, compose containers grouped under per-project section headers (non-compose ungrouped). Trimmed to metrics-only by [[PID-063]]: the per-row restart / stop / stop+remove buttons are gone (container actions belong in Docker Desktop); the Docker process kind, its container-owner hint, and `docker stop` kill routing are unchanged. All `docker` access stays in `DockerService` (in `PidlyseCore` since PID-57.2); pure parsing in `PidlyseCore.DockerCore`.
- Full Supabase stack awareness
- ~~Auto-start on login~~ — **delivered post-v1** (PID-010): a "Launch at login" toggle in Settings registers a login item via `SMAppService`.
- Animated menu bar icon beyond simple badge (partially delivered post-v1: a one-shot stray-found pulse, PID-026; continuous animation / scanning spinner remain out)
- Daemon / background XPC service

---

## Milestones

1. **Scaffold** — Xcode project, `MenuBarExtra` with static placeholder popover. Runs in menu bar, no Dock icon.
2. **Scan engine** — `ps aux` parsing, pattern matching, TTY + elapsed + parent checks. Returns `[ProcessItem]`.
3. **Popover UI** — Two sections (Safe / Review). Shows PID, command snippet, age, kill button.
4. **Kill action** — `kill(pid, SIGTERM)`, rescan after 2 s, confirm removal from list.
5. **Port registry** — Load table from bundled data; demote registry-port hits to Review.
6. **Polish** — Icon states, badge counts, scan timer, Settings panel.
