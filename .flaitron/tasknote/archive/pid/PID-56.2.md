---
title: container-stats
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-56, PID-56.1]
---

# PID-56.2 | container-stats

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-56]] [[PID-56.1]]

## 🎯 Goal

Per-container CPU/memory in the Docker panel: one-shot `docker stats --no-stream` fetched alongside `docker ps` on load/refresh, parsed by a pure DockerCore parser, and joined by container ID onto ContainersView rows.

## ✅ Acceptance

- [ ] `DockerCore.statsFormat` constant + pure `parseStats` parser in `PidlyseCore` (mirrors the `inspectOwnerFormat` / `parseContainerOwners` precedent), returning an ID-keyed map of a new pure `ContainerStats` value
- [ ] Impure one-shot fetch in `DockerService` (`stats(onComplete:)`) — off-main, delivers on main, empty map on Docker-absent/failure
- [ ] `ContainersView` fetches stats alongside `docker ps` on load and on ↻, joins by container ID, and renders CPU% + memory on each row; rows render normally when stats are missing (progressive fill-in)
- [ ] Stats refetched after stop/remove actions so remaining rows don't show stale values
- [ ] Unit tests for `parseStats` (happy path, malformed/blank lines, `MemUsage` "used / limit" split, empty input); `make test` green
- [ ] No polling timer, no auto-action path — one-shot on load/refresh only (per PID-56.1 resolved scoping)

## 🧩 Subtasks

- [ ] Add `ContainerStats` pure value (cpu, memory) in `Packages/PidlyseCore/Sources/PidlyseCore/Container.swift`
- [ ] Add `DockerCore.statsFormat` (`{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}`) + `parseStats(_:) -> [String: ContainerStats]` (strip the " / limit" tail from MemUsage)
- [ ] Add `DockerService.stats(onComplete:)` — `docker stats --no-stream --format DockerCore.statsFormat`, off-main via the `list(onComplete:)` pattern
- [ ] Wire `ContainersView`: `@State stats` map, fetch in `reload()` and after stop/remove completions, render CPU · mem caption in the row's trailing stack
- [ ] Add `parseStats` unit tests in `PidlyseTests/ScanEngineTests.swift` beside the `parseContainerOwners` block
- [ ] Run `make test`

## 🔗 Related

- [[PID-EPIC-56]] — parent epic: docker-enhance (stats, compose grouping, restart action)
- [[PID-56.1]] — epic discovery that scoped this child (one-shot stats on load/refresh decision)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** First implementation child of PID-EPIC-56, scoped one day ago by [[PID-56.1]] with user-resolved decisions (one-shot fetch, no polling); the Docker panel is stable and no stats surface exists yet — the task is exactly as filed.

- [x] Read relevant source files — `DockerCore.swift` (psFormat/inspectOwnerFormat constants + pure parsers), `Container.swift` (pure value), `DockerService.swift` (`run`/`listContainers`/`list` async pattern, `performThenRefresh` action path), `ContainersView.swift` (`@State` list, `reload()` on appear + `refreshToken`, per-row stop/remove), `ScanEngineTests.swift` DockerCore test block (parsePS/parseContainerOwners precedents).

- [x] **Archive skim** — [[PID-56.1]] is the load-bearing record: resolved scoping table (one-shot `docker stats --no-stream` alongside `docker ps` on load/refresh; no polling timer), architecture inventory naming the exact shape this task implements (new format constant + pure parser mirroring `inspectOwnerFormat`, impure fetch in DockerService, join by ID), and the note that `docker stats --no-stream` blocks ~1-2 s — safe because fetches run off-main. PID-28.x established the DockerService/DockerCore split; PID-037.2 is the `inspectOwnerFormat` second-format-constant precedent; PID-35.3 requires all docker invocations to route through `DockerService.run` (they do by construction); PID-049's system-wide-monitoring reject doesn't apply (container-scoped, in-panel).

