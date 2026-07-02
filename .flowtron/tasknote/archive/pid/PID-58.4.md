---
title: integrations audit
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-58, PID-58.1, PID-58.2, PID-58.3]
---

# PID-58.4 | integrations audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-58]]

## 🎯 Goal

Verify the completed `PID-EPIC-58` (`integrations`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-58.4 — audit PID-EPIC-58` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-58.4` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-58.4.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-58` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-58.4` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-58]] — parent epic (integrations: URL scheme + external-launcher bridges)
- [[PID-58.1]] — discovery (scoped the cohort)
- [[PID-58.2]] — url-scheme + engine-side action layer
- [[PID-58.3]] — bridges (AppIntents + Raycast)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-58.4`; pre-flight passed — PID-EPIC-58 is active (under `## Future Opportunities`), PID-58.4 is the highest `.N` child, and all three implementation siblings (.1 discovery, .2 url-scheme, .3 bridges) are closed. No open siblings → no early-audit gate. Capturing cohort state at audit time: all three children closed 2026-07-02 (same-day cohort), no early-audit decision.

- [x] Read relevant source files

- [x] **Archive skim** — read each cohort child's archived tasknote (`archive/pid/PID-58.1..3.md`); deliverables captured in Discovery Notes. Cohort children are themselves the archive entries; no non-cohort surface with prior tasknote history beyond the [[PID-EPIC-57]] CLI (already a cohort cross-ref) and [[PID-35.1]] security baseline (cited consistently across all three children).

- [x] **Drift check** — every deliverable path/API cited by the cohort tasknotes confirmed present at HEAD (see Discovery Notes verification table). No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — no clarifications needed; cohort scope is unambiguous (three closed children, no deferrals).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort children inventory (from archived tasknotes):**

- **PID-58.1 | discovery** — Pure PLAN.md filing. Inventoried the shared design surface (no `CFBundleURLTypes` at the time; the "Clean all" sweep was view-side in `MenuBarView`; the [[PID-EPIC-57]] CLI as the Raycast substrate; PID-35.1's "no AppleScript/no network" baseline). Resolved 3 scoping questions (direct `pidlyse://clean` + result notification; AppIntents + Raycast-scripts with AppleScript dropped; extraction-first child split). Filed .2/.3, refined the parent, confirmed .4 as-filed. No code.
- **PID-58.2 | url-scheme** — 6 files. New pure `PidlyseCore/URLScheme.swift` (`pidlyse` scheme + `clean`/`scan` verbs, mirrors `CLICore`, 6 unit tests). Engine-side SSOT hoisted from the view onto `ScanEngine`: `isProtected`, `sweepableSafeItems`, `CleanSummary`, `cleanAllSafe(completion:)` (kill → `recordCleaned` → rescan), `fireCleanResultNotification`. `AppDelegate.application(_:open:)` routes verbs. `Info.plist` `CFBundleURLTypes`. `MenuBarView.isProtected` delegates to the engine SSOT (dedup, no behavior change).
- **PID-58.3 | bridges** — 4 files (1 app edit + 3 new). Two `AppIntent`s (`CleanSafeStraysIntent` → `cleanAllSafe`, dialog-summarised; `ScanNowIntent` → `rescan`) + `PidlyseShortcuts: AppShortcutsProvider`, all in `PidlyseApp.swift` (surgery-free, no pbxproj edit; reach the shared engine via `NSApp.delegate as? AppDelegate`). `integrations/raycast/` — `clean-safe-strays.sh`, `list-strays.sh`, `README.md` (CLI wrappers). README/SPEC/CLAUDE.md doc updates land here (see doc-drift sweep). AppleScript stays dropped.

**Drift-check verification (deliverables present at HEAD):**

| Cited deliverable | Verified |
|---|---|
| `PidlyseCore/URLScheme.swift` | present |
| `ScanEngine` `cleanAllSafe` (:323) / `sweepableSafeItems` (:313) / `isProtected` (:304) / `CleanSummary` (:291) / `rescan` (:252) / `fireCleanResultNotification` (:346) | all present at noted lines |
| `AppDelegate.application(_:open:)` (:70) | present |
| `Info.plist` `CFBundleURLTypes` scheme `pidlyse` | present (:17,:24) |
| `PidlyseApp.swift` `CleanSafeStraysIntent`/`ScanNowIntent`/`PidlyseShortcuts`/`sharedEngine` | all present |
| `integrations/raycast/{clean-safe-strays.sh,list-strays.sh,README.md}` | present, scripts `+x` |
| README "Integrations" (:39) · SPEC "Integrations (PID-EPIC-58)" (:196) · CLAUDE.md integrations bullet (:26) | all present |

**No clarifications needed** — cohort is a clean three-child sweep, all closed same-day, no deferrals or scope shifts.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A (verification pass over existing cohort deliverables; no new code surface)

- [x] Implemented the minimal solution — audit is verification work; findings below. No inline fix needed (see coherence pass).

- [x] Updated/added tests for non-trivial behavior — N/A (no code edit)

**Implementation Notes:**

**Cohort coherence pass — findings:**

- **Single action-layer SSOT, no re-derivation.** All three external-trigger surfaces (popover "Clean all", `pidlyse://clean`, `CleanSafeStraysIntent`) route through the one `ScanEngine.cleanAllSafe` + `sweepableSafeItems` SSOT extracted in .2. Grep confirms `AppDelegate` (URL) and `PidlyseApp` (AppIntent) both reach it; the CLI `commandClean()` derives the equivalent set from the same core primitives. Matches the CLAUDE.md convention bullet exactly ("never re-derive the sweep set"). ✔
- **Naming parity.** The pure core parser `URLScheme` mirrors `CLICore` (namespace enum + `Command` + static `parse`, both tested from `PidlyseTests`) — the .1-scoped "extraction-first, mirror the PID-57 split" intent held. `cleanAllSafe`/`sweepableSafeItems`/`CleanSummary`/`rescan` names used consistently across `AppDelegate` and `PidlyseApp`. ✔
- **Per-surface homes are principled and documented.** Pure verb parse in core; app-lifecycle URL routing in `AppDelegate`; AppIntents in `PidlyseApp.swift` (they need the shared `ScanEngine` + must sit in the app target for AppShortcuts metadata extraction, and stay there to avoid `project.pbxproj` surgery); Raycast docs-only. CLAUDE.md :26 + SPEC :196 table + README :39 all state this split consistently — no contradictory cross-refs. ✔
- **Security posture uniform.** All three children cite PID-35.1 "no NSAppleScript / no network" baseline; every kill path bounded to safe-minus-protected (never Needs Review); AppleScript deliberately dropped with the `osascript`-via-CLI escape hatch documented in README, SPEC, and CLAUDE.md identically. ✔
- **Feedback-channel distinction documented once, consistently.** `pidlyse://clean` posts a result notification (a URL open has no return path); AppIntents return a dialog (their native channel) and post no notification. SPEC :206 and the .3 tasknote both state this rationale — no drift. ✔

**Non-regression observation (not a miss):** PID-58.3's archived tasknote frontmatter reads `status: in-progress`. This is **not** a cohort inconsistency — the `status:` frontmatter field is unmaintained project-wide at closure (archive sample: PID-57.4/57.3 `completed`; PID-56.5/55.4/52.4/57.2 `in-progress`), and the nav-chip "🟢 In progress" is uniform across the entire archive including .1/.2. No inline fix applied (editing it would be a non-surgical change to a field the project doesn't track, and would single out .3 against a uniform archive).

