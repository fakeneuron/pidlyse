---
title: compose-grouping
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-56, PID-56.1, PID-56.2]
---

# PID-56.3 | compose-grouping

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-56]] [[PID-56.1]] [[PID-56.2]]

## 🎯 Goal

Group ContainersView rows under per-compose-project section headers by extending DockerCore.psFormat with the `com.docker.compose.project` label field (parser + tests in lockstep); non-compose containers stay ungrouped.

## ✅ Acceptance

- [x] `DockerCore.psFormat` carries a 6th tab-separated field: `{{.Label "com.docker.compose.project"}}`
- [x] `Container` gains `composeProject: String?` — `nil` for non-compose containers (empty label)
- [x] `DockerCore.parseLine` parses the 6-field form; existing 5-field test lines updated in lockstep; new tests cover compose label present / empty-label → nil
- [x] `ContainersView` renders compose containers grouped under per-project section headers (project name + count), non-compose containers ungrouped
- [x] `make test` green

## 🧩 Subtasks

- [x] Extend `DockerCore.psFormat` with the compose-project label field and bump `parseLine` to the 6-field form (empty label → `nil`)
- [x] Add `composeProject: String?` to `Container` (field + init + doc)
- [x] Update existing `parseLine`/`parsePS` tests to 6-field lines; add compose-label coverage
- [x] Group rows in `ContainersView`: per-project sections (alphabetical) with header, ungrouped non-compose tail
- [x] Run `make test`

## 🔗 Related

- [[PID-EPIC-56]] — parent epic: docker-enhance (stats, compose grouping, restart)
- [[PID-56.1]] — epic discovery that scoped this child
- [[PID-56.2]] — container-stats sibling (one-shot docker stats on ContainersView rows)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Scoped by [[PID-56.1]] (grouping presentation resolved with the user: per-project section headers, non-compose ungrouped); sibling [[PID-56.2]] just landed the stats join, so the panel surface is current and stable. Straight execution of the filed scope.

- [x] Read relevant source files — `DockerCore.swift` (`psFormat` 5-field constant, `parseLine` guard `>= 5`, `parsePS`; `statsFormat`/`inspectOwnerFormat` precedent for format-string SSOT), `Container.swift` (pure value, no compose field yet), `DockerService.swift` (`listContainers` passes `DockerCore.psFormat` — no change needed there), `ContainersView.swift` (flat `ForEach(containers)` list; grouping is view-side), `ScanEngineTests.swift` `DockerCoreTests` (parseLine/parsePS fixtures are 5-field lines — must move to 6-field in lockstep).

- [x] **Archive skim** — [[PID-28.2]] established the psFormat-as-SSOT + parser/tests-lockstep convention this task extends. [[PID-037.2]] (`inspectOwnerFormat`) and [[PID-56.2]] (`statsFormat`) are the precedents for evolving DockerCore's format constants with paired pure parsers. [[PID-56.1]] resolved the presentation question: section headers per compose project, non-compose ungrouped, mirroring the Processes tab's section shape. [[PID-49]]-style scope rejects don't apply.

- [x] **Drift check** — No drift. `DockerCore.psFormat` exists as cited (5 fields, `DockerCore.swift:11`); `ContainersView` renders a flat list, no grouping surface yet (expected — that's the work). `com.docker.compose.project` is the standard compose label; `{{.Label "…"}}` is valid `docker ps --format` template syntax.

- [x] Asked clarifying questions — **No clarifications needed.** Explicit assumptions (routine presentational calls within the .1-resolved scope): (1) parser goes strict 6-field (`guard >= 6`) since format + parser move in lockstep and docker emits the tab even when the label is empty; (2) empty label → `composeProject = nil`; (3) project sections sort alphabetically, header shows project name + row count; (4) non-compose containers render after the project sections, header-free, preserving `docker ps` order; (5) headers are plain (not collapsible) — minimal mirror of the Processes-tab section shape, no collapse machinery.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- Only one production `Container(id:…)` call site (`DockerCore.parseLine`) — adding the `composeProject` init param is contained.
- `docker stats` join key (`{{.ID}}`) is untouched — grouping is orthogonal to the PID-56.2 stats map.
- Grouping stays view-side (presentation, not docker-output parsing) — consistent with the CLAUDE.md core/app split; `DockerCore` keeps only the parse.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the established `psFormat`-as-SSOT + parser/tests-lockstep shape from [[PID-28.2]] (sibling precedents: `inspectOwnerFormat` [[PID-037.2]], `statsFormat` [[PID-56.2]]); grouping mirrors the Processes tab's section-header shape, kept view-side (presentation, not docker-output parsing) per the core/app split.

- [x] Implemented the minimal solution — `psFormat` + `parseLine` moved to the 6-field form (`{{.Label "com.docker.compose.project"}}`, empty → `nil`); `Container.composeProject: String?` added; `ContainersView` renders alphabetical per-project sections (stack icon + name + count header) with the non-compose tail header-free in `docker ps` order.

- [x] Updated/added tests for non-trivial behavior — existing `parseLine`/`parsePS` fixtures moved to 6-field lines in lockstep; new coverage: compose label parsed (`testParseLine_fullRow`), empty label → nil (`testParseLine_emptyComposeLabel_isNil`), old 5-field form now malformed (`testParseLine_tooFewFields_isNil`), mixed compose/non-compose ps output (`testParsePS_multipleContainers`).

**Implementation Notes:**

- `DockerCore.parseLine` guard bumped `>= 5` → `>= 6` — format + parser move in lockstep; docker emits the trailing tab even when the label is empty, so real lines are always 6-field.
- Only one production `Container(…)` call site (`parseLine`), so the new init param stayed contained; the stats join by `{{.ID}}` is untouched.
- View grouping is two computed properties (`composeGroups` via `Dictionary(grouping:)`, `ungrouped` filter) + a small `header(_:count:)` — no collapse machinery.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 202 tests, 0 failures (suite is fast; runs whole)

- [x] Ran lint/type-check on changed code — Swift compile within `make test` is the type gate; clean (SourceKit editor diagnostics were stale-index noise, contradicted by the successful build)

- [x] (frontend) Asked the user for visual confirmation (👁️ ask bundled into the 📦 gate)

**Testing Notes:** New/updated DockerCoreTests all green; no other suites affected (grouping is view-side, untested UI per project convention).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: Containers-tab bullet updated with compose-project grouping. `AGENTS.md`: no change (no Docker-panel content). `CLAUDE.md`: no change (Docker split convention unchanged; no field lists). `SPEC.md`: three updates — `Container` model field list gains `composeProject`, `ContainersView` one-liner gains compose grouping, post-v1 Docker-panel entry gains the grouping sentence. `.flowtron/PLAN.md`: closure flip only.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-02.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Compose-project grouping shipped for the Containers tab. `DockerCore.psFormat` moved to a 6-field form with `{{.Label "com.docker.compose.project"}}`; `parseLine` parses it in lockstep (guard `>= 6`, empty label → `nil`) into the new `Container.composeProject: String?`. `ContainersView` renders compose containers under alphabetical per-project section headers (stack icon + project name + count) with non-compose containers in a header-free tail preserving `docker ps` order — no collapse machinery, grouping kept view-side per the core/app split. Tests updated in lockstep + new compose-label coverage; `make test` 202/202 green.

**Archived:** 2026-07-02
