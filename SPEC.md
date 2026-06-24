# Pidly — Technical Specification

## Overview

A native macOS menu bar app for Apple Silicon that surfaces stray and zombie processes and lets you kill them with one click. No Electron, no Node — Swift + SwiftUI only.

---

## Tech Stack

- **Language / UI**: Swift + SwiftUI, macOS 13+ target
- **Menu bar**: `MenuBarExtra` (SwiftUI, macOS 13) — avoids AppKit boilerplate
- **Process enumeration**: `sysctl` or `ps aux` shell-out
- **No helper daemon** for v1. XPC service / `launchd` plist deferred to post-v1 if background scanning proves necessary.

---

## Project Structure

```
Pidly/
  Pidly.xcodeproj
  Pidly/
    PidlyApp.swift          # @main, MenuBarExtra entry point
    MenuBarView.swift       # popover UI — process list
    ScanEngine.swift        # ps enumeration + classification logic
    ProcessItem.swift       # model: pid, name, age, tty, bucket
    PortRegistry.swift      # hardcoded + parseable port table
    KillService.swift       # safe kill wrapper (SIGTERM → SIGKILL fallback)
    Settings.swift          # scan interval, thresholds, ignored pids
```

---

## Scan Engine

Runs on a configurable timer (default: every 60 s). Shells out to `ps aux` or uses `sysctl` directly to enumerate processes. Matches against a pattern set:

| Pattern | Category |
|---------|----------|
| `playwright-mcp` / `@playwright/mcp` | Orphaned MCP browser tooling |
| `pytest`, `vitest`, `jest.*test`, `playwright test` | Hung test runners |
| Chrome processes under `ms-playwright-mcp/` user-data dirs | Zombie browser helpers |

Each match is evaluated on:

- **TTY**: `??` = no controlling terminal → stray indicator
- **Elapsed time**: configurable threshold, default > 30 min
- **Parent PID**: parent dead → orphan

---

## Classification

Two buckets only. A process goes in exactly one:

| Bucket | Criteria |
|--------|----------|
| **Safe to kill** | Old elapsed + no TTY + parent dead + no registry-port match |
| **Needs review** | Tied to a registered port/project, recently started, or parent still alive |

Port registry awareness: any process listening on a port in the CLAUDE.md global port table is automatically demoted to "needs review" — never auto-killed.

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

`PortRegistry.swift` holds the canonical port table (mirrored from CLAUDE.md global table). Loaded at startup; user can also supply a JSON override file.

Any process matched whose port appears in the registry is demoted to "needs review" regardless of other criteria.

---

## Menu Bar States

| State | Icon | Badge |
|-------|------|-------|
| Clean | ghost/skull outline | none |
| Has safe kills | filled icon | red count |
| Has review items only | filled icon | yellow count |
| Scanning | spinner overlay | — |

---

## Settings Panel

Configurable at runtime:

- Scan interval (default: 60 s)
- Elapsed-time threshold for "old" (default: 30 min)
- Ignored PIDs list (session or persistent)

---

## Non-Goals (v1)

- Docker / container management
- Full Supabase stack awareness
- Auto-start on login (deferred — add via `SMAppService` post-v1)
- Animated menu bar icon beyond simple badge
- Daemon / background XPC service

---

## Milestones

1. **Scaffold** — Xcode project, `MenuBarExtra` with static placeholder popover. Runs in menu bar, no Dock icon.
2. **Scan engine** — `ps aux` parsing, pattern matching, TTY + elapsed + parent checks. Returns `[ProcessItem]`.
3. **Popover UI** — Two sections (Safe / Review). Shows PID, command snippet, age, kill button.
4. **Kill action** — `kill(pid, SIGTERM)`, rescan after 2 s, confirm removal from list.
5. **Port registry** — Load table from bundled data; demote registry-port hits to Review.
6. **Polish** — Icon states, badge counts, scan timer, Settings panel.
