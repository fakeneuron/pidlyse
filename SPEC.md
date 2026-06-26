# Pidly — Technical Specification

## Overview

A native macOS menu bar app for Apple Silicon that surfaces stray and zombie processes and lets you kill them with one click. No Electron, no Node — Swift + SwiftUI only.

---

## Tech Stack

- **Language / UI**: Swift + SwiftUI, macOS 14+ target
- **Menu bar**: AppKit `NSStatusItem` bridge (managed by `AppDelegate`) hosting SwiftUI views — left-click opens the popover, right-click shows a Quit menu. (`MenuBarExtra` was retired in PID-023 because it exposes only left-click.)
- **Process enumeration**: `sysctl` or `ps aux` shell-out
- **No helper daemon** for v1. XPC service / `launchd` plist deferred to post-v1 if background scanning proves necessary.

---

## Project Structure

```
Pidly/
  Pidly.xcodeproj
  Pidly/
    PidlyApp.swift          # @main, Settings scene + NSApplicationDelegateAdaptor
    AppDelegate.swift       # NSStatusItem bridge: icon, popover, right-click Quit menu
    MenuBarView.swift       # popover UI — process list
    ScanEngine.swift        # ps enumeration + classification logic
    ProcessItem.swift       # model: pid, name, age, tty, bucket
    PortRegistry.swift      # hardcoded + parseable port table
    KillService.swift       # safe kill wrapper (SIGTERM → SIGKILL fallback)
    SettingsView.swift      # scan interval, thresholds, ignored pids
```

---

## Scan Engine

Runs on a configurable timer (default: every 2 min). Shells out to `ps aux` or uses `sysctl` directly to enumerate processes. Matches against a pattern set:

| Pattern | `kind` | Category |
|---------|--------|----------|
| `playwright-mcp` / `@playwright/mcp` | `playwrightMCP` | Orphaned MCP browser tooling |
| `pytest`, `vitest`, `jest`, `playwright test` | `pytest` / `vitest` / `jest` / `playwrightTest` | Hung test runners |
| Chrome processes under `ms-playwright-mcp/` user-data dirs | `chromeHelper` | Zombie browser helpers |
| `docker` (daemon + helpers) | `docker` | Real dev infra — never an easy kill |
| `uvicorn` | `uvicorn` | Backend dev server — never an easy kill |
| `npm` | `npm` | Dev tooling / servers |
| `vite` | `vite` | Dev server (Vite) |
| `bun` | `bun` | JS runtime / package manager |
| `node` | `node` | Node.js runtime |

A process that matches no `kind` is not a stray candidate and is excluded. Each match is evaluated on:

- **TTY**: `??` = no controlling terminal → stray indicator
- **Elapsed time**: configurable threshold, default > 30 min
- **Parent PID**: parent dead (reparented to `launchd`, ppid == 1) → orphan

---

## Classification

Each candidate carries a descriptive **`kind`** (see the Scan Engine table) and a 3-level **`riskTier`** — `easy` / `moderate` / `high` — the display gradient (the popover may render all three). The two **kill-action buckets** (`safe` / `needsReview`) are **derived** from the tier and remain the only classification the kill flow acts on:

| `riskTier` | Bucket | When |
|------------|--------|------|
| **easy** | **Safe to kill** | Test runner / playwright-mcp / Chrome helper that is a *strong stray*: old elapsed **and** no TTY **and** parent dead |
| **moderate** | **Needs review** | A candidate without all three strong-stray signals (recently started, has a TTY, or parent still alive) |
| **high** | **Needs review** | Real dev infra (`docker`, `uvicorn`, `node`) — never an easy kill regardless of signals; also `npm`/`vite`/`bun` when not a strong stray |

`bucket = (riskTier == .easy) ? .safe : .needsReview`. A process is **never auto-killed**; `safe` items still require an explicit click (per CLAUDE.md).

Port registry awareness ([[PID-005]]): any process listening on a port in the CLAUDE.md global port table is automatically demoted to "needs review" — never auto-killed.

---

## Kill Flow

1. User clicks kill button for a safe process.
2. `KillService` sends `SIGTERM`.
3. After 2 s, if process still alive → `SIGKILL` fallback.
4. Rescan triggered immediately after kill.
5. PID removed from list on next scan result.

Bulk action: "Kill all safe" applies the same flow to every safe-bucket process.

Dismiss / ignore: snoozes that PID for the session (does not survive restart).

"Why is this here?" expands inline classification reasoning.

---

## Port Registry

`PortRegistry.swift` holds the canonical port table (mirrored from CLAUDE.md global table). Loaded at startup.

Any process matched whose port appears in the registry is demoted to "needs review" regardless of other criteria.

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

Configurable at runtime:

- Scan interval (default: 2 min)
- Elapsed-time threshold for "old" (default: 30 min)
- Ignored PIDs list (session or persistent)

---

## Non-Goals (v1)

- Docker / container management
- Full Supabase stack awareness
- Auto-start on login (deferred — add via `SMAppService` post-v1)
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
