---
title: gitignore — Swift/Xcode .gitignore + untrack user-state
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-19, PID-19.3, PID-19.N]
---

# PID-19.2 | gitignore — Swift/Xcode .gitignore + untrack user-state

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-19]]

## 🎯 Goal

Add a Swift/Xcode `.gitignore` and stop tracking the per-user Xcode state files that should never have been committed.

## ✅ Acceptance

- [ ] `.gitignore` exists at repo root covering `xcuserdata/`, `*.xcuserstate`, `.DS_Store`, `DerivedData/` (+ build/ and standard Xcode noise)
- [ ] The two tracked user-state files are removed from the index (`git rm --cached`) but kept on disk
- [ ] `git status` shows the user-state files and `.DS_Store` are no longer tracked / untracked-and-ignored
- [ ] No source or app behavior changes

## 🧩 Subtasks

- [ ] Write `.gitignore` at repo root with the Swift/Xcode patterns
- [ ] `git rm --cached` the two tracked Xcode user-state files
- [ ] Verify `git status` — files now ignored, working tree clean of them

## 🔗 Related

- [[PID-EPIC-19]] — parent epic (repo-hygiene + SPEC doc-sync)
- [[PID-19.3]] — sibling: SPEC.md scan-interval / table drift fix
- [[PID-19.N]] — epic audit + doc-drift sweep

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** No `.gitignore` exists; two per-user Xcode state files are tracked (`UserInterfaceState.xcuserstate`, `xcschememanagement.plist`) and `.DS_Store` is untracked-and-uncommitted. Exactly the hygiene gap the task describes — still the right work.

- [x] Read relevant source files

- [x] **Archive skim** — no prior PID tasknote touched `.gitignore` or repo-root tracking config (grep of `archive/pid/*.md` for `gitignore` / `xcuserstate` returned no load-bearing hits). No prior decisions to honor.

- [x] **Drift check** — confirmed against current tree: no `.gitignore` present; `git ls-files` shows exactly the two user-state files named in the task; `.DS_Store` present as untracked (`??`). Task description matches reality. One refinement: `.DS_Store` is not yet tracked, so it needs only the ignore rule, not a `git rm --cached`.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: use a standard Swift/Xcode `.gitignore` (GitHub `Swift.gitignore` + Xcode user-data patterns); keep files on disk (`--cached`, not a hard rm); do not touch `.flowtron/` tracking.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- Tracked files to untrack:
  - `Pidly.xcodeproj/project.xcworkspace/xcuserdata/fakeneuron.xcuserdatad/UserInterfaceState.xcuserstate`
  - `Pidly.xcodeproj/xcuserdata/fakeneuron.xcuserdatad/xcschemes/xcschememanagement.plist`
- Both live under `xcuserdata/`, so the `xcuserdata/` rule covers them going forward.
- Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no existing `.gitignore` in repo; used the canonical GitHub Swift/Xcode template shape (macOS + Xcode user-state + build artifacts + SPM).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (no code; pure repo-hygiene config)

**Implementation Notes:**

- Created repo-root `.gitignore` covering: `.DS_Store`; `xcuserdata/` + `*.xcuserstate`; `DerivedData/` + `build/` + dSYM/hmap noise; SPM `.build/` + `.swiftpm/`.
- `git rm --cached` on the two tracked files; both remain on disk (verified with `ls`).
- `git check-ignore -v` confirms all three (the two user-state files + `.DS_Store`) now match ignore rules; `git ls-files` shows no remaining user-state tracking.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (no Swift source touched)

- [x] Ran lint/type-check on changed code — N/A (no compilable change)

- [x] (frontend) Asked the user for visual confirmation — N/A (not frontend)

**Testing Notes:** Verification was git-state based: `git status`, `git check-ignore -v`, `git ls-files`. No build/test impact — `.gitignore` and index untracking do not alter the app or its sources.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change · `AGENTS.md`: no change · `CLAUDE.md`: no change · `.flowtron/PLAN.md`: line flipped (closure action below).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (inline on conditional skip)

**Final Summary:** Added repo-root `.gitignore` (Swift/Xcode: `.DS_Store`, `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `build/`, SPM) and untracked the two committed per-user Xcode state files via `git rm --cached` (kept on disk). Verified with `git check-ignore -v` / `git ls-files` — no user-state remains tracked, `.DS_Store` now ignored. No source or app-behavior changes.

**Archived:** 2026-06-25
