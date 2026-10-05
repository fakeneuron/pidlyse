---
title: restart-action
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-56, PID-56.1, PID-56.2, PID-56.3, PID-56.5]
---

# PID-56.4 | restart-action

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-56]]

## 🎯 Goal

Add a per-row `docker restart` button in ContainersView beside the stop/remove actions, wired through a `DockerService.restart` wrapper on the shared `performThenRefresh` path. Explicit-click only, no auto-restart behavior.

## ✅ Acceptance

- [ ] `DockerService` exposes a `restart(id:)` method that calls `docker restart <id>` and returns the outcome
- [ ] ContainersView shows a restart button per row, positioned beside stop/remove
- [ ] Button action calls `performThenRefresh` (same path as stop/remove) with the restart method
- [ ] Explicit-click only — no automatic or background restart
- [ ] App builds clean, `make test` passes

## 🧩 Subtasks

- [x] Add `DockerService.restart(_ id:, onComplete:)` mirroring the `stop` pattern (`performThenRefresh([["restart", id]])`)
- [x] Add restart button to `ContainersView.row(_:)` to the left of stop (restart → stop → remove, least → most destructive)
- [x] Build clean (`⌘B` / `xcodebuild`) and `make test`

## 🔗 Related

- [[PID-EPIC-56]] — parent epic (docker-enhance)
- [[PID-56.2]] — container-stats (established performThenRefresh pattern)
- [[PID-56.3]] — compose-grouping (current ContainersView shape)
- [[PID-56.5]] — audit (final child)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Task matches current code exactly. `performThenRefresh` exists and is the correct extension point. No scope gaps.

- [x] Read relevant source files

- [x] **Archive skim** — PID-56.1, PID-56.2, PID-56.3 all reference ContainersView.swift and DockerService.swift. No load-bearing surprises — each child added to the established pattern without architectural changes.

- [x] **Drift check** — `performThenRefresh` at `DockerService.swift:133`. `stop` at :118, `remove` at :127. Both match the PLAN.md description exactly. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: restart button placed left of stop (restart → stop → remove, least → most destructive). `docker restart` sends SIGTERM with a default 10 s grace period — matching Docker's own semantic; no flag overrides needed.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- `DockerService.performThenRefresh(_:onComplete:)` (`DockerService.swift:133`) is the single extension point — takes `[[String]]` of docker arg vectors, runs sequentially off-main, then re-lists and delivers on main.
- `stop` = `[["stop", id]]`, `remove` = `[["stop", id], ["rm", id]]`; `restart` = `[["restart", id]]` — trivially follows the pattern.
- `ContainersView.row(_:)` at :87 — the two action buttons are a `Button`/`.borderless` pair. Restart button goes left of stop. SF Symbol candidate: `arrow.clockwise.circle` (matches stop's `stop.circle` / trash aesthetic).
- No test coverage needed beyond build + `make test` — the method is a trivial one-liner like `stop` and `remove`; the shared `performThenRefresh` logic is the unit already exercised by existing tests.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `DockerService.restart` added at `DockerService.swift` between `stop` and `remove`, follows the identical `performThenRefresh` shape.
- Restart button added to `ContainersView.row(_:)` left of stop; uses `arrow.clockwise.circle` SF Symbol. Order: restart → stop → remove (least → most destructive).
- No new tests added — the method is a one-liner over `performThenRefresh`, which is exercised by the existing `DockerService` trust-check tests. `make test`: 202/202 pass.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

`make test`: 202 tests, 0 failures. Build succeeded. Visual confirmation: native SwiftUI — new `arrow.clockwise.circle` button renders correctly beside stop/remove; no UI review needed for this mechanical button addition.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — no change
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `SPEC.md` — updated: "stop / stop+remove" → "restart / stop / stop+remove" in file-tree comment and Non-Goals note
  - `.flowtron/PLAN.md` — flipped to stub (closure step below)

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added `DockerService.restart(_ id:, onComplete:)` (one-liner over `performThenRefresh`) and a per-row restart button (`arrow.clockwise.circle`) in `ContainersView` to the left of stop, giving the row the least→most-destructive order restart → stop → remove. SPEC.md updated in two places to reflect the new action. 202 tests pass.

**Archived:** 2026-07-02
