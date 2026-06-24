---
title: feature-expansion discovery
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13]
---

# PID-13.1 | feature-expansion discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Scope the PID-EPIC-13 epic (`feature-expansion`) before any implementation child fires; deliverable = filed concrete child scopes for PID-13.2..PID-13.5 in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (sources, SPEC contract impact, existing patterns) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-13.2..PID-13.5 filed in .flowtron/PLAN.md (each line under the 50w target / 70w hard cap)
- [ ] Audit line PID-13.6 reviewed and confirmed as-filed (or rewritten if Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing

## 🧩 Subtasks

- [ ] Inventory shared design surface (ScanEngine.swift, ProcessItem.swift, MenuBarView.swift, PortRegistry.swift, SettingsView.swift) — log in Discovery Notes
- [ ] Skim .flowtron/tasknote/archive/pid/ for relevant precedents — log load-bearing findings
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (per-child shortname + scope + feasibility) — record answers in "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-13.2..PID-13.5; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-13 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-13]] — parent epic

---

## 📝 Phase 1: Discovery

- [ ] Reviewed the task entry in PLAN.md

- [ ] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-epic-discovery` with a rich brief covering CPU/RAM display, process-pattern expansion, app description improvements, and proactive notifications — clearly multi-child epic scope.

- [ ] Read relevant source files

- [ ] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [ ] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [ ] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [ ] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

## 🛠️ Phase 2: Execution

- [ ] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [ ] Implemented the minimal solution

- [ ] Updated/added tests for non-trivial behavior

**Implementation Notes:**

## 🧪 Phase 3: Testing & Linting

- [ ] Ran targeted test suite for changed code

- [ ] Ran lint/type-check on changed code

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

## 🚀 Phase 4: Closure

- [ ] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [ ] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [ ] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Epic PID-EPIC-13 (`feature-expansion`) filed and Discovery closed. Four implementation children scoped and filed in PLAN.md: PID-13.2 (CPU/RAM per-row display via new `ps` columns + `ProcessItem` fields), PID-13.3 (vite/bun/node process-pattern expansion), PID-13.4 (README tagline + in-app copy refresh), PID-13.5 (UserNotifications opt-in for new stray alerts). Audit line PID-13.6 confirmed as-filed. No downstream impact on existing active entries.

**Archived:** 2026-06-24
