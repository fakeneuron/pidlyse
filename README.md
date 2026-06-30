# Pidlyse

Native macOS menu bar app that spots stray dev processes and clears them in one click.

Sits beside the clock. Periodically scans for known process junk — orphaned test runners, idle servers, stale playwright-mcp instances, zombie Chrome helpers — and badges the icon when it finds them. Click to expand: a categorised list with per-row CPU%, RAM, and age; risk-tier color dots; kill buttons for obvious strays; and a "Needs review" section for anything that warrants a second look.

## Features

- **12 process kinds** detected: `pytest`, `vitest`, `vite`, `jest`, `npm`, `docker`, `uvicorn`, `playwright`, `playwright-mcp`, `Chrome (playwright-mcp)`, `bun`, `node`
- **Per-row signals** — the owning project (the git repo / working directory the process runs in, e.g. `bidviz` or `bidviz/frontend`, shown as the row label so a bare `npm`/`node` is identifiable; full path on hover), CPU%, RAM, age, risk-tier color dot (green / orange / red), expandable "why is this here?" detail (tty status, orphan flag, age criteria, plus provenance hints: the registered port it listens on, its scanned parent process, and the Docker container that owns it)
- **Two-section layout** — *Safe to clean* (easy-tier orphaned/old/no-tty strays, with a "~X MB reclaimable" footprint total in the section header) and *Needs review* (ambiguous processes tied to real dev infra)
- **"Clean all"** sweeps the safe section in one click; per-row kill button for surgical cleanup
- **Right-click a row** for quick actions — copy the PID, the full command line, or a ready-to-paste `kill <pid>`, and reveal the process's working directory in Finder (clipboard / Finder only, no extra shell-out)
- **Quick filter** — a search field on the Processes tab narrows the list live by command, owning project, or listening port; session-scoped, clears when the popover closes
- **Session dismiss** — hide a process until restart without killing it (↺ rescan restores all dismissed items)
- **Docker containers tab** — a Processes / Containers segmented toggle in the popover; the Containers tab lists running containers (name, image, status, ports) with per-row **stop** and **stop + remove** buttons, and a clear empty state when Docker isn't installed
- **Kill flow**: SIGTERM first, SIGKILL fallback after 2 s — always explicit, never automatic
- **Settings**: scan interval (default 2 min), stale-process threshold (default 30 min), ignored command substrings, per-kind scan toggles (switch off whole process categories), launch at login, notification alerts (opt-in)

## Requirements

- macOS 14+
- Xcode 15+
- Apple Silicon (M-series) target

## Build & Run

Open `Pidlyse.xcodeproj` in Xcode and run (⌘R). The app lives in the menu bar — no Dock icon (`LSUIElement = YES`). Left-click the icon to open the popover; right-click (or two-finger tap) for a quick Quit menu.

Run the test suite from the command line with `make test`. The same suite runs automatically on every push to `main` via GitHub Actions (`.github/workflows/test.yml`).

Build a Release `.app` with ad-hoc signing: `make build-release` (output: `build/Release/Pidlyse.app`). Copy it to `/Applications` with `make install`. Package a distributable DMG (drag-install, with `/Applications` symlink): `make dmg` (output: `build/Pidlyse.dmg`). Push a `v*` tag to trigger the release workflow (`.github/workflows/release.yml`), which builds the Release app, packages the DMG, and attaches it to a GitHub Release automatically.

## Menu Bar States

| State | Icon | Badge |
|-------|------|-------|
| Clean | ghost outline | none |
| Safe kills available | filled icon | red count |
| Review items only | filled icon | yellow count |
| Scanning | spinner overlay | — |

The icon pulses once when a new stray appears (suppressed under Reduce Motion).

## Security — what Pidlyse can (and can't) touch

Pidlyse sends real kill signals, so its trust story matters. The source is public precisely so you can verify all of the below:

- **Runs as you, never root.** Kills use `Darwin.kill(pid, …)` and only succeed against your own processes; anything owned by another user (e.g. the root Docker daemon) returns `EPERM` and is left untouched. Pidlyse never escalates, never asks for an admin password.
- **No network, no telemetry, no analytics.** Pidlyse makes zero network connections. It reads local process state and writes nothing back out.
- **Minimal disk footprint.** Reads `~/Library/Application Support/Pidlyse/ports.json` if the user-created file exists (the app never writes it); its only disk write is the settings plist via `UserDefaults` (`~/Library/Preferences/com.fakeneuron.pidlyse.plist`).
- **Launch at login is opt-in.** Enabling it registers a login item via `SMAppService`. The registration persists until the app is removed or you disable the option in Settings.
- **Never auto-kills.** Every kill is an explicit click; the flow is always SIGTERM → 2 s grace → SIGKILL, with a process-start-time PID-reuse guard that refuses to send *either* signal if the PID was recycled between the scan and your click. Processes tied to a registered port are demoted to *Needs review* and excluded from "Clean all".
- **Narrow, injection-free shell-out surface.** Pidlyse shells out to exactly three pinned, absolute-path binaries — `/bin/ps`, `/usr/sbin/lsof`, and `docker` (`/usr/local/bin/docker` or `/opt/homebrew/bin/docker`) — always with arguments passed as an array, never via a shell string. There is no `sh -c`, no `$PATH` lookup of the binary, and no user input interpolated into a command. The resolved `docker` binary is also verified before exec — owned by root or you, and not world-writable — so a trojan `docker` planted in a world-writable or foreign-owned location won't run on a docker-kill. (Residual: `/usr/local/bin` is group-writable by `admin` on Intel by design, so a same-group attacker could still replace it there; closing that would silently break Docker detection on those machines, so it's left as a documented gap.) Read it for yourself in [`ScanCore.swift`](Packages/PidlyseCore/Sources/PidlyseCore/ScanCore.swift), [`PortRegistry.swift`](Packages/PidlyseCore/Sources/PidlyseCore/PortRegistry.swift), [`DockerService.swift`](Pidlyse/DockerService.swift), and [`KillService.swift`](Pidlyse/KillService.swift).

### Verifying the download

Release DMGs are **ad-hoc signed, not yet Apple-notarized**, so on first launch macOS Gatekeeper shows "Apple could not verify…". To open it: **right-click the app → Open** (once), or clear the quarantine flag with `xattr -d com.apple.quarantine /Applications/Pidlyse.app`. Because the source is public, you can also just build it yourself (`make build-release`). Each release publishes a **SHA-256 checksum** alongside the DMG — verify with `shasum -a 256 Pidlyse.dmg` and compare.

### Uninstalling

Drag Pidlyse.app to the Trash. The only residue is `~/Library/Preferences/com.fakeneuron.pidlyse.plist` (tiny settings file) and, if "Launch at login" was enabled, a login-item registration. Remove the prefs manually with `rm ~/Library/Preferences/com.fakeneuron.pidlyse.plist`; the login-item clears on its own once the app is gone.

## Design

See [`SPEC.md`](SPEC.md) for the full technical specification, scan logic, classification rules, and project structure.

## Task Tracking

See [`.flowtron/PLAN.md`](.flowtron/PLAN.md).
