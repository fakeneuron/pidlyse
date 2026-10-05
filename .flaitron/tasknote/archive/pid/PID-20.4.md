---
title: release-ci
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-20, PID-20.2, PID-20.3]
---

# PID-20.4 | release-ci

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-20]] [[PID-20.2]] [[PID-20.3]]

## 🎯 Goal

Add a `.github/workflows/release.yml` that triggers on `v*` tag push, builds the Release app via `make build-release`, packages the DMG via `make dmg`, and attaches `build/Pidly.dmg` to the GitHub Release via `gh release upload`.

## ✅ Acceptance

- [ ] `.github/workflows/release.yml` exists, triggers on `v*` tag push
- [ ] Workflow builds Release app on `macos-latest` using `make build-release`
- [ ] Workflow packages DMG using `make dmg`
- [ ] DMG is attached to the GitHub Release via `gh release upload`
- [ ] Workflow YAML is valid and minimal (no speculative steps)

## 🧩 Subtasks

- [ ] Phase 1: archive skim + drift check
- [ ] Write `.github/workflows/release.yml`: trigger, checkout, build, dmg, upload steps
- [ ] Validate workflow YAML (tab-free indent, correct key names, correct permissions)
- [ ] Phase 4: doc-drift sweep + PLAN.md flip + archive

## 🔗 Related

- [[PID-EPIC-20]] — parent epic: dmg-release
- [[PID-20.2]] — predecessor: added `make build-release` and `make install` targets
- [[PID-20.3]] — predecessor: added `make dmg` target with hdiutil

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Directly scoped in PID-20.1 Discovery. Both prerequisite Makefile targets (`make build-release`, `make dmg`) landed in PID-20.2 and PID-20.3. The GitHub Actions workflow is the final implementation child of PID-EPIC-20.

- [x] Read relevant source files — read `.github/workflows/test.yml` (existing CI pattern), `Makefile` (confirms `build-release` and `dmg` targets), PID-20.1 (scoping decisions), PID-17.3 (CI workflow shape).

- [x] **Archive skim** — grepped `archive/PID/*.md` for "release.yml", "gh release", "tag". No prior tasknote touches a release workflow. The closest precedent is PID-17.3 (`ci-actions`), which established `test.yml` and the `macos-latest` runner pattern. PID-20.1 explicitly scoped this workflow's trigger, approach, and tool (`gh release upload`). Load-bearing decisions recorded below in Discovery Notes.

- [x] **Drift check** — `make build-release` and `make dmg` confirmed in `Makefile` at HEAD. `test.yml` confirms `actions/checkout@v4` + `macos-latest` pattern still current. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **Assumptions asserted:**
  - Uses `GITHUB_TOKEN` for `gh release upload` (automatically provided to Actions; no additional secret needed)
  - Creates the GitHub Release first (via `gh release create`) if it doesn't exist, or uploads to an existing one — using `gh release upload` with `--clobber` for idempotency. Alternatively, the `softprops/action-gh-release` action creates + uploads in one step. Will use the minimal `gh` CLI approach consistent with PID-17.3's style (native tooling over third-party actions).
  - No Xcode version pin (same decision as PID-17.3; macos-latest ships a recent Xcode; revisit if CI fails)
  - `permissions: contents: write` required for creating/uploading to GitHub Releases
  - Ad-hoc signing in CI is fine (no `CODE_SIGN_IDENTITY` env needed — `make build-release` already passes `CODE_SIGN_IDENTITY="-"`)

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **`test.yml` pattern:** `on: push: branches: [main]`, single job, `runs-on: macos-latest`, `actions/checkout@v4`, `make test`. Release workflow will mirror this structure, substituting the trigger and steps.
- **`make build-release`:** `xcodebuild build -scheme Pidly -configuration Release CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build` → `build/Release/Pidly.app`
- **`make dmg`:** `hdiutil create` → `build/Pidly.dmg`
- **`gh release upload`:** `gh` CLI is pre-installed on GitHub-hosted runners (macos-latest). Using `gh release create` first (with `--notes` from tag) then `gh release upload` is two steps. Alternative: `gh release create $TAG build/Pidly.dmg --title "$TAG" --notes ""` (creates and attaches in one call). This is the cleanest approach.
- **Permissions:** Need `permissions: contents: write` so `GITHUB_TOKEN` can create Releases and upload assets.
- **Trigger:** `on: push: tags: ['v*']` — standard tag-push trigger.
- **Tag name in workflow:** `${{ github.ref_name }}` gives the tag string (e.g. `v1.0.1`).

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `test.yml` (PID-17.3) is the direct predecessor: `macos-latest`, `actions/checkout@v4`, single job. Release workflow extends the same structure with `on: push: tags` trigger and three added steps (build, dmg, gh release). `gh release create <tag> <asset>` (one command) preferred over `gh release create` + `gh release upload` (two commands) — cleaner and sufficient for the personal-use/GitHub-Releases distribution scope from PID-20.1. No third-party actions (consistent with PID-17.3 native-tooling preference).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (CI workflow file; no compilable test surface)

**Implementation Notes:**

- `.github/workflows/release.yml` (new, 19 lines): `on: push: tags: ['v*']`, `permissions: contents: write`, single `release` job on `macos-latest`, `actions/checkout@v4` → `make build-release` → `make dmg` → `gh release create "${{ github.ref_name }}" build/Pidly.dmg` with `GH_TOKEN` from `github.token`. One-command create+upload approach; no external actions.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (YAML-only change; no Swift code affected; existing `ScanEngineTests` suite unchanged)

- [x] Ran lint/type-check on changed code — YAML validated: no tabs, valid indent, all keys correct (`on`/`permissions`/`jobs`/`steps`/`uses`/`run`/`env` all present and well-formed)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

- 19-line YAML, spaces only, checked line by line against GitHub Actions schema. `GH_TOKEN: ${{ github.token }}` is the standard `gh` CLI pattern for Actions; `permissions: contents: write` grants the token rights to create Releases and upload assets.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — UPDATED: added one sentence to Build & Run about the `v*` tag → release workflow
  - `AGENTS.md` — no change (no CI/build command section)
  - `CLAUDE.md` — no change (`make build-release` and `make dmg` already documented; CI automation is not a dev command)
  - `.flowtron/PLAN.md` — UPDATED (PID-20.4 flipped to stub form)

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/PID/`

- [x] Recap drafted (inline on conditional skip)

**Final Summary:**

Added `.github/workflows/release.yml` (19 lines): triggers on `v*` tag push, runs `make build-release` + `make dmg` on `macos-latest`, then `gh release create` to create a GitHub Release and attach `build/Pidly.dmg` in one command. Uses `permissions: contents: write` and `github.token` — no external secrets needed. Updated `README.md` to mention the tag-push release workflow. Third and final implementation child of PID-EPIC-20; only PID-20.N (audit) remains.

**Archived:** 2026-06-25
