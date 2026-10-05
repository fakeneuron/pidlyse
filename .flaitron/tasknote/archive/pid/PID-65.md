---
title: quality-stack-gaps
status: completed
tags: [justfile, dependabot, fleet-verbs]
created: 2026-09-23
due:
related-tasks: []
touches:
  - .github/dependabot.yml
  - justfile
  - Makefile
---

# PID-65 | quality-stack-gaps

[← PLAN.md](../PLAN.md) · ✅ Completed 2026-09-23

## 🎯 Goal

Adopt the missing fleet quality-stack items into Pidlyse: a security-only Dependabot config and a justfile coverage recipe, per natabula's STACK-TENDENCIES.md conventions.

## ✅ Acceptance

- [x] `.github/dependabot.yml` exists with an active `github-actions` security-only block (`open-pull-requests-limit: 0`) — `test -f .github/dependabot.yml && grep -q 'package-ecosystem: "github-actions"' .github/dependabot.yml` → 0
- [x] `just coverage` runs and exits 0 — `just coverage` → 0
- [x] Structural quality / no dead code — `judgment` — recipe additions only, no Swift source touched; confirmed by external review (0 findings)

## 🧩 Subtasks

- [x] Deposit `.github/dependabot.yml` (github-actions block active, security-updates-only; no npm/uv/swift ecosystem block — pidlyse's SwiftPM package has zero external dependencies)
- [x] Add a `coverage` target to `Makefile` (xcodebuild test with `-enableCodeCoverage YES` + `xccov view --report`, following the existing test/build/install/dmg delegation pattern)
- [x] Wire `just coverage` in `justfile` to delegate to `make coverage`
- [x] Verify `just coverage` runs clean

## 🔗 Related

- Routed by natabula `NAT-247.4` (NAT-EPIC-247 gap sweep, NAT-103.4 lazy backfill)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Confirmed neither gap has landed: no `.github/dependabot.yml` exists, and `justfile`'s `coverage` verb is absent. PLAN.md line and STACK-TENDENCIES.md citations both check out against current repo state.

- [x] Read relevant source files — read `justfile`, `Makefile`, `.gitignore`, natabula's `docs/STACK-TENDENCIES.md` §"Command interface" and §"Dependency updates", and natabula's canonical `configs/.github/dependabot.yml` template.

- [x] **Best Practices Review** — `justfile`/`Makefile` already establish the delegation pattern (justfile recipe → `make <verb>`) used by `test`/`build`/`install`/`dmg`; the new `coverage` verb extends that same shape rather than inventing a new one. `dependabot.yml` is a config deposit, no code boundary to weigh.

- [x] **Archive skim** — `grep -l -E 'justfile|dependabot|Makefile' archive/pid/*.md` returned ~16 hits (most are incidental Makefile mentions in unrelated tasknotes); read the one directly on point, [[PID-67]] (`typecheck-verb-missing`, today), which confirms `justfile` landed in `d966271` with no prior tasknote and that no dependabot work has ever touched this repo. No load-bearing prior decisions found.

- [x] **Drift check** — no drift. PLAN.md line, STACK-TENDENCIES.md §"Command interface" (`just coverage` verb) and §"Dependency updates" (security-only Dependabot) both match current repo state and current fleet doc content.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — **No clarifications needed.** Explicit assumption: STACK-TENDENCIES.md's `just coverage` row (`diff-cover` + `vitest`/`pytest --cov`) targets npm/uv stacks only and has no native-macOS-app precedent in the fleet; pidlyse already hand-authors non-standard recipe bodies for `lint`/`typecheck` (Swift compiler via `xcodebuild build`) per STACK-TENDENCIES.md's own "Non-standard repos hand-author bodies" carve-out, so `coverage` is adapted the same way: `xcodebuild test -enableCodeCoverage YES` + `xccov view --report`, giving a local coverage report without inventing a diff-cover/lcov pipeline this repo has no other language to share it with. Confirmed via web search that this is a judgment call, not a documented fleet pattern — flagging it in the recap for the operator to note if a different shape is later wanted.

- [x] Subtasks above populated with concrete, ordered steps, and YAML `touches:` declared with the paths this task expects to edit (omit only on a task with no file deliverable)

**Discovery Notes:**

- `.github/dependabot.yml` does not exist (only `.github/workflows/` present). No npm/uv/pip manifests in this repo; the sole dependency manifest is `Packages/PidlyseCore/Package.swift`, which declares zero external dependencies (no `dependencies:` array, no `Package.resolved`) and the `.xcodeproj` has no `XCRemoteSwiftPackageReference` — so no ecosystem block beyond the always-on `github-actions` one currently applies (confirmed `package-ecosystem: "swift"` exists and covers `.xcodeproj`-only SwiftPM manifests too, per GitHub's 2026-03-31 changelog, but there's nothing here for it to scan).
- `justfile` (created today by [[PID-67]]) has `setup`/`lint`/`typecheck`/`test`/`build`/`install`/`dmg` but no `coverage`. `Makefile` has `test`/`build-release`/`install`/`build-cli`/`install-cli`/`dmg`. `build/` is already gitignored.
- Confirmed `xcodebuild` and `xcrun xccov` are available in this environment.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the existing justfile→Makefile delegation shape (`test`/`build`/`install`/`dmg` all follow `just <verb>` → `make <verb>`); `coverage` follows the same shape rather than inlining an `xcodebuild` call directly in the justfile.

- [x] **Minimal refactor gate** — no refactor; pure additions (one Makefile target, one justfile recipe, one new config file).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A, config/recipe additions only, no Swift behavior changed.

**Implementation Notes:**

- Added `.github/dependabot.yml` (github-actions block active, security-updates-only; no npm/uv/swift ecosystem block needed today).
- Added `coverage:` target to `Makefile` — `xcodebuild test -enableCodeCoverage YES -resultBundlePath build/coverage.xcresult` then `xcrun xccov view --report`.
- Wired `just coverage` → `make coverage` in `justfile`, mirroring the existing `test`/`build`/`install`/`dmg` delegation pattern.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A, no Swift source changed; `just coverage` itself runs the full XCTest suite as part of verifying the new recipe (all green).

- [x] Ran lint/type-check on changed code — N/A for the config/recipe files themselves (no Swift linter/type-checker applies to `Makefile`/`justfile`/YAML); `.github/dependabot.yml` validated as well-formed YAML.

- [x] **Verification receipt** — see below. No avoidable duplication (coverage reuses the existing test-invocation shape), no dead code, no public-surface growth, no stale docs (`README.md` "Project quick commands" doesn't enumerate `just`/`make` targets exhaustively today, so no entry needed there).

- [x] (frontend) Asked the user for visual confirmation — N/A, no UI/frontend surface touched.

**Choosing a test strategy:** see SPEC.md §"🧪 Phase 3: Testing & Linting".

**Testing Notes:**

- `ruby -ryaml -e "YAML.load_file('.github/dependabot.yml')"` → exit 0, "YAML valid"
- `test -f .github/dependabot.yml && grep -q 'package-ecosystem: "github-actions"' .github/dependabot.yml` → exit 0
- `just coverage` → exit 0 (full XCTest suite passes with coverage instrumentation; `xccov view --report` prints per-file coverage, e.g. `Pidlyse.app 4.92% (134/2722)` — low overall app-target coverage is a pre-existing baseline, not something this task changes)
- `just --list` → shows `coverage` alongside the existing verbs, correctly ordered
- `git status --porcelain` → only `Makefile`, `justfile` modified and `.github/dependabot.yml`, tasknote added — matches declared `touches:`
- **External review** (`/code-review medium`, scoped to this task's diff): 0 findings. Reviewer specifically verified `CODE_SIGNING_ALLOWED=NO` carried over correctly from `test` into `coverage`, and that the Makefile backslash line-continuation has no trailing whitespace. No blockers, no notes to file.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (its "Project quick commands" / command sections don't enumerate `just`/`make` targets exhaustively — precedent set by [[PID-67]], which also added a fleet verb without touching README). `AGENTS.md`: no change (no command-interface content). `CLAUDE.md`: no change (no justfile/Makefile/dependabot content). `SPEC.md`: no change (no command-interface content). `.flowtron/PLAN.md`: updated below (this closure).

- [x] Closed — every `## ✅ Acceptance` criterion ticked, YAML `status:` flipped to `completed`, PLAN.md line flipped to stub form and moved to top of `## Low` closure target under `## Completed` (standalone task), tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] **Evidence-based recap** drafted — see Final Summary below

**Final Summary:**

Added `.github/dependabot.yml` (github-actions block, security-updates-only) and a `coverage` verb to the fleet command interface (`Makefile` `coverage:` target using `xcodebuild test -enableCodeCoverage YES` + `xccov view --report`, wired through `justfile`'s existing delegation pattern). Both were confirmed genuinely missing in Discovery and verified working in Phase 3 (`just coverage` exits 0, dependabot.yml is valid YAML with the expected block). Changed files: `Makefile` (+7 lines), `justfile` (+3 lines), `.github/dependabot.yml` (new, 20 lines) — no Swift source touched, no refactor needed or deferred. Documentation verdict: no doc updates needed (see doc-drift sweep). `touches:` scope reconciliation: declared `[.github/dependabot.yml, justfile, Makefile]`; `git diff --name-only` (plus untracked) matches exactly, plus this tasknote and the PLAN.md line flip (workflow files, not source). Maintainability effect: pidlyse now has a working local coverage signal and CVE-driven security-update PRs, closing two of the fleet quality-stack gaps routed by natabula NAT-247.4 — one judgment call is worth flagging for the operator: `just coverage` is a native-Xcode adaptation (xccov, not diff-cover) since STACK-TENDENCIES.md's diff-cover recipe has no npm/uv equivalent to run in this repo; it gives a full-suite coverage report today, not a changed-line gate wired into CI (CI wiring was outside this ticket's stated scope: "dependabot security-only, justfile coverage recipe").

**Archived:** 2026-09-23
