---
title: docker-panel audit
status: in-progress
tags: [epic-28, audit, docker]
created: 2026-06-26
due:
related-tasks: [PID-EPIC-28, PID-28.1, PID-28.2, PID-28.3, PID-28.4]
---

# PID-28.5 | docker-panel audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-28]]

## 🎯 Goal

Verify the completed `PID-EPIC-28` (`docker-panel`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-28.5 — audit PID-EPIC-28` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-28.5` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-28.5.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-28` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-28.5` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-28]] — parent epic: Docker/container management panel
- [[PID-28.1]] — discovery
- [[PID-28.2]] — docker-service
- [[PID-28.3]] — container-actions
- [[PID-28.4]] — container-panel-ui

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-close-epic PID-28.5`. All four implementation children (`.1`–`.4`) are closed `[x]`. `PID-28.5` is the highest-numbered child and the pre-filed audit. Pre-flight passed cleanly — no early-audit override needed.

- [x] Read relevant source files — read all four cohort archived tasknotes (Final Summary + Implementation Notes). Verified at HEAD: `Packages/PidlyCore/Sources/PidlyCore/Container.swift`, `DockerCore.swift`; `Pidly/DockerService.swift` (all six methods: `isInstalled`, `listContainers`, `list`, `stop`, `remove`, `performThenRefresh`); `Pidly/ContainersView.swift`; `Pidly/MenuBarView.swift` (Tab enum + segmented control + tab-aware ↻); `Pidly/KillService.swift` (no private docker helpers).

- [x] **Archive skim** — cohort is self-contained; no non-cohort archive entries touch the docker panel surfaces (confirmed: prior docker references live in `PID-14.3` (docker-stop-note, documents KillService behavior — behavior unchanged), `PID-16.2` (shellout-helper, centralized `runDocker` inside KillService — now extracted to DockerService), `PID-27.2` (shared-scan-core, the impure/pure split precedent mirrored by this cohort)).

- [x] **Drift check** — All cohort deliverables present at HEAD. One minor path discrepancy: cohort tasknotes cite `PidlyCore/Sources/PidlyCore/` but the actual path is `Packages/PidlyCore/Sources/PidlyCore/`. This is a prose artefact in already-archived tasknotes only — the code is at the correct location, the app compiles clean, tests pass. No action needed.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — No clarifications needed. Audit scope is the four implementation children (.1–.4); all closed.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort deliverables (one bullet per child):**
- **PID-28.1** (discovery): Scoped the epic via AskUserQuestion — resolved three decisions (segmented tab in popover, stop+remove action set, DockerService/DockerCore impure/pure split). Filed `.2`–`.4` into PLAN.md. No code edits.
- **PID-28.2** (docker-service): Added `Container.swift` + `DockerCore.swift` to `Packages/PidlyCore/Sources/PidlyCore/`; added `DockerService.swift` to `Pidly/`; refactored `KillService.swift` to delegate all docker CLI access to `DockerService`; wired `DockerService.swift` into `project.pbxproj` (explicit refs B145/B146); added 7 `DockerCoreTests`; updated `CLAUDE.md` with the docker-split convention.
- **PID-28.3** (container-actions): Added `stop(_:onComplete:)`, `remove(_:onComplete:)`, private `performThenRefresh` to `DockerService.swift`. Resolved stop-then-remove semantics with the user (graceful stop → rm, no force `-f`). No new files, no `project.pbxproj` edit.
- **PID-28.4** (container-panel-ui): Added `ContainersView.swift` to `Pidly/`; updated `MenuBarView.swift` (Tab enum, `selectedTab` state, `containerRefreshToken`, `tabPicker` segmented control, tab-aware `↻` button); added `DockerService.list(onComplete:)` async wrapper; wired `ContainersView.swift` into `project.pbxproj` (explicit refs B150/B151); updated `README.md` §Features with the Docker containers tab bullet.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A for this audit (verification pass over cohort deliverables; no new code surface). Coherence check uses the established ScanEngine/ScanCore precedent as the reference shape.

- [x] Implemented the minimal solution — audit coherence pass (see Implementation Notes below).

- [x] Updated/added tests for non-trivial behavior — N/A; audit applied no code fixes.

**Implementation Notes:**

**Doc-drift sweep (AI-referenced docs per `.flowtron/tasknote/README.md` §"AI-referenced docs"):**
- `README.md` — no change. §Features "Docker containers tab" bullet present (added in PID-28.4). No further update needed.
- `AGENTS.md` — no change. No docker/container surface enumerated; none added by this cohort.
- `CLAUDE.md` — no change. Docker-split convention bullet added in PID-28.2 is present and accurate (`DockerCore.swift`/`Container.swift` in PidlyCore; `DockerService.swift` app-side; `KillService` delegates). Verified against HEAD.
- `.flowtron/PLAN.md` — no change beyond flipping PID-28.5 to stub (Phase 4 step).

**Cohort coherence inventory:**
- **Naming consistency**: `DockerService` / `DockerCore` / `Container` / `ContainersView` follow the existing `ScanEngine`/`ScanCore`/`ProcessItem`/`MenuBarView` naming grammar — Engine/Core (impure/pure) + model (singular noun) + View. Consistent across all four children.
- **Style parity**: async pattern (`DispatchQueue.global` → `onComplete` on `.main`) matches `KillService.kill`; local `@State` for container list (no `ObservableObject` — correctly chosen since there is no timer/persistence/notification lifecycle). `project.pbxproj` explicit-refs pattern (BuildFile + FileReference + group + Sources phase) applied consistently in .2 and .4.
- **Cross-ref consistency**: `.2` → `.3` → `.4` dependency chain is accurately documented in each child's Related section. `.1` scoping decisions (segmented tab, stop+remove, split model layer) correctly carried through in .2/.3/.4 implementations.
- **No contradictory cross-refs**: no conflicts found. `KillService`'s docker-stop kill path delegates cleanly to `DockerService`; `ContainersView` calls only `DockerService` methods (no direct shell-outs in the view layer); all `docker` CLI access isolated in `DockerService` per the CLAUDE.md convention.
- **Regressions**: `make test` reported 67 tests, 0 failures at each of .2, .3, .4 closures. The `DockerCoreTests` (7 tests) and all pre-existing tests remained green throughout.

**Misses / follow-up candidates:**
- Minor path inaccuracy in archived tasknote prose (`.2`, `.3`, `.4` all cite `PidlyCore/Sources/PidlyCore/` instead of `Packages/PidlyCore/Sources/PidlyCore/`). Tasknotes are already archived — no in-flight doc to update. Low-priority cosmetic note; not worth a follow-up filing.
- No other misses surfaced.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (audit applied no code fixes; `make test` baseline was 67 tests, 0 failures at PID-28.4 closure).

- [x] Ran lint/type-check on changed code — N/A (no code edited in this audit).

- [x] (frontend) N/A — no UI changes.

**Testing Notes:** Markdown-prose verification only. No test surface for this audit.

## 🚀 Phase 4: Closure

- [ ] **Doc-drift sweep** — documented in Implementation Notes above. Summary: `README.md` no change; `AGENTS.md` no change; `CLAUDE.md` no change; `.flowtron/PLAN.md` stub flip below.

- [ ] Closed — PLAN.md line flipped to stub form `Completed 2026-06-26.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [ ] Recap drafted

**Final Summary:**

Audited the `PID-EPIC-28` (`docker-panel`) cohort — four implementation children (`.1` discovery, `.2` docker-service, `.3` container-actions, `.4` container-panel-ui). No inconsistencies surfaced. Doc-drift sweep clean: `README.md`/`AGENTS.md`/`CLAUDE.md` are current; no further updates land in this audit. Cohort coherence verified: naming follows the existing ScanEngine/ScanCore/ProcessItem grammar, async patterns are consistent with `KillService`, no scattered `docker` CLI access, all cross-refs accurate. `make test` stayed green (67 tests, 0 failures) across the full cohort. One cosmetic path discrepancy in archived tasknote prose (missing `Packages/` prefix) — not worth a follow-up (archived, code correct). No follow-up tasks to file.

**Archived:** 2026-06-26
