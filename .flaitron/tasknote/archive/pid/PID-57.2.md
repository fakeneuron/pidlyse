---
title: kill-core-extraction
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-57, PID-57.1, PID-57.3, PID-35.3]
---

# PID-57.2 | kill-core-extraction

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-57]] [[PID-57.1]] [[PID-57.3]] [[PID-35.3]]

## 🎯 Goal

Move the kill path (synchronous SIGTERM → 2 s grace → SIGKILL with PID-35.3 identity guards, plus docker-stop routing) into the `PidlyseCore` package so the upcoming CLI target ([[PID-57.3]]) can share it; the app keeps thin async wrappers and behavior is unchanged.

## ✅ Acceptance

- [ ] `PidlyseCore` exposes a synchronous kill path (SIGTERM → 2 s grace → SIGKILL) callable without a run loop, preserving the PID-35.3 identity guards (`shouldSendSIGTERM` / `shouldEscalateToSIGKILL`) and the EPERM / `notKilled` outcome semantics byte-for-byte in behavior
- [ ] Docker-stop routing (container-owner lookup → `docker stop` → POSIX fallback) lives in the core kill path; the impure docker CLI layer (`DockerService`: trusted-path resolution, `run`, `listContainers`, `containerOwners`) moves into `PidlyseCore`
- [ ] App keeps thin async wrappers with unchanged call shapes — `KillService.kill(_:containerOwners:onComplete:)` (single + bulk, main-queue callbacks) and the SwiftUI-facing `DockerService.list/stats/restart/stop/remove` — zero edits required in `MenuBarView` / `ContainersView` / `ScanEngine` call sites beyond type aliasing
- [ ] Existing `KillServiceTests` + `DockerServiceTests` migrate to target the core symbols; `make test` passes
- [ ] CLAUDE.md convention notes updated (kill-flow + docker-plumbing bullets reflect the new core/app split); `Package.swift` header comment stops citing the abandoned PID-EPIC-27 helper as the second consumer

## 🧩 Subtasks

- [ ] Create `Packages/PidlyseCore/Sources/PidlyseCore/KillCore.swift`: move `gracePeriod`, `KillOutcome`, `startTime(of:)`, both identity guards, and a synchronous `kill(pid:expected:)` (Thread.sleep grace) + `kill(item:containerOwners:)` with docker-stop routing — all `public`
- [ ] Move the impure sync half of `DockerService` (cliPath / trust checks / isInstalled / run / listContainers / containerOwners) into `Packages/PidlyseCore/Sources/PidlyseCore/DockerService.swift`, symbols `public`
- [ ] Rewrite app-side `Pidlyse/DockerService.swift` as `DockerService+Async.swift` — an extension holding the five async main-queue-delivery wrappers (`list`, `stats`, `restart`, `stop`, `remove`, `performThenRefresh`); update the pbxproj file reference path
- [ ] Rewrite `Pidlyse/KillService.swift` as a thin async wrapper over `KillCore` (same two `kill` entry points, `KillOutcome`/`ProcStartTime` typealiases, `startTime` forwarding for `ScanEngine`)
- [ ] Migrate `KillServiceTests` guard/startTime tests to `KillCore`; keep `DockerServiceTests.isTrustedOwnership` tests pointing at the (now-core) `DockerService`
- [ ] Update `Package.swift` header comment (consumer = cli-companion, not the abandoned EPIC-27 helper)
- [ ] Update CLAUDE.md conventions (kill-core split + DockerService location)
- [ ] `make test` green; `make build-release` compiles

## 🔗 Related

- [[PID-EPIC-57]] — parent epic: cli-companion terminal binary sharing PidlyseCore
- [[PID-57.1]] — epic discovery that scoped this extraction as the first implementation child
- [[PID-57.3]] — follow-up: the `pidlyse` SPM executable target that consumes the extracted kill core
- [[PID-35.3]] — kill-path hardening (start-time identity guards) that must be preserved verbatim

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Filed today by [[PID-57.1]] Discovery with operator-resolved scoping (extraction-first split); nothing has moved kill logic into core since — `KillService.swift` and `DockerService.swift` are still app-target at HEAD. The extraction is the live prerequisite for [[PID-57.3]].

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source survey (files read):** `Pidlyse/KillService.swift` (169 LOC — two public `kill` entry points with main-queue callbacks; pure guards `shouldSendSIGTERM`/`shouldEscalateToSIGKILL`; `sysctl` `startTime(of:)`; `killPosix` sends SIGTERM synchronously on the caller thread then `asyncAfter(2s)` for the SIGKILL check; `dockerStopByName` delegates to `DockerService.run`), `Pidlyse/DockerService.swift` (150 LOC — sync impure half: `cliPath`/`isTrustedExecutable`/`isTrustedOwnership`/`isInstalled`/`run`/`listContainers`/`containerOwners`; async SwiftUI-facing half: `list`/`stats`/`restart`/`stop`/`remove`/`performThenRefresh`), core `Shell.swift` + `Package.swift`, call sites (`MenuBarView` ×3 `KillService.kill`; `ScanEngine` uses `DockerService.containerOwners()`, `KillService.startTime` as `startTimeProvider`, and `KillService.KillOutcome` in `recordCleaned` signatures; `ContainersView` uses only the async docker wrappers), tests (`KillServiceTests` — pure guards + live-sysctl; `DockerServiceTests` — `isTrustedOwnership` policy; both in `PidlyseTests`, which already does `import PidlyseCore`).

