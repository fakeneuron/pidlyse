---
title: spec-drift
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-19, PID-19.2, PID-19.N]
---

# PID-19.3 | spec-drift

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-19]]

## 🎯 Goal

Fix SPEC.md scan interval discrepancy (60s→2min) and add vite/bun/node entries to the Scan Engine + Classification tables.

## ✅ Acceptance

- [ ] SPEC.md lines 37 & 111 reflect 2-minute scan interval (no 60s references)
- [ ] Scan Engine table in SPEC.md includes vite, bun, and node entries
- [ ] Classification table in SPEC.md includes vite, bun, and node entries
- [ ] `make test` passes

## 🧩 Subtasks

- [ ] Read SPEC.md to verify drift points at lines 37 & 111 and locate the Scan Engine + Classification tables
- [ ] Fix scan interval references (60s→2min) at confirmed line numbers
- [ ] Add vite, bun, node rows to the Scan Engine table
- [ ] Add vite, bun, node rows to the Classification table
- [ ] Run `make test` to confirm no regressions

## 🔗 Related

- [[PID-EPIC-19]] — parent epic: repo-hygiene
- [[PID-19.2]] — predecessor: gitignore
- [[PID-19.N]] — follow-up: epic audit

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Drift confirmed — SPEC.md still says 60 s in two places; ScanEngine.swift uses 120 (2 min) as default. vite/bun/node are all implemented in detectKind/riskTier but absent from both SPEC tables.

- [x] Read relevant source files

- [x] **Archive skim** — PID-19.2 archive only references PID-19.3 as sibling; no load-bearing prior context on SPEC tables or scan interval.

- [x] **Drift check** — Line 37 and 111 drift confirmed. vite/bun/node presence in code confirmed. Line numbers may have shifted; will re-verify at edit time.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) 2 min = `2 min` prose style to match SPEC tone; (2) node is `high` always (matches docker/uvicorn row); (3) vite/bun cap at moderate so they belong in the npm-style row; (4) doc-only change, no Swift edits.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**
- SPEC.md line 37: "every 60 s" → change to "every 2 min"
- SPEC.md line 111: "default: 60 s" → change to "2 min"
- Scan Engine table: add vite (Dev server — Vite), bun (JS runtime / package manager), node (Node.js runtime)
- Classification table high row: add node to the never-an-easy-kill list; add vite/bun to the npm/other clause
- ScanEngine.swift riskTier: node → always .high; vite/bun → strongStray ? .moderate : .high (same as npm)

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing Scan Engine and Classification tables are the shape to extend; no new structure needed.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**
- SPEC.md line 37: "every 60 s" → "every 2 min"
- SPEC.md line 111: "default: 60 s" → "2 min"
- Scan Engine table: added vite (Dev server — Vite), bun (JS runtime / package manager), node (Node.js runtime) rows after npm
- Classification high row: added node to the never-an-easy-kill list; added vite/bun to the npm clause
- No Swift changes needed (code already correct)

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**
- 51/51 tests passed (0 failures) — doc-only change, no Swift regressions

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md: no change (already lists 2 min + vite/bun/node). AGENTS.md: no change. CLAUDE.md: no change. PLAN.md: updated at closure.

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**
Fixed two stale 60s scan-interval references in SPEC.md (lines 37 and 111 → "2 min") and added vite, bun, and node to the Scan Engine and Classification tables. Doc-only; no Swift changes; 51/51 tests pass.

**Archived:** 2026-06-25
