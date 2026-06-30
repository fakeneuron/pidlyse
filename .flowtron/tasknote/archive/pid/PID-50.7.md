---
title: popover-keys-dismiss
status: in-progress
tags: []
created: 2026-06-30
due:
related-tasks: [PID-EPIC-50, PID-049, PID-50.2]
---

# PID-50.7 | popover-keys-dismiss

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-50]] [[PID-049]] [[PID-50.2]]

## 🎯 Goal

Add a ⌘⌫ keyboard shortcut that kills the selected/sole safe row, and verify Esc + click-outside reliably dismiss the popover (adding an event monitor only if the existing `.transient` behaviour proves unreliable).

## ✅ Acceptance

- [x] ⌘⌫ kills the **sole visible safe row** when exactly one safe row is shown; no-op when 0 or >1 safe rows (no selection mechanism exists / arrow-traversal out of scope per locked PID-50.1 scope)
- [x] Esc dismisses the popover (verified on a real build)
- [x] Click-outside dismisses the popover (verified on a real build)
- [x] An event monitor / popover-key fix is added **only if** the existing `.transient` behaviour proves insufficient for Esc / click-outside / ⌘⌫ — **needed**: popover wasn't key on open; fixed by activating + keying the popover window on show (simpler than an `NSEvent` monitor)
- [x] `xcodebuild build` (type-check) clean; existing test suite still green (121 tests)

## 🧩 Subtasks

- [x] Add a hidden `.keyboardShortcut(.delete, modifiers: .command)` button to `MenuBarView` that kills the sole visible safe row (`safeItems.count == 1`), disabled otherwise — kill via the existing `KillService.kill(item, …) { engine.scan() }`
- [x] Build + run (`make build-release`), verify on a real build: ⌘⌫ kills the sole safe row, Esc dismisses, click-outside dismisses
- [x] Esc / click-outside / ⌘⌫ didn't fire on open (popover not key) → added the minimal `AppDelegate` fix: `NSApp.activate()` + `popover.contentViewController?.view.window?.makeKey()` on show
- [x] `xcodebuild build` type-check + run the test suite (121 pass)
- [x] 👁️ visual confirmation with the operator — all four behaviours confirmed working on open

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover power-user UX)
- [[PID-049]] — UX feature survey that surfaced this (survey item 6)
- [[PID-50.2]] — row-context-menu (kill affordance precedent)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Final implementation child of PID-EPIC-50; scope was locked in the [[PID-50.1]] discovery via AskUserQuestion (minimal: ⌘⌫ kills sole safe row, no arrow traversal, verify Esc/click-outside on the already-`.transient` popover). Last open item before the [[PID-50.8]] audit.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source surface (read):**

- `Pidlyse/AppDelegate.swift` — owns the `NSPopover`. `popover.behavior = .transient` set at **line 38**; `NSPopoverDelegate` wired (`popoverDidClose`). `togglePopover(from:)` (line 143) calls `popover.show(relativeTo:of:preferredEdge:)`. No app-activation on open. No `NSEvent` monitor.
- `Pidlyse/MenuBarView.swift` — popover content. **No row-selection state** (only `expandedPIDs`, `collapsedKinds`, `seenKinds`, `filterText`). `safeItems` (line 382) is the **filtered** safe set. Single-item kill API in use at line 295: `KillService.kill(item, containerOwners: engine.containerOwners) { engine.scan() }`. A TextField (filter, line 125) already exists → the popover *can* become key (otherwise typing into the filter would be impossible).

