---
title: bridges
status: in-progress
tags: []
created: 2026-07-02
related-tasks: [PID-EPIC-58, PID-58.1, PID-58.2, PID-EPIC-57]
---

# PID-58.3 | bridges

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-58]] [[PID-58.1]] [[PID-58.2]]

## 🎯 Goal

Expose Pidlyse's clean/scan actions to external launchers: a Shortcuts bridge via AppIntents ("Clean safe strays", "Scan now") riding the [[PID-58.2]] `cleanAllSafe` engine action, plus sample Raycast script commands wrapping the installed `pidlyse` CLI (`integrations/raycast/` + docs). AppleScript dropped — the CLI covers `osascript` users.

## ✅ Acceptance

- [ ] Two `AppIntent`s — "Clean safe strays" (→ `engine.cleanAllSafe`) and "Scan now" (→ `engine.rescan`) — invocable from Shortcuts + Spotlight
- [ ] An `AppShortcutsProvider` registers both intents with natural-language phrases
- [ ] The intents reach the running app's shared `ScanEngine` and bridge its main-thread completion handler into `async` `perform()`; "Clean safe strays" returns a dialog summarising the `CleanSummary` (cleaned/requested) — the dialog is the return channel (no result notification, which `pidlyse://clean` needs only because a URL open has none)
- [ ] "Clean safe strays" never touches `needsReview` and respects protected projects (parity with "Clean all" / `pidlyse://clean` — it reuses `sweepableSafeItems`)
- [ ] `integrations/raycast/` ships sample script commands wrapping the installed CLI (`pidlyse list --safe`, `pidlyse clean`) with Raycast metadata headers + a README (install path, `make install-cli` prerequisite)
- [ ] `xcodebuild build -scheme Pidlyse` type-checks clean; `make test` stays green
- [ ] Phase 4 doc-drift sweep across README §"AI-referenced docs" (README integrations surface + SPEC.md integration section land here as the epic's user-facing bridges ship)

## 🧩 Subtasks

- [ ] Add `CleanSafeStraysIntent` (`AppIntent`) to `PidlyseApp.swift` — reaches the shared engine via `NSApp.delegate as? AppDelegate`, bridges `cleanAllSafe`'s completion into `async perform()` (`withCheckedContinuation`), and returns a dialog from `CleanSummary` (dialog is the intent's return channel — no result notification, unlike `pidlyse://clean` which has none)
- [ ] Add `ScanNowIntent` (`AppIntent`) — calls `engine.rescan()` on the main actor; returns a brief confirmation dialog
- [ ] Add `PidlyseShortcuts: AppShortcutsProvider` registering both intents with natural-language phrases
- [ ] Create `integrations/raycast/` — `clean-safe-strays.sh` (wraps `pidlyse clean`) + `list-strays.sh` (wraps `pidlyse list --safe`) with Raycast metadata headers + a `README.md` (install path, `make install-cli` prereq)
- [ ] Build + type-check (`xcodebuild build -scheme Pidlyse`) and `make test`; operator Shortcuts smoke (👁️)
- [ ] Phase 4: doc-drift sweep + flip PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-58]] — parent epic (integrations: URL scheme + external-launcher bridges)
- [[PID-58.1]] — discovery; scoped this child (AppIntents + Raycast-script bridge set, AppleScript dropped)
- [[PID-58.2]] — url-scheme; extracted the `cleanAllSafe` / `sweepableSafeItems` engine action layer this rides on
- [[PID-EPIC-57]] — cli-companion; the `pidlyse` CLI the Raycast script commands wrap

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Discovery ([[PID-58.1]]) scoped this exact child; [[PID-58.2]] shipped the `cleanAllSafe` action layer the AppIntents bridge rides on and the CLI ([[PID-EPIC-57]]) the Raycast scripts wrap already exists. No AppIntents/Raycast surface has shipped — live and unduplicated.

- [x] Read relevant source files

- [x] **Archive skim**

- [x] **Drift check**

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source-file inventory (current code):**

