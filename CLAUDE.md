# CLAUDE.md — Pidly

Native macOS menu bar app. Full design in [`SPEC.md`](SPEC.md).

### Tech stack

- Swift + SwiftUI, macOS 14+, Apple Silicon target
- AppKit `NSStatusItem` bridge (`AppDelegate`) for the tray icon — hosts SwiftUI views; needed for right-click (`MenuBarExtra` exposes only left-click)
- `sysctl` / `ps aux` for process enumeration
- Xcode project, no backend

### Build

Open `Pidly.xcodeproj` in Xcode, ⌘R to run. App appears in menu bar only (`LSUIElement = YES`). Run the test suite from the command line with `make test`. Build a Release app: `make build-release` (ad-hoc signed, output: `build/Release/Pidly.app`). Install to `/Applications`: `make install`. Package a DMG: `make dmg` (output: `build/Pidly.dmg`).

### Conventions

- All scan + classification logic lives in the `PidlyCore` package (`ScanCore.swift`, `ProcessItem.swift`, `PortRegistry.swift`) — the shared core the app links; do not scatter it. App-side `ScanEngine.swift` owns only the timer / persistence / notification lifecycle and calls `ScanCore.enumerate(...)`.
- Docker plumbing mirrors the same split: pure `docker ps` parsing + the `Container` model live in `PidlyCore` (`DockerCore.swift`, `Container.swift`); the app-side `DockerService.swift` owns the impure `docker` CLI access (path resolution, shell-out, `listContainers()`). `KillService`'s docker-stop path delegates to `DockerService` — keep all `docker` invocations there, don't scatter.
- Two classification buckets only: `safe` and `needsReview` — never kill without explicit user action
- Port registry lives in `PortRegistry.swift` (in the `PidlyCore` package); keep in sync with CLAUDE.md global port table when ports are added
- Kill flow is always SIGTERM first, SIGKILL fallback after 2 s — never skip the grace period
