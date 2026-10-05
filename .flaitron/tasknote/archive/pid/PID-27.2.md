---
title: shared-scan-core
status: in-progress
tags: []
created: 2026-06-26
related-tasks: [PID-EPIC-27, PID-27.1, PID-27.3]
---

# PID-27.2 | shared-scan-core

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-27]] [[PID-27.1]] [[PID-27.3]]

## 🎯 Goal

Extract the pure scan core (`enumerate` + classification, `ProcessItem`, `PortRegistry`, `ps`/`lsof` shell-outs) into a shared target that both the app and the future LaunchAgent helper can link — no behavior change, existing tests stay green.

## ✅ Acceptance

- [ ] A shared target (`PidlyCore`) exists in the Xcode project; the app links it.
- [ ] Pure scan core moved into `PidlyCore`: `ProcessItem`/`ProcessKind`/`RiskTier`/`Bucket`, `PortRegistry`, and the static scan/parse/classify functions (`enumerate`, `makeItem`, `parsePSLine`, `parseElapsed`, `detectKind`, `riskTier`, `runPS`).
- [ ] The app-only `ScanEngine` `ObservableObject` (Timer / `@Published` / `UserDefaults` / notifications) stays in the `Pidly` app target and calls into the shared core.
- [ ] Cross-module API surface marked `public` as needed; no app behavior change.
- [ ] `make test` is green — all existing `ScanEngineTests` + `KillServiceTests` pass (references updated to the new module/type only where unavoidable).
- [ ] `make build-release` succeeds (app still links + runs).

## 🧩 Subtasks

- [ ] (pending clarifying answer) Create the shared target of the chosen kind in `Pidly.xcodeproj`.
- [ ] Move `ProcessItem.swift` + `PortRegistry.swift` into the core target; add `public` to the consumed API.
- [ ] Split `ScanEngine.swift`: extract the static pure functions into a `ScanCore` namespace in the core target; leave the `ObservableObject` wrapper in the app calling `ScanCore.enumerate(...)`.
- [ ] Wire the app target + test target to link/import the core; `import PidlyCore` at call sites.
- [ ] Update test references (`ScanEngine.X` → `ScanCore.X` where moved) — keep assertions unchanged.
- [ ] `make test` green; `make build-release` green.

## 🔗 Related

- [[PID-EPIC-27]] — parent epic (xpc-background-scan / launchd background scanning)
- [[PID-27.1]] — Discovery: established launchd-LaunchAgent mechanism, read-only helper, pure-core-is-extractable finding
- [[PID-27.3]] — helper-target: the consumer that links this shared core next

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** First implementation child of PID-EPIC-27. The shared core is the prerequisite both the helper (.3) and downstream children link against. Discovery (.1) already confirmed the pure core is cleanly extractable; nothing has shifted.

- [x] Read relevant source files — `ScanEngine.swift`, `ProcessItem.swift`, `PortRegistry.swift`, `PidlyTests/ScanEngineTests.swift`, `Pidly.xcodeproj/project.pbxproj`.

- [x] **Archive skim** — PID-27.1 (direct predecessor; launchd mechanism + read-only helper + "pure core already isolated & injectable"). PID-16.2 shellout-helper introduced the per-file `runShell` (duplicated in `ScanEngine` + `PortRegistry`). No prior tasknote touched Xcode target/module structure — this is the first multi-target split.

- [x] **Drift check** — PLAN cites `enumerate`, `ProcessItem`, `PortRegistry`, classification, `ps`/`lsof` shell-outs. All present and matching current code (`ScanEngine.enumerate:156`, `runPS:306`, `PortRegistry.runLSOF:123`, `ProcessItem` struct). No drift.

- [x] Asked clarifying questions — **shared-target kind** surfaced via AskUserQuestion. **Decision: local Swift Package** (`Packages/PidlyCore`), library product, static-linked into app + helper → zero added signing/notarization surface for the unsandboxed Developer-ID helper (.6).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Extraction boundary