- `Pidlyse/ScanEngine.swift:304-338` — the [[PID-58.2]] engine action layer is ready to ride: `isProtected`, `sweepableSafeItems` (SSOT: safe minus protected), `cleanAllSafe(completion:)` (kill → `recordCleaned` → `scan` → `CleanSummary`), `rescan()` (:252, clears dismissed + rescans). `CleanSummary { requested, cleaned, reclaimedKB }` (:291). All main-thread; `cleanAllSafe`'s completion fires on the main thread after the grace period.
- `Pidlyse/AppDelegate.swift:70-83` — `application(_:open:)` routes URL verbs to `engine.cleanAllSafe`/`engine.rescan`; the sibling external-trigger entry point. Holds the shared engine as `let engine = ScanEngine()` (:15). Reachable from an AppIntent via `NSApp.delegate as? AppDelegate`.
- `Pidlyse/PidlyseApp.swift` — `@main` `App` with `@NSApplicationDelegateAdaptor`; tiny (Settings scene only). Candidate home for the `AppShortcutsProvider` (app-level declaration, surgery-free).
- `Packages/PidlyseCore/Sources/PidlyseCLI/main.swift:132-150` — `commandClean()`: `runScan(Settings.load())` (scans **fresh** each run) → safe-minus-protected sweep → `killAll` → `recordCleaned` → summary. The Raycast `clean` script wraps this; inherently fresh because the CLI scans on every invocation.
- `PidlyseTests/ScanEngineTests.swift` — single app-test file. AppIntents are system-instantiated and not unit-testable in isolation; the engine action layer they call is already exercised by [[PID-58.2]]. Testing here is build/type-check + operator Shortcuts smoke.

**Xcode project structure (load-bearing):** `Pidlyse.xcodeproj/project.pbxproj` is a **classic** project — no `PBXFileSystemSynchronizedRootGroup`, so app-side source is referenced file-by-file. A **new** app Swift file needs pbxproj surgery (PBXFileReference + PBXBuildFile + group child + Sources phase). [[PID-58.2]] deliberately **avoided** this by putting new pure code in the SPM core (auto-included) and editing only existing app files. AppIntents can't live in core (they need the app-side `ScanEngine` + must be in the app target for `AppShortcuts` metadata extraction) → placement is a real fork: dedicated new file + surgery vs. tuck into existing `PidlyseApp.swift` (surgery-free, extends the .2 precedent). → clarifying question.

