---
title: popover-power-ux audit
status: in-progress
tags: [audit, epic]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-50.1, PID-50.2, PID-50.3, PID-50.4, PID-50.5, PID-50.6, PID-50.7]
---

# PID-50.8 | popover-power-ux audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Verify the completed `PID-EPIC-50` (`popover-power-ux`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-50.8 — audit PID-EPIC-50` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-50.8` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-50.8.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-50` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-50.8` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-50.1]] — discovery; scoped the cohort
- [[PID-049]] — ux-feature-survey; sourced the Tier 1+2 shortlist

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-50.8`; pre-flight passed — PID-50.8 is the highest `.N` child of active parent PID-EPIC-50, and all implementation children .1–.7 are closed (no early-audit). Capture cohort state at audit time and verify integration coherence.

- [x] Read relevant source files

- [x] **Archive skim** — read each cohort child's archived tasknote (`archive/pid/PID-50.1..7.md`); deliverables captured below.

- [x] **Drift check** — every cited helper/symbol from the cohort children verified against HEAD (grep); all present, no drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort inventory (archived tasknotes read):**

- **.1 discovery** [medium]🧠 — scoped the epic from the [[PID-049]] Tier 1+2 shortlist; filed .2–.7 + audit. PLAN.md only, no code.
- **.2 row-context-menu** [light]🔧 — `MenuBarView`: `.contextMenu { rowContextMenu(item) }` (Copy PID / command line / `kill <pid>` via `copyToPasteboard` on `NSPasteboard.general`; Reveal-in-Finder via `NSWorkspace`, cwd-conditional, tilde-expanded). +27 LOC; +1 README bullet. No new shell-out.
- **.3 provenance-sort** [light]🔧 — `MenuBarView.grouped(_:)`: per-kind alphabetical sort by `rowDescriptor` (`localizedCaseInsensitiveCompare`), `pid` tiebreaker. ~10 LOC. No README (UX refinement).
- **.4 reclaimable-footprint** [light]🔧 — `MenuBarView`: `safeReclaimableKB` computed prop + "~X MB reclaimable" in the *Safe to clean* header (reuses `ramString`). +5 LOC; +1 README bullet.
- **.5 quick-filter** [medium]🧠 — `MenuBarView`: `@State filterText`, `searchField`, `matchesFilter` folded into `safeItems`/`reviewItems`, "no matches" hint, `.onDisappear` clear (session-scoped). +~45 LOC; +1 README bullet.
- **.6 per-kind-toggles** [medium]🧠 — `ScanCore.enumerate(disabledKinds:)` filter after `collapseWrappers`; `ScanEngine` `@Published disabledKinds` persisted as UserDefaults rawValues; `SettingsView` "Scanned kinds" section + `kindEnabled` binding. +3 `ScanCore` tests; +1 README bullet.
- **.7 popover-keys-dismiss** [medium]🧠 — `MenuBarView` `soleSafeKillShortcut` (invisible ⌘⌫ button, gated to `safeItems.count == 1`); `AppDelegate.togglePopover` `NSApp.activate()` + `makeKey()` fix (popover wasn't key on open → also restored Esc + click-outside). +1 README bullet.

**Drift check:** All cohort helpers verified present at HEAD — `rowContextMenu`/`copyToPasteboard` (MenuBarView:330,345), `localizedCaseInsensitiveCompare` (:430), `safeReclaimableKB` (:421), `matchesFilter`/`filterText`/`safeItems`/`reviewItems` (:400-421), `soleSafeKillShortcut` (:67), `NSApp.activate()`+`makeKey()` (AppDelegate:153-154), `disabledKinds` (ScanCore:25,47-48 / ScanEngine:63-139 / SettingsView), "Scanned kinds"/`kindEnabled` (SettingsView:29,88). No drift.

**No clarifications needed.** Full cohort closed before audit (no early-audit gate); scope is the standard coherence + doc-drift pass.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A; audit is a verification pass over existing cohort deliverables, no new code surface.

- [x] Implemented the minimal solution — verification work only; no inline fixes needed (no misses surfaced).

- [x] Updated/added tests for non-trivial behavior — N/A (no code edits landed).

**Implementation Notes:**

**Coherence findings — no inconsistencies surfaced:**

1. **Interlocking semantics are correct.** `.5`'s `matchesFilter` is folded into `safeItems`/`reviewItems` (MenuBarView:400-401), the single derived-array source; `.4`'s `safeReclaimableKB` reduces over `safeItems` (:421) so the header total tracks the filtered set; `.7`'s ⌘⌫ gates on `safeItems.count == 1` (:67 region) so it targets the *visible* sole safe row. The three later children deliberately compose on the filtered `safeItems` derivation — verified no contradiction, exactly as each child's Discovery Notes claimed.
2. **Naming/style parity.** All new view helpers follow the file's camelCase private-helper idiom (`rowContextMenu`, `copyToPasteboard`, `safeReclaimableKB`, `matchesFilter`, `soleSafeKillShortcut`) alongside the pre-existing `ramString`/`ageString`/`rowDescriptor`; the core/settings additions (`disabledKinds`, `kindEnabled`) mirror the existing `ignoredNames` filter idiom. No new abstraction invented across the cohort.
3. **CLAUDE.md convention respected.** `.6`'s scan-filter lives in `PidlyseCore` (`ScanCore.enumerate`), `.7`'s popover-focus lifecycle in app-side `AppDelegate` — the core/app split in CLAUDE.md holds; no scan logic leaked app-side.
4. **README coherence.** Five feature bullets added (.2/.4/.5/.6/.7); .3 correctly omitted (ordering refinement, not a feature surface). The Features list reads as a coherent whole — no contradictory or duplicated entries.
5. **No regression** — full suite 121/121 green (118 pre-cohort + 3 from .6's `disabledKinds` tests).

**Misses logged for `/ft-file-followup`:** none. No code edits landed → `chore:` commit.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → **TEST SUCCEEDED**, 121 tests, 0 failures (regression check across the cohort's surfaces).

- [x] Ran lint/type-check on changed code — N/A (no code edits in the audit); the test build is the type-check gate and passed.

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed; each cohort child got its own 👁️ confirmation at closure).

**Testing Notes:** Audit is markdown-prose verification + a regression run. Full suite green (121/121) confirms no earlier-shipped cohort surface regressed.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep (fixed line)** — cumulative sweep across §"AI-referenced docs":
  - `README.md` — **no change at audit time**; cumulatively updated by .2/.4/.5/.6/.7 during their closures. Verified all five surfaces are present and read coherently (lines 11, 13, 14, 15, 19). .3 (ordering refinement) correctly carries no bullet.
  - `AGENTS.md` — no change (pure flowtron workflow contract; no feature-surface enumeration).
  - `CLAUDE.md` — no change (cohort introduced no new architectural split; .6's core filter mirrors the existing `ignoredNames` idiom already covered by the "scan/classification lives in PidlyseCore" convention).
  - `.flowtron/PLAN.md` — flipped .8 to stub form below; parent + cohort move to `## Completed` on the Step 9 parent-flip confirmation.

- [x] Closed — PLAN.md `.8` line flipped to stub form `Completed 2026-06-30.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Audited the completed **PID-EPIC-50** (`popover-power-ux`) cohort — six implementation children (.2 row-context-menu, .3 provenance-sort, .4 reclaimable-footprint, .5 quick-filter, .6 per-kind-toggles, .7 popover-keys-dismiss) plus the .1 Discovery. **No inconsistencies surfaced.** Verified the three later children compose correctly on the shared filtered `safeItems` derivation (filter → reclaimable header → ⌘⌫ all track the visible set); naming/style parity holds across all new helpers; the CLAUDE.md core/app split is respected (.6 scan-filter in `PidlyseCore`, .7 focus-lifecycle in `AppDelegate`); README carries five coherent feature bullets (.3 rightly omitted). Full suite 121/121 green — no regression. No misses → no follow-ups filed. `chore:` commit (no code edits in the audit itself).

**Archived:** 2026-06-30
