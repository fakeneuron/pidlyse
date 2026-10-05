---
title: notifications
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13]
---

# PID-13.5 | notifications

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Add `UserNotifications` support so Pidly fires a macOS system notification whenever a scan surfaces stray processes not seen in the previous result, with an opt-in toggle in `SettingsView`.

## ✅ Acceptance

- [x] New stray processes (present in current scan but not the previous) trigger a macOS notification
- [x] Notifications only fire when the opt-in toggle is enabled in Settings
- [x] The toggle persists across app launches (stored in `UserDefaults` via `@Published var notificationsEnabled`)
- [x] Notification permission is requested on first enable; no notification fires if permission is denied
- [x] No notification fires for the first scan (no previous baseline to compare against)
- [x] Existing scan/kill behavior is unaffected

## 🧩 Subtasks

- [x] Add `import UserNotifications` and `@Published var notificationsEnabled: Bool` (with `UserDefaults` persistence + permission request in `didSet`) to `ScanEngine.swift`
- [x] Add `private var previousPIDs: Set<Int32>?` to `ScanEngine`; load `notificationsEnabled` from UserDefaults in `init()`
- [x] Modify `scan()` completion handler: snapshot old PIDs → update `previousPIDs` → call `fireNotificationIfNeeded`
- [x] Reset `previousPIDs = nil` in `rescan()` to suppress noise from cleared dismissals
- [x] Add `private func fireNotificationIfNeeded(newItems:previousPIDs:)` that posts a `UNNotificationRequest`
- [x] Add "Notifications" section to `SettingsView` with a Toggle bound to `engine.notificationsEnabled`
- [x] Build and verify

## 🔗 Related

- [[PID-EPIC-13]] — parent epic (feature-expansion)
- [[PID-13.4]] — predecessor (app-description)
- [[PID-13.6]] — follow-up audit subtask

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Files exist, scope is well-defined from PID-13.1 discovery ("UserNotifications opt-in for new stray alerts"). No drift.

- [x] Read relevant source files

- [x] **Archive skim** — PID-13.1 confirms notification scope. PID-13.3 shows ScanEngine extension pattern (all scan logic goes there). PID-13.4 confirmed SettingsView toggle/section shape. No prior notification code exists.

- [x] **Drift check** — No function names or line numbers cited in task description. `ScanEngine.swift` and `SettingsView.swift` both exist and match expectations.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Explicit assumptions: (1) notification fires for any new PID in results (both buckets); (2) first scan fires no notification (no prior baseline); (3) `rescan()` resets the baseline to avoid noise; (4) no Info.plist/entitlements changes needed — app is not sandboxed.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**
- `ScanEngine.scan()` publishes results via `self?.items = result` in a main-queue block — this is the hook for tracking `previousPIDs` and firing notifications.
- Other scan settings (`scanInterval`, `elapsedThreshold`, `ignoredNames`) all use `@Published var` + `UserDefaults` persistence in `didSet` — same pattern for `notificationsEnabled`.
- `launchAtLogin` binding in `SettingsView` is the precedent for the permission-request-on-enable flow; `UNUserNotificationCenter.requestAuthorization` is the analogous async call.
- `rescan()` clears `dismissedPIDs` — resetting `previousPIDs = nil` there prevents previously dismissed PIDs from appearing as "new" after the user explicitly clears their dismissed set.
- No `NSUserNotificationsUsageDescription` needed on macOS for non-sandboxed apps.

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `@Published var scanInterval`/`elapsedThreshold` pattern in `ScanEngine` is the exact shape; `launchAtLogin` didSet-with-async in `SettingsView` is the permission-request precedent. Pure extension, no new shape.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (notification layer is async integration with `UNUserNotificationCenter`; pure parsing/classification logic unchanged; 35 existing tests all pass)

**Implementation Notes:**
- `ScanEngine.swift`: added `import UserNotifications`; `@Published var notificationsEnabled: Bool` (UserDefaults key `notificationsEnabled`, permission request on `false → true` transition via `oldValue` guard); `private var previousPIDs: Set<Int32>?` (nil = first scan); loaded from UserDefaults in `init()`.
- `scan()` completion block: captures `oldPIDs = self?.previousPIDs`, updates `self?.previousPIDs`, then calls `self?.fireNotificationIfNeeded(newItems:previousPIDs:)`.
- `rescan()`: resets `previousPIDs = nil` to suppress false-positive notifications when cleared dismissals re-emerge.
- `fireNotificationIfNeeded`: guards on `notificationsEnabled` + non-nil prior baseline; filters `newItems` against prior PIDs; posts `UNNotificationRequest` (single: "New stray process: Kind: path"; multiple: "N new stray processes: Kind, Kind, …").
- `SettingsView.swift`: new "Notifications" `Section` with `Toggle("Alert on new strays", isOn: $engine.notificationsEnabled)` + caption.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — 35/35 passed, no regressions

- [x] Ran lint/type-check on changed code — `xcodebuild build` succeeded clean; SourceKit diagnostics are false positives from stale index

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (not a visual/layout change; toggle appears in existing Settings form)

**Testing Notes:**
35/35 tests passed. Build succeeded. The notification toggle and permission request are runtime integration points not covered by unit tests (would require mocking `UNUserNotificationCenter`); verified structurally via build.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (notification toggle is new, not a drift of existing content). `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: updated (PID-13.5 stub → Completed 2026-06-24, added to ## Completed).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**
Added `UserNotifications` support to Pidly: a background scan that surfaces new stray PIDs (not seen in the previous result) fires a macOS system notification when the user opts in. Permission is requested on first enable and reverts the toggle if denied. Files changed: `ScanEngine.swift` (~35 lines — `notificationsEnabled` property, `previousPIDs` tracking, `fireNotificationIfNeeded` method, scan/rescan hooks), `SettingsView.swift` (~7 lines — new Notifications section). 35/35 tests pass.

**Archived:** 2026-06-24
