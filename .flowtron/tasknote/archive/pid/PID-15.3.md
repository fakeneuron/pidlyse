---
title: tasknote-readme-cmds
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-15]
---

# PID-15.3 | tasknote-readme-cmds

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-15]]

## 🎯 Goal

Replace the generic Quick Commands stub in `.flowtron/tasknote/README.md` with correct xcodebuild invocations and document the `CODE_SIGNING_ALLOWED=NO` requirement for CLI test runs.

## ✅ Acceptance

- [ ] Quick Commands section has correct `xcodebuild` invocations (build + test)
- [ ] `CODE_SIGNING_ALLOWED=NO` flag documented for CLI test runs
- [ ] No placeholder / generic stub text remains

## 🧩 Subtasks

- [x] Replace "Project quick commands" section in `.flowtron/tasknote/README.md` with correct xcodebuild invocations (build + test) and `CODE_SIGNING_ALLOWED=NO` note
- [x] Verify no generic stub text remains

## 🔗 Related

- [[PID-EPIC-15]] — parent epic: doc-sync

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Confirmed. `.flowtron/tasknote/README.md` §"Project quick commands" still contains the generic flowtron-template stub (pytest/npm/ruff/`npm run dev`). None of these apply to a Swift/Xcode project. Task is accurate and scoped correctly.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Archive skim:** Multiple prior tasknotes (PID-002, PID-004, PID-007, PID-008) used `xcodebuild test -scheme Pidly -destination 'platform=macOS'` as the canonical test invocation. PID-011 first documented `CODE_SIGNING_ALLOWED=NO` as a required flag for CLI test runs — described as "pre-existing infrastructure issue; suppressed with the flag." The scheme is `Pidly` (not `PidlyTests`), which runs all unit tests. Build check: `xcodebuild build -scheme Pidly`. No separate lint tool; Swift compiler surfaces all type/compile errors.
- **Drift check:** Generic stub still present exactly as expected. Scheme name `Pidly` confirmed via `xcschememanagement.plist`. Test target `PidlyTests` confirmed in `project.pbxproj`. The `xcodebuild` invocations in the archives are consistent and accurate.
- **No clarifications needed.** Assumptions: (1) build cmd is `xcodebuild build -scheme Pidly`; (2) test cmd is `xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`; (3) no dev-server entry needed (menu bar app, no web component); (4) no separate lint step — compiler is the type-checker.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — doc-only edit; no code pattern needed; existing README.md format extended in place

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — doc-only; no tests applicable

**Implementation Notes:**

- `.flowtron/tasknote/README.md` §"Project quick commands": replaced 7-line generic stub with 4-line xcodebuild block covering build, test (with `CODE_SIGNING_ALLOWED=NO` note), and type-check.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — doc-only; no test suite applicable

- [x] Ran lint/type-check on changed code — markdown only; no compiler/linter applicable

- [x] (frontend) Asked the user for visual confirmation — not applicable (no frontend changes)

**Testing Notes:**

Verified the updated section against archive evidence: build/test invocations match the forms used in PID-002, PID-004, PID-007, PID-011. `CODE_SIGNING_ALLOWED=NO` wording matches PID-011 note. No generic stub text remains.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: line flipped to stub form below.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Replaced the generic flowtron-template Quick Commands stub in `.flowtron/tasknote/README.md` with correct xcodebuild invocations: `xcodebuild build -scheme Pidly` for build/type-check, and `xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` for tests, with an inline note explaining the `CODE_SIGNING_ALLOWED=NO` requirement (pre-existing code-signing limitation first documented in PID-011). No code changes.

**Archived:** 2026-06-24
