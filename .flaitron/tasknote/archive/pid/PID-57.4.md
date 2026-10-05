---
title: cli-companion audit
status: completed
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-57, PID-57.1, PID-57.2, PID-57.3]
---

# PID-57.4 | cli-companion audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-57]]

## 🎯 Goal

Verify the completed `PID-EPIC-57` (`cli-companion`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [x] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [x] No regressions surfaced in earlier-shipped cohort children's surfaces
- [x] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate) — no misses surfaced
- [x] Single `feat: PID-57.4 — audit PID-EPIC-57` (or `chore: ...` if no code edits land) commit lands
- [x] PLAN.md line for `PID-57.4` flipped to stub form `Completed YYYY-MM-DD.`
- [x] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-57.4.md`
- [x] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-57` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [x] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [x] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [x] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [x] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate (none surfaced)
- [x] Phase 4: flip `PID-57.4` PLAN line to stub form + archive tasknote
- [x] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-57]] — parent epic: cli-companion terminal binary sharing PidlyseCore
- [[PID-57.1]] — discovery: scoped children .2–.3, operator scoping table
- [[PID-57.2]] — kill-core-extraction: kill path + DockerService into PidlyseCore
- [[PID-57.3]] — cli-target: the `pidlyse` SPM executable

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User invoked `/ft-close-epic PID-57.4`; skill pre-flight passed. Full cohort at audit time: .1 (discovery), .2 (kill-core-extraction), .3 (cli-target) all closed 2026-07-02 — no early-audit partial-cohort caveat; the audit covers the complete implementation set.

- [x] Read relevant source files

- [x] **Archive skim** — cohort children's archived tasknotes read in full (self-referential for an epic audit); no non-cohort archive reads needed — the cohort's own tasknotes cite the load-bearing precedents ([[PID-35.3]], [[PID-53.2]], [[PID-27.2]], [[PID-28.2]])

- [x] **Drift check** — all paths cited in cohort deliverables verified at HEAD (see Discovery Notes); no drift

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — **no clarifications needed**; full cohort closed, scope unambiguous

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort inventory (from archived tasknotes):**

- [[PID-57.1]] (discovery) — filed children .2/.3 in PLAN.md; operator scoping table: extraction-first split, full app-settings parity via `com.fakeneuron.pidlyse` defaults domain, shared clean-log writes, hand-rolled arg parsing / zero deps. No code.
- [[PID-57.2]] (kill-core-extraction) — new core `KillCore.swift` (synchronous SIGTERM → 2 s grace → SIGKILL, PID-35.3 identity guards, EPERM → `.notKilled`, docker-stop routing); impure `DockerService` moved into core; app kept thin wrappers (`KillService.swift` ~57 LOC, `DockerService+Async.swift`); tests migrated (`KillServiceTests` → `KillCoreTests`); CLAUDE.md/SPEC.md/README convention + structure updates; `Package.swift` header re-pointed at this epic.
- [[PID-57.3]] (cli-target) — `.executableTarget` `PidlyseCLI` + `pidlyse` product in the existing package; pure grammar/formatting in core `CLICore.swift` (+18 tests); clean-log disk I/O extracted to core `CleanLogFile.swift` (single format SSOT, `CleanLogStore` reduced to the `@Published` binding); `main.swift` replicates `ScanEngine.scan()`'s pipeline with full defaults-domain parity; Makefile `build-cli`/`install-cli`; SPEC "CLI Companion" section, README build paragraph, CLAUDE.md bullets, tasknote README quick-command.

**Drift check at HEAD:** all cohort-cited files present — core: `KillCore.swift`, `DockerService.swift`, `CLICore.swift`, `CleanLogFile.swift`, `Sources/PidlyseCLI/main.swift`; app: `KillService.swift`, `DockerService+Async.swift`, `CleanLogStore.swift`. Makefile has `build-cli`/`install-cli` (+ `.PHONY`). Tasknote README quick-commands includes the `build-cli` line. No path drift.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A: verification pass over existing cohort deliverables; no new code surface

