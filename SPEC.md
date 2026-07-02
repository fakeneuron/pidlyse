# Pidlyse — Technical Specification

## Overview

A native macOS menu bar app for Apple Silicon that surfaces stray and zombie processes and lets you kill them with one click. No Electron, no Node — Swift + SwiftUI only.

---

## Tech Stack

- **Language / UI**: Swift + SwiftUI, macOS 14+ target
- **Menu bar**: AppKit `NSStatusItem` bridge (managed by `AppDelegate`) hosting SwiftUI views — left-click opens the popover, right-click shows a Quit menu. (`MenuBarExtra` was retired in PID-023 because it exposes only left-click.)
- **Process enumeration**: `ps -axww` shell-out (column-formatted); port-listener detection via `lsof -nPi -sTCP:LISTEN`. (`sysctl` is used in `KillService` for the PID-reuse start-time guard, not for enumeration.)
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
        ProcessItem.swift         # model: pid, ppid, command, elapsed, tty, kind, riskTier, cpu%, rss; derived bucket
        PortRegistry.swift        # compiled port table + user-override merge + lsof listener parse
        CwdResolver.swift         # lsof cwd parse + git-root project label & root path (row descriptor + protect scope)
        AncestryResolver.swift    # pure `ps -axo pid/ppid/comm` parse; `processTable(psOutput:)` + `ancestorChain(ofPPID:in:)` cycle-guarded walk to launchd
        OpenFilesResolver.swift   # on-demand `lsof -p <pid>` parse; `OpenFile`/`OpenFileList` model + `openFiles(forPID:)` composer; REG+socket filter
        IgnoreRule.swift          # model: command-substring ignore, optionally scoped to a cwd path prefix
        CustomRule.swift          # model: user-defined command-substring rule + friendly label (always Needs Review)
        ScanHistory.swift         # rolling-window per-process CPU cache (PID+startTime keyed) + sustained-low-CPU query
        CleanEvent.swift          # Codable model: kind rawValue, project label, rssKB, timestamp; no command line (privacy-first)
        CleanLog.swift            # pure rolling-window stats (count, RAM reclaimed, top kinds) + count-cap retention
        DockerCore.swift          # pure `docker ps` / `docker stats` output parsing
        Container.swift           # models: Container (id, name, image, status, ports) + ContainerStats (cpu, memory)
        Shell.swift               # shared subprocess primitive (Process/Pipe drain) — all four shell-out sites delegate
  Pidlyse/
    PidlyseApp.swift          # @main; required (inert) Settings scene + NSApplicationDelegateAdaptor
    AppDelegate.swift         # NSStatusItem bridge: icon, popover, right-click Quit, self-managed Settings window
    MenuBarView.swift         # popover UI — Processes/Containers toggle + process list
    ContainersView.swift      # popover UI — running-container list (one-shot CPU/mem sample) with stop / stop+remove
    CleanedView.swift         # popover UI — "Cleaned" tab: kill-history stats (count, RAM reclaimed, top kinds)
    ScanEngine.swift          # app-side scan lifecycle: timer, persistence, notifications (drives ScanCore)
    CleanLogStore.swift       # app-side JSON store for kill history; wired from ScanEngine, persists to Application Support
    DockerService.swift       # app-side docker CLI access: path resolution, shell-out, container listing
    KillService.swift         # safe kill wrapper (SIGTERM → 2 s grace → SIGKILL; PID-reuse guard; docker-stop path)
    SettingsView.swift        # scan interval, thresholds, ignored substrings (+ per-project scoping), custom rules, protected projects, launch-at-login, notifications
  PidlyseTests/
    ScanEngineTests.swift     # unit tests for the PidlyseCore pipeline
  logo.png                    # master brand/icon source (532×543 RGBA); wired into AppIcon.appiconset as 7 PNG sizes (16–1024px)
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
| Chrome processes under `ms-playwright-mcp/` user-data dirs | `chromeHelper` | Zombie browser helpers |
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

`bucket = (riskTier == .easy) ? .safe : .needsReview`. A process is **never auto-killed**; `safe` items still require an explicit click (per CLAUDE.md).

Port registry awareness ([[PID-005]]): any process listening on a port in the CLAUDE.md global port table is automatically demoted to "needs review" — never auto-killed.

Protected-projects awareness (PID-54.4): a safe process whose working directory sits under a user-protected project tree stays *listed* in the Safe section (badged 🔒) but is excluded from the "Clean all" sweep, the section count, and the reclaimable total — a display/sweep overlay, not a bucket change. Its individual kill button still works.

---

## Kill Flow

1. User clicks kill button for a safe process.
2. `KillService` sends `SIGTERM`.
3. After 2 s, if process still alive → `SIGKILL` fallback.
4. Rescan triggered immediately after kill.
5. PID removed from list on next scan result.

Bulk action: "Kill all safe" applies the same flow to every safe-bucket process.

Dismiss / ignore: snoozes that PID for the session (does not survive restart).

Each process row's descriptor line shows the **project it runs in** — the enclosing git repo (`bidviz`, or `bidviz/frontend` when the process runs in a subfolder) resolved from the process's working directory via `lsof`, so a bare `npm`/`node` is identifiable beyond its executable name. It falls back to the compact executable path when no cwd resolves (with the full path on hover). (PID-038)

"Why is this here?" expands inline classification reasoning: the full command line, the stray signals that fired (no TTY / orphan / old) plus raw `tty · ppid · age`, the full ancestor chain to launchd (`child of X ← … ← launchd`, resolved via `AncestryResolver`), and — when resolvable — provenance hints: the registered port(s) the PID listens on (`:5173 listening`, [[PID-005]] demotion) and the Docker container that owns it (`owned by container <name>`, [[PID-EPIC-037]]). On expand, open files + sockets load on demand via `OpenFilesResolver` (capped at 15 entries, `+N more` when truncated). Hints are omitted when absent. (PID-EPIC-036, [[PID-52]]) When sustained low CPU across recent scans coincides with old + no-TTY + an explicit dev-mode flag in the command, an advisory "idle dev server" line also appears — signal-only, never feeding the risk tier or kill bar. ([[PID-EPIC-55]])

---

## Port Registry

`PortRegistry.swift` holds the canonical compiled port table (mirrored from CLAUDE.md global table). Loaded at startup.

**User override file ([[PID-025]]):** at startup the app also reads an optional, user-editable JSON file at `~/Library/Application Support/Pidlyse/ports.json`, keyed by project:

```json
{ "siteguy": [3001, 8003], "bidviz": [5181, 8005] }
```

Its port lists are flattened and **unioned** with the compiled defaults (`effectivePorts = registeredPorts ∪ user ports`) — extend-only: a user can add ports without recompiling but cannot remove a built-in. A missing or malformed file falls back silently to the compiled defaults (the file is advisory, never fatal to a scan). This decouples per-project port additions from the manual CLAUDE.md ↔ `registeredPorts` sync.

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

## Non-Goals (v1)

- ~~Docker / container management~~ — **delivered post-v1** (PID-EPIC-28): a Processes / Containers segmented toggle whose Containers tab lists running containers with per-row stop / stop+remove. All `docker` access stays in the app-side `DockerService`; pure parsing in `PidlyseCore.DockerCore`.
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
