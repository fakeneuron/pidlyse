---
title: clean-history-stats audit
status: in-progress
tags: []
created: 2026-07-01
due:
related-tasks: [PID-EPIC-53, PID-53.1, PID-53.2, PID-53.3]
---

# PID-53.4 | clean-history-stats audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-53]]

## 🎯 Goal

Verify the completed PID-EPIC-53 (`clean-history-stats`) cohort sits coherently in
the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md`
§"AI-referenced docs", naming/style consistency across the cohort's deliverables,
and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-53.4 — audit PID-EPIC-53` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-53.4` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-53.4.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-53` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-53.4` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-53]] — parent epic (clean-history-stats)
- [[PID-53.1]] — discovery; scoped the epic + filed .2/.3
- [[PID-53.2]] — clean-log-store (data layer: CleanEvent + CleanLog + CleanLogStore + KillOutcome)
- [[PID-53.3]] — cleaned-tab-stats (presentation layer: CleanedView + third tab)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-53.4`; pre-flight passed
  (audit is the highest `.N` child of PID-EPIC-53; siblings `.1`/`.2`/`.3` all
  closed; parent still open under `## High`). Capture cohort state at audit time
  — all three children closed 2026-06-30..2026-07-01; no early-audit decision
  (full cohort closed before audit).

- [x] Read relevant source files — read all three archived cohort tasknotes and
  verified their cited deliverables at HEAD (see Discovery Notes).

- [x] **Archive skim** — self-referential for this epic audit; the cohort children
  are themselves the archive entries. No non-cohort surfaces with prior tasknote
  history beyond the cohort needed re-reading.

- [x] **Drift check** — every path/symbol cited in the cohort children's
  deliverables still matches HEAD (verified paths below). No drift.

- [x] Asked clarifying questions — none needed; cohort scope is unambiguous (full
  cohort closed, three children, clean Core/App split).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

*Cohort inventory (children read + verified at HEAD):*
- **PID-53.1 (discovery)** — scoped the epic, resolved 3 operator forks
  (confirmed-kills-only, minimal privacy-first `CleanEvent`, third "Cleaned" tab),
  filed `.2`/`.3`. Deliverable = planning; no code.
- **PID-53.2 (clean-log-store, data layer)** — `Packages/PidlyseCore/Sources/PidlyseCore/CleanEvent.swift`
  (Codable, no command line) + `CleanLog.swift` (pure `capped(_:cap:)` retention +
  `stats(from:now:window:)` → count / RAM / freq-ranked topKinds).
  `KillService.KillOutcome { confirmed, notKilled }` threaded through single + batch
  completions (guard-refuse / EPERM → notKilled; SIGTERM-sent / docker-stop →
  confirmed; no guard predicate touched). App `CleanLogStore.swift` (JSON at
  `~/Library/Application Support/Pidlyse/clean-log.json`, count cap 1000).
  `ScanEngine.recordCleaned` builds events labelled from `cwds`. 9 new `CleanLogTests`.
- **PID-53.3 (cleaned-tab-stats, presentation layer)** — `Pidlyse/CleanedView.swift`
  (~150 LOC, `@ObservedObject CleanLogStore`): rolling-week stats strip + newest-first
  "Recently cleaned" list (cap 50) + empty state. `MenuBarView` `.cleaned` Tab +
  third "Cleaned" segment + `refreshHelp` / disabled header on the live-bound tab.

*Drift check (paths/symbols verified at HEAD):*
- `Packages/PidlyseCore/Sources/PidlyseCore/CleanEvent.swift`, `CleanLog.swift` — present.
- `Pidlyse/CleanLogStore.swift`, `Pidlyse/CleanedView.swift` — present.
- `KillOutcome` (KillService.swift:22), `recordCleaned` (ScanEngine.swift:217/224),
  `cleanLog` (ScanEngine.swift:103), `CleanedView(store: engine.cleanLog)`
  (MenuBarView.swift:50), 3 kill sites forwarding outcomes (MenuBarView:73/224/336) — all present.

**Phase 1→2 exit:** No clarifications needed; entering Phase 2.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A. Verification pass over existing cohort deliverables;
  no new code surface.

- [x] Implemented the minimal solution — audit verification (no code edits). Cohort
  coherence checklist walked; findings below.

