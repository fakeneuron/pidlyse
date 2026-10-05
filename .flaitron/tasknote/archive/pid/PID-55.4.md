---
title: idle-stray-signals audit
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-55, PID-55.1, PID-55.2, PID-55.3]
---

# PID-55.4 | idle-stray-signals audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-55]]

## 🎯 Goal

Verify the completed PID-EPIC-55 (idle-stray-signals) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [x] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [x] No regressions surfaced in earlier-shipped cohort children's surfaces (`make test`: 197/197 green, same count as `.3` closure)
- [x] Audit findings recorded in Implementation Notes; one miss cited as `/ft-file-followup` candidate (SPEC.md cumulative refresh — filed AFTER audit closure to preserve the filing-discipline gate)
- [x] Single `feat: PID-55.4 — audit PID-EPIC-55` commit lands (SPEC.md doc fixes count as the audit's edits)
- [x] PLAN.md line for `PID-55.4` flipped to stub form `Completed 2026-07-02.`
- [x] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-55.4.md`
- [x] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-55` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [x] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [x] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [x] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [x] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [x] Phase 4: flip `PID-55.4` PLAN line to stub form + archive tasknote
- [x] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-55]] — parent epic (idle-stray-signals)
- [[PID-55.1]] — discovery (scoped children .2–.3)
- [[PID-55.2]] — scan-history-cache (rolling-window CPU cache in PidlyseCore)
- [[PID-55.3]] — idle-dev-signal (dev-flag parse + idle-dev-server inspector signal)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md — parent `PID-EPIC-55` active under `## Medium`; audit `.4` is the highest child; all implementation siblings (`.1`–`.3`) closed 2026-07-02. Full-cohort audit, no early-audit caveat.

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-55.4` and Step 2 pre-flight passed. Cohort state at audit time: `.1` discovery, `.2` scan-history-cache, `.3` idle-dev-signal all completed 2026-07-02 — complete cohort, no deferred children.

- [x] Read relevant source files — each sibling's archived tasknote (Final Summary + Implementation Notes), then the deliverable surfaces at HEAD: `ScanHistory.swift`, `ScanCore.hasDevModeFlag` (ScanCore.swift:305), `ScanEngine.swift` (scanHistory:141 / recordScanHistory:292 / hasSustainedLowCPU:301 / isIdleDevServer:312), `MenuBarView.reasoningBlock` idle line (:420), `ScanEngineTests.swift` (hasDevModeFlag tests :181, ScanHistoryTests :1020), plus README.md, AGENTS.md, CLAUDE.md, SPEC.md.

- [x] **Archive skim** — self-referential: the cohort children (`archive/pid/PID-55.{1,2,3}.md`) are the archive entries in scope. Non-cohort context already folded in by the children themselves (PID-35.3 `ProcStartTime` token, PID-54.2 `hasTokenBoundary`, PID-036/52 reasoningBlock line pattern, PID-53.2 pure/impure split).

- [x] **Drift check** — all cohort-cited paths and symbols match HEAD (verified by grep + read; see source list above). One cumulative drift found *outside* the per-task sweep set: `SPEC.md` (see Discovery Notes).

- [x] Asked clarifying questions OR logged "No clarifications needed" — **No clarifications needed.** Cohort is complete and unambiguous; audit scope is the full `.1`–`.3` set.

- [x] Subtasks above populated with concrete, ordered steps (Step 3 scaffold; no scope shift surfaced)

**Discovery Notes:**

**Cohort deliverables inventory.**
- **PID-55.1 (discovery)** — no code; filed `.2`/`.3` scopes, resolved two operator decisions: expansion-only surfacing (no row chip) and infra/signal child split. Parent line refined to N=4.
- **PID-55.2 (scan-history-cache)** — `PidlyseCore/ScanHistory.swift` (new pure value type: rolling window keyed by PID+`ProcStartTime`, `recording(_:)` append/cap/prune, `isSustainedLowCPU` query, defaults 5/<1.0%/3); `ProcStartTime` gained `Hashable`; `ScanEngine` holds the instance + `hasSustainedLowCPU(_:)` accessor. 11 `ScanHistoryTests`. CLAUDE.md convention line updated.
- **PID-55.3 (idle-dev-signal)** — pure `ScanCore.hasDevModeFlag` (`--watch`/`--dev`/`--hot`/`--reload` + `NODE_ENV=development`, token-boundary discipline); `ScanEngine.isIdleDevServer` strict-AND fold (sustained-low-CPU + old + no-TTY + dev-flag, operator-resolved); one graceful-degrade reasoning line in `MenuBarView.reasoningBlock`. 3 parser tests (197 total green at closure). README.md inspector enumeration + CLAUDE.md convention line updated.

**Coherence signals (verified at HEAD).** All symbols present where the children said; CLAUDE.md line 18 names both halves of the split consistently; README line 10 carries the signal; doc comments in all three code surfaces state the signal-only invariant consistently; `riskTier` takes no CPU input (invariant held).

**Drift found — SPEC.md (cumulative, mostly pre-cohort).** `SPEC.md` is not in the AI-referenced docs registry, so per-task Phase 4 sweeps never walk it, and it has lagged several cohorts:
- Inspector paragraph (SPEC.md:122) omits the idle-dev-server signal (this cohort) *and* PID-52's additions (full command line, ancestor chain to launchd, open files + sockets).
- Project-structure tree (SPEC.md:20–46) omits `ScanHistory.swift` (this cohort) *and* `AncestryResolver`/`OpenFilesResolver` (PID-52), `CleanEvent`/`CleanLog` + app-side `CleanLogStore`/`CleanedView` (PID-53), `CustomRule` (PID-54).

**Resolution:** cohort-slice fixes applied inline in Phase 2 (add `ScanHistory.swift` to the tree + the idle-dev-server line to the inspector paragraph); the pre-cohort SPEC.md staleness (PID-52/53/54 slices, plus deciding whether SPEC.md belongs in the AI-referenced docs registry) is follow-up-sized → `/ft-file-followup` candidate.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A for the verification pass (no new code surface). The two inline SPEC.md doc fixes follow the section's own idiom: one-line file-tree comment matching the sibling entries' style, and a `([[PID-EPIC-55]])` provenance tag matching the paragraph's existing `(PID-EPIC-036)` / `[[PID-EPIC-037]]` convention.

- [x] Implemented the minimal solution — verification pass over the cohort + two small in-scope inline doc fixes (no Swift edits):
  - `SPEC.md` project-structure tree: added the missing `ScanHistory.swift` entry.
  - `SPEC.md:122` inspector paragraph: appended the idle-dev-server advisory line (signal-only wording preserved).

- [x] Updated/added tests for non-trivial behavior — N/A (doc-only edits; full suite run in Phase 3 as the regression check).

**Implementation Notes:**

**Cohort children inventoried.**
- `.1` discovery — filed `.2`/`.3`, resolved expansion-only surfacing + infra/signal split; no code.
- `.2` scan-history-cache — pure `ScanHistory` in PidlyseCore (PID+startTime keyed, append/cap/prune, sustained-low-CPU query) + `ScanEngine` wiring; 11 tests.
- `.3` idle-dev-signal — pure `ScanCore.hasDevModeFlag` + `ScanEngine.isIdleDevServer` strict-AND fold + one graceful-degrade `reasoningBlock` line; 3 tests; README/CLAUDE.md updated.

**Coherence findings.** No inconsistencies across the cohort's deliverables: naming is consistent (`ScanHistory` / `hasSustainedLowCPU` / `hasDevModeFlag` / `isIdleDevServer` cross-reference each other correctly in doc comments), the pure-core/impure-app split matches the CLAUDE.md convention line verbatim, the signal-only invariant is stated identically at all three code surfaces and held in code (`riskTier` takes no CPU input, no new `@Published`), and README/CLAUDE.md updates the children logged are present at HEAD.

**Inline fixes applied.**
- `SPEC.md` tree: `+ ScanHistory.swift` line (cohort slice of a larger pre-existing omission).
- `SPEC.md` inspector paragraph: `+` idle-dev-server sentence with `([[PID-EPIC-55]])` tag.

**Miss logged → `/ft-file-followup` candidate (1).**
- **SPEC.md cumulative refresh (pre-cohort slices):** the inspector paragraph still omits PID-52's additions (full command line, ancestor chain to launchd, open files + sockets) and the project-structure tree still omits `AncestryResolver`/`OpenFilesResolver` (PID-52), `CleanEvent`/`CleanLog`/`CleanLogStore`/`CleanedView` (PID-53), and `CustomRule` (PID-54). Root cause: SPEC.md is not in the AI-referenced docs registry, so per-task Phase 4 sweeps never walk it — the follow-up should also decide whether to add it (or note why it stays out). Doc-only, [light]🔧-shaped.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **197 tests, 0 failures** (same count as `.3` closure — the "no regressions in cohort surfaces" acceptance check).

- [x] Ran lint/type-check on changed code — N/A beyond the suite build (doc-only edits; the `make test` build compiles app + PidlyseCore clean; no separate linter in this repo).

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed; `.3`'s 👁️ offer stands on its own terms).

**Testing Notes:** Audit is a verification pass — the full suite doubles as the regression check over the cohort's surfaces (`ScanHistoryTests` ×11 + `hasDevModeFlag` ×3 included in the 197). Markdown edits verified by re-read.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (line 10 already carries the idle-dev-server signal from `.3`'s closure; the audit shipped nothing user-facing) · `AGENTS.md`: no change (no inspector/signal detail lives there) · `CLAUDE.md`: no change (the PidlyseCore convention line already covers `.2` + `.3`; verified verbatim-accurate at HEAD) · `.flowtron/PLAN.md`: **updated** — `.4` flipped to stub form; parent flip pending the Step 8/9 prompt. *(Outside the registry: `SPEC.md` updated inline for the cohort slice; pre-cohort staleness → follow-up candidate.)*

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-02.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate — parent-flip prompt forces the gate)

**Final Summary:** Audited the completed `PID-EPIC-55` (`idle-stray-signals`) cohort. The cohort is coherent: naming, doc comments, and the pure-core/impure-app split are consistent across `ScanHistory` (`.2`) and the `hasDevModeFlag`/`isIdleDevServer`/reasoning-line path (`.3`); the signal-only invariant is stated identically at all three code surfaces and held in code (`riskTier` takes no CPU input, no new `@Published`); `make test` 197/197 green (same count as `.3` closure — no regressions). One cumulative miss surfaced: `SPEC.md` is outside the AI-referenced docs registry and lags several cohorts. Cohort slice fixed inline (added `ScanHistory.swift` to the project tree + the idle-dev-server line to the inspector paragraph); pre-cohort slices (PID-52 inspector additions; PID-52/53/54 file-tree omissions; registry-membership decision) logged as a `/ft-file-followup` candidate. **Parent flip: confirmed (Yes)** — `PID-EPIC-55` flipped to stub form `Completed 2026-07-02.` and the full cohort moved to the top of `## Completed`. Files: `SPEC.md`, `.flowtron/PLAN.md`, this tasknote.

**Archived:** 2026-07-02
