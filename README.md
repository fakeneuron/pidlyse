# Pidly

Native macOS menu bar app that spots stray dev processes and clears them in one click.

Sits beside the clock. Periodically scans for known process junk — orphaned test runners, idle servers, stale playwright-mcp instances, zombie Chrome helpers — and badges the icon when it finds them. Click to expand: a categorised list with per-row CPU%, RAM, and age; risk-tier color dots; kill buttons for obvious strays; and a "Needs review" section for anything that warrants a second look.

## Features

- **12 process kinds** detected: `pytest`, `vitest`, `vite`, `jest`, `npm`, `docker`, `uvicorn`, `playwright`, `playwright-mcp`, `Chrome (playwright-mcp)`, `bun`, `node`
- **Per-row signals** — CPU%, RAM, age, risk-tier color dot (green / orange / red), expandable "why is this here?" detail (tty status, orphan flag, age criteria)
- **Two-section layout** — *Safe to clean* (easy-tier orphaned/old/no-tty strays) and *Needs review* (ambiguous processes tied to real dev infra)
- **"Clean all"** sweeps the safe section in one click; per-row kill button for surgical cleanup
- **Session dismiss** — hide a process until restart without killing it (↺ rescan restores all dismissed items)
- **Kill flow**: SIGTERM first, SIGKILL fallback after 2 s — always explicit, never automatic
- **Settings**: scan interval (default 2 min), stale-process threshold (default 30 min), ignored command substrings, launch at login, notification alerts (opt-in)

## Requirements

- macOS 14+
- Xcode 15+
- Apple Silicon (M-series) target

## Build & Run

Open `Pidly.xcodeproj` in Xcode and run (⌘R). The app lives in the menu bar — no Dock icon (`LSUIElement = YES`). Left-click the icon to open the popover; right-click (or two-finger tap) for a quick Quit menu.

Run the test suite from the command line with `make test`. The same suite runs automatically on every push to `main` via GitHub Actions (`.github/workflows/test.yml`).

Build a Release `.app` with ad-hoc signing: `make build-release` (output: `build/Release/Pidly.app`). Copy it to `/Applications` with `make install`. Package a distributable DMG (drag-install, with `/Applications` symlink): `make dmg` (output: `build/Pidly.dmg`). Push a `v*` tag to trigger the release workflow (`.github/workflows/release.yml`), which builds the Release app, packages the DMG, and attaches it to a GitHub Release automatically.

## Menu Bar States

| State | Icon | Badge |
|-------|------|-------|
| Clean | ghost outline | none |
| Safe kills available | filled icon | red count |
| Review items only | filled icon | yellow count |
| Scanning | spinner overlay | — |

## Design

See [`SPEC.md`](SPEC.md) for the full technical specification, scan logic, classification rules, and project structure.

## Task Tracking

See [`.flowtron/PLAN.md`](.flowtron/PLAN.md).
