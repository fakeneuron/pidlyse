---
title: scanengine-persistence
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-16, PID-16.1]
---

# PID-16.4 | scanengine-persistence

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-16]]

## 🎯 Goal

Eliminate spurious `startTimer()` calls in `ScanEngine.init` by assigning persisted values via backing storage (`_prop = Published(wrappedValue:)`) instead of through the `@Published` setters that trigger `didSet`; no observable behaviour change.

## ✅ Acceptance

- [ ] `startTimer()` is called exactly once in `init()` (at the end)
- [ ] All four persisted values still load from UserDefaults on first launch
- [ ] `notificationsEnabled.didSet` auth-request behaviour preserved
- [ ] No tests broken; no other files touched

## 🧩 Subtasks

- [ ] Read `ScanEngine.swift` `init()` block and confirm current double-startTimer path
- [ ] Rewrite `init()`: read all four UserDefaults keys into locals first, then assign via `_prop = Published(wrappedValue:)` for `elapsedThreshold`/`ignoredNames`/`scanInterval`; keep normal assignment for `notificationsEnabled` to preserve `didSet` auth-request
- [ ] Verify `startTimer()` now called once at end of init
- [ ] Build passes (Xcode ⌘B)

## 🔗 Related

- [[PID-EPIC-16]] — parent epic: code-quality
- [[PID-16.1]] — discovery: confirmed double-startTimer and recommended `_prop` backing-storage approach

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Problem confirmed in `ScanEngine.swift` init() lines 62-71: `scanInterval = savedInterval` triggers `didSet → startTimer()`, then `startTimer()` is called again explicitly. Fix is exactly as scoped in PID-16.1. No drift found.

- [x] Read relevant source files

- [x] **Archive skim** — PID-16.1 confirmed the fix approach: assign via backing storage or `_scanInterval.wrappedValue` style. No other prior tasknotes add load-bearing constraints for this specific change.

- [x] **Drift check** — `ScanEngine.init()` lines 62-71 match the PID-16.1 discovery description exactly. `startTimer()` is called at line 70 (via `scanInterval.didSet`) and again at line 71 explicitly. All four persisted keys confirmed: `elapsedThreshold`, `ignoredNames`, `scanInterval`, `notificationsEnabled`.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions
  - Assumption: `notificationsEnabled.didSet` auth-request on startup is intentional (requesting auth on launch if notifications were previously enabled is harmless — OS won't re-show dialog if already granted/denied).
  - Assumption: The three non-notification properties' `didSet` write-back to UserDefaults during init (writing back the same values just read) is wasteful but the task asks to fix it by using `_prop` assignment.
  - Assumption: `Published(wrappedValue:)` initializer is correct Swift API for bypassing didSet (confirmed for Swift 5.7+ which macOS 13+ target implies).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Double-startTimer path:** `scanInterval = savedInterval` (line 68) → `didSet` → `startTimer()` (timer 1). Then explicit `startTimer()` at line 71 (timer 2). Timer 1 is immediately invalidated by timer 2 but wastes a Timer object allocation.
- **Fix approach:** In `init()`, read all four values into locals first, then assign via `_elapsedThreshold`, `_ignoredNames`, `_scanInterval` (backing storage, no didSet), keep `notificationsEnabled = true` as normal assignment (preserves didSet auth-request), then call `startTimer()` once.
- **`notificationsEnabled` exception:** Must keep as normal assignment because its `didSet` requests notification authorization — that side effect is observable and must be preserved.
- Discovery surfaced no significant scope deviation → skip 🛠️.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `_prop = Published(wrappedValue:)` backing-storage bypass is the established Swift pattern for avoiding `didSet` in `init`; recommended in PID-16.1 discovery. No new shape needed.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — pure init refactor; all 38 existing tests cover the affected paths; no new test surface needed.

**Implementation Notes:**

Rewrote `ScanEngine.init()` to read all four UserDefaults keys into locals first, then assign via `_elapsedThreshold`, `_ignoredNames`, `_scanInterval` (backing storage, bypasses `didSet`). `notificationsEnabled` kept as a normal assignment to preserve its `didSet` auth-request side effect. `startTimer()` now called exactly once at the end of `init()`.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — all 38 `ScanEngineTests` passed

- [x] Ran lint/type-check on changed code — `xcodebuild build` passed with 0 errors

- [x] (frontend) Asked the user for visual confirmation — not applicable (no UI change)

**Testing Notes:**

38/38 tests passed. Build succeeded. No SourceKit errors from the changed code (cross-file false positives unrelated to this change, pre-existing).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: PID-16.4 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Simplified `ScanEngine.init()` to read all UserDefaults values into locals before assignment, using `_prop = Published(wrappedValue:)` to bypass `didSet` for three properties — eliminating the spurious `startTimer()` triggered by `scanInterval.didSet` mid-init. `notificationsEnabled` kept as a normal assignment to preserve the auth-request side effect. `startTimer()` now called exactly once. 38/38 tests pass; no behaviour change.

**Archived:** 2026-06-24
