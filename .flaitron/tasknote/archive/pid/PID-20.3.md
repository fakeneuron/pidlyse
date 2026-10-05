---
title: dmg-package
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-20, PID-20.2]
---

# PID-20.3 | dmg-package

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-20]]

## 🎯 Goal

Add a `make dmg` target that packages the Release `.app` into a distributable DMG containing a symlink to `/Applications`, using `hdiutil` with no external dependencies.

## ✅ Acceptance

- [ ] `make dmg` produces `build/Pidly.dmg` from `build/Release/Pidly.app`
- [ ] The DMG contains `Pidly.app` and a symlink to `/Applications` so users can drag-install
- [ ] `make dmg` is `.PHONY` and follows the existing Makefile target style
- [ ] `make test` still passes after changes

## 🧩 Subtasks

- [ ] Add `dmg` to the `.PHONY` line in Makefile
- [ ] Write `dmg` target: staging dir → copy app → `ln -sf /Applications` → `hdiutil create -format UDZO` → remove staging dir
- [ ] Run `make dmg` and verify the DMG mounts with Pidly.app + Applications symlink, then dismounts cleanly
- [ ] Run `make test` to confirm no regressions

## 🔗 Related

- [[PID-EPIC-20]] — parent epic: dmg-release
- [[PID-20.2]] — predecessor: added `make build-release` (output at `build/Release/Pidly.app`)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Direct implementation of the `.3 dmg-package` scope from PID-20.1 Discovery. `hdiutil` approach confirmed, ad-hoc signing decision locked, no new questions.

- [x] Read relevant source files — `Makefile` (current: `.PHONY: test build-release install`, three targets), `PID-20.1.md` (DMG approach: hdiutil, no external deps, UDZO format), `PID-20.2.md` (build-release pattern: `.PHONY` extension, `SYMROOT=$(CURDIR)/build`, output confirmed at `build/Release/Pidly.app`).

- [x] **Archive skim** — PID-20.2.md is the load-bearing prior: established the `.PHONY`-extension pattern, full xcodebuild command style, and `build/Release/Pidly.app` as the canonical output path. No prior tasknote touched `hdiutil` or DMG creation.

- [x] **Drift check** — Makefile confirmed at `build/Release/Pidly.app` output path via PID-20.2 execution notes. `.PHONY: test build-release install` is current state. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) DMG output: `build/Pidly.dmg`; (2) staging approach: `build/dmg-staging/` temp dir — copy `.app`, `ln -sf /Applications`, then `hdiutil create`, then `rm -rf` staging; (3) `hdiutil` format `UDZO` (compressed read-only) for smallest artifact; (4) `-ov` flag to overwrite on repeated runs; (5) DMG itself not separately signed (app inside is ad-hoc signed by `make build-release`); (6) no prerequisite enforcement in the target itself (user runs `make build-release` first, same as `make install`).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- Makefile currently: `.PHONY: test build-release install` — `dmg` appends cleanly.
- `hdiutil create` approach:
  ```
  mkdir -p build/dmg-staging
  cp -R build/Release/Pidly.app build/dmg-staging/
  ln -sf /Applications build/dmg-staging/Applications
  hdiutil create -volname Pidly -srcfolder build/dmg-staging -ov -format UDZO build/Pidly.dmg
  rm -rf build/dmg-staging
  ```
- Volume name `Pidly` → mounts as `/Volumes/Pidly`.
- No external tools required — `hdiutil` is built into macOS.
- Discovery surfaced no significant deviation → skip 🛠️.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing `install` and `build-release` targets follow `.PHONY`-extension + one-line comment + single command. `dmg` uses the same shape with multi-step shell commands; `mkdir`/`cp`/`ln`/`hdiutil`/`rm` are all built-in. No external tool pattern in the codebase to extend — `hdiutil` is the macOS-native approach decided in PID-20.1.

- [x] Implemented the minimal solution — extended `.PHONY` line to include `dmg`; added `dmg` target with 5-step staging approach (mkdir, cp, ln, hdiutil create UDZO, rm staging).

- [x] Updated/added tests for non-trivial behavior — N/A (build-tooling change; no app logic touched)

**Implementation Notes:**

- `Makefile`: extended `.PHONY` line to `test build-release install dmg`; added 7 new lines (1 comment + 5 target lines + blank).
- Staging dir `build/dmg-staging/` is ephemeral — created and removed in the same target; idempotent on repeated runs via `-ov` flag on `hdiutil create`.
- DMG output: `build/Pidly.dmg` (281 KB compressed). Volume name `Pidly`.
- No changes to Swift source, entitlements, or project.pbxproj — purely additive Makefile change.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → `** TEST SUCCEEDED **` (51 tests, 0 failures)

- [x] Ran lint/type-check on changed code — N/A (Makefile only; Swift compiler type-checks during test build, no separate linter)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

- `make dmg` → `created: build/Pidly.dmg` (281 KB). DMG mounted at `/Volumes/Pidly`, confirmed contents: `Pidly.app` + `Applications` symlink. Detached cleanly.
- `make test` → 51 tests passing, no regressions.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — UPDATED: added `make dmg` to Build & Run section
  - `AGENTS.md` — no change
  - `CLAUDE.md` — UPDATED: added `make dmg` to Build section
  - `.flowtron/PLAN.md` — UPDATED: PID-20.3 flipped to stub form
  - `.flowtron/tasknote/README.md` §"Project quick commands" — UPDATED: added `make dmg` line

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (inline on conditional skip)

**Final Summary:**

Added `make dmg` to the Makefile: stages `build/Release/Pidly.app` + `/Applications` symlink into a temp dir, runs `hdiutil create -format UDZO`, cleans up staging. Produces `build/Pidly.dmg` (281 KB). DMG verified: mounts at `/Volumes/Pidly` with correct contents, detaches cleanly. `make test` → 51 tests passing. Updated README.md, CLAUDE.md, and tasknote README to reflect the new DMG packaging command.

**Archived:** 2026-06-25