**Design shape (extends existing splits):**
- New core `KillCore.swift` mirrors the `ScanEngine`/`ScanCore` and `DockerService`/`DockerCore` naming: pure guards + sysctl reader + **synchronous blocking** kill (`Thread.sleep` grace instead of `asyncAfter`) usable by the run-loop-free CLI ([[PID-57.1]] explicitly scoped "a synchronous call shape usable without a run loop").
- Core `DockerService` keeps its name and moves file-wise into the package (PLAN line says the impure docker CLI layer moves); the five async main-queue wrappers stay app-side as an `extension DockerService` in `Pidlyse/DockerService+Async.swift` — call sites in `ContainersView` are byte-identical. Core stays run-loop-free.
- App `KillService` becomes a thin wrapper: dispatches each item to `DispatchQueue.global()`, calls the sync core kill, delivers outcomes on main. Timing note: today SIGTERM for non-docker items fires synchronously on the caller (main) thread before `kill()` returns; after the wrap it fires microseconds later off-main. No caller observes the difference (all react via `onComplete`) — logged as the one deliberate micro-deviation inside "behavior unchanged".
- `KillOutcome` moves to core (CLI + clean-log both need it); `KillService` keeps `typealias KillOutcome = KillCore.KillOutcome` + `startTime` forwarding so `ScanEngine`'s signatures compile unchanged (precedent: the PID-35.3 `ProcStartTime` typealias used exactly this trick).
- pbxproj is hand-maintained (objectVersion 56, `AAAA…` ids): only edit needed is the `DockerService.swift` → `DockerService+Async.swift` file-reference rename; `KillService.swift` keeps its path; SPM auto-includes new core files.

