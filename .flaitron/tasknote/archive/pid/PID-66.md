---
title: ci-spine-shape
status: completed
tags: [ci, github-actions]
created: 2026-09-24
due:
related-tasks: []
touches:
  - .github/workflows/test.yml
---

# PID-66 | ci-spine-shape

[← PLAN.md](../PLAN.md) · ✅ Completed 2026-09-24

## 🎯 Goal

Bring `.github/workflows/test.yml` onto the fleet CI spine shape: a bare `pull_request:` trigger and a `concurrency` block, per natabula `docs/STACK-TENDENCIES.md` §"Continuous integration".

## ✅ Acceptance

- [x] `test.yml` triggers on both push-to-main and pull requests — `grep -qE '^  pull_request:\s*$' .github/workflows/test.yml`
- [x] `test.yml` has the fleet concurrency block — `grep -qF 'group: ci-${{ github.ref }}' .github/workflows/test.yml && grep -qF 'cancel-in-progress: true' .github/workflows/test.yml`
- [x] `test.yml` is still valid YAML — `ruby -ryaml -e "YAML.load_file('.github/workflows/test.yml')"` → 0
- [x] The out-of-scope SHA-pinned `actions/checkout` line is untouched — `grep -q 'actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1' .github/workflows/test.yml`

## 🧩 Subtasks

- [ ] Add a bare `pull_request:` trigger beside `push: {branches: [main]}` in `.github/workflows/test.yml`
- [ ] Add the `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }` block
- [ ] Verify YAML validity and that the checkout SHA pin is unchanged

## 🔗 Related

- Surfaced by natabula fleet audit 2026-09-12 at `5b80741`, routed by `NAT-254`.

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** `.github/workflows/test.yml` currently has only `push: {branches: [main]}` and no `concurrency` block — both gaps from the PLAN.md line are confirmed still present at HEAD. natabula `docs/STACK-TENDENCIES.md` §"Continuous integration" spine text matches the PLAN citation verbatim.

- [x] Read relevant source files — read `.github/workflows/test.yml` (12 lines, single `test` job: checkout + `make test`) and natabula `docs/STACK-TENDENCIES.md` §"Continuous integration" (Triggers, Concurrency spine bullets).

- [x] **Best Practices Review** — pure config addition (two workflow-level keys), no code boundary or abstraction to weigh. N/A.

- [x] **Archive skim** — `grep -l 'test\.yml' archive/pid/*.md` returned 8 hits (PID-17.2/.3/.N, PID-20.1/.4/.N, PID-35.1/.5), all from the `PID-EPIC-17` (ci-gates, established `test.yml`) and `PID-EPIC-35` (security sweep, SHA-pinned `actions/checkout`) cohorts. Load-bearing finding: PID-35.5 deliberately SHA-pinned `actions/checkout` to `34e114876b0b11c390a56381ad16ebd13914f8d5` (`# v4.3.1`) as a stricter-than-floor posture — confirms this PLAN line's explicit "not in scope" carve-out is correct and that pin must survive this edit untouched. No prior tasknote added a `pull_request` trigger or `concurrency` block to either `test.yml` or the sibling `release.yml` — clean slate, no conflicting precedent.

- [x] **Drift check** — PLAN.md line cites `:3-5` for the `push` trigger and `:11` for the checkout SHA; both match current `test.yml` line numbers exactly. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — **No clarifications needed.** The trigger and concurrency shapes are given verbatim by both the PLAN.md line and natabula's spine text; no design choice left open.

- [x] Subtasks above populated with concrete, ordered steps, and YAML `touches:` declared with the paths this task expects to edit (omit only on a task with no file deliverable)

**Discovery Notes:**

- `.github/workflows/test.yml` (12 lines): `on: push: {branches: [main]}`, single `test` job on `macos-latest`, SHA-pinned `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1` (`:11`), `make test` step.
- Sibling `.github/workflows/release.yml` also exists (tag-triggered) but is **not** named on this PLAN line — out of scope, left untouched.
- natabula spine text (verbatim): "**Triggers**: `push: {branches: [main]}` + bare `pull_request:` (run on main pushes and all PRs). One canonical form — don't invent per-repo variants." and "**Concurrency**: `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }` — kills redundant runs."

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extending the canonical natabula spine shape verbatim; no repo-specific variant to invent.

- [x] **Minimal refactor gate** — pure two-key config addition; no refactor.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A, CI config only, no testable behavior.

