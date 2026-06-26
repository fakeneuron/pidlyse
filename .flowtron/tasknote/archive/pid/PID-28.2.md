---
title: docker-service
status: in-progress
tags: [epic-28, docker]
created: 2026-06-26
due:
related-tasks: [PID-EPIC-28, PID-28.1]
---

# PID-28.2 | docker-service

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-28]] [[PID-28.1]]

## 🎯 Goal

Extract `KillService`'s docker CLI access into a shared app-side `DockerService` that can list running containers, and add a pure, unit-tested `docker ps` parser + typed `Container` model to `PidlyCore`.

## ✅ Acceptance

- [x] `Container` value type lives in `PidlyCore` (id / name / image / status / ports), `Identifiable` for SwiftUI lists
- [x] Pure `DockerCore.parsePS(_:)` parser in `PidlyCore` turns `docker ps --format` output into `[Container]`; tolerant of empty ports + malformed lines
- [x] App-side `DockerService` owns the docker CLI access (path resolution + shell-out) extracted from `KillService`, plus `listContainers()`
- [x] `KillService` docker-stop kill path refactored to call `DockerService` — no duplicated docker plumbing, behavior unchanged
- [x] Unit tests for `DockerCore.parsePS` (happy path, empty ports, blank/malformed lines, multi-container)
- [x] `make test` green (67 tests, 0 failures); app target compiled clean (test build links the app)
- [x] Phase 4 doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs"

## 🧩 Subtasks

- [x] Add `Container.swift` to `PidlyCore` (typed value model, `Identifiable`, `Equatable`)
- [x] Add `DockerCore.swift` to `PidlyCore` (pure `parsePS` / `parseLine`, mirrors `ScanCore`)
- [x] Add `DockerService.swift` to app (`cliPath` / `run` / `isInstalled` / `listContainers`), wire into `Pidly.xcodeproj` (new file refs B145/B146)
- [x] Refactor `KillService` docker helpers to delegate CLI access to `DockerService` (drop private `dockerCLIPath`/`runDocker`)
- [x] Add `DockerCoreTests` to `PidlyTests/ScanEngineTests.swift`
- [x] Run `make test` + `xcodebuild build`; fix to green

## 🔗 Related

- [[PID-EPIC-28]] — parent epic: Docker/container management panel
- [[PID-28.1]] — discovery: resolved the split-model-layer + DockerService decisions this task implements

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** First implementation child of PID-EPIC-28. Scope was pre-resolved in [[PID-28.1]] discovery (split model layer: app-side `DockerService` for impure shell-outs, pure parser + `Container` in `PidlyCore`). Docker CLI plumbing already exists in `KillService` and needs sharing for the upcoming container panel.

- [x] Read relevant source files — `KillService.swift` (private docker helpers `dockerCLIPath`/`runDocker`/`dockerStopByPID`/`findContainerID`/`containerPID`/`dockerStop`), `ScanCore.swift` + `ProcessItem.swift` (the pure-core / model split to mirror), `PidlyTests/ScanEngineTests.swift` (single test file, multiple `XCTestCase` classes), `Package.swift` (SPM globs `Sources/PidlyCore/`), `Pidly.xcodeproj/project.pbxproj` (explicit file refs, no synchronized groups).

- [x] **Archive skim** — `PID-27.2` (`shared-scan-core`) is the precedent for the impure-engine / pure-core split (ScanEngine ↔ ScanCore) this task mirrors for docker. `PID-16.2` (`shellout-helper`) centralized the `runDocker` shell-out helper inside `KillService` — the exact code now being extracted. `PID-14.3` (`docker-stop-note`) documented the docker-stop kill path that must keep working after extraction.

- [x] **Drift check** — No drift. All six private docker helpers cited in the epic line are present in `KillService.swift` at HEAD. `ProcessKind.docker` exists but is orthogonal (classifies stray container root PIDs, not the container inventory). `PidlyCore` SPM-globs new sources → `Container.swift`/`DockerCore.swift` need no project edit; only the app-target `DockerService.swift` requires a `project.pbxproj` entry (no `PBXFileSystemSynchronizedRootGroup` in this project).

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **No clarifications needed.** Explicit assumptions:
  - Parser consumes `docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"` (tab-delimited, mirrors the existing `--format` usage in `KillService.containerPID`) — robust vs. parsing column-aligned default output.
  - `Container` fields = id / name / image / status / ports (covers the `.4` UI requirement name/image/status/ports). `ports` kept as the raw string column.
  - `listContainers()` lists running containers only (`docker ps`, not `-a`), per the discovery decision.
  - `DockerService` fully owns CLI access; `KillService` delegates (drops its private `dockerCLIPath`/`runDocker`). Docker-stop kill behavior unchanged.
  - Tests added as a new `DockerCoreTests` class inside the existing `ScanEngineTests.swift` (matches the single-test-file convention; avoids a second `project.pbxproj` edit). Parser is the pure/testable surface; `DockerService` shell-out stays untested (impure, like `ScanCore.runPS`/`runShell`).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Architecture mirror (ScanEngine/ScanCore → DockerService/DockerCore):**