- [x] Updated/added tests — N/A (no code changed).

**Implementation Notes:**

*Cohort children inventoried:* (see Discovery Notes — .1 planning, .2 data layer,
.3 presentation layer.)

*Coherence findings — no inconsistencies surfaced:*
- **Type/naming parity.** `CleanEvent` / `CleanLog` / `CleanLogStore` / `CleanedView`
  follow the established PascalCase + Core/App split naming (mirrors
  `Container`/`DockerCore`/`DockerService`, `ScanCore`/`ScanEngine`). The "Cleaned"
  tab label is consistent everywhere (Tab case `.cleaned`, segment text "Cleaned",
  README bullet "Cleaned tab").
- **Data-model contract consistency.** `CleanEvent` fields (`kind` rawValue,
  `projectLabel`, `rssKB`, `timestamp`) are described identically across the code
  doc-comments, the CLAUDE.md Conventions bullet, and the README "Cleaned tab"
  bullet ("kind, project label, RAM, and time only — never the command line").
  No contradiction.
- **Privacy posture aligned.** The "no command line" decision (fork #2) is stated
  consistently in `CleanEvent.swift` doc-comment, `CLAUDE.md`, and `README.md`.
- **Cross-refs intact.** Archived cohort tasknotes cross-link cleanly
  ([[PID-53.1/.2/.3/.4]], [[PID-EPIC-53]]); no dangling or contradictory refs.
- **No regressions** in earlier-shipped surfaces — `make test` green (see Testing).

*Inline fixes applied:* none — audit surfaced no coherence issues.

*Misses logged as `/ft-file-followup` candidates:* none.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — no code changed by the audit; ran
  the full suite anyway as the no-regression check (see Testing Notes).

- [x] Ran lint/type-check on changed code — N/A (no code edits; audit is
  markdown-prose verification + PLAN/tasknote closure ops only).

- [x] (frontend) Visual confirmation — N/A (no UI change; PID-53.3 already
  operator-confirmed the Cleaned tab).

**Testing Notes:** Ran `make test` as a no-regression sanity check over the
shipped cohort surface — **149 passed, 0 failures** (incl. the 9 `CleanLogTests`
shipped in PID-53.2). No regressions.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each `.flowtron/tasknote/README.md` §"AI-referenced docs" entry, verdict recorded below.

- [x] Closed — PLAN.md line flipped to stub form + tasknote moved to `archive/pid/`.

- [x] Recap drafted.

**Doc-drift sweep (fixed line):**
- `README.md` — **no change.** Cleaned-tab Features bullet + the Processes /
  Containers / Cleaned 3-segment toggle mention (added by PID-53.3) are present
  and accurate at HEAD.
- `AGENTS.md` — **no change.** Carries no core-file / feature inventory that
  references the clean log; consistent with all three children's Phase 4 sweeps.
- `CLAUDE.md` — **no change.** The clean-log Conventions bullet (added PID-53.2)
  accurately cites `CleanEvent.swift`, `CleanLog.swift`, `CleanLogStore.swift`,
  the `clean-log.json` path, `recordCleaned`, and `KillOutcome`/`.confirmed` — all
  verified present at HEAD.
- `.flowtron/PLAN.md` — **updated** (this audit's own closure artifact: `.4` line
  flipped to stub; parent-flip on operator confirm).

**Final Summary:** Audited the PID-EPIC-53 (`clean-history-stats`) cohort — no
inconsistencies surfaced; the three children sit coherently in the codebase.
Verified all cited deliverables at HEAD: `CleanEvent`/`CleanLog` (PidlyseCore),
`CleanLogStore`/`CleanedView` (app), `KillOutcome` threading, and the
`recordCleaned`/`cleanLog`/third-tab wiring. Type naming follows the established
Core/App split convention; the `CleanEvent` data-model contract and the
privacy-first "no command line" posture are described consistently across the
code doc-comments, `CLAUDE.md`, and `README.md`; cross-refs across the archived
cohort tasknotes are intact. Doc-drift sweep: `README.md` / `AGENTS.md` /
`CLAUDE.md` all no-change (the cohort's per-task Phase 4 sweeps kept them
current); `.flowtron/PLAN.md` updated by this closure. `make test` = 149 passing,
no regressions. No inline fixes needed; no follow-ups filed.

**Archived:** 2026-07-01
