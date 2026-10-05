---
title: provenance-sort
status: in-progress
tags: [ux, popover]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-50.1, PID-038]
---

# PID-50.3 | provenance-sort

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Deterministically order rows alphabetically by their provenance/project label (`rowDescriptor`) within each kind group, so the popover list stays stable across scans.

## ✅ Acceptance

- [ ] Within each kind group, rows are ordered alphabetically by `rowDescriptor` (provenance/project label)
- [ ] Ordering is deterministic across scans — equal descriptors break the tie on `pid` (stable, no scan-order leakage)
- [ ] No sort UI added; change is MenuBarView ordering only
- [ ] Existing test suite still passes (no regression); app builds

## 🧩 Subtasks

- [ ] Sort `matches` in `grouped(_:)` by `rowDescriptor` with a `pid` tiebreaker
- [ ] Verify `initCollapsedKinds()` (other `grouped()` caller) is order-independent — no behavior change
- [ ] Build + run existing test suite (`make test`)

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-50.1]] — discovery; rescoped .3 from a sort control to a deterministic auto-sort
- [[PID-038]] — introduced `rowDescriptor` (the project/provenance label this sorts by)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Direct implementation of the [[PID-50.1]] discovery rescope — a deterministic alphabetical auto-sort by the provenance label, MenuBarView-local, clear diff.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source surveyed:** `Pidlyse/MenuBarView.swift`.
- `grouped(_:)` (L338-343) builds `[(ProcessKind, [ProcessItem])]` by `ProcessKind.allCases` order; within each kind, `matches = items.filter { $0.kind == kind }` **preserves `engine.items` (scan) order** — this is the non-determinism the task targets.
- `rowDescriptor(_:)` (L205-207) = `engine.cwds[item.pid]?.label ?? item.displayPath` — the provenance/project label to sort by. It reads view state (`engine.cwds`), so the sort must live in the view (it already calls `rowDescriptor` from `row(_:)`).
- `grouped()` has two callers: `groups(for:)` (L159, renders rows — wants the sorted order) and `initCollapsedKinds()` (L55, only does `rows.contains(where: { $0.riskTier == .high })` — **order-independent**). So sorting inside `grouped()` centralizes the change and is safe for both callers.

**Archive skim** (pid/, popover-ordering precedents): PID-003 (popover-ui, original section layout), PID-021 (collapsible sections), PID-038 (introduced the cwd→project `rowDescriptor`), PID-50.2 (row context menu, same `row(_:)` surface). No prior tasknote imposed a within-group order — rows have always rendered in scan order. The `ports.sorted()` at L302 is the only existing sort idiom; nothing for string descriptors. No regression risk flagged.

**Drift check:** All cited paths/symbols (`grouped`, `rowDescriptor`, `initCollapsedKinds`, `engine.cwds`) match HEAD. No drift.

**Clarifications:** No clarifications needed. Explicit assumptions:
- **Case-insensitive alphabetical** via `localizedCaseInsensitiveCompare` — descriptors are mostly lowercase repo names, but a fallback `displayPath` can be mixed-case; case-insensitive reads as "alphabetical" to a human and avoids ASCII upper-before-lower surprises.
- **Tiebreaker = `pid` ascending** — guarantees full determinism when two rows share a descriptor (e.g. two processes in the same repo) so order can't leak from scan order.
- Sort lives in `grouped()` (single site), not a new pure helper — view-local sort reading `engine.cwds`; a `PidlyseCore` extraction would be over-engineering for the scope (consistent with the [[PID-50.1]] "MenuBarView-local, [light]" framing).

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the file's existing `.sorted` idiom (`ports.sorted()`, L302); the sort lives in `grouped(_:)`, the single per-kind grouping site both render callers share

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A; the sort is a view-private method reading `engine.cwds` (view state), not unit-testable without a UI-layer refactor out of scope for this [light] change. Covered by the existing suite (no regression) + build.

**Implementation Notes:**

- One edit in `Pidlyse/MenuBarView.swift` `grouped(_:)`: each kind group's `matches` is now `.sorted` by `rowDescriptor(_:).localizedCaseInsensitiveCompare(...)`, with `pid` ascending as the `.orderedSame` tiebreaker. ~10 LOC + comment.
- Centralized in `grouped()` so both callers inherit it: `groups(for:)` renders sorted; `initCollapsedKinds()` only does `contains(where:)` (order-independent) so its behavior is unchanged.
- No new data, no model/core change, no sort UI — MenuBarView-local exactly as scoped.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 118 tests, 0 failures. The suite compiles the full app via xcodebuild, so the edit builds clean.

- [x] Ran lint/type-check on changed code — type-checked as part of the xcodebuild compile. (A SourceKit `No such module 'PidlyseCore'` note is a standalone-LSP indexing artifact — the SPM package resolves under xcodebuild, where compilation succeeded.)

- [x] (frontend) Asked the user for visual confirmation — see 👁️ prose ask at closure.

**Testing Notes:** No regression — same 118-test green as before the change. Visual effect (alphabetized rows within each kind group) is best confirmed on a build with ≥2 same-kind processes across different projects.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (row ordering is a UX refinement, not a new feature-surface entry) · `AGENTS.md`: no change · `CLAUDE.md`: no change · `.flowtron/PLAN.md`: `.3` line flipped to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-50; parent + cohort move to `## Completed` only when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Made the popover's per-kind row order deterministic: rows are now sorted alphabetically (case-insensitive) by their provenance/project label (`rowDescriptor`) within each kind group, with `pid` breaking ties, so the list no longer reshuffles from scan-order leakage between scans. One ~10-LOC edit in `MenuBarView.grouped(_:)` — no new data, no sort UI, no core/model change. Existing suite stays green (118 tests).

**Archived:** 2026-06-30