- [x] Implemented the minimal solution — audit = coherence verification; findings below; no inline fixes required

- [x] Updated/added tests for non-trivial behavior — N/A: no code edits

**Implementation Notes:**

**Cohort coherence findings — no inconsistencies surfaced.**

- **Naming consistency:** the cohort's three new core files follow the established `*Core` split naming (`KillCore` beside `ScanCore`/`DockerCore`; `CLICore` for the grammar; `CleanLogFile` for the shared I/O, matching the `CleanLog`/`CleanLogStore` pair). App-side wrapper naming (`DockerService+Async.swift` extension file) matches its declared role in both SPEC.md:54 and CLAUDE.md.
- **Cross-refs coherent across docs:** SPEC.md structure listing (lines 39–55) names all five new/moved files with roles matching the tasknotes; SPEC.md:185–194 "CLI Companion" section states the parity contract (defaults domain, `KillCore` routing, shared clean-log) consistently with CLAUDE.md's cli-companion bullet; SPEC.md:200's docker note correctly says `DockerService` is "in `PidlyseCore` since PID-57.2". README security section links point at the *core* `DockerService.swift`/`KillCore.swift` paths (updated by .2). `Package.swift` header cites this epic (PID-EPIC-57) as the second consumer, not the abandoned EPIC-27 helper.
- **No stale pre-extraction references:** grep across README/SPEC/AGENTS/CLAUDE for "app-side DockerService" / `Pidlyse/DockerService.swift` / kill-path-in-KillService phrasing — the only hit is CLAUDE.md's *current* convention bullet (kill path in `KillCore`, `KillService` as thin wrapper), which is correct.
- **No regressions:** `make test` — **222 tests, 0 failures** (includes the migrated `KillCoreTests` and the .3-added `CLICoreTests`/`CleanLogFileTests`); `swift build --package-path Packages/PidlyseCore` — clean standalone build including the `pidlyse` executable (the CLI's consumption mode).
- **Inline fixes applied:** none needed.
- **`/ft-file-followup` candidates:** none — no misses surfaced.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — no code changed by the audit; full suite run anyway as the regression check (222/222 green)

- [x] Ran lint/type-check on changed code — N/A (markdown-only edits: tasknote + PLAN.md; mental-pass on grammar/indent/cross-refs)

- [x] (frontend) Asked the user for visual confirmation — N/A (no frontend surface)

**Testing Notes:** Verification-only audit. `make test` 222/222 pass; standalone `swift build` of `PidlyseCore` (incl. `pidlyse` executable) builds clean in 2 s. No lint surface (no SwiftLint in repo; no Swift edits landed).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-02.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Audited the completed PID-EPIC-57 (cli-companion) cohort — **no inconsistencies surfaced, no follow-ups to file.** All three children's deliverables verified at HEAD: naming follows the established `*Core` split conventions, doc cross-refs (SPEC.md structure + "CLI Companion" section, README build paragraph + security links, CLAUDE.md convention bullets, `Package.swift` header) are mutually consistent and current, no stale pre-extraction references remain, and the regression check passed (`make test` 222/222; standalone package build incl. the `pidlyse` executable green). Cumulative doc-drift sweep: all five AI-referenced docs current — the per-child Phase 4 closures (.2/.3) had already landed every needed update.

Doc-drift sweep: `README.md` no change (CLI paragraph + core security links landed in .2/.3, verified current) · `AGENTS.md` no change (workflow-only content; no kill/docker/CLI references) · `CLAUDE.md` no change (Build line + convention bullets updated by .2/.3, match HEAD) · `SPEC.md` no change (structure entries + "CLI Companion" section landed in .3, verified current) · `.flowtron/PLAN.md` updated in-task (.4 stub flip; parent flip per operator decision at the 📦 gate).

Parent-flip decision: **confirmed** — PID-EPIC-57 flipped to stub form and cohort moved to `## Completed` in the same commit.

**Archived:** 2026-07-02
