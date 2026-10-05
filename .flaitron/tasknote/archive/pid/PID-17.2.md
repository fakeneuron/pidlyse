---
title: makefile-test
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-17, PID-17.3]
---

# PID-17.2 | makefile-test

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-17]] [[PID-17.3]]

## 🎯 Goal

Add a repo-root `Makefile` with a `test` target that runs the Pidly test suite via `xcodebuild`, and document it in the README.

## ✅ Acceptance

- [x] `Makefile` exists at repo root with a `test` target
- [x] `make test` runs the `xcodebuild test` suite and passes
- [x] README documents the `make test` shortcut
- [x] No regression to existing build/test flow

## 🧩 Subtasks

- [x] Create repo-root `Makefile` with a `.PHONY` `test` target running the documented `xcodebuild test` command (full form with `-destination` + `CODE_SIGNING_ALLOWED=NO`)
- [x] Add a `make test` shortcut mention to README (under Build & Run)
- [x] Run `make test` and confirm the suite passes

## 🔗 Related

- [[PID-EPIC-17]] — parent epic (ci-gates): `make test` shortcut + GitHub Actions on push
- [[PID-17.3]] — follow-up: `.github/workflows/test.yml` runs `make test` on push (consumes this target)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** First implementation child of PID-EPIC-17 (ci-gates). A `make test` shortcut is the foundation PID-17.3's GitHub Actions workflow consumes. No Makefile exists yet.

- [x] Read relevant source files

- [x] **Archive skim** — no prior tasknote mentions `Makefile` or `make test` (genuinely new artifact). README.md appears in many archived tasknotes only via routine Phase-4 doc-drift sweeps. `xcodebuild test` appears in many tasknotes' testing phases — the canonical command form is authoritatively documented in `.flowtron/tasknote/README.md` §"Project quick commands".

- [x] **Drift check** — DRIFT FOUND: PLAN.md's terse command `xcodebuild test -scheme Pidly` lacks `-destination 'platform=macOS'` and `CODE_SIGNING_ALLOWED=NO`, both of which `.flowtron/tasknote/README.md` §"Project quick commands" marks as required for CLI test runs (code-signing limitation in this environment). The Makefile uses the documented working form, not PLAN.md's shorthand.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) Makefile uses the documented full test command form; (2) scope is the `test` target only — no `build`/`lint` targets added (stay surgical to the PLAN line); (3) README mention is a one-line addition under Build & Run.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- No Makefile and no `.github/` directory currently exist at repo root.
- `PidlyTests` target exists (`ScanEngineTests.swift`), scheme `Pidly`.
- Canonical test command (from tasknote README): `xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.
- Discovery surfaced no significant scope deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no existing Makefile to extend; new artifact. Used the standard `.PHONY` single-target shape. Test command form taken from the authoritative `.flowtron/tasknote/README.md` §"Project quick commands".

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (build-tooling change; no app logic touched, existing suite is the test)

**Implementation Notes:**

- `Makefile` (repo root): `.PHONY: test` target running `xcodebuild test -scheme Pidly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` with a comment pointing at the tasknote README for the code-signing rationale.
- `README.md`: one-line `make test` mention under Build & Run.
- Scope kept to the `test` target only (no `build`/`lint` targets) per the PLAN line.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → `** TEST SUCCEEDED **` (all `ScanEngineTests` pass)

- [x] Ran lint/type-check on changed code — Swift compiler type-checks during the test build; no separate linter

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no frontend/UI change)

**Testing Notes:**

- `make test` exercises the new target end-to-end and the full `ScanEngineTests` suite passes.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — UPDATED (added `make test` line under Build & Run)
  - `AGENTS.md` — no change (carries no build/test command section)
  - `CLAUDE.md` — UPDATED (added `make test` to Build section; the prior "no CLI build step" line is now contextualized by the CLI test entrypoint)
  - `.flowtron/PLAN.md` — UPDATED (PID-17.2 flipped to stub + moved to Completed)

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added a repo-root `Makefile` with a `.PHONY` `test` target running the documented `xcodebuild test` command, and documented the `make test` shortcut in README + CLAUDE.md. Resolved drift between PLAN.md's terse command and the working form (`-destination` + `CODE_SIGNING_ALLOWED=NO`). `make test` → `** TEST SUCCEEDED **`. Files: `Makefile` (new, 7 lines), `README.md` (+1 line), `CLAUDE.md` (+1 clause). First implementation child of PID-EPIC-17; unblocks PID-17.3 (CI workflow consumes `make test`).

**Archived:** 2026-06-25