| File | Disposition |
|---|---|
| `ProcessItem.swift` | Fully pure (`ProcessKind`, `RiskTier`, `Bucket`, `ProcessItem`) → moves wholesale to core. |
| `PortRegistry.swift` | Pure logic + owns its own `lsof` shell-out + `ports.json` file IO → moves wholesale to core. |
| `ScanEngine.swift` | **Splits.** Static scan/parse/classify half (`enumerate`, `makeItem`, `parsePSLine`, `parseElapsed`, `detectKind`, `riskTier`, `runShell`, `runPS`) → core. `ObservableObject` half (`@Published`, `Timer`, `UserDefaults`, `UNUserNotificationCenter`) → stays in app. |

### Module-boundary collision (load-bearing)

- Tests use `@testable import Pidly` and reference `ScanEngine.parsePSLine` / `.enumerate` / `.detectKind` / `.riskTier` / `.makeItem`, plus `ProcessItem.isTTYAttached` and `PortRegistry.*`.
- A Swift type cannot span modules, and the app already has an `ObservableObject` named `ScanEngine`. So the moved static functions need a **new home type** in the core — planned name `ScanCore` (enum namespace). The app's `ScanEngine` keeps its name and calls `ScanCore.enumerate(...)`.
- Cross-module consumption by the app + future helper means the consumed core API must be `public` (within-module `@testable` access alone won't serve the non-test consumers).
- Test references to the moved statics shift `ScanEngine.X` → `ScanCore.X`; assertions stay byte-identical. `KillServiceTests` is unaffected (`KillService` stays in the app). This keeps "tests stay green" honest while honoring the module split.

### Signal: rpath already framework-ready

`LD_RUNPATH_SEARCH_PATHS` already includes `@executable_path/../Frameworks` — a framework product would embed cleanly. A local Swift Package / static library links in with no embed/signing surface (relevant to the unsandboxed Developer-ID helper story in .6).

### Open fork (clarifying question)

Target kind: **local Swift Package** vs **framework** vs **static library**. Real downstream impact on helper signing/notarization (.6) and the `make test` / CI invocation. Surfacing to the user.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no prior multi-target split in this repo (confirmed via .1 archive skim). The existing `enumerate`/`PortRegistry` were already authored as injectable, side-effect-light statics (PID-16.x) — the package just relocates that established shape behind a `public` boundary; no new pattern invented. `SMAppService.mainApp` precedent (SettingsView) is the .3/.4 consumer story, out of scope here.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — no new behavior; existing tests retargeted to the moved namespace, assertions unchanged.

**Implementation Notes:**

- Created `Packages/PidlyCore` (local SwiftPM, `swift-tools-version:5.9` → Swift 5 mode, matching the app's `SWIFT_VERSION = 5.0` to avoid Swift 6 concurrency behavior change). Library product `PidlyCore`, `.macOS(.v14)`.
- Moved `ProcessItem.swift` + `PortRegistry.swift` into the package wholesale; added `public` to the cross-module surface (types, memberwise `init`, computed vars, `registeredPorts`/`mergedPorts`/`listeningPIDs`/`parsePIDAndPort`). Kept `effectivePorts`/`userPortsFileURL`/`loadUserPortsJSON`/`runLSOF`/`runShell` internal (same-module consumers only).
- Split `ScanEngine.swift`: the static pure half became `public enum ScanCore` in the package (`enumerate`/`makeItem`/`parsePSLine`/`parseElapsed`/`detectKind`/`riskTier`/`runPS` + `defaultElapsedThreshold`). The app's `ScanEngine` `ObservableObject` stayed in `Pidly` (`Timer`/`@Published`/`UserDefaults`/`UNUserNotificationCenter`), now `import PidlyCore` and calls `ScanCore.enumerate(...)`. `defaultScanInterval` (timer-domain) stayed on `ScanEngine`.
- A type can't span modules and the app already owns a `ScanEngine` `ObservableObject`, so the moved statics needed a new home type → `ScanCore`. Test refs `ScanEngine.X` → `ScanCore.X` (46 call sites, assertions byte-identical). `KillService`/`ScanEngine` stay app-side → test file keeps `@testable import Pidly` alongside `import PidlyCore`.
- Added `import PidlyCore` to `KillService.swift` + `MenuBarView.swift` (consume `ProcessItem`/`ProcessKind`/`RiskTier`/`Bucket`). `SettingsView`/`AppDelegate`/`PidlyApp` only touch the app-side `ScanEngine` — untouched.
- pbxproj: added `XCLocalSwiftPackageReference` (`Packages/PidlyCore`) + project `packageReferences`; one `XCSwiftPackageProductDependency` per target (app + test) wired into each `packageProductDependencies` + Frameworks phase; removed the two moved files from the app target's file refs / group / Sources phase. Hand-edited with the repo's deterministic `AAAA…B14x` ID scheme.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **59 tests, 0 failures** (all `ScanEngineTests` + `KillServiceTests`). `PidlyCore` resolves from both app + test targets.

- [x] Ran lint/type-check on changed code — `make build-release` **BUILD SUCCEEDED** (Swift compiler is the type-checker per README; ad-hoc signed Release links the static package). Verified the app bundle has **no `Frameworks/` dir** (fully static-linked) and 387 `PidlyCore` symbols inline in the app binary → zero added dylib/signing surface for .6.

- [x] (frontend) Visual confirmation — **N/A**: pure module extraction, no UI or behavior change. Test parity + clean Release build prove the app behaves identically; no 👁️ ask warranted.

**Testing Notes:**

Build emitted `note: Removed stale file … ProcessItem.o / PortRegistry.stringsdata` — confirms the old app-target objects were dropped, not duplicated. No warnings introduced.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (generic SPEC pointer; extraction is internal, not a shipped feature). `AGENTS.md`: no change (only flowtron boilerplate, no source-structure refs). `CLAUDE.md`: **updated** — Conventions bullets now point scan/classification + port registry at the `PidlyCore` package and scope `ScanEngine.swift` to the app-side lifecycle. `.flowtron/PLAN.md`: `.2` line flipped in place. (SPEC.md Non-Goals/Tech-Stack updates remain owned by .6 per the .1 plan.)

- [x] Closed — PLAN.md `.2` line flipped to stub form `Completed 2026-06-26.` (in place under the still-open `PID-EPIC-27`, matching the PID-20.x cohort convention) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Extracted the pure scan core into a new local Swift Package `PidlyCore` that the app links statically (and the future LaunchAgent helper will too). `ProcessItem` + `PortRegistry` moved wholesale; `ScanEngine`'s static scan/parse/classify half became `ScanCore` in the package, while its `ObservableObject` timer/persistence/notification half stayed in the `Pidly` app and now calls `ScanCore.enumerate(...)`. Cross-module API marked `public`; `KillService`/`MenuBarView` gained `import PidlyCore`; tests retargeted `ScanEngine.X` → `ScanCore.X` (assertions unchanged). No behavior change: `make test` 59/59 green, `make build-release` succeeds, and the app bundle has no embedded framework (387 `PidlyCore` symbols inline) → zero added signing surface for the unsandboxed helper (.6). Architecture decision (target kind = local Swift Package) resolved via AskUserQuestion. Files: `Packages/PidlyCore/{Package.swift, Sources/PidlyCore/{ProcessItem,PortRegistry,ScanCore}.swift}` (new); `Pidly/ScanEngine.swift` (rewritten, −157 static LOC); `Pidly/{KillService,MenuBarView}.swift`, `PidlyTests/ScanEngineTests.swift`, `Pidly.xcodeproj/project.pbxproj`, `CLAUDE.md` (edited); `Pidly/{ProcessItem,PortRegistry}.swift` (deleted).

**Archived:** 2026-06-26
