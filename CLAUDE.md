# CLAUDE.md — Pidly

Native macOS menu bar app. Full design in [`SPEC.md`](SPEC.md).

### Tech stack

- Swift + SwiftUI, macOS 13+, Apple Silicon target
- `MenuBarExtra` for tray icon + popover — no AppKit
- `sysctl` / `ps aux` for process enumeration
- Xcode project, no backend

### Build

Open `Pidly.xcodeproj` in Xcode, ⌘R to run. App appears in menu bar only (`LSUIElement = YES`). Run the test suite from the command line with `make test`. Build a Release app: `make build-release` (ad-hoc signed, output: `build/Release/Pidly.app`). Install to `/Applications`: `make install`.

### Conventions

- All scan + classification logic lives in `ScanEngine.swift` — do not scatter it
- Two classification buckets only: `safe` and `needsReview` — never kill without explicit user action
- Port registry lives in `PortRegistry.swift`; keep in sync with CLAUDE.md global port table when ports are added
- Kill flow is always SIGTERM first, SIGKILL fallback after 2 s — never skip the grace period
