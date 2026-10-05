---
title: url-scheme
status: completed
tags: []
created: 2026-07-02
related-tasks: [PID-EPIC-58, PID-58.1, PID-58.3, PID-EPIC-57]
---

# PID-58.2 | url-scheme

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-58]] [[PID-58.1]] [[PID-58.3]]

## 🎯 Goal

Register a `pidlyse://` URL scheme with `clean`/`scan` verbs and extract an engine-side headless "clean all safe" action (safe minus protected + clean-log append) that external triggers share; `pidlyse://clean` acts directly and posts a result notification.

## ✅ Acceptance

- [ ] `Pidlyse/Info.plist` declares `CFBundleURLTypes` for the `pidlyse` scheme
- [ ] `AppDelegate` handles `application(_:open:)` and routes `pidlyse://clean` / `pidlyse://scan` to engine actions; unknown/malformed URLs are ignored safely
- [ ] A pure `pidlyse://` verb parser lives in `PidlyseCore` (mirroring `CLICore.parse`) with unit tests (scheme guard, host-vs-path, case-insensitivity, unknown verb → nil)
- [ ] `ScanEngine` exposes a headless `cleanAllSafe(...)` action + a `sweepableSafeItems` SSOT (safe bucket minus protected) that kills via `KillService`, appends confirmed deaths to the clean-log (`recordCleaned`), and rescans — the same set the popover "Clean all" and the CLI `commandClean()` sweep
- [ ] `pidlyse://clean` posts a result notification summarising the outcome (count + reclaimed memory)
- [ ] `pidlyse://clean` never touches `needsReview` items and respects protected projects (parity with "Clean all")
- [ ] Targeted tests pass; `xcodebuild build -scheme Pidlyse` type-checks clean
- [ ] Phase 4 doc-drift sweep across README §"AI-referenced docs"

## 🧩 Subtasks

- [ ] Add pure `URLScheme` parser (`pidlyse` scheme + `clean`/`scan` verbs) to `PidlyseCore`
- [ ] Add engine-side `sweepableSafeItems` SSOT + `cleanAllSafe(completion:)` + a `CleanSummary` result type to `ScanEngine`
- [ ] Add `fireCleanResultNotification(_:)` to `ScanEngine` per the resolved permission model
- [ ] Declare `CFBundleURLTypes` in `Info.plist`
- [ ] Add `application(_:open:)` routing in `AppDelegate` (clean → cleanAllSafe+notify, scan → rescan)
- [ ] Unit tests for `URLScheme.parse` in `PidlyseTests`
- [ ] Build + test; manual `open pidlyse://clean` smoke (operator visual-confirm)

## 🔗 Related

- [[PID-EPIC-58]] — parent epic (integrations: URL scheme + external-launcher bridges)
- [[PID-58.1]] — discovery; scoped this child (direct-clean posture, engine-side action layer)
- [[PID-58.3]] — bridges; rides on the `cleanAllSafe` action layer this task extracts
- [[PID-EPIC-57]] — cli-companion; `commandClean()` is the reference headless "Clean all"

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Discovery ([[PID-58.1]], closed 2026-07-02) scoped this exact child: `pidlyse://` scheme + engine-side action layer, extraction-first. No URL scheme has shipped; the [[PID-EPIC-57]] CLI dependency it rides on is closed. Live and unduplicated.

- [x] Read relevant source files

- [x] **Archive skim**

- [x] **Drift check**

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source-file inventory (current code):**

