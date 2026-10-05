---
title: spec-settings
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-15]
---

# PID-15.2 | spec-settings

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-15]]

## 🎯 Goal

Fix the `Settings.swift` → `SettingsView.swift` filename in SPEC.md's project structure table and reconcile the JSON override claim (move to Future Opportunities or implement as per scope).

## ✅ Acceptance

- [ ] SPEC.md project structure table lists `SettingsView.swift` (not `Settings.swift`)
- [ ] JSON override claim in SPEC.md is reconciled — either moved to Future Opportunities or implemented

## 🧩 Subtasks

- [ ] Read SPEC.md to find the project structure table and JSON override claim
- [ ] Fix `Settings.swift` → `SettingsView.swift` in the table
- [ ] Evaluate JSON override claim: move to Future Opportunities section or implement (per PLAN.md intent)
- [ ] Verify no other stale filenames in the SPEC.md structure table

## 🔗 Related

- [[PID-EPIC-15]] — parent doc-sync epic

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Both issues confirmed. SPEC.md §"Project Structure" lists `Settings.swift` but the actual file is `SettingsView.swift` (created in PID-006). SPEC.md §"Port Registry" claims "user can also supply a JSON override file" but this is not implemented — Future Opportunities in PLAN.md already describes it as deferred.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Archive skim:** PID-006 explicitly created `SettingsView.swift` (not `Settings.swift`) and wired it as the Settings scene. PID-13.6 confirmed `SettingsView.swift` present. SPEC.md was never updated. No decision to keep old name.
- **Drift check:** `SettingsView.swift` confirmed in `Pidly/` source dir. JSON override claim in SPEC.md §"Port Registry" is false — it's in PLAN.md Future Opportunities as unimplemented.
- **Adjacent drift noted (out of scope):** SPEC.md §"Classification" line references `([[PID-005]], not yet implemented)` — PID-005 is now completed. Whether port-based demotion is fully wired in the classification flow is a separate question; flagged as adjacent drift for the epic audit.
- **No clarifications needed.** Assumptions: JSON override sentence in SPEC.md §"Port Registry" is removed (accurate state); Future Opportunities in PLAN.md already carries it.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — doc-only edit; no code pattern needed; existing SPEC.md format extended in place

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — doc-only changes; no tests applicable

**Implementation Notes:**

- `SPEC.md` §"Project Structure": `Settings.swift` → `SettingsView.swift` (1 line)
- `SPEC.md` §"Port Registry": removed false "user can also supply a JSON override file" sentence (JSON override is deferred — already in PLAN.md Future Opportunities)

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — doc-only; no test suite applicable

- [x] Ran lint/type-check on changed code — markdown only; no compiler/linter applicable

- [x] (frontend) Asked the user for visual confirmation — not applicable (no frontend changes)

**Testing Notes:**

Verified both changes against ground truth: `ls Pidly/` confirms `SettingsView.swift` exists; PID-006 archive confirms it was always the correct name. Port Registry section now accurately reflects shipped state.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: no change (Future Opportunities entry for JSON override is accurate).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Fixed two SPEC.md divergences: renamed `Settings.swift` → `SettingsView.swift` in the project structure table (the correct name was used when PID-006 created the file and was never back-propagated to SPEC), and removed the false "user can also supply a JSON override file" claim from §"Port Registry" (this feature is deferred — already in PLAN.md Future Opportunities). One line changed in each section. Adjacent drift noted: §"Classification" still says `([[PID-005]], not yet implemented)` — flagged for the PID-15.N audit.

**Archived:** 2026-06-24
