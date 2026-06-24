# Pidly

macOS menu bar app that surfaces stray and zombie processes and lets you kill them with one click.

Sits beside the clock as a small icon. Periodically scans for known process junk — orphaned test runners, stale playwright-mcp instances, zombie Chrome helpers — and shows a badge count when it finds them. Click to expand a tray UI: categorised list of candidates, kill buttons for safe ones, and a "needs review" section for anything ambiguous.

## Requirements

- macOS 13+
- Xcode 15+
- Apple Silicon (M-series) target

## Build & Run

Open `Pidly.xcodeproj` in Xcode and run (⌘R). The app lives in the menu bar — no Dock icon (`LSUIElement = YES`).

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
