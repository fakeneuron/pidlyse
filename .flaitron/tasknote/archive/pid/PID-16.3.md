---
title: makeitem-alloc
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-16, PID-16.2, PID-16.4]
---

# PID-16.3 | makeitem-alloc

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-16]] [[PID-16.2]] [[PID-16.4]]

## 🎯 Goal

Inline the `hasTTY` and `isOrphan` computations directly inside `ScanEngine.makeItem`, eliminating the draft `ProcessItem` heap allocation used as an intermediary.

## ✅ Acceptance

- [ ] `hasTTY` and `isOrphan` computed inline in `makeItem` without a draft `ProcessItem` allocation
- [ ] `riskTier` logic is unchanged
- [ ] Build succeeds (`xcodebuild build -scheme Pidly`)

## 🧩 Subtasks

- [ ] Read `ScanEngine.swift` around lines 190-200 to understand the draft allocation
- [ ] Archive skim for prior decisions on `ScanEngine.makeItem`
- [ ] Drift check — verify line numbers and function names still match
- [ ] Inline the computations, removing the draft allocation
- [ ] Build and verify no regressions

## 🔗 Related

- [[PID-EPIC-16]] — parent code-quality epic
- [[PID-16.2]] — predecessor: shellout-helper extraction
- [[PID-16.4]] — follow-up: ScanEngine persistence coupling simplification

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** `ScanEngine.makeItem` (lines 189-201) allocates a draft `ProcessItem` with stub `.moderate` tier solely to access `draft.hasTTY` and `draft.isOrphan`. Both are trivially inline-computable from `p.tty` and `p.ppid` already in scope.

- [x] Read relevant source files

- [x] **Archive skim** — PID-16.1 documented this exact double-alloc pattern with ready-to-use inline formulas. No other prior tasknotes touch `makeItem`.

- [x] **Drift check** — Lines 190-200 match exactly. `hasTTY` (ProcessItem.swift:93-96) and `isOrphan` (ProcessItem.swift:99) confirmed. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) inline logic must match `ProcessItem.hasTTY`/`isOrphan` exactly; (2) `p.tty` is passed unchanged into the final `ProcessItem` init; (3) `riskTier` call and the port-registry demotion line are untouched.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

Archive (PID-16.1): "Both are trivially computable from `p.tty` and `p.ppid` inline: `hasTTY = !(["??","?","-",""].contains(p.tty.trimmingCharacters(in:.whitespaces)))`, `isOrphan = p.ppid == 1`."

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — mirrors `ProcessItem.hasTTY`/`isOrphan` exactly; `hasTTY` trims once into `t` (reused for the check); no new pattern introduced

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — no test needed; behavior is provably identical by inspection (same logic, no conditional)

**Implementation Notes:**

Replaced draft `ProcessItem` allocation (3 lines) with two inline `let` bindings (`hasTTY`, `isOrphan`) computed from `p.tty`/`p.ppid`. `riskTier` call and port-registry demotion line unchanged. Final `ProcessItem` return unchanged.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A: Swift/macOS, no frontend surface

**Testing Notes:**

All 30 `ScanEngineTests` passed (`xcodebuild test`). Build succeeded with no warnings on the changed file.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md: no change; AGENTS.md: no change; CLAUDE.md: no change; .flowtron/PLAN.md: stub-form flip below

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/PID-16.3.md`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Removed the draft `ProcessItem` heap allocation from `ScanEngine.makeItem` by inlining `hasTTY` and `isOrphan` directly from `p.tty` / `p.ppid`. Replaced 3 lines (draft init + two `draft.x` property reads) with 2 `let` bindings. Build and all 30 tests pass.

**Archived:** 2026-06-24