- `Pidlyse/Info.plist` — real file (`GENERATE_INFOPLIST_FILE = NO`, `INFOPLIST_FILE = Pidlyse/Info.plist`); no `CFBundleURLTypes` today. Editable directly.
- `Pidlyse/AppDelegate.swift` — `NSApplicationDelegate` (via `@NSApplicationDelegateAdaptor`), owns the shared `ScanEngine`. No `application(_:open:)` yet. `LSUIElement` app — URL opens route to the delegate cleanly with no window.
- `Pidlyse/ScanEngine.swift` — app-side lifecycle owner (timer, `@Published items`, `cwds`, `containerOwners`, `protectedProjects`, `cleanLog`, `recordCleaned`, `fireNotificationIfNeeded`). No headless clean action; the sweep set is **not** computed here.
- `Pidlyse/MenuBarView.swift:503-528` — `sweepableSafeItems = safeItems.filter { !isProtected($0) }`; `isProtected` reads `engine.cwds` + `engine.protectedProjects` via `CwdResolver.isUnderPrefix`. "Clean all" (line 224-228) = `KillService.kill(sweepableSafeItems) → engine.recordCleaned → engine.scan()`. Note the view set folds in the quick-filter (`matchesFilter`); the headless action must sweep the **unfiltered** safe-minus-protected set.
- `Packages/PidlyseCore/Sources/PidlyseCLI/main.swift:132-150` — `commandClean()`: `items.filter { .safe && !protectedPIDs }` → `killAll` → `recordCleaned` → summary (`confirmed/total · reclaimed`). The reference headless "Clean all"; computes `protectedPIDs` eagerly in `runScan` (:71-74).
- `Packages/PidlyseCore/Sources/PidlyseCore/CLICore.swift` — pure command grammar (`Command` enum + `parse -> Result`), tested from `PidlyseTests`. Precedent for a pure `pidlyse://` parser in core.
- `PidlyseTests/ScanEngineTests.swift` — single app-test file (`@testable import Pidlyse` + `import PidlyseCore`), covers ScanCore + app types + CLICore. New tests append here (avoids pbxproj surgery). Core files auto-include in the SPM package.

**Archive skim (load-bearing):**

- [[PID-35.1]] (security discovery) — baseline records "no network, **no NSAppleScript**". The `pidlyse://` scheme deliberately expands external attack surface. Mitigation already resolved in [[PID-58.1]]: the drive-by `pidlyse://clean` is bounded to the **safe-minus-protected** set (never `needsReview`), so the "never kill without explicit user action" non-negotiable holds — the launcher invocation *is* the explicit action, and a malicious local app could `kill` directly anyway.
- [[PID-57.3]] / [[PID-57.1]] — CLI `commandClean()` is the SSOT reference for the headless sweep; defaults-domain parity + shared `CleanLogFile` rules (`.confirmed`-only, custom-label kind, `displayPath` fallback). Match its `recordCleaned` shape.
- [[PID-53.2]] — clean-log rules: only `.confirmed` deaths logged, no command line persisted (privacy-first).

**Drift check:** [[PID-58.1]] cited the sweep set as `sweepableItems @ MenuBarView.swift:503`; current name is `sweepableSafeItems` at :507 (concept intact, trivial naming drift). All other cited paths/concepts (Info.plist no CFBundleURLTypes, CLI commandClean, KillService/recordCleaned) confirmed current. No blocking drift.

**Design shape (extraction-first, mirrors PID-57 split):**

1. **Pure core parser** — `URLScheme` namespace in `PidlyseCore` (`scheme = "pidlyse"`, `Command { clean, scan }`, `parse(URL) -> Command?`). Handles host-vs-path (`pidlyse://clean` and `pidlyse:clean`), case-insensitivity, scheme guard, unknown → nil. Tested from `PidlyseTests` like `CLICore`.
2. **Engine action layer** — `ScanEngine.sweepableSafeItems` (SSOT: `items.filter { .safe && !isProtected }`) + `isProtected(_:)` moved/hosted engine-side + `cleanAllSafe(completion: (CleanSummary) -> Void)` wrapping kill→record→rescan. `CleanSummary { requested, cleaned, reclaimedKB }`.
3. **Notification** — `fireCleanResultNotification(_:)` posts the clean outcome (per resolved permission model).
4. **Wiring** — `CFBundleURLTypes` in Info.plist + `application(_:open:)` in AppDelegate routing verbs to `engine.cleanAllSafe { … notify }` / `engine.rescan()`.

**Resolved scoping (AskUserQuestion, 2026-07-02):**

| Question | Resolution |
|---|---|
| Result-notification permission model | **Request on-demand + always post** — the result notification is the only feedback for a headless trigger, so `cleanAllSafe`'s notification requests authorization if `.notDetermined` and always posts, independent of the Settings `notificationsEnabled` toggle (which stays scoped to new-stray scan notifications). First `pidlyse://clean` may surface a one-time permission prompt. |
| `scan` verb semantics | **`engine.rescan()`** — clears the session's dismissed PIDs and re-enumerates (same as the manual ↺); headless, no popover, no result notification. New-stray notification still fires if that setting is on. |