- `PidlyCore`: `Container.swift` (model, like `ProcessItem`) + `DockerCore.swift` (pure parser, like `ScanCore`).
- App: `DockerService.swift` (impure shell-out + `listContainers()`, like `ScanEngine` shelling out then calling `ScanCore`).

**`project.pbxproj` plan:** add `DockerService.swift` with build-file `B145` + file-ref `B146` (both unused); register in app `Sources` phase `B10D` and the `Pidly` group `B104`. Pattern copied from `KillService.swift` (`B127`/`B128`).

**Phase 1→2 exit:** Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the `ScanEngine`(impure)/`ScanCore`+`ProcessItem`(pure) split rather than inventing a new shape: `DockerService` is the impure app-side service, `DockerCore`+`Container` the pure `PidlyCore` half. `run()` reuses the exact read-to-EOF-before-`waitUntilExit` deadlock-safe shell-out the codebase already uses in `ScanCore.runShell` / the old `KillService.runDocker`.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `PidlyCore/Container.swift` — `Container` value type (`id`/`name`/`image`/`status`/`ports`), `Identifiable` (id = container ID) for the `.4` SwiftUI list, `Equatable` for test assertions.
- `PidlyCore/DockerCore.swift` — pure parser: `psFormat` constant (shared tab-delimited `--format` string), `parsePS(_:)` (line split + compactMap), `parseLine(_:)` (5-field tab split, drops <5 fields or empty ID, keeps trailing empty ports).
- `Pidly/DockerService.swift` — `cliPath()` / `isInstalled` / `run(_:)` (extracted from `KillService`, now resolves the docker path internally per call and returns `("", false)` when absent) / `listContainers()` (shells `docker ps --format`, parses via `DockerCore`).
- `Pidly/KillService.swift` — dropped private `dockerCLIPath`/`runDocker`; `dockerStopByPID`/`findContainerID`/`containerPID` now delegate to `DockerService.run`. Kill behavior unchanged.
- `Pidly.xcodeproj/project.pbxproj` — registered `DockerService.swift` in the app target (build-file `B145`, file-ref `B146`, Sources phase `B10D`, `Pidly` group `B104`). PidlyCore files need no project edit (SPM globs `Sources/`).
- **Downstream-impact:** none. Decision (the split) was already resolved in [[PID-28.1]]; `.3`/`.4` build directly on this surface as planned. No active PLAN entries outside the EPIC-28 cohort share this surface.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 67 tests, 0 failures. 7 new `DockerCoreTests` (full row, empty ports, too-few-fields, empty ID, blank, multi-container, malformed-line skip, empty input).

- [x] Ran lint/type-check on changed code — app target compiled clean as part of the test build (no separate linter; the Swift compiler is the type-check). The transient SourceKit "No such module" diagnostics were stale indexing, contradicted by the successful build.

- [x] (frontend) N/A — no UI surface in this task; the container panel is [[PID-28.1]]'s `.4` child.

**Testing Notes:** Parser is the pure/testable surface; `DockerService`'s shell-out stays untested by design (impure, mirrors untested `ScanCore.runPS`/`runShell`).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (the "12 process kinds" scan surface is unchanged; container management has no shipped UI until `.4`). `AGENTS.md`: no change (no PidlyCore/KillService/docker references). `CLAUDE.md`: **updated** — added a conventions bullet documenting the docker split (pure `DockerCore`/`Container` in PidlyCore, impure `DockerService` app-side, `KillService` delegates) so future work doesn't scatter docker plumbing. `.flowtron/PLAN.md`: `.2` line flipped to stub form.

- [x] Closed — PLAN.md `.2` line flipped to `Completed 2026-06-26.` (kept nested under PID-EPIC-28; parent flips when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Extracted the Docker CLI plumbing out of `KillService` into a shared app-side `DockerService` and added a pure, unit-tested `docker ps` parser + typed `Container` model to `PidlyCore` — mirroring the existing `ScanEngine`/`ScanCore` impure/pure split. `DockerService` now owns docker path resolution, the deadlock-safe shell-out, and `listContainers()`; `KillService`'s docker-stop kill path delegates to it with unchanged behavior. New: `Container.swift`, `DockerCore.swift` (PidlyCore, SPM-globbed), `DockerService.swift` (app target, wired into `project.pbxproj`); refactored `KillService.swift`; 7 new parser tests; `CLAUDE.md` conventions updated. `make test` green (67 tests, 0 failures). Sets up `.3` (stop/remove actions) and `.4` (container panel UI).

**Archived:** 2026-06-26
