---
title: killability-truth audit
status: completed
tags: []
created: 2026-09-24
due:
related-tasks: [PID-EPIC-62, PID-62.1, PID-62.2, PID-62.3, PID-62.4, PID-62.5]
touches:
  - SPEC.md
---

# PID-62.N | killability-truth audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-62]]

## 🎯 Goal

Verify the completed `PID-EPIC-62` (`killability-truth`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [x] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [x] No regressions surfaced in earlier-shipped cohort children's surfaces
- [x] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [x] Single `feat: PID-62.N — audit PID-EPIC-62` (or `chore: ...` if no code edits land) commit lands — `chore:` (doc-only inline fixes)
- [x] PLAN.md line for `PID-62.N` flipped to stub form `Completed YYYY-MM-DD.`
- [x] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-62.N.md`
- [x] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-62` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [x] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [x] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [x] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [x] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [x] Phase 4: flip `PID-62.N` PLAN line to stub form + archive tasknote
- [x] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-62]] — parent epic
- [[PID-62.1]] / [[PID-62.2]] / [[PID-62.3]] / [[PID-62.4]] / [[PID-62.5]] — audited cohort
- [[PID-069]] / [[PID-070]] — already-parked follow-ups from [[PID-62.5]]

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-62.N`. All implementation children are closed: .1 and .2 on 2026-08-08, .3 and .4 on 2026-09-23, .5 on 2026-09-24. No early-audit decision was needed.

- [x] Read relevant source files — the five archived cohort tasknotes (Final Summaries), plus the current `SPEC.md` §"Classification" / §"Kill Flow" / §"CLI Companion" / §"Integrations", `README.md` feature list, `CLAUDE.md` conventions, `ScanEngine.isSweepable` / `sweepableSafeItems`, and CLI `commandClean`

- [x] **Best Practices Review** — N/A: this is a verification pass. The only edits are two doc lines.

- [x] **Archive skim** — self-referential: the cohort children are the archive entries. PID-039 (npm merge), PID-54.4 (protected projects) and PID-58.2 (action layer) are cited in the cohort notes. Their surfaces are covered by the drift check below.

- [x] **Drift check** — the cited symbols exist at HEAD: `ScanCore.collapseTrees`, `KillCore.groupOutcome`, `Killability.groupOwnerUID`, `ScanEngine.kill` / `isSweepable` / `sweepableSafeItems`, `KillFeedback.swift` (`KillPhase` / `KillReport`), and `RespawnHistory.swift`. `recordCleaned` still exists (only the single-item overload was removed in .5), so the references in CLAUDE.md, `KillService.swift` and `CleanLogStore.swift` still hold.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — No clarifications needed. The cohort is complete, and the audit scope is exactly .1–.5.

- [x] Subtasks above populated with concrete, ordered steps, and YAML `touches:` declared with the paths this task expects to edit (omit only on a task with no file deliverable)

**Discovery Notes:**

- **.1 killability-truth discovery.** Deep pre-pass: a constitution, a per-child spec, and 4 clarifications (explanation replaces the button; session-only respawn memory; app-only CLI respawn parity). It filed .2–.5 and parked PID-063. No code.
- **.2 respawn-detection-core.** `KillCore` checks for death after SIGKILL and adds `.survived`. It also adds the pure `RespawnHistory` and `ScanEngine.isRespawner`. 250 tests.
- **.3 honest-unkillable-ux.** Adds `Killability` (unkillable / respawner) and `KillOutcome.unkillable` (EPERM). `ProcessItem.uid`, `ScanEngine.killability` / `isSweepable`, and `KillCore.routesViaDockerStop` go with it. Rows get 🚫 / ↻ badges and an inspector line, and the CLI `clean` excludes foreign-owned rows. 273 tests.
- **.4 tree-redundancy-collapse.** `ScanCore.collapseTrees` with `belongsWithParent`, `ProcessItem.members`, `KillCore.groupOutcome`, `Killability.groupOwnerUID`, a ×N count and a "group of N" inspector line. 290 tests. It deferred two side findings: Chrome helpers under `--isolated` playwright-mcp go undetected, and Claude Code `zsh -c` shell-snapshot processes are misclassified as `.npm`.
- **.5 kill-feedback-stability.** One `ScanEngine.kill` for every trigger, plus `KillFeedback.swift` (`KillPhase` / `KillReport`). Scan requests during a scan now coalesce, and kill state is keyed by pid + start time. Respawns must start after the kill. 301 tests. It parked PID-069 and PID-070.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A: a verification pass with no new code surface

- [x] **Minimal refactor gate** — no refactor; two stale doc lines corrected in place

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (doc-only edits)

**Implementation Notes:**

- **Coherence:** the cohort reads as one design. Each piece has one home: kill truth in `KillCore`, respawn memory in `RespawnHistory`, the overlay in `Killability`, grouping in `collapseTrees`, and the feedback vocabulary in `KillFeedback`. Each follows the established pure-core / `ScanEngine`-owned-instance split, and CLAUDE.md records every one. Naming is consistent: the outcome cases `confirmed` / `survived` / `notKilled` / `unkillable` map 1:1 to the `KillPhase` labels `gone` / `didn't die` / `skipped` / `can't kill`. SPEC §"Kill Flow" steps 4–7 cite the right child each time. There are no contradictory cross-refs.
- **Regressions:** none found. .5 tightened .2's respawn rule (the respawn must start after the kill), and SPEC §"Respawn detection" records the change. .4's group-owner fold feeds .3's overlay, and both docs agree.
- **Inline fix 1:** `SPEC.md` §"CLI Companion", `pidlyse clean` row. It said "safe bucket minus protected projects", which predates .3. It now also excludes foreign-owned rows, with respawners app-only, matching SPEC §"Classification" and CLAUDE.md.
- **Inline fix 2:** `SPEC.md` §"Integrations" intro. `cleanAllSafe` was described as "safe bucket minus protected", and every trigger as "bounded to safe-minus-protected". Both predate .3 and .5. The intro now names the `sweepableSafeItems` / `ScanEngine.isSweepable` set and the `ScanEngine.kill` route.
- **Misses (follow-up candidates, file after closure):**
  - `/ft-file-followup` — **isolated-chrome-helper-detection**: under `--isolated`, playwright-mcp's Chrome helpers are not detected, so the README's "playwright-mcp → its Chrome helpers" single-row example doesn't hold in that mode. Found in .4 and never filed.
  - `/ft-file-followup` — **shell-snapshot-misclassify**: Claude Code `zsh -c` shell-snapshot processes are classified as `.npm`. Found in .4 and never filed.
  - PID-069 and PID-070 are already filed (from .5). No action needed.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (markdown-only diff)

- [x] Ran lint/type-check on changed code — N/A (no Swift changed)

- [x] **Verification receipt** — N/A: the diff is 2 SPEC.md prose lines, checked against `ScanEngine.isSweepable` (`Pidlyse/ScanEngine.swift:473`) and CLI `commandClean`

- [x] **External review** — N/A: a two-line prose correction, too small to grade

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

Nothing to run: the diff is prose only. Each corrected claim was checked against the code at HEAD.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — no change. The cohort's features (one row per logical process, honest kill feedback) are listed. The playwright-mcp example is accurate outside `--isolated`, and that gap is a follow-up candidate.
  - `AGENTS.md` — no change (only the flowtron paste-block and project guide; no cohort surface)
  - `CLAUDE.md` — no change. `RespawnHistory`, `Killability`, `KillFeedback`, `collapseTrees`, `ScanEngine.kill` and the four kill outcomes are all current.
  - `SPEC.md` — updated: 2 sweep-set lines (see Implementation Notes)
  - `.flowtron/PLAN.md` — audit line stubbed; parent flip per operator decision

- [x] Closed — every `## ✅ Acceptance` criterion ticked or explicitly annotated (`N/A` / not-met with a one-line reason), YAML `status:` flipped to `completed`, PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` and placed (standalone → top of `## Completed`; epic child → kept nested beneath its active parent — see SPEC/plan-filing.md §"`## Completed` archive convention" if unclear), then tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] **Evidence-based recap** drafted — changed files/LOC where meaningful, verification commands/results, refactors made or deferred with rationale, documentation verdict, the `touches:` scope reconciliation (`git diff --name-only` vs declared; name undeclared paths), and concrete maintainability effect (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

- [x] **Learnings** — N/A. The deferred side findings from .4 slipped because they appeared only in its Final Summary and were never parked with `--park`. That is covered by the existing filing discipline, not a new rule.

**Final Summary:**

The audit found no inconsistencies in the PID-EPIC-62 (killability-truth) cohort. The five children fit together: each concern has one home in core, one consumer in `ScanEngine`, and one vocabulary across the popover, notification, Shortcuts and CLI. Two SPEC.md lines still described the sweep set as it was before .3; both were corrected inline. Two side findings from .4 were never filed and are listed as follow-up candidates: Chrome helpers under isolated playwright-mcp, and shell-snapshot processes misclassified as npm.

- Changes: `SPEC.md` +2/−2 (§"CLI Companion" `clean` row, §"Integrations" intro). `touches:` reconciliation: SPEC.md as declared, plus `.flowtron/PLAN.md` and this tasknote (closure).
- Verification: prose checked against `ScanEngine.isSweepable` / `sweepableSafeItems` and CLI `commandClean`. No code changed, so no tests were needed.
- Parent flip: the operator confirmed. PID-EPIC-62 is marked done, and it moved with all its tasks to the top of `## Completed` (`## High` is back to `(none)`).

**Archived:** 2026-09-24
