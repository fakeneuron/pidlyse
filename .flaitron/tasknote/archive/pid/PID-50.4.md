---
title: reclaimable-footprint
status: in-progress
tags: []
created: 2026-06-30
due:
related-tasks: [PID-EPIC-50, PID-50.3, PID-049]
---

# PID-50.4 | reclaimable-footprint

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Show "~X MB reclaimable" in the "Safe to clean" section header by summing the safe-bucket processes' `rssKB`, reusing the existing `ramString` formatter.

## ✅ Acceptance

- [x] "Safe to clean" section header shows "~X MB reclaimable" summed from the safe-bucket `rssKB`
- [x] Reuses the existing `ramString` formatter; no new data sources
- [x] Change confined to `MenuBarView.swift`
- [x] Build + test suite pass

## 🧩 Subtasks

- [x] Add a `safeReclaimableKB` computed property summing `safeItems` `rssKB` (next to `safeItems`/`reviewItems`)
- [x] Render `~\(ramString(safeReclaimableKB)) reclaimable` secondary text in the `safeSection` header (after the title, before the Spacer)
- [x] Build + run the test suite

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-50.3]] — predecessor child (provenance-sort)
- [[PID-049]] — survey that surfaced this item (survey item 3)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Survey item 3, scoped by PID-50.1 discovery as the `.4` child; the safe section + `ramString` + `rssKB` all exist as described.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- `MenuBarView.swift:132` `safeSection` renders the header `Text("Safe to clean (\(safeItems.count))")` in an HStack: title — `Spacer()` — "Clean all" button. This is the target header.
- `safeItems` (`:335`) = `engine.items.filter { $0.bucket == .safe }`; `reviewItems` (`:336`) alongside. Natural home for a sibling `safeReclaimableKB` computed property.
- `ramString(_ kb: Int)` (`:355`) → "X MB" (kb/1024) or "X KB" for sub-MB. Reuse directly; "~\(ramString(total)) reclaimable" yields "~12 MB reclaimable".
- **Pattern to extend:** the collapsed-group header (`:172-179`) already computes `rows.reduce(0) { $0 + $1.rssKB }` and renders `ramString(totalRAM)` as `.font(.caption2).foregroundStyle(.secondary)`. The same reduce + formatter shape applies here.
- **Archive:** PID-50.1 (discovery) explicitly scoped `.4` as "reclaimable-footprint header" in MenuBarView; PID-13.2 introduced `rssKB` + `ramString`; PID-40 (popover-realign) tuned header layout. No conflicting decisions — no prior reclaimable display existed.
- **Drift:** none. All cited names/paths match current code.
- No new data needed — `rssKB` already on every `ProcessItem`.

**Discovery surfaced no significant deviation → skip 🛠️.**

_No clarifications needed._ Assumptions: place the reclaimable text as secondary caption after the title (before the Spacer), styled like the group-header RAM annotation; total includes all safe-bucket rows regardless of per-kind collapse state.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- Extended the exact pattern from the collapsed-group header (`MenuBarView.swift:172-179`): `reduce(0) { $0 + $1.rssKB }` + `ramString(...)`.
- Added `safeReclaimableKB` computed property beside `safeItems`/`reviewItems`.
- Added a secondary `Text("~\(ramString(safeReclaimableKB)) reclaimable")` (`.font(.caption).foregroundStyle(.secondary)`) in the `safeSection` header after the title, before the `Spacer()`.
- No test added: pure presentational reuse of already-tested `ramString` (PID-13.2) over the already-tested `rssKB` field; no new behavior to cover.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

- `make test` → all 118 tests pass; build compiled cleanly.
- SourceKit reported `No such module 'PidlyseCore'` — stale-index false positive (the SPM module built fine for the passing test run).
- 👁️ Visual confirmation requested in the closure recap (menu-bar popover header).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - `README.md` — **updated**: line 11 *Safe to clean* description now notes the "~X MB reclaimable" footprint total in the section header.
  - `AGENTS.md` — no change (no feature-surface enumeration affected).
  - `CLAUDE.md` — no change.
  - `.flowtron/PLAN.md` — flipped below (PID-50.4 → Completed).

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added a "~X MB reclaimable" footprint total to the *Safe to clean* popover section header, summing the safe-bucket processes' `rssKB` via a new `safeReclaimableKB` computed property and the existing `ramString` formatter. Change confined to `MenuBarView.swift` (+5 LOC) plus a one-line README feature-surface note. All 118 tests pass.

**Archived:** 2026-06-30