**Archive skim** (popover/dismiss/keyboard precedents):
- **PID-50.1** (this epic's discovery) — explicitly resolved `.7` scope: minimal, ⌘⌫ kills selected/sole safe row, **no arrow traversal**; Esc + click-outside dismissal to be **verified against the already-`.transient` popover** before adding any event monitor.
- **PID-040** (popover-realign) — the popover's width-fixed / height-driven sizing + arrow anchoring is deliberate; the icon is frozen while shown. New hidden controls must not change layout/sizing (a zero-size/hidden button is fine).
- **PID-045** — the `Set.toggle(_:)` extension at the bottom of MenuBarView is the local idiom for membership sets (not needed here — no selection set).
- **PID-003 / PID-001** — original popover-ui + status-item bridge; no prior keyboard-shortcut work in the popover, so this is net-new.

**Drift check:** All cited paths/symbols match HEAD. Confirmed material point from PID-50.1: popover is **already `.transient`** — so Esc + click-outside likely already work *when the popover is key*. The real risk is whether the popover is **key on open** (without a prior click); both Esc and a SwiftUI `.keyboardShortcut` depend on key-window status. No other drift.

**Interpretation of "selected/sole safe row":** No selection mechanism exists and arrow-traversal is out of scope (locked in PID-50.1), so the only achievable target is the **sole** safe row. Operative rule: when exactly one safe row is *visible* (`safeItems.count == 1`, respecting the active filter), ⌘⌫ kills it; otherwise it's a no-op (nothing to disambiguate).

**Clarifications:** No clarifications needed — scope was resolved in PID-50.1's AskUserQuestion. Explicit assumptions:
1. "Sole safe row" = the sole *filtered/visible* safe item (`safeItems`), not the raw unfiltered set — keeps the shortcut consistent with what the user sees.
2. ⌘⌫ is a no-op (not "Clean all", not an error) when 0 or >1 safe rows exist.
3. Implementation starts with the SwiftUI-native hidden `.keyboardShortcut` button; the `AppDelegate` event-monitor / popover-key fix is added **only if** a real build shows the `.transient` default doesn't reliably deliver Esc / click-outside / ⌘⌫. This matches the task's "add an event monitor only if needed".

**Exit-gate judgment:** Discovery surfaced no significant deviation from the PID-50.1-locked scope → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (SwiftUI view + AppKit popover wiring; not unit-testable without UI tests, which this project doesn't have. The kill path itself routes through the already-tested `KillService`.)

**Implementation Notes:**

- **`MenuBarView.swift`** — added `soleSafeKillShortcut`: an invisible (`opacity 0`, `accessibilityHidden`) `Button` with `.keyboardShortcut(.delete, modifiers: .command)`, hosted via `.background(...)` on the root VStack so it adds no layout (respects PID-040's fixed-width / height-driven sizing). `.disabled(safeItems.count != 1)` gates the shortcut to exactly one *visible* safe row; the action unwraps `safeItems.first` and kills via the existing `KillService.kill(item, containerOwners:) { engine.scan() }`.
- **`AppDelegate.swift`** — in `togglePopover(from:)`, after `popover.show(...)` added `NSApp.activate()` + `popover.contentViewController?.view.window?.makeKey()`. Root cause (found via build verification): an `NSStatusItem` click doesn't activate the app, so the popover window was never key on open — Esc/⌘⌫ leaked to the previously-active app and `.transient` click-outside dismissal stayed dormant until first inside-click. Keying the window on show fixes all three at once. Used `NSApp.activate()` (macOS 14 API) not the deprecated `activate(ignoringOtherApps:)` — no deprecation warning.
- **No `NSEvent` monitor needed** — the popover-key fix is strictly simpler and covers Esc + click-outside + ⌘⌫ together. The task's "event monitor only if needed" fallback stays unused.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — full suite (no UI-specific tests exist): **121 tests, 0 failures**

- [x] Ran lint/type-check on changed code — `xcodebuild build` clean (no errors, no deprecation warnings)

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

Two-round build verification (this task is verification-driven by design). Round 1 (shortcut only): operator reported Esc/click-outside/⌘⌫ did **not** fire on open — focus stayed in the background app until the popover was clicked into. Diagnosis: popover not key on open (the `.transient` default is insufficient because the status-item click doesn't activate the app). Round 2 (after the `AppDelegate` activate+makeKey fix): operator confirmed all four behaviours work immediately on open — Esc dismisses, click-outside dismisses, ⌘⌫ kills the sole safe row, and 0/2+ safe rows make ⌘⌫ a no-op.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** — added a "Keyboard & dismissal" bullet to §Features (⌘⌫ sole-safe-row kill + Esc/click-outside dismissal). `AGENTS.md`: no change. `CLAUDE.md`: no change (no keyboard/popover-focus contract). `.flowtron/PLAN.md`: the `.7` line flip below.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-50 in `## Medium`; parent + cohort move to `## Completed` only after the `.8` audit) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces inline on conditional skip)

**Final Summary:**

Closed the final implementation child of PID-EPIC-50. Added a ⌘⌫ keyboard shortcut that kills the sole visible safe row (invisible `.keyboardShortcut` button in `MenuBarView`, gated to exactly one safe row — no selection/arrow-traversal, per the PID-50.1-locked minimal scope). Build verification surfaced that the popover wasn't taking keyboard focus on open (an `NSStatusItem` click doesn't activate the app), which also explained why Esc and click-outside dismissal only worked after an inside-click — fixed in `AppDelegate.togglePopover` by activating the app + keying the popover window on show, which covers all three behaviours without the `NSEvent` monitor the task held in reserve. Touched `MenuBarView.swift`, `AppDelegate.swift`, `README.md`. 121 tests green; operator-confirmed on a real build. Remaining: PID-50.8 audit to close the epic.

**Archived:** 2026-06-30
