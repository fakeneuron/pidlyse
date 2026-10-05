---
title: init-notifications
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-18, PID-16.4]
---

# PID-18.2 | init-notifications

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-18]] · [[PID-16.4]]

## 🎯 Goal

Remove the init-time auth-request side effect in `ScanEngine.init()` by loading the persisted `notificationsEnabled` value via backing storage (`_notificationsEnabled = Published(wrappedValue:)`) instead of the `didSet`-triggering direct assignment — matching the `_scanInterval` / `_elapsedThreshold` pattern already used two lines above.

## ✅ Acceptance

- [ ] `ScanEngine.init()` no longer fires `requestAuthorization` as a side effect of loading the persisted toggle
- [ ] `notificationsEnabled` still loads its persisted value from UserDefaults on launch
- [ ] `notificationsEnabled.didSet` auth-request still fires on a *user-driven* enable (toggle in Settings) — only the init path changes
- [ ] Build passes; no tests broken; no other files touched

## 🧩 Subtasks

- [ ] Replace `if savedNotifications { notificationsEnabled = true }` with `if savedNotifications { _notificationsEnabled = Published(wrappedValue: true) }` in `ScanEngine.init()`
- [ ] Build (Xcode ⌘B / `xcodebuild build`) — confirm 0 errors
- [ ] Run `ScanEngineTests` — confirm green

## 🔗 Related

- [[PID-EPIC-18]] — parent epic: correctness (init side-effect, PID-reuse race, test coverage, port drift)
- [[PID-16.4]] — scanengine-persistence: applied this exact `_prop = Published(wrappedValue:)` bypass to the other three persisted props but **intentionally exempted** `notificationsEnabled` to keep the auth-request. PID-18.2 reverses that exemption.

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Bug confirmed at `ScanEngine.swift:72`: `if savedNotifications { notificationsEnabled = true }` routes through `didSet` (lines 41-52), which — because `oldValue` is `false` at init — fires `UNUserNotificationCenter.requestAuthorization` as a launch-time side effect. The PLAN-specified fix (`_notificationsEnabled = Published(wrappedValue: true)`) is exactly the pattern already used for `_elapsedThreshold`/`_scanInterval` at lines 69/71. No drift.

- [x] Read relevant source files — `ScanEngine.swift` (init lines 62-74, `notificationsEnabled` didSet lines 41-52, `fireNotificationIfNeeded` lines 121+); `SettingsView.swift:45` (user-driven toggle binding).

- [x] **Archive skim** — `PID-16.4` (scanengine-persistence) applied `_prop = Published(wrappedValue:)` to the three other persisted props but **deliberately kept** `notificationsEnabled = true` as a normal assignment "to preserve its `didSet` auth-request side effect" (its acceptance: "`notificationsEnabled.didSet` auth-request behaviour preserved"). PID-18.2 is the audit-repo (2026-06-24) decision to reverse that exemption. `PID-13.5` introduced the toggle + didSet. This reversal is intentional, filed by the epic — not a silent correction.

- [x] **Drift check** — `ScanEngine.init()` line 72 matches the task description exactly; `_scanInterval`/`_elapsedThreshold` backing-storage pattern present at lines 69/71. `notificationsEnabled` is `@Published` (line 41) so `_notificationsEnabled` backing storage exists. No tests reference `notificationsEnabled`. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **No clarifications needed.** Explicit assumptions:
  - The init-time `requestAuthorization` is the side effect the audit flagged; removing it is the intended outcome. The OS never re-shows the auth dialog once decided, so the *visible* prompt was already idempotent — the smell is an impure init firing an async permission request, not a repeated popup.
  - **Accepted consequence:** the old init path also ran a reconciliation — if the callback returned `!granted`, it flipped `notificationsEnabled` back to `false`. With the side effect gone, a user who enabled notifications and *later revoked* permission in System Settings will keep a `true` toggle while the OS silently drops notifications (`fireNotificationIfNeeded` posts requests that never surface). This is a minor stale-toggle cosmetic, not a functional regression — notifications still don't appear. User-driven re-enable still triggers a fresh auth request via `didSet`. Out of scope for this one-line fix.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Root cause:** `notificationsEnabled = true` (line 72) → `didSet` (oldValue=false) → `requestAuthorization`. Backing-storage assignment bypasses `didSet`.
- **Load-bearing archive finding:** PID-16.4 intentionally exempted this exact line; PID-18.2 reverses it per the audit. Documented in 🔗 Related and acceptance so the history reads coherently.
- Discovery surfaced no significant scope deviation (task is the exact PLAN-specified one-liner; archive finding confirms the reversal is intentional) → skip 🛠️.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `_prop = Published(wrappedValue:)` backing-storage bypass is the established in-file pattern (lines 69/71 for `_elapsedThreshold`/`_scanInterval`, set by PID-16.4). Extended it to `_notificationsEnabled`; no new shape.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — pure init refactor; no `notificationsEnabled` test surface exists or is warranted (auth flow is OS-driven, not unit-testable). 38 existing tests cover the unaffected scan paths.

**Implementation Notes:**

Single-line change in `ScanEngine.init()` (line 72): `notificationsEnabled = true` → `_notificationsEnabled = Published(wrappedValue: true)`, bypassing the `didSet` that fired `requestAuthorization` at launch. Mirrors the sibling lines above. No other files touched.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 38/38 `ScanEngineTests` passed, `** TEST SUCCEEDED **`.

- [x] Ran lint/type-check on changed code — `xcodebuild build` (within `make test`) compiled with 0 errors. SourceKit cross-file false positives (`ProcessItem`/`PortRegistry` "not in scope") are pre-existing editor noise, not compile errors (same as documented in PID-16.4).

- [x] (frontend) Asked the user for visual confirmation — n/a (no UI change; init-internal refactor).

**Testing Notes:**

38/38 tests pass, build clean. No behaviour change to observable scan/notification flow; only the launch-time auth-request side effect is removed.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: PID-18.2 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Removed the launch-time `requestAuthorization` side effect from `ScanEngine.init()` by loading the persisted `notificationsEnabled` toggle via backing storage (`_notificationsEnabled = Published(wrappedValue: true)`) instead of the `didSet`-triggering direct assignment — completing the init-purity pattern PID-16.4 applied to the other three persisted props but exempted here. User-driven enables still request auth via `didSet`. One accepted trade-off: the dropped init path no longer reconciles a revoked permission back to a `false` toggle (minor stale-toggle cosmetic; notifications still don't surface either way). 38/38 tests pass.

**Archived:** 2026-06-25