**Freshness posture (load-bearing):** When Shortcuts runs an AppIntent and the app isn't already running, macOS cold-launches it; `ScanEngine.scan()` is async, so `sweepableSafeItems` may be empty at `perform()` time → "nothing to clean" despite live strays. `pidlyse://clean` ([[PID-58.2]]) has the identical cold-launch caveat and shipped acting on the running engine's current `items` (relies on the menu-bar app's periodic scan — the common case). The CLI is immune (scans per-invocation). → parity-with-URL (+ documented caveat) vs. scan-first-then-sweep is a real fork → clarifying question.

**Archive skim (load-bearing):**

- [[PID-35.1]] (security discovery) — baseline "no network, no NSAppleScript". AppIntents run in-process on user invocation; bounded to safe-minus-protected (never Needs Review), same posture as `pidlyse://clean`. AppleScript `.sdef` stays dropped ([[PID-58.1]] resolution). Raycast scripts add no app surface (they shell out to the already-shipped CLI).
- [[PID-58.2]] — the `cleanAllSafe`/`sweepableSafeItems` SSOT + `CleanSummary` are the exact substrate this rides; reuse, don't re-derive. The [[PID-53.2]] clean-log rules (`.confirmed`-only, no command line persisted) flow through `cleanAllSafe` automatically.
- [[PID-57.3]] — the CLI (`pidlyse list`/`clean`) is the Raycast substrate; `integrations/raycast/` wraps `/usr/local/bin/pidlyse` (from `make install-cli`).

**Drift check:** All [[PID-58.2]] paths/APIs cited (`cleanAllSafe`, `sweepableSafeItems`, `CleanSummary`, `rescan`, `application(_:open:)`) confirmed present at the noted lines. CLI `commandClean`/`commandList` confirmed. No drift.

**Resolved scoping (AskUserQuestion, 2026-07-02):**

| Question | Resolution |
|---|---|
| AppIntent file placement | **Existing `PidlyseApp.swift`** — add the two intents + `AppShortcutsProvider` to the `@main` App file; surgery-free, extends the [[PID-58.2]] "avoid pbxproj surgery" precedent, idiomatic (provider next to `App`). |
| "Clean safe strays" freshness | **Parity with `pidlyse://clean`** — act on the running engine's current `items` (reuse `cleanAllSafe` as-is). Matches [[PID-58.2]]; relies on the menu-bar app's periodic scan (common case). Cold-launch caveat documented, not fixed. |

**Exit-gate judgment:** Discovery surfaced no significant deviation — both clarifications resolved parameters inside the already-scoped shape (surgery-free placement, reuse the existing `cleanAllSafe` action; no new files, no new engine APIs, no approach change) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior (N/A — see below)

**Implementation Notes:**

Pattern survey: the intents mirror [[PID-58.2]]'s `application(_:open:)` — reach the shared engine and call the same `cleanAllSafe`/`rescan` action layer; the `AppShortcutsProvider` is the idiomatic sibling of the `@main App` struct (placed in the same file per the resolved scoping). No new engine API invented — the [[PID-58.2]] SSOT is reused wholesale.

Changes (both surgery-free per the resolved scoping):
- **`Pidlyse/PidlyseApp.swift`** — added `import AppIntents` + `import AppKit`; a `@MainActor sharedEngine()` helper (`NSApp.delegate as? AppDelegate → engine`); `CleanSafeStraysIntent` (bridges `cleanAllSafe`'s main-thread completion into `async perform()` via `withCheckedContinuation`, returns a `CleanSummary` dialog — no notification, the dialog is the return channel); `ScanNowIntent` (`engine.rescan()` on the main actor); `PidlyseShortcuts: AppShortcutsProvider` registering both with `\(.applicationName)` phrases + SF Symbols. No `project.pbxproj` edit (added to an existing target file).
- **`integrations/raycast/`** (new) — `clean-safe-strays.sh` (wraps `pidlyse clean`), `list-strays.sh` (wraps `pidlyse list --safe`), both with Raycast metadata headers, `command -v pidlyse` resolution + a missing-CLI hint, `chmod +x`; `README.md` (install path, `make install-cli` prereq, Shortcuts cross-note).

Tests: no unit tests added — AppIntents are system-instantiated (`perform()` isn't callable in-process without the Shortcuts runtime) and the `cleanAllSafe`/`sweepableSafeItems`/`rescan` layer they delegate to is already exercised by [[PID-58.2]]. The Raycast scripts are thin CLI wrappers (the CLI is covered by [[PID-57.3]]). Coverage here is build/metadata-extraction + operator smoke.

Security posture ([[PID-35.1]] / [[PID-58.1]]): "Clean safe strays" is bounded to `sweepableSafeItems` (safe minus protected — never Needs Review); the Shortcuts/Spotlight invocation is the explicit user action. `openAppWhenRun = false` keeps the menu-bar utility headless. No new attack surface from Raycast (shells out to the already-shipped CLI). AppleScript stays dropped.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix — see recap)

**Testing Notes:** `xcodebuild build -scheme Pidlyse` → **BUILD SUCCEEDED**; the `ExtractAppIntentsMetadata` step ran and wrote `Metadata.appintents` (both intents + the `AppShortcutsProvider` registered — the real type-check that `perform()`, the continuation bridge, and the provider compile). `make test` → **228 tests, 0 failures** (no regressions; the [[PID-58.2]] `URLScheme`/engine suite still green). No separate linter (Swift compiler is the type-check per the README). The SourceKit single-file diagnostics on `PidlyseApp.swift` (`cannot find ScanEngine/AppDelegate in scope`) are cross-file-resolution noise — the full-module build resolves them. End-to-end Shortcuts/Spotlight + Raycast smoke deferred to the operator (👁️ ask in recap — requires invoking the shortcut and observing real kills).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added the Shortcuts/Spotlight bridge and Raycast script commands that complete [[PID-EPIC-58]]'s external-launcher surface. Two `AppIntent`s — "Clean safe strays" (→ `engine.cleanAllSafe`, dialog-summarised) and "Scan now" (→ `engine.rescan`) — plus a `PidlyseShortcuts: AppShortcutsProvider`, all in `PidlyseApp.swift` (surgery-free, no pbxproj edit). The intents reach the running app's shared `ScanEngine` via `NSApp.delegate` and bridge its main-thread completion into `async perform()`; the clean is bounded to the same `sweepableSafeItems` SSOT the popover and `pidlyse://clean` use (never Needs Review / protected). `integrations/raycast/` ships two CLI-wrapping scripts + a README for users who prefer the terminal companion. AppleScript stays dropped (CLI covers `osascript`). 4 files (1 app edit + 3 new integration files). Build succeeds with AppShortcuts metadata extracted; 228 tests pass.

Doc-drift sweep: `README.md` — **updated** (new "Integrations" section: URL scheme + Shortcuts/Spotlight + Raycast, AppleScript-dropped note) · `AGENTS.md` — no change (no assistant-facing convention shift) · `CLAUDE.md` — **updated** (new integrations convention bullet: shared action layer, per-surface homes, why AppIntents sit in `PidlyseApp.swift`) · `SPEC.md` — **updated** (new "Integrations (PID-EPIC-58)" section with the per-surface entry-point table; also back-documents the PID-58.2 URL scheme, previously deferred) · `.flowtron/PLAN.md` — updated in-task (.3 stub flip).

**Archived:** 2026-07-02