**Implementation Notes:**

- Added a bare `pull_request:` trigger beside `push: {branches: [main]}` (`:6`).
- Added `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }` (`:8-10`), expanded to block form for YAML readability (equivalent to the flow-mapping form cited on the PLAN line).
- Left the SHA-pinned `actions/checkout` step (`:16`) and the `test` job body entirely untouched.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A, CI config only, no Swift source changed.

- [x] Ran lint/type-check on changed code — N/A, no Swift linter/type-checker applies to a workflow YAML file; validated as well-formed YAML instead (see receipt).

- [x] **Verification receipt** — see below. No avoidable duplication, no dead code, no unnecessary public-surface growth, no stale code-facing documentation (pure CI-config addition).

- [x] **External review**

- [x] (frontend) Asked the user for visual confirmation — N/A, no UI/frontend surface touched.

**Choosing a test strategy:** see SPEC.md §"🧪 Phase 3: Testing & Linting".

**Testing Notes:**

- `grep -qE '^  pull_request:\s*$' .github/workflows/test.yml` → exit 0
- `grep -qF 'group: ci-${{ github.ref }}' .github/workflows/test.yml && grep -qF 'cancel-in-progress: true' .github/workflows/test.yml` → exit 0 (initial pass used a `{{ }}`-unsafe basic-regex `grep -q`, which silently failed since `{{`/`}}` are BRE interval-expression metacharacters; corrected the Acceptance criterion to `grep -qF` — fixed-string match)
- `ruby -ryaml -e "YAML.load_file('.github/workflows/test.yml')"` → exit 0, valid YAML
- `grep -q 'actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1' .github/workflows/test.yml` → exit 0, checkout pin unchanged
- `git status --porcelain` → only `.github/workflows/test.yml` modified, tasknote added — matches declared `touches:`
- **External review** (`/code-review medium`): returned 1 finding, in `Packages/PidlyseCore/Sources/PidlyseCore/ScanCore.swift:350` (`isShellSnapshotWrapper` duplicating `hasTokenBoundary`) — outside this task's `touches:` scope (pre-existing code from PID-072, not part of this diff, which is confined to `.github/workflows/test.yml`). Not graded against this task's Acceptance; not filed as a follow-up here since it's an existing task's code, not something this diff introduced or is responsible for. 0 findings against the actual diff.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (no CI-trigger/concurrency content). `AGENTS.md`: no change. `CLAUDE.md`: no change. `SPEC.md`: no change. `.flowtron/PLAN.md`: updated below (this closure).

- [x] Closed — every `## ✅ Acceptance` criterion ticked, YAML `status:` flipped to `completed`, PLAN.md line flipped to stub form and moved to top of `## Completed` (standalone task), tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] **Evidence-based recap** drafted — see Final Summary below

- [x] **Learnings** — N/A, no new pattern for the always-loaded layer; a routine fleet-spine sync.

**Final Summary:**

Brought `.github/workflows/test.yml` onto the fleet CI spine shape: added a bare `pull_request:` trigger beside `push: {branches: [main]}` and a `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }` block, per natabula `docs/STACK-TENDENCIES.md` §"Continuous integration". Confirmed genuinely missing in Discovery (archive skim of PID-EPIC-17/PID-EPIC-35 cohorts showed no prior tasknote had added either), and the deliberately out-of-scope SHA-pinned `actions/checkout` (PID-35.5, `:16`) verified untouched. Changed files: `.github/workflows/test.yml` (+6/-0 lines). No Swift source touched, no refactor. Verification: all 4 Acceptance commands pass (YAML valid, both new keys present, checkout pin unchanged) — one criterion's own verify command needed a mid-flight fix (`grep -q` → `grep -qF`, since `{{`/`}}` are BRE interval-expression metacharacters that silently no-op a basic-regex match). External review (`/code-review medium`) returned one finding, but in a pre-existing file (`ScanCore.swift`, from PID-072) entirely outside this task's `touches:` — 0 findings against the actual diff. Documentation verdict: no doc updates needed. `touches:` scope reconciliation: declared `[.github/workflows/test.yml]`; `git diff --name-only` matches exactly, plus this tasknote and the PLAN.md line flip. Maintainability effect: pidlyse's CI now runs on every PR (not just pushes to `main`) and cancels superseded runs on the same ref, matching the fleet standard natabula's 2026-09-12 audit (`NAT-254`) flagged as drift.

**Archived:** 2026-09-24
