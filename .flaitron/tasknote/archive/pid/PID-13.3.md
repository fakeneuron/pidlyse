---
title: process-patterns
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13, PID-13.1, PID-13.2]
---

# PID-13.3 | process-patterns

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Extend `ScanEngine.detectKind` to recognise vite, bun, and bare node processes; assign appropriate risk tiers; add the corresponding `ProcessKind` cases and labels.

## ✅ Acceptance

- [ ] `ProcessKind` has new cases for `vite`, `bun`, and `node`
- [ ] `ScanEngine.detectKind` matches vite, bun, and bare node command strings
- [ ] Risk tiers: vite and bun classified at npm-tier (needsReview), node classified as high (needsReview)
- [ ] Labels/descriptions shown in the UI reflect the new process types
- [ ] Build succeeds without errors

## 🧩 Subtasks

- [ ] Read `ScanEngine.swift` and `ProcessKind` definition to understand current pattern
- [ ] Add `ProcessKind` cases: `.vite`, `.bun`, `.node`
- [ ] Add detection logic in `detectKind` for each new kind
- [ ] Assign risk tiers (classification bucket) for each
- [ ] Add labels/display strings for each new kind
- [ ] Build and verify

## 🔗 Related

- [[PID-EPIC-13]] — parent epic: feature-expansion
- [[PID-13.1]] — discovery subtask that scoped this child
- [[PID-13.2]] — cpu-ram-per-row (sibling, completed)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** All cited files/functions exist and match the task description exactly. Scope is well-defined from PID-13.1 discovery.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source state (confirmed):**
- `ProcessKind` enum in `ProcessItem.swift`: 9 cases with `label` computed property. Pattern to extend.
- `ScanEngine.detectKind` (line 200): ordered if-chain on `s.lowercased()`. Order matters — `vitest` before `npm`.
- `ScanEngine.riskTier` (line 223): guard for always-high kinds at top; switch for the rest.

**Detection strings (decided):**
- `vite`: `s.contains("vite")` — placed after `vitest` check (vitest fires first for vitest commands; "vite" is safe as second check)
- `bun`: `s.contains("bun")` — consistent broad-match philosophy (docker, npm also use contains)
- `node`: `s.contains("node ")` (trailing space) — prevents matching `inode`, `nodestore`, etc.

**Risk tiers:** node → always `.high` (joins docker/uvicorn guard); vite/bun → npm-tier (`strongStray ? .moderate : .high`).

**Labels:** "Vite", "Bun", "Node". No MenuBarView changes — labels flow through existing `kind.label` path.

**Archive skim:** PID-13.1 confirms scope; PID-13.2 confirms current file shapes. No prior work on vite/bun/node patterns.

**Drift check:** All file paths, function names, line numbers match current code. No drift.

**No clarifications needed.** Explicit assumptions stated above.

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

**Pattern survey:** Extended the existing `detectKind` if-chain and `riskTier` switch — no new shape, pure extension of the existing patterns.

**Changes:**
- `ProcessItem.swift`: added `.vite`, `.bun`, `.node` cases to `ProcessKind` enum; added `label` entries ("Vite", "Bun", "Node")
- `ScanEngine.swift` `detectKind`: inserted `s.contains("vite")` after vitest check; appended `s.contains("bun")` and `s.contains("node ")` after npm
- `ScanEngine.swift` `riskTier`: added `|| kind == .node` to the always-high guard; added `.vite, .bun` to the npm-tier case in the switch; added `.node` to the always-high switch case for exhaustiveness
- `ScanEngineTests.swift`: added 3 new `detectKind` asserts in `testDetectKind_basics` (vite, bun, node + vitest-order check); added 4 new riskTier tests (`testNode_isHighRisk`, `testViteStrongStray_isModerate`, `testViteNotStrongStray_isHigh`, `testBunStrongStray_isModerate`)

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

`xcodebuild test` — 35/35 passed (5 new tests all green). Build succeeded clean. No frontend changes.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - `README.md` — no change (PID-13.4 owns the README refresh)
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `.flowtron/PLAN.md` — updated: PID-13.3 line flipped to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Extended `ScanEngine.detectKind` to recognise vite, bun, and bare node processes; added the three `ProcessKind` cases with labels ("Vite", "Bun", "Node") and assigned risk tiers (vite/bun = npm-tier, node = always high). 5 new tests; 35/35 passing.

**Archived:** 2026-06-24