**No misses requiring `/ft-file-followup` filing.** The cohort is internally coherent; docs are current; no code fix surfaced.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → 228 tests, 0 failures (includes the 6 `URLSchemeTests` from .2). Backs the "no regressions in earlier-shipped cohort surfaces" acceptance criterion; run against a clean tree (only the new audit tasknote untracked).

- [x] Ran lint/type-check on changed code — N/A (no code edit landed in the audit; the full app target already type-checks green as part of `make test`)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change; the cohort children already carried their own 👁️ operator-smoke asks for the URL scheme / Shortcuts / Raycast surfaces at their closures)

**Testing Notes:** No code edit in the audit itself, so the suite run is a regression sentinel rather than coverage of new work. 228/228 green confirms the cohort's shipped surfaces (URLScheme parser, engine action layer, AppIntents metadata extraction) remain intact at HEAD.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — per-entry verdict across `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — **no change needed** (PID-58.3 added the "Integrations" section: URL scheme + Shortcuts/Spotlight + Raycast + AppleScript-dropped note; verified current at :39–47).
  - `AGENTS.md` — **no change** (pure flowtron workflow guide; carries no project feature surface, so integrations correctly don't appear there).
  - `CLAUDE.md` — **no change needed** (PID-58.3 added the integrations convention bullet at :26 — shared action layer, per-surface homes, why AppIntents sit in `PidlyseApp.swift`; verified current).
  - `SPEC.md` — **no change needed** (PID-58.3 added "Integrations (PID-EPIC-58)" at :196 with the per-surface entry-point table + back-documented the .2 URL scheme; verified current).
  - `.flowtron/PLAN.md` — **updated in-task** (.4 stub flip; parent flip + cohort move to `## Completed` on operator confirm).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-02.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Audited the completed PID-EPIC-58 (`integrations`) three-child cohort; it sits coherently in the codebase with no misses and no regressions. All external-trigger surfaces (popover "Clean all", `pidlyse://clean`, the `CleanSafeStraysIntent` AppIntent) route through the single `ScanEngine.cleanAllSafe`/`sweepableSafeItems` SSOT extracted in .2 — no re-derivation; the pure `URLScheme` parser mirrors `CLICore` per the .1 extraction-first plan; per-surface homes (core parse / `AppDelegate` URL routing / `PidlyseApp.swift` AppIntents / Raycast docs) are principled and documented identically across README, SPEC, and CLAUDE.md; the PID-35.1 "no NSAppleScript" security baseline and the safe-minus-protected kill bound are uniform across all three children. Doc-drift sweep: all AI-referenced docs current (README/SPEC/CLAUDE.md updated in .3; AGENTS.md correctly untouched). `make test` → 228/228 green against a clean tree. One benign observation logged (PID-58.3's `status: in-progress` frontmatter is project-wide-unmaintained, not a cohort regression — no fix). No `/ft-file-followup` candidates. Chore-only closure (PLAN flip + tasknote archive; no code edits).

**Archived:** 2026-07-02
