---
title: ci-actions
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-17, PID-17.2]
---

# PID-17.3 | ci-actions

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-17]] [[PID-17.2]]

## 🎯 Goal

Add a `.github/workflows/test.yml` GitHub Actions workflow that runs `make test` on a macOS runner on push to `main`.

## ✅ Acceptance

- [x] `.github/workflows/test.yml` exists, runs on push to `main`
- [x] Workflow runs on a macOS runner and invokes `make test`
- [x] The `Pidly` scheme resolves on a headless CI checkout (scheme shared — `xcshareddata/xcschemes/Pidly.xcscheme`)
- [x] Workflow YAML is valid and minimal (no speculative extra jobs/steps)

## 🧩 Subtasks

- [x] Share the `Pidly` scheme: commit `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme` so CI resolves it deterministically
- [x] Add `.github/workflows/test.yml`: `on: push: branches: [main]`, `runs-on: macos-latest`, checkout + `make test`
- [x] Verify the shared scheme drives the test action (`make test` passes locally with it present)
- [x] Validate workflow YAML

## 🔗 Related

- [[PID-EPIC-17]] — parent epic (ci-gates): `make test` shortcut + GitHub Actions on push
- [[PID-17.2]] — predecessor: added the `make test` target this workflow consumes

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Second implementation child of PID-EPIC-17 (ci-gates). PID-17.2 landed the `make test` target; this task wires it into GitHub Actions on push. No `.github/` directory exists yet.

- [x] Read relevant source files

- [x] **Archive skim** — PID-17.2 (`makefile-test`) is the direct predecessor: it created the `Makefile` `test` target using the documented full command form (`-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`). No prior tasknote touches `.github/` (genuinely new artifact).

- [x] **Drift check** — DRIFT/BLOCKER surfaced: the `Pidly` scheme is **not shared** — there is no `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme`. It currently resolves only via xcodebuild's autocreate behavior. On a headless CI checkout autocreation generally still works, but the deterministic/standard practice is to commit a shared scheme. Surfaced to user.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  See Discovery Notes — asked about scheme-sharing strategy and trigger scope.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- No `.github/` directory exists; this is a new artifact.
- `make test` runs `xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` (Makefile, repo root). `CODE_SIGNING_ALLOWED=NO` already handles the CI code-signing limitation.
- Local Xcode is 26.4; GitHub `macos-latest` runners are Apple Silicon and ship a recent Xcode. Project targets macOS 13+, plain SwiftUI — default runner Xcode should build it. Not pinning Xcode (avoids over-engineering; can revisit if CI fails).
- No `.gitignore` exists (out of scope for this task; `.DS_Store` noise noted but not addressed here).
- Scheme-sharing finding (drift check) is the one genuine decision — see clarifying questions.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no existing workflow or shared scheme to extend (both new). Scheme mirrors Xcode's standard autocreated app+unit-test shape; workflow uses a standard single-job macOS CI pattern. `make test` command form inherited from PID-17.2's Makefile.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (CI/build-tooling change; the existing `ScanEngineTests` suite is what CI runs)

**Implementation Notes:**

- `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme` (new) — shared scheme with Build + Test (PidlyTests) + Launch/Profile/Analyze/Archive actions, blueprint IDs `B101` (Pidly.app) / `B11E` (PidlyTests.xctest) read from `project.pbxproj`. First draft used `<TestableElement>` and failed with "Scheme Pidly is not currently configured for the test action"; corrected to the canonical `<Testables>` → `<TestableReference>` wrapper.
- `.github/workflows/test.yml` (new) — `on: push: branches: [main]`, single `test` job on `runs-on: macos-latest`, `actions/checkout@v4` + `make test`.
- Not pinning Xcode on the runner (default macos-latest Xcode builds plain SwiftUI / macOS 13+ target); revisit only if CI fails.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` with the shared scheme present → `** TEST SUCCEEDED **` (38 `ScanEngineTests` pass). Confirms the shared scheme drives the test action.

- [x] Ran lint/type-check on changed code — workflow YAML: no tabs (valid indent); scheme XML validated by xcodebuild loading it for the test run

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no frontend/UI change)

**Testing Notes:**

- The shared scheme now takes precedence over autocreation; `xcodebuild -list` shows `Pidly` and `make test` exercises PidlyTests through it end-to-end.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — UPDATED (one-line CI note under Build & Run: suite runs on push to `main` via GitHub Actions)
  - `AGENTS.md` — no change (no build/CI command section)
  - `CLAUDE.md` — no change (`make test` already documented; CI is automation, not a new dev command)
  - `.flowtron/PLAN.md` — UPDATED (PID-17.3 child line removed from open PID-EPIC-17 block, flipped to stub + added to Completed; epic parent stays open — PID-17.N audit remains)

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added a `.github/workflows/test.yml` GitHub Actions workflow (single `test` job on `macos-latest`, `actions/checkout@v4` + `make test`) triggered on push to `main`. Discovery surfaced that the `Pidly` scheme was not shared (autocreate-only), which would make headless CI scheme resolution non-deterministic; per user decision, committed a shared `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme` (Build + Test/PidlyTests + standard actions). Fixed an initial malformed `<TestableElement>` → canonical `<Testables>`/`<TestableReference>`; `make test` then passed through the shared scheme (`** TEST SUCCEEDED **`, 38 tests). Triggers kept to push-to-main per the PLAN line. Files: `.github/workflows/test.yml` (new, 12 lines), `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme` (new), `README.md` (+1 clause). Second implementation child of PID-EPIC-17; only PID-17.N (audit) remains before the epic closes.

**Archived:** 2026-06-25