- [x] **Drift check** — No drift. `inspectOwnerFormat` precedent, `DockerService`, and `ContainersView` all exist as cited; no stats constant/parser/fetch/UI exists yet; `Container` has no CPU/mem fields (expected — that's the work).

- [x] No clarifications needed — scoping was user-resolved at [[PID-56.1]]. Explicit assumptions: (1) stats keyed by the 12-char short ID, which `{{.ID}}` emits identically in `docker ps` and `docker stats`; (2) `MemUsage` renders as "used / limit" — the parser keeps only the used part for row compactness; (3) `CPUPerc`/`MemUsage` stay display strings (no numeric parse) since no sorting/thresholding consumes them; (4) stats live in a separate `@State` map joined at render (not on `Container`), so the `performThenRefresh` `[Container]` callback signature is untouched; (5) row placement: trailing stack under the status text.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

`ContainerStats` goes in `Container.swift` beside `Container` (same pure-model file; too small for its own file). The stats fetch is a sibling of `list(onComplete:)` — same off-main/deliver-on-main shape. After stop/remove, the action completion refetches stats separately (the shared `performThenRefresh` stays `[Container]`-only). Missing stats for a row (container started between the two shell-outs, or stats call failed) render nothing — progressive fill-in, no placeholder.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the [[PID-037.2]] `inspectOwnerFormat`/`parseContainerOwners` shape exactly: second format constant + pure ID-keyed-map parser in `DockerCore`, impure wrapper in `DockerService` on the `list(onComplete:)` off-main/deliver-on-main shape. No new shapes introduced.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 4 `parseStats` tests beside the `parseContainerOwners` block

**Implementation Notes:**

- `Container.swift` — new pure `ContainerStats` value (cpu, memory as display strings; nothing sorts/thresholds on them).
- `DockerCore.swift` — `statsFormat` constant + `parseStats(_:) -> [String: ContainerStats]`; strips the ` / limit` tail from `{{.MemUsage}}`; drops <3-field or empty-ID lines.
- `DockerService.swift` — `stats(onComplete:)`: `docker stats --no-stream --format DockerCore.statsFormat` off-main, empty map on absence/failure; one-shot only, no timer.
- `ContainersView.swift` — `@State stats` map; `reload()` fetches list + stats together; new `reloadStats()` also called from stop/remove completions (keeps `performThenRefresh`'s `[Container]` signature untouched); row's trailing side is now a VStack of status + `cpu · memory` caption (tertiary, monospaced) that renders only when the sample exists — progressive fill-in while the ~1-2 s stats shell-out completes.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 201 tests, 0 failures (4 new `parseStats` tests)

- [x] Ran lint/type-check on changed code — Swift build inside `make test` is the type-check; no separate linter configured in this repo

- [x] (frontend) Asked the user for visual confirmation (👁️ ask surfaced at the 📦 gate)

**Testing Notes:** `parseStats` covers: ID-keyed mapping + mem-limit strip, MemUsage without ` / ` kept whole (defensive), malformed/blank/empty-ID lines dropped, empty input. Impure `DockerService.stats` mirrors `listContainers` — not unit-tested, per the established `ScanCore.runPS` convention.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: Containers-tab feature line updated (CPU/memory sample added to the row description). `AGENTS.md`: no change (no Docker surface). `CLAUDE.md`: no change (the Docker pure/impure split description already covers stats parsing by construction). `SPEC.md`: file-map comments updated for `DockerCore.swift`, `Container.swift`, `ContainersView.swift`. `.flowtron/PLAN.md`: `.2` line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-02.` (kept in place under the open parent per mid-epic convention) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate — frontend signal trips)

**Final Summary:**

Per-container CPU/memory landed in the Docker panel. A one-shot `docker stats --no-stream` runs alongside `docker ps` on tab load and ↻ (and refetches after stop/remove); each row now shows a `cpu · memory` caption under its status, filling in when the ~1-2 s sample completes. Implementation followed the `inspectOwnerFormat` precedent exactly: pure `statsFormat` constant + `parseStats` (ID-keyed `ContainerStats` map, ` / limit` tail stripped) in `DockerCore`, impure off-main `DockerService.stats(onComplete:)`, join-by-ID in `ContainersView`. No polling timer, no auto-action path. 4 new `parseStats` unit tests; `make test` 201/201 green.

**Archived:** 2026-07-02
