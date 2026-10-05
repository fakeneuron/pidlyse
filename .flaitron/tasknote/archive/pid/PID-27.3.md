---
title: helper-target
status: in-progress
tags: []
created: 2026-06-26
related-tasks: [PID-EPIC-27, PID-27.1, PID-27.2, PID-27.4, PID-27.5]
---

# PID-27.3 | helper-target

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-27]] [[PID-27.1]] [[PID-27.2]]

## 🎯 Goal

Add an unsandboxed LaunchAgent helper executable (its own target) that links the shared `PidlyCore` package, runs exactly one `ScanCore.enumerate(...)` per invocation, and reads scan config (elapsed threshold / ignored names / notify flag) from a shared store — the buildable, runnable foundation the `.4` launchd registration and `.5` notify-and-handoff children build on.

## ✅ Acceptance

- [x] A new `PidlyHelper` executable target (`com.apple.product-type.tool`) exists in `Pidly.xcodeproj` and links the `PidlyCore` package.
- [x] The helper runs exactly one `ScanCore.enumerate(...)` per invocation and exits — no timer, no loop.
- [x] Helper reads scan config (elapsed threshold / ignored names / notify flag) from `~/Library/Application Support/Pidly/config.json` via a shared `HelperConfig` decoder in `PidlyCore`; absent/malformed config falls back to defaults (never blocks a scan).
- [x] Helper does **not** post notifications or write shared state (deferred to `.5`); it reads the notify flag only.
- [x] `HelperConfig` decode is unit-tested (absent → default, malformed → default, partial → default, valid → round-trips).
- [x] `xcodebuild build -scheme PidlyHelper` succeeds; running the built helper prints a candidate count (`Pidly helper: 45 stray candidate(s) found`, exit 0). *(scheme, not `-target`: target-mode doesn't propagate the SwiftPM module search path — see Testing Notes.)*
- [x] `make test` stays green (59 prior + 6 new `HelperConfig` = 65/65); `make build-release` (app) still succeeds.

## 🧩 Subtasks

- [ ] Add `HelperConfig.swift` to `PidlyCore` — `Codable`/`Equatable` struct (threshold/ignored/notify) + pure injectable `decode(_:)` + `load()` reading the Application-Support JSON (mirrors PID-025 `ports.json`).
- [ ] Add `PidlyHelper/main.swift` — top-level entry: `HelperConfig.load()` → `ScanCore.enumerate(...)` → print count → `exit(0)`.
- [ ] Hand-edit `Pidly.xcodeproj/project.pbxproj` (deterministic `B15X` IDs): new tool target `PidlyHelper`, its Sources + Frameworks phases, `PidlyCore` product dependency, Debug/Release configs + list, product ref, source group, project `targets` + `TargetAttributes`.
- [ ] Add `PidlyTests/HelperConfigTests.swift` and wire it into the `PidlyTests` target (file ref, build file, group, Sources phase).
- [ ] Verify: `xcodebuild build -target PidlyHelper` succeeds; run the built binary; `make test` green; `make build-release` green.

## 🔗 Related

- [[PID-EPIC-27]] — parent epic (xpc-background-scan / launchd background scanning)
- [[PID-27.1]] — Discovery: launchd-LaunchAgent mechanism, read-only helper (scan + notify only), unsandboxed posture
- [[PID-27.2]] — shared-scan-core: produced the `PidlyCore` local Swift Package this helper links
- [[PID-27.4]] — launchd-registration: authors the `.plist` + `SMAppService.agent` wiring (consumes this helper)
- [[PID-27.5]] — notify-and-handoff: helper posts notifications + dedupe baseline + app↔helper shared state

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Second implementation child of PID-EPIC-27. The shared core (`.2`) is in place; the helper executable is the prerequisite the launchd registration (`.4`) and notify/handoff (`.5`) children both consume. Nothing has shifted since Discovery.

- [x] Read relevant source files — `ScanEngine.swift` (app-side config keys + lifecycle), `PidlyCore/ScanCore.swift` (`enumerate` entry point), `PidlyCore/PortRegistry.swift` (PID-025 Application-Support JSON pattern), `Package.swift`, `Makefile`, `Pidly.xcodeproj/project.pbxproj` (target/product structure).

- [x] **Archive skim** — PID-27.1 (mechanism + read-only helper + unsandboxed posture), PID-27.2 (PidlyCore package, static-linked, **no embedded framework / zero added signing surface**), PID-025 (Application-Support `ports.json` pattern: injectable pure merge, absent→defaults). No prior tasknote added an Xcode *target* — `.2` added a package *reference*; this is the first new build target.

- [x] **Drift check** — `ScanCore.enumerate(elapsedThreshold:ignoredNames:dismissedPIDs:)` present and public (`ScanCore.swift:20`). App config keys `elapsedThreshold` / `ignoredNames` / `notificationsEnabled` / `scanInterval` persisted to `UserDefaults.standard` (`ScanEngine.swift:18-74`). `PidlyCore` static-links (no `Frameworks/`). No `.entitlements` file (unsandboxed). No drift.

- [x] Asked clarifying questions — 3 architecture forks resolved via AskUserQuestion (all to the recommended option, consistent with the `.1` plan):

  | Fork | Decision |
  |---|---|
  | Helper target kind | **Xcode `tool` target** in `Pidly.xcodeproj` linking `PidlyCore` (idiomatic `SMAppService.agent` path; `.4` embeds it) |
  | Shared store | **Application-Support JSON** `config.json` (mirrors PID-025 `ports.json`; no entitlements → keeps `.2`'s zero added signing surface) |
  | `.3` end-state | **Build + run only** — buildable/runnable helper + config-decoder unit test; embedding → `.4`, notify-post + handoff → `.5` |

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Scope boundary (per `.1` plan)

| Child | Owns |
|---|---|
| **.3 (this)** | The helper *executable target* — links `PidlyCore`, reads config from a shared store, runs one scan, exits. |
| .4 | LaunchAgent `.plist` (`StartInterval`) + embed-in-bundle + `SMAppService.agent` register/unregister/status. |
| .5 | Helper *posts* notifications (UN auth + dedupe baseline) + app↔helper shared config/last-results so they don't double-alert. |

So `.3` reads the *notify flag* but does **not** post notifications (that's `.5`); produces a buildable/runnable executable but does **not** author the plist or embed/register it (that's `.4`).

### Architecture forks (surfacing to user)

1. **Helper target kind** — Xcode executable (command-line `tool`) target in `Pidly.xcodeproj` linking the `PidlyCore` package, vs a SwiftPM `executableTarget` in the package. The `SMAppService.agent` bundled-LaunchAgent pattern (`.4`) expects a Mach-O embedded in the app bundle → Xcode tool target is idiomatic.
2. **Shared-store mechanism** — Application-Support JSON file (`~/Library/Application Support/Pidly/config.json`, mirroring PID-025's `ports.json`: no entitlements, injectable pure decode) vs shared `UserDefaults` App-Group suite (needs a group container/entitlement → adds signing surface `.2` deliberately kept at zero).
3. **`.3` end-state** — buildable + runnable helper that reads config and scans once (embedding into the app bundle deferred to `.4`), confirmed via the helper's own build + a unit test on the config decoder.

**Phase 1→2 exit:** Clarifications resolved to the recommended approach with **no scope deviation** from the `.1` plan (same target kind, same store, same scope line) → **skip 🛠️** per the `default-skip` flavor.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `HelperConfig` mirrors `PortRegistry`'s PID-025 shape exactly: Application-Support file URL builder + pure injectable decode that falls back to a built-in default on absent/malformed input (`PortRegistry.mergedPorts`/`userPortsFileURL`/`loadUserPortsJSON`). The pbxproj target addition follows `.2`'s deterministic `AAAA…B1XX` ID scheme and the existing app/test target structure (one `XCSwiftPackageProductDependency` per target, Sources+Frameworks phases). No new pattern invented.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 6 `HelperConfig` decode tests (the helper's `main.swift` is top-level glue, not unit-tested).

**Implementation Notes:**

- **`Packages/PidlyCore/Sources/PidlyCore/HelperConfig.swift`** (new) — `public struct HelperConfig: Codable, Equatable` (`elapsedThreshold`/`ignoredNames`/`notificationsEnabled`) + `public init` with `ScanCore.defaultElapsedThreshold` default, `static default`, `static fileURL` (`~/Library/Application Support/Pidly/config.json`), pure `decode(_:)`, and `load()`. Decode is all-or-nothing (synthesized `Codable` → missing keys fail → `.default`); the app writes the full object in `.5`/`.6`.
- **`PidlyHelper/main.swift`** (new) — top-level entry: `HelperConfig.load()` → `ScanCore.enumerate(elapsedThreshold:ignoredNames:)` → `print` count → `exit(0)`. No notify (`.5`), no plist/embed (`.4`).
- **`Pidly.xcodeproj/project.pbxproj`** — added tool target `PidlyHelper` (`com.apple.product-type.tool`) hand-edited with the `B15X` ID block: native target (B150) + product ref (B151) + `main.swift` ref (B152) + Sources phase (B154) + Frameworks phase (B155) linking a new `PidlyCore` `XCSwiftPackageProductDependency` (B157) + Debug/Release configs (B159/B15A) + config list (B158) + source group (B15B); registered in project `targets` + `TargetAttributes`. Also wired `HelperConfigTests.swift` (B15C/B15D) into the `PidlyTests` target.
- **`PidlyTests/HelperConfigTests.swift`** (new) — 6 decode tests.
- Xcode auto-generated a shared `PidlyHelper` scheme on first parse (visible in `xcodebuild -list`).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **65 tests, 0 failures** (6 new `HelperConfigTests` + 59 prior `ScanEngineTests`/`KillServiceTests`, all green). Built `PidlyHelper` and ran it live: `Pidly helper: 45 stray candidate(s) found`, exit 0; 185 KB standalone Mach-O (static-linked `PidlyCore`, no embedded framework — preserves `.2`'s zero-signing-surface).

- [x] Ran lint/type-check on changed code — `make build-release` (app) **BUILD SUCCEEDED**; `xcodebuild build -scheme PidlyHelper` **BUILD SUCCEEDED** (Swift compiler is the type-checker per README). No warnings introduced in the new code.

- [x] (frontend) Visual confirmation — **N/A**: no UI surface (a background CLI executable + a model struct). No 👁️ ask warranted.

**Testing Notes:**

- **Build-command gotcha:** `xcodebuild build -target PidlyHelper` fails with `unable to resolve module dependency: 'PidlyCore'` — target-mode doesn't propagate the local SwiftPM module search path. `-scheme PidlyHelper` (or building it as an app dependency, which `.4` will set up via the embed phase) resolves it. The auto-generated scheme is the correct CLI entry point; matches how the Makefile drives the app (`-scheme Pidly`).
- Earlier SourceKit diagnostics (`Cannot find 'ScanCore'`, `No such module 'PidlyCore'`/`XCTest`) were pre-build index lag before the target existed in the build graph — all cleared; the green build is authoritative.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (helper not yet a shipped/registered feature — that's `.4`–`.6`). `AGENTS.md`: no change (flowtron boilerplate only). `CLAUDE.md`: **updated** — Conventions bullet now lists `HelperConfig.swift` in the `PidlyCore` inventory and names the `PidlyHelper` executable + its `-scheme PidlyHelper` build. `.flowtron/PLAN.md`: `.3` line flipped in place under the still-open `PID-EPIC-27` (PID-20.x cohort convention).

- [x] Closed — PLAN.md `.3` line flipped to stub form `Completed 2026-06-26.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added the `PidlyHelper` LaunchAgent helper — a new `com.apple.product-type.tool` Xcode target that statically links the `PidlyCore` package, runs exactly one `ScanCore.enumerate(...)` per invocation, and exits (launchd will drive the cadence in `.4`). A new shared `HelperConfig` struct in `PidlyCore` reads scan config (threshold / ignored names / notify flag) from `~/Library/Application Support/Pidly/config.json`, mirroring PID-025's `ports.json` pattern (pure injectable decode, absent/malformed → defaults, so a missing config never blocks a scan). Per the `.1` boundary, the helper reads the notify flag but does **not** post notifications (→ `.5`) and is not embedded/registered (→ `.4`). The pbxproj target was hand-edited with the `B15X` ID block (target, product, Sources+Frameworks phases, `PidlyCore` dependency, Debug/Release configs, source group, project registration). Verified: `xcodebuild -scheme PidlyHelper` builds; the 185 KB standalone binary runs live (`45 stray candidate(s) found`, exit 0) confirming static linking (no embedded framework → preserves `.2`'s zero added signing surface); `make test` 65/65 green (6 new `HelperConfig` tests); `make build-release` (app) succeeds. Files: `Packages/PidlyCore/Sources/PidlyCore/HelperConfig.swift`, `PidlyHelper/main.swift`, `PidlyTests/HelperConfigTests.swift` (new); `Pidly.xcodeproj/project.pbxproj`, `CLAUDE.md` (edited). Build-command gotcha logged: `-target PidlyHelper` can't resolve the SwiftPM module; use `-scheme PidlyHelper`.

**Archived:** 2026-06-26