**Archive skim (load-bearing):** [[PID-57.1]] (yesterday's full surface inventory — reused; scoping table resolves extraction-first, full parity, shared clean-log, zero deps), [[PID-35.3]] (identity guards + F2 docker-binary trust check — preserve behavior byte-for-byte; residual-risk comment on `/usr/local/bin` group-writability must move with the code), [[PID-28.2]] (docker-service extraction precedent — established "app-side owns impure CLI" convention this task deliberately revises), [[PID-27.2]] (created PidlyseCore for a second consumer; cross-module API already `public`), [[PID-042]] (Shell consolidation — core `Shell.run` is the only spawn primitive; keep it that way), [[PID-53.2]] (`KillOutcome` semantics: only `.confirmed` logged — moving the enum must not change case behavior), [[PID-18.3]] (SIGKILL-escalation guard origin).

**Drift check:** PLAN line's cited concepts all match HEAD — kill path is SIGTERM → 2 s → SIGKILL in app-side `KillService.swift`, PID-35.3 guards present, docker-stop routing via `containerOwners`, `DockerService` app-side. No drift.

**No clarifications needed.** Explicit assumptions: (1) `KillCore` is the new core type name, mirroring `ScanCore`/`DockerCore`; (2) the five SwiftUI-facing async docker wrappers stay app-side (core stays run-loop-free — "App keeps thin async wrappers" per PLAN line); (3) tests stay in `PidlyseTests` (already imports `PidlyseCore`; no new SPM test target — `make test` remains the single suite); (4) the micro-deviation in SIGTERM dispatch timing noted above counts as "behavior unchanged".

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

Extended the established core/app splits (`ScanCore`/`ScanEngine`, `DockerCore`/`DockerService`, `CleanLog`/`CleanLogStore`) — no new shape invented:

- **New `Packages/PidlyseCore/Sources/PidlyseCore/KillCore.swift`** (~135 LOC): `gracePeriod`, `KillOutcome`, `startTime(of:)` sysctl reader, both PID-35.3 identity guards, and the synchronous `kill(_:containerOwners:)` — POSIX path uses `Thread.sleep(gracePeriod)` instead of `asyncAfter`, docker-stop routing via the (now-core) `DockerService.run(["stop", name])`. All comments (PID-53.2 outcome semantics, PID-35.3 guard rationale, EPERM notes) moved with the code.
- **New core `DockerService.swift`**: the impure sync half moved verbatim from the app target (`cliPath` trusted-path resolution incl. the F2 residual-risk comment, `isTrustedExecutable`/`isTrustedOwnership`, `isInstalled`, `run`, `listContainers`, `containerOwners`), symbols `public`.
- **App `Pidlyse/DockerService.swift` → `DockerService+Async.swift`**: now an `extension DockerService` holding only the five SwiftUI-facing async wrappers (`list`/`stats`/`restart`/`stop`/`remove` + private `performThenRefresh`) — bodies unchanged, so `ContainersView` call sites are byte-identical. Core stays run-loop-free. pbxproj file reference renamed (path quoted — `+` needs quoting in OpenStep plist), `plutil -lint` OK.
- **App `KillService.swift` rewritten** (~57 LOC): same two `kill` entry points; each dispatches the blocking `KillCore.kill` to `DispatchQueue.global()` and delivers on main. `KillOutcome`/`ProcStartTime` re-exported as typealiases so `ScanEngine.recordCleaned` signatures compile unchanged. Bulk variant keeps the DispatchGroup + main-queue-single-threaded-dict shape.
- **Call-site edits**: `ScanEngine` `startTimeProvider:` now points at `KillCore.startTime` (1 line); `CleanLogStore` header's split example updated (`DockerService ↔ DockerCore` → `KillService ↔ KillCore`); `ProcessItem.swift`'s `ProcStartTime` doc no longer claims the sysctl reader is app-side; `Package.swift` header now cites the cli-companion (PID-EPIC-57) instead of the abandoned EPIC-27 helper.
- **Tests migrated in place** (`PidlyseTests/ScanEngineTests.swift`): `KillServiceTests` → `KillCoreTests` targeting `KillCore.*` + bare `ProcStartTime`; `DockerServiceTests` unchanged (name and API survive the move).
- **CLAUDE.md**: docker-plumbing and kill-flow convention bullets rewritten for the new split.
- Logged micro-deviation (accepted in Discovery): SIGTERM for non-docker items now fires off-main microseconds after the click instead of synchronously on the caller thread; all callers react via `onComplete`, so nothing observes the difference.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (N/A — no UI change; `MenuBarView`/`ContainersView` untouched)

**Testing Notes:** `swift build --package-path Packages/PidlyseCore` — clean (verifies the package compiles standalone, the CLI's consumption mode). `make test` — **202 tests, 0 failures** (includes the migrated `KillCoreTests` decision matrices + live-sysctl tests and `DockerServiceTests` trust policy). `make build-release` — BUILD SUCCEEDED. No SwiftLint in this repo; compiler is the type-checker.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Extracted the kill path into `PidlyseCore` for the cli-companion epic: new `KillCore.swift` carries the synchronous SIGTERM → 2 s grace → SIGKILL path (identity guards, EPERM → `.notKilled`, docker-stop routing — comments and behavior preserved; grace now `Thread.sleep`, usable without a run loop), and the impure `DockerService` sync layer moved into the package. App keeps thin wrappers only: `KillService.swift` (queue hops + `KillOutcome`/`ProcStartTime` typealiases) and `DockerService+Async.swift` (the five SwiftUI-facing wrappers) — `MenuBarView`/`ContainersView` call sites untouched, `ScanEngine` needed one line (`startTimeProvider: KillCore.startTime`). Tests migrated (`KillServiceTests` → `KillCoreTests`); 202/202 pass; standalone `swift build` of the package and `make build-release` both green. Docs updated: CLAUDE.md conventions, SPEC.md structure/kill-flow, README security links, `Package.swift` header (consumer = PID-EPIC-57, not the abandoned EPIC-27 helper).

Doc-drift sweep: `README.md` **updated** (security-section source links → core `DockerService.swift` + `KillCore.swift`) · `AGENTS.md` no change (no kill/docker references) · `CLAUDE.md` **updated** (docker-plumbing + kill-flow convention bullets rewritten for the core/app split) · `SPEC.md` **updated** (structure listing gains core `KillCore.swift`/`DockerService.swift`, app rows renamed; `sysctl` note; Kill Flow step 2; docker feature note) · `.flowtron/PLAN.md` updated in-task (.2 stub flip).

**Archived:** 2026-07-02
