---
title: app-description
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13]
---

# PID-13.4 | app-description

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Update `README.md` with a sharp tagline and accurate feature summary reflecting the shipped feature set, and improve stale or generic in-app copy.

## ✅ Acceptance

- [ ] `README.md` has an updated tagline and feature list accurately reflecting the shipped feature set (all 12 process kinds, CPU%/RAM columns, risk-tier dots, expandable "why" block, session dismiss, settings)
- [ ] In-app copy reviewed across `MenuBarView.swift` and `SettingsView.swift`; any stale/generic strings updated
- [ ] No functional code changes — text/copy only

## 🧩 Subtasks

- [x] Read current `README.md` and note stale/generic content (done in Phase 1)
- [x] Read all SwiftUI views for in-app copy (done in Phase 1)
- [ ] Write updated `README.md` with sharp tagline and feature section
- [ ] Apply any warranted in-app copy improvements (minimal — views are mostly clean)

## 🔗 Related

- [[PID-EPIC-13]] — parent feature-expansion epic

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** README predates most shipped features (CPU/RAM columns, 12 process kinds, risk-tier dots, expandable "why" block, session dismiss, settings) — clearly stale and in need of a refresh.

- [x] Read relevant source files

- [x] **Archive skim** — No prior tasknote specifically updated README content. PID-13.1 (epic discovery) explicitly scoped PID-13.4 as "README tagline + in-app copy refresh." PID-001 noted "README.md: no change — already accurate" at scaffold time (before most features existed).

- [x] **Drift check** — `README.md` exists. `MenuBarView.swift` and `SettingsView.swift` exist. No function names or line numbers cited in task description — no drift to check.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) README gets a feature-section rewrite; (2) in-app copy in views is mostly clean — only genuinely stale/generic strings get updated; (3) no functional changes.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**
- README missing: 12 process kinds list, CPU%/RAM/age per row, risk-tier color dots, expandable "why" detail block, session dismiss, Settings capabilities (scan interval, stale threshold, ignore list, launch at login)
- `MenuBarView.swift` copy is clean and accurate. Criterion tags ("no tty", "orphan", "old") are fine technical shorthand for a dev tool.
- `SettingsView.swift` copy is clean. Stepper labels ("Every X min", "Stale after X min") are terse but readable in context.
- In-app copy verdict: no changes warranted — views are already clean post PID-008/PID-011/PID-012 work.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing README structure retained (standard GitHub markdown: tagline → body → feature sections → requirements → build → table → links); extended with a new Features section rather than inventing a different shape.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (text-only change; no logic to test)

**Implementation Notes:**
- `README.md` rewritten: sharper tagline, new Features section listing all 12 process kinds + per-row signals + kill flow + settings.
- In-app copy (MenuBarView.swift, SettingsView.swift): no changes — already clean and accurate after PID-008/PID-011/PID-012 work.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (text-only change; no Swift modified)

- [x] Ran lint/type-check on changed code — N/A (markdown only)

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (not a UI change)

**Testing Notes:**
No code changed. README.md is the only modified file.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: updated (this task's deliverable). `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: updated (PID-13.4 stub → Completed 2026-06-24, added to ## Completed).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**
Rewrote `README.md`: sharper tagline, new Features section listing all 12 process kinds, per-row signals (CPU%/RAM/age/risk-tier dots/expandable "why" detail), kill flow, session dismiss, and settings summary. In-app copy reviewed across `MenuBarView.swift` and `SettingsView.swift` — already clean, no changes needed. One file changed: `README.md` (~25 lines added/rewritten).

**Archived:** 2026-06-24
