---
title: container-actions
status: in-progress
tags: [epic-28, docker]
created: 2026-06-26
due:
related-tasks: [PID-EPIC-28, PID-28.1, PID-28.2]
---

# PID-28.3 | container-actions

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-28]] [[PID-28.2]]

## 🎯 Goal

Add explicit-click stop + remove actions to `DockerService` (`docker stop` / `docker rm`) that refresh the running-container list on completion, ready for the `.4` panel UI to wire to per-row buttons.

## ✅ Acceptance

- [ ] `DockerService` gains stop + remove methods that shell out via the existing `run(_:)` primitive
- [ ] Each action is async (off the main queue) and delivers the refreshed `[Container]` list on the main queue, mirroring `KillService`'s `onComplete` pattern
- [ ] No auto-action — methods only run when explicitly called (no timer/auto path), per CLAUDE.md
- [ ] All `docker` CLI access stays inside `DockerService` (no plumbing scattered into KillService/UI), per CLAUDE.md conventions
- [ ] `make test` green; app target compiles clean
- [ ] Phase 4 doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs"

## 🧩 Subtasks

- [x] Resolve remove semantics for a running-only list (clarifying question) — stop-then-remove
- [x] Add `stop(_:onComplete:)` to `DockerService` (`docker stop <id>`, async, refresh on completion)
- [x] Add `remove(_:onComplete:)` to `DockerService` (`docker stop` then `docker rm`, async, refresh on completion)
- [x] Factor the shared `performThenRefresh` helper (run commands → re-list → deliver on main)
- [ ] Run `make test` + build; fix to green

## 🔗 Related

- [[PID-EPIC-28]] — parent epic: Docker/container management panel
- [[PID-28.2]] — docker-service: created `DockerService` (`run`/`listContainers`) this task extends
- [[PID-28.1]] — discovery: resolved stop+remove action set on a running-only (`docker ps`) list

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Second implementation child of PID-EPIC-28. `DockerService` exists from [[PID-28.2]] with the `run(_:)` shell-out and `listContainers()`; this task adds the stop/remove actions the `.4` panel will call. Scope pre-resolved in [[PID-28.1]] (stop + remove, explicit-click, no auto-action).

- [x] Read relevant source files — `DockerService.swift` (`cliPath`/`run`/`isInstalled`/`listContainers`), `KillService.swift` (async `onComplete` main-queue pattern; `docker stop`/`docker rm` precedent), `Container.swift` + `DockerCore.swift` (PidlyCore model + parser), `ScanEngineTests.swift` (single test file, `DockerCoreTests` class).

- [x] **Archive skim** — [[PID-28.2]] created `DockerService` and centralized all `docker` CLI access there (`KillService` delegates). [[PID-28.1]] resolved the stop+remove action set on a running-only list. `PID-14.3` (`docker-stop-note`) documented the docker-stop kill path. No prior container-action work.

- [x] **Drift check** — No drift. `DockerService.run(_:)` and `listContainers()` are present at HEAD as cited; `KillService` already uses `docker stop` via `DockerService.run`. The panel list (`.4`) is running-only (`docker ps`), which is the open question for remove semantics (below).

- [x] Asked clarifying questions — resolved below.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Resolved scoping (via AskUserQuestion):**

| Question | Decision |
|---|---|
| Remove semantics on a running-only (`docker ps`) list | **Stop then remove** — Remove = `docker stop <id>` (graceful) then `docker rm <id>`. Uses both literal commands from the task line; honors CLAUDE.md's grace-period spirit; fully removes the container. (Rejected: `docker rm -f` skips grace; plain `docker rm` errors on running containers.) |

**Explicit assumptions:**
- Stop = `docker stop <id>` (Docker's own graceful SIGTERM→10s→SIGKILL); Remove = `docker stop <id>` then `docker rm <id>` (sequential).
- Methods are async (background queue) and deliver the refreshed `[Container]` list on the main queue, mirroring `KillService`'s `onComplete` pattern. The `.4` panel re-renders from the returned list.
- Shell-outs stay impure/untested by design (mirrors `listContainers()` per [[PID-28.2]]); no new pure logic to unit-test. Phase 3 = `make test` green + clean compile.
- No new files → no `project.pbxproj` edit (additions live in existing `DockerService.swift`).

**Phase 1→2 exit:** Discovery surfaced no significant deviation (one within-scope clarification resolving the literal-`docker rm` ambiguity; same file, same approach, consistent with the filed `docker stop` / `docker rm` line) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended `KillService`'s established async-with-`onComplete`-on-main-queue shape (`kill(_:onComplete:)` runs the docker work on `DispatchQueue.global()` then fires `onComplete` on `.main`). Reused `DockerService.run(_:)` for the shell-outs rather than adding a parallel primitive. No new shape invented.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A; the new methods are thin impure shell-outs (no pure branching logic), mirroring the untested `listContainers()` per [[PID-28.2]]. The pure/testable docker surface (`DockerCore.parsePS`) is unchanged.

**Implementation Notes:**

- `Pidly/DockerService.swift` — added `stop(_:onComplete:)` (`docker stop <id>`), `remove(_:onComplete:)` (`docker stop <id>` then `docker rm <id>`, per the resolved stop-then-remove semantics), and a private `performThenRefresh(_:onComplete:)` helper that runs the command sequence on a background queue, re-lists running containers via `listContainers()`, and delivers `[Container]` on the main queue. `onComplete` defaults to a no-op so callers that don't need the refreshed list can omit it.
- No new files → no `project.pbxproj` edit. All `docker` access stays inside `DockerService`.
- **Downstream-impact:** none. The `.4` panel UI is the only planned consumer and builds directly on this API as scoped. No active PLAN entries outside the EPIC-28 cohort share this surface.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 67 tests, 0 failures.

- [x] Ran lint/type-check on changed code — app target compiled clean as part of the test build (Swift compiler is the type-check; no separate linter). The SourceKit "No such module 'PidlyCore'" diagnostic was stale indexing, contradicted by the successful build (same transient as [[PID-28.2]]).

- [x] (frontend) N/A — no UI surface in this task; per-row stop/remove buttons land in [[PID-28.1]]'s `.4` child.

**Testing Notes:** No new tests — the added methods are thin impure shell-outs over the existing `run(_:)` primitive (mirrors the untested `listContainers()`); the pure `DockerCore.parsePS` surface is unchanged and stays covered by the 7 `DockerCoreTests`.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (its `docker` reference is stray-process-kind detection; no shipped container UI lands until `.4`). `AGENTS.md`: no change (no docker references). `CLAUDE.md`: no change (the docker-split convention added in [[PID-28.2]] already mandates `DockerService` owning all `docker` invocations — these methods comply, no new convention). `.flowtron/PLAN.md`: `.3` line flipped to stub form.

- [x] Closed — PLAN.md `.3` line flipped to `Completed 2026-06-26.` (kept nested under PID-EPIC-28; parent flips when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Added explicit-click `stop(_:onComplete:)` and `remove(_:onComplete:)` to `DockerService`, plus a private `performThenRefresh` helper. `stop` runs `docker stop <id>`; `remove` runs `docker stop <id>` then `docker rm <id>` (stop-then-remove, resolved with the user — honors CLAUDE.md's grace-period spirit, no force `-f`, since the panel lists running containers only). Both run on a background queue and deliver the refreshed `[Container]` list on the main queue, mirroring `KillService`'s `onComplete` pattern. No new files, no `project.pbxproj` edit, no scattered docker plumbing. `make test` green (67 tests, 0 failures). Sets up `.4` (container panel UI) to wire these to per-row buttons.

**Archived:** 2026-06-26
