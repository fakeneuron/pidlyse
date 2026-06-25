---
title: kill-pidreuse
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-18, PID-004]
---

# PID-18.3 | kill-pidreuse

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-18]] [[PID-004]]

## 🎯 Goal

Close the PID-reuse TOCTOU race in `KillService.killPosix`: snapshot the target
process's start time before SIGTERM and only fire the SIGKILL fallback if the PID
still maps to the *same* process after the grace period.

## ✅ Acceptance

- [ ] `KillService` reads a process's start time (`kinfo_proc.kp_proc.p_starttime`) via `sysctl` before sending SIGTERM
- [ ] The SIGKILL fallback fires only when the post-grace start time matches the pre-SIGTERM snapshot (identical process); a mismatch (recycled PID) or a gone process skips SIGKILL
- [ ] The 2 s grace period is preserved unchanged (never skipped)
- [ ] Pure decision logic + the start-time reader are unit-tested
- [ ] `make test` passes

## 🧩 Subtasks

- [ ] Add `ProcStartTime` identity value + `startTime(of:)` sysctl reader to `KillService`
- [ ] Add pure `shouldEscalateToSIGKILL(snapshot:current:)` decision helper
- [ ] Wire snapshot-before-SIGTERM + guarded-SIGKILL into `killPosix`; remove now-unused `isAlive`
- [ ] Add `KillServiceTests` (pure decision matrix + `startTime(of:)` liveness) to `ScanEngineTests.swift`
- [ ] Run `make test`

## 🔗 Related

- [[PID-EPIC-18]] — parent epic: correctness gaps (this is the PID-reuse race child)
- [[PID-004]] — created the SIGTERM→2s→SIGKILL flow + EPERM handling this hardens

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** The race is real in current code — `killPosix` (KillService.swift:66-71)
  waits the grace period, then re-checks `isAlive(pid)` and SIGKILLs. Between SIGTERM and
  the SIGKILL the original process can exit and the kernel can recycle its PID for an
  unrelated process; `isAlive` would see *a* process and SIGKILL the bystander. Snapshotting
  start time as an identity token closes the TOCTOU window.

- [x] Read relevant source files

- [x] **Archive skim** — see Discovery Notes

- [x] **Drift check** — no drift: `kinfo_proc.kp_proc.p_starttime` field path is correct;
  `KillService.killPosix` exists (KillService.swift:57, `private static`); "add unit tests"
  matches the project's pure-helper testing convention.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

*Archive skim (sources in scope: `Pidly/KillService.swift`, `PidlyTests/ScanEngineTests.swift`):*
- **PID-004 (kill-hardening)** created the SIGTERM→2s→SIGKILL flow + EPERM silent-rescan.
  Notes line 64: "Process-already-gone already handled by `isAlive()`." My change folds that
  already-gone handling into the start-time reader (a gone PID returns `nil` → no SIGKILL).
- **PID-004:108 / PID-14.4:112** — the CLAUDE.md kill rule "SIGTERM first, SIGKILL fallback
  after 2 s — never skip the grace period" is load-bearing. This change preserves the grace
  period verbatim and only adds an *identity guard* on whether SIGKILL fires after it. No
  doc drift expected.
- PID-14.3 touched only docker-path doc comments; no overlap with the POSIX signal path.

*Pattern survey (informs Phase 2):* The codebase strongly favors small pure static helpers
(`ScanEngine.parsePSLine` / `parseElapsed` / `detectKind` / `riskTier`) tested directly,
with thin impure shell wrappers (`runPS`, `runShell`, `kill`) left untested. I'll mirror that:
extract a pure `shouldEscalateToSIGKILL(snapshot:current:)` + a thin `startTime(of:)` sysctl
reader (testable against `getpid()`), keeping the async `killPosix` shell minimal.

*Test placement:* `Pidly.xcodeproj/project.pbxproj` uses fixed-UUID groups (no
`PBXFileSystemSynchronizedRootGroup`), so a new test *file* would need pbxproj surgery.
`ScanEngineTests.swift` already hosts multiple concerns (ScanEngine + PortRegistry), so the
convention-matching, zero-pbxproj-risk choice is a new `KillServiceTests` XCTestCase class in
that same file.

**No clarifications needed.** Explicit assumptions:
1. Identity token = `(tv_sec, tv_usec)` of `p_starttime`; equality requires both fields equal.
2. Conservative on ambiguity — a missing snapshot OR a missing post-grace reading → do **not**
   escalate to SIGKILL (favor never killing an unverified/innocent PID; matches the app's
   never-kill-without-certainty ethos). A gone process (`current == nil`) needs no SIGKILL anyway.
3. Grace period stays 2 s, never skipped — only the SIGKILL *decision* is guarded.
4. `isAlive` becomes unused after this change (its sole caller is the guarded SIGKILL); remove it.
5. Tests live in a new `KillServiceTests` class inside `ScanEngineTests.swift` (no pbxproj edit).

→ Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

Mirrored `ScanEngine`'s pure-helper + thin-shell split (`KillService.swift`):
- Added `ProcStartTime: Equatable` identity value + `startTime(of:)` — a thin `sysctl`
  reader over `[CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]` returning `kp_proc.p_starttime`
  as `(sec, usec)`; `nil` when the kernel returns a zero-length result (unknown PID).
- Added pure `shouldEscalateToSIGKILL(snapshot:current:)` — escalate only when both
  readings present AND equal; missing/mismatched → no escalation.
- `killPosix` now snapshots `startTime(of: pid)` before SIGTERM and replaces the old
  `isAlive(pid)` post-grace check with `shouldEscalateToSIGKILL(...)`. The 2 s grace
  period is byte-for-byte unchanged.
- Removed `isAlive` — its sole caller was the post-grace check; the start-time reader now
  covers liveness (gone PID → `nil`). No other references (confirmed by grep).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no UI change)

**Testing Notes:**

`make test` → **TEST SUCCEEDED**, 51 tests, 0 failures (was 42; +9 new `KillServiceTests`).
New tests: 6-case `shouldEscalateToSIGKILL` decision matrix (same / mismatch / usec-near-miss /
current-gone / snapshot-missing / both-missing) + 3 `startTime(of:)` liveness checks
(`getpid()` non-nil, stable across two reads, beyond-`maxproc` PID → nil). Build compiled
clean; no SwiftLint config in the project. Editor SourceKit warnings (`XCTest` / `ProcessItem`
not found) are indexer noise — the `xcodebuild` compile succeeded.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — no change (the line-14 "SIGTERM → 2 s → SIGKILL" description still holds; the guard is internal)
  - `AGENTS.md` — no change (no kill-flow refs)
  - `CLAUDE.md` — no change (the "SIGTERM first, SIGKILL fallback after 2 s — never skip the grace period" non-negotiable is preserved verbatim)
  - `.flowtron/PLAN.md` — flipped this task's line to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Closed the PID-reuse TOCTOU race in `KillService.killPosix`. The kill path now snapshots the
target's start time (`kinfo_proc.kp_proc.p_starttime`, via `sysctl`) before SIGTERM and, after
the unchanged 2 s grace period, only escalates to SIGKILL when the re-read start time is
identical — so a recycled PID (original exited, kernel reassigned the number) or an
already-gone process is never SIGKILLed. Extracted as a pure decision helper
(`shouldEscalateToSIGKILL`) + a thin `sysctl` reader (`startTime(of:)`), mirroring
`ScanEngine`'s pure-helper/thin-shell convention; removed the now-unused `isAlive`. Added
`KillServiceTests` (9 tests). `make test` → 51 passing.

**Archived:** 2026-06-25
