# CLAUDE.md — Pidlyse

Native macOS menu bar app. Full design in [`SPEC.md`](SPEC.md).

### Tech stack

- Swift + SwiftUI, macOS 14+, Apple Silicon target
- AppKit `NSStatusItem` bridge (`AppDelegate`) for the tray icon — hosts SwiftUI views; needed for right-click (`MenuBarExtra` exposes only left-click)
- `sysctl` / `ps aux` for process enumeration
- Xcode project, no backend

### Build

Open `Pidlyse.xcodeproj` in Xcode, ⌘R to run. App appears in menu bar only (`LSUIElement = YES`). Run the test suite from the command line with `make test`. Build a Release app: `make build-release` (ad-hoc signed, output: `build/Release/Pidlyse.app`). Install to `/Applications`: `make install`. Package a DMG: `make dmg` (output: `build/Pidlyse.dmg`). Build the `pidlyse` terminal companion: `make build-cli` (output: `Packages/PidlyseCore/.build/release/pidlyse`); install to `/usr/local/bin`: `make install-cli`.

### Conventions

- All scan + classification logic lives in the `PidlyseCore` package (`ScanCore.swift`, `ProcessItem.swift`, `PortRegistry.swift`, `CwdResolver.swift`, `AncestryResolver.swift`, `OpenFilesResolver.swift`, `CustomRule.swift`, `IgnoreRule.swift`, `ScanHistory.swift`) — the shared core the app links; do not scatter it. App-side `ScanEngine.swift` owns only the timer / persistence / notification lifecycle and calls `ScanCore.enumerate(...)`. The pure rolling-window CPU cache (`ScanHistory.swift`, PID-55.2) mirrors the same split: `ScanEngine` holds the single mutable instance, feeds it each scan, and exposes the "sustained low CPU" query (signal-only — never touches the kill bar). The idle-dev-server consumer (PID-55.3) stays on the same split: the pure dev-mode-flag parse (`ScanCore.hasDevModeFlag`) lives in the core, `ScanEngine.isIdleDevServer` folds it with the sustained-low-CPU query + age + no-TTY, and `MenuBarView` surfaces the verdict as a single inspector reasoning line — still signal-only.
- All subprocess spawning goes through the shared `Shell.run(_:_:)` primitive in `PidlyseCore` (`Shell.swift`) — one `Process`/`Pipe`/stdout-drain body for `ps`, `lsof`, and `docker`; do not hand-roll a new `Process()`. Callers own the *what* (which binary/args, how to parse); `Shell` owns the *how*.
- Docker plumbing lives in `PidlyseCore` (moved from app-side by PID-57.2 for the cli-companion): pure `docker ps` parsing + the `Container` model (`DockerCore.swift`, `Container.swift`) and the impure `docker` CLI access (`DockerService.swift` — path resolution, arg-building, `listContainers()`), which delegates the raw spawn to `Shell.run`. The app-side `DockerService+Async.swift` extension owns only the SwiftUI-facing async wrappers (background-queue shell-out, main-queue delivery). `KillCore`'s docker-stop path delegates to `DockerService` — keep all `docker` invocations there, don't scatter.
- Clean-log plumbing mirrors the same split (PID-53.2): the pure `CleanEvent` model + `CleanLog` aggregation (rolling-window stats + count-cap retention) live in `PidlyseCore` (`CleanEvent.swift`, `CleanLog.swift`), as does the shared disk I/O for `~/Library/Application Support/Pidlyse/clean-log.json` (`CleanLogFile.swift` — moved to core by PID-57.3 when the cli-companion became the second writer; one encoder/decoder so the formats can't drift). The app-side `CleanLogStore.swift` owns only the `@Published` binding + main-thread lifecycle and delegates load/save to `CleanLogFile`; `ScanEngine` owns the kill-hook wiring (`recordCleaned`). `KillService.kill` reports a per-item `KillOutcome`; only `.confirmed` deaths are logged (privacy-first — no command line is persisted).
- Two classification buckets only: `safe` and `needsReview` — never kill without explicit user action
- Port registry lives in `PortRegistry.swift` (in the `PidlyseCore` package); keep in sync with CLAUDE.md global port table when ports are added
- Kill flow is always SIGTERM first, SIGKILL fallback after 2 s — never skip the grace period. The kill path lives in `PidlyseCore` (`KillCore.swift`, PID-57.2): a synchronous, run-loop-free call (identity guards from PID-35.3, docker-stop routing, EPERM → `.notKilled`) shared with the cli-companion; app-side `KillService.swift` is only the thin async wrapper (background-queue call, main-queue callbacks).
- The `pidlyse` terminal companion (PID-57.3) is an `.executableTarget` (`Sources/PidlyseCLI/main.swift`) in the same package: a thin impure shell that reads the app's defaults domain (`com.fakeneuron.pidlyse`) for full rule parity and replicates `ScanEngine.scan()`'s pipeline order — keep the two pipelines in step when scan inputs change. Its pure command grammar + table formatting live in core (`CLICore.swift`, tested from `PidlyseTests`); hand-rolled arg parsing, zero external deps. `clean` sweeps exactly the app's "Clean all" set (safe minus protected); `kill <pid>` accepts only scanned candidates; never kills without an explicit invocation.