**Exit-gate judgment:** Discovery surfaced no significant deviation — both clarifications resolved behavioral parameters inside the already-scoped shape (no file/subtask/approach change) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

Pattern survey: pure parser mirrors `CLICore` (namespace enum + `Command` + static parse in core, tested from `PidlyseTests`); the headless action mirrors the popover "Clean all" sequence (kill → `recordCleaned` → `scan`, MenuBarView:224-228) and the CLI `commandClean()`; the notification mirrors `fireNotificationIfNeeded`'s UNUserNotificationCenter shape. No new pattern invented.

Changes:
- **`PidlyseCore/URLScheme.swift`** (new) — pure `pidlyse://` grammar: `scheme` const, `Command { clean, scan }`, `parse(URL) -> Command?` (scheme guard, host-or-path verb, case-insensitive, unknown → nil). Auto-included in the SPM package.
- **`ScanEngine.swift`** — engine-side SSOT: `isProtected(_:)` + `sweepableSafeItems` (safe minus protected) hoisted from the view; `CleanSummary` struct; `cleanAllSafe(completion:)` (kill → record → rescan → summary); `fireCleanResultNotification(_:)` (always-post, request-auth-on-demand per resolved model).
- **`MenuBarView.swift`** — `isProtected` now delegates to `engine.isProtected` (removed the duplicated predicate body; `toggleProtected` unchanged). No behavior change; the popover's filter-aware `sweepableSafeItems` stays view-side.
- **`AppDelegate.swift`** — `import PidlyseCore`; `application(_:open:)` routes parsed verbs (clean → `cleanAllSafe` + notify, scan → `rescan`, nil → ignore).
- **`Info.plist`** — `CFBundleURLTypes` declaring the `pidlyse` scheme.
- **`PidlyseTests/ScanEngineTests.swift`** — new `URLSchemeTests` class (6 cases).

Security posture (PID-35.1 / PID-58.1): `clean` is bounded to safe-minus-protected (never Needs Review); the launcher invocation is the explicit action; unknown/foreign URLs are ignored silently. No command line persisted (PID-53.2 clean-log rules reused via `recordCleaned`).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask — see recap)

**Testing Notes:** `make test` → 228 tests, 0 failures (6 new `URLSchemeTests` pass: host form, opaque form, case-insensitivity, trailing path/query, foreign scheme, unknown verb). `TEST SUCCEEDED` confirms the full app target compiles (type-checks `application(_:open:)`, `cleanAllSafe`, `fireCleanResultNotification`, Info.plist). `make build-release` → `BUILD SUCCEEDED`; verified `CFBundleURLTypes` (scheme `pidlyse`) baked into `build/Release/Pidlyse.app/Contents/Info.plist` and LaunchServices registered the app. End-to-end `open pidlyse://clean` smoke deferred to operator (👁️ ask in recap — requires observing the result notification + real kills).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Registered the `pidlyse://` URL scheme with `clean`/`scan` verbs and extracted an engine-side headless "Clean all safe" action shared by all external triggers. `pidlyse://clean` runs the safe-minus-protected sweep directly (kill → clean-log append → rescan) and posts a result notification; `pidlyse://scan` re-enumerates. Pure verb parsing lives in `PidlyseCore.URLScheme` (mirrors `CLICore`, 6 unit tests); the sweep-set predicate (`isProtected` + `sweepableSafeItems`) is now an engine-side SSOT the popover and headless action share. 6 files (1 new core + 4 app + Info.plist + tests). 228 tests pass; Release build registers the scheme. The `cleanAllSafe` layer is the substrate [[PID-58.3]] (AppIntents bridge) rides on.

Doc-drift sweep: `README.md` — no change (URL scheme is a new external-trigger surface; README feature list updates when the epic's bridges land, or here if desired) · `AGENTS.md` — no change · `CLAUDE.md` — no change (URL-scheme wiring is app-lifecycle in AppDelegate/ScanEngine, consistent with the stated split; no convention shift) · `SPEC.md` — no change (integration surfaces documented when EPIC-58 completes; noted for the .4 audit) · `.flowtron/PLAN.md` — updated in-task (.2 stub flip).

**Archived:** 2026-07-02
