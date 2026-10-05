---
title: build-install
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-20]
---

# PID-20.2 | build-install

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-20]]

## 🎯 Goal

Add `make build-release` (Release config, ad-hoc signed) and `make install` (copies to /Applications) Makefile targets.

## ✅ Acceptance

- [ ] `make build-release` produces a Release `.app` bundle under `build/Release/` with ad-hoc signing (`CODE_SIGN_IDENTITY="-"`)
- [ ] `make install` copies the built `.app` to `/Applications/` (requires prior `build-release` or prompts the user)
- [ ] Both targets are `.PHONY` and integrate cleanly with the existing `test` target style
- [ ] `make test` still passes after changes

## 🧩 Subtasks

- [ ] Survey existing `xcodebuild` flags used in the `test` target for consistent style
- [ ] Add `build-release` target: `xcodebuild build -scheme Pidly -configuration Release CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO` with output to `build/Release/`
- [ ] Add `install` target: `cp -R build/Release/Pidly.app /Applications/`
- [ ] Verify `make build-release` produces the `.app` at the expected path
- [ ] Run `make test` to confirm no regressions

## 🔗 Related

- [[PID-EPIC-20]] — parent epic: dmg-release

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Direct implementation of the scoped targets from PID-20.1 Discovery. No ambiguity — signing approach, output path, and install mechanism all resolved.

- [x] Read relevant source files — `Makefile` (current, single `test` target), `Pidly.xcscheme` (`ArchiveAction buildConfiguration = "Release"` already wired), `PID-20.1.md` (ad-hoc signing decision), `PID-17.2.md` (Makefile pattern).

- [x] **Archive skim** — PID-17.2.md is the load-bearing prior: established `.PHONY` pattern, `xcodebuild test` full-form command, and `$(CURDIR)` not used (test doesn't need SYMROOT). No prior tasknote touched `build-release`, `install`, or `SYMROOT`. `archive/pid/` has no other hits for those terms.

- [x] **Drift check** — `Makefile` confirmed at repo root with single `test` target. Task description accurate; no drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) `CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual` for ad-hoc signing (overrides project's `Automatic` which has no team); (2) `SYMROOT=$(CURDIR)/build` → output at `build/Release/Pidly.app`; (3) `install` and `build-release` are independent targets (no implicit dependency chain); (4) `ditto` for install target (macOS-native, handles app bundle atomicity).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- Makefile currently: `.PHONY: test` only. Both new targets append cleanly.
- `build-release` approach: `xcodebuild build -scheme Pidly -configuration Release CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build` → produces `build/Release/Pidly.app`.
- `install` approach: `ditto build/Release/Pidly.app /Applications/Pidly.app` — ditto replaces in-place cleanly; `cp -R` risks merging into existing bundle.
- Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing `test` target: `.PHONY` declaration, xcodebuild invocation, one-line comment. New targets follow the same shape. `ditto` used for install (macOS-native app-bundle atomicity; `cp -R` risks merge into existing bundle).

- [x] Implemented the minimal solution — added `build-release` and `install` to `.PHONY`, `build-release` target with `xcodebuild build -scheme Pidly -configuration Release CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build`, `install` target with `ditto build/Release/Pidly.app /Applications/Pidly.app`.

- [x] Updated/added tests — N/A (build-tooling change; no app logic touched, existing suite is the test)

**Implementation Notes:**

- `Makefile`: extended `.PHONY` line to `test build-release install`; added 5 new lines (2 targets + continuation line + blank separators).
- No changes to Swift source, entitlements, or project.pbxproj — purely additive Makefile change.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → `** TEST SUCCEEDED **` (51 tests, 0 failures)

- [x] Ran lint/type-check on changed code — N/A (Makefile only; Swift compiler type-checks during test build, no separate linter)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

- `make build-release` → `** BUILD SUCCEEDED **`; `build/Release/Pidly.app` confirmed at expected path.
- `make test` passes with no regressions (51 tests).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — UPDATED: added `make build-release` / `make install` mention in Build & Run
  - `AGENTS.md` — no change
  - `CLAUDE.md` — UPDATED: removed "no CLI build step" (now there is one); added `make build-release` + `make install` to Build section
  - `.flowtron/PLAN.md` — UPDATED: PID-20.2 flipped to stub form
  - `.flowtron/tasknote/README.md` §"Project quick commands" — UPDATED: Build line updated to `make build-release` as canonical Release shorthand

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/PID-20.2.md`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added `make build-release` (ad-hoc signed Release build → `build/Release/Pidly.app`) and `make install` (`ditto` to `/Applications/Pidly.app`) to the Makefile. Both verified: `make build-release` → `** BUILD SUCCEEDED **`, `make test` → 51 tests passing. Updated README.md, CLAUDE.md, and tasknote README to reflect the new CLI build surface.

**Archived:** 2026-06-25
