---
title: discovery
status: in-progress
tags: [epic-56, discovery, docker]
created: 2026-07-02
due:
related-tasks: [PID-EPIC-56, PID-56.5]
---

# PID-56.1 | discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-56]] [[PID-56.5]]

## 🎯 Goal

Scope the docker-enhance epic's shared design (per-container CPU/memory via `docker stats`, compose-project grouping, restart action) and file implementation children PID-56.2..4 in PLAN.md per SPEC/epic.md.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (DockerCore/Container model layer, DockerService shell-outs, ContainersView UI, MenuBarView refresh wiring) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-56.2 .. PID-56.4 filed in `.flowtron/PLAN.md` (each line ≤50w target / 70w hard cap)
- [ ] Audit line PID-56.5 reviewed and confirmed as-filed (or renumbered if Discovery shifts N)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (DockerCore.swift, Container.swift, DockerService.swift, ContainersView.swift) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/pid/` for docker-panel precedents — log load-bearing findings
- [ ] Drift check on the epic line's cited surfaces — flag any drift before re-interpreting the epic
- [ ] Resolve open scoping questions via AskUserQuestion (stats fetch model, grouping presentation, child split) — record in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-56.2 .. PID-56.4; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under PID-EPIC-56 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip `.1` PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-56]] — parent epic (docker-enhance)
- [[PID-56.5]] — closing audit subtask (filed at filing time)
- [[PID-EPIC-28]] — shipped docker-panel epic this builds on (DockerService/DockerCore split)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Epic pre-filed via `/ft-epic-discovery` shell; the Docker panel (PID-EPIC-28) shipped and is stable, so the three enhancement features are a natural, well-motivated extension of an existing surface. PID-049's "no system-wide monitoring" reject does not apply — per-container stats are container-scoped, inside the panel's existing lane.

- [x] Read relevant source files — `DockerCore.swift` (pure `psFormat` + `parsePS`/`parseLine` + `parseContainerOwners`; format string is the shared source of truth with tests), `Container.swift` (pure value: id/name/image/status/ports), `DockerService.swift` (trusted-path CLI resolution, `run`/`listContainers`/`containerOwners`, async `list`, `stop`/`remove` via `performThenRefresh`), `ContainersView.swift` (local `@State` list, load-on-appear + shared-header `refreshToken` reload, per-row stop/remove buttons).

- [x] **Archive skim** — `PID-28.1` (docker-panel discovery): recorded the three standing decisions — segmented popover tab, stop+remove explicit-click only, DockerService/DockerCore impure/pure split; `PID-28.2..5` implemented them. `PID-037.2` added the bulk-inspect owner cache (`inspectOwnerFormat` precedent for a second format string in DockerCore). `PID-049` (ux-feature-survey): strong-reject on *system-wide* resource monitoring (Stats/iStat lane) — per-container stats inside the Docker panel stay in-lane. `PID-35.3` hardened `cliPath()` trust checks — any new docker subcommand must go through `DockerService.run` (it does, by construction).

- [x] **Drift check** — No drift. Epic line cites the "shipped DockerService/DockerCore split" — both exist at HEAD as described; stop action exists (`DockerService.stop`), remove too; no stats / compose-grouping / restart surface exists yet. Container model has no CPU/mem or compose-project fields (expected — that's the work).

- [x] Asked clarifying questions — resolved scoping table below.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Resolved scoping (via AskUserQuestion):**

| Question | Decision |
|---|---|
| Stats fetch model | **One-shot on load/refresh** — fetch `docker stats --no-stream` alongside `docker ps` on tab appear and on ↻; no polling timer, zero idle cost |
| Grouping presentation | **Section headers per compose project** — rows grouped under project headers, non-compose containers in an ungrouped section (mirrors the Processes tab's section shape) |
| Child split | **One feature per child** — `.2` container-stats (medium), `.3` compose-grouping (medium), `.4` restart-action (light); audit stays `.5` |

**Architecture inventory:**
- `DockerCore.psFormat` is the single source of truth for the `docker ps` field order — compose grouping extends it with `{{.Label "com.docker.compose.project"}}` (one new tab-separated field; parser + tests updated in lockstep).
- Stats need a second shell-out: `docker stats --no-stream --format "{{.ID}}\t{{.CPUPerc}}\t{{.MemUsage}}"` — new format constant + pure parser in `DockerCore` (mirrors the `inspectOwnerFormat` precedent), impure fetch in `DockerService`, joined to containers by ID.
- `docker stats --no-stream` blocks ~1-2 s (CPU sampling window) — already safe because `DockerService.list`-style wrappers run off-main and deliver on main.
- Restart is a one-liner on the existing `performThenRefresh` path (`docker restart <id>`); UI is a third borderless button on the row.
- All actions stay explicit-click only (CLAUDE.md non-negotiable); no auto-action path is added.

**Final child breakdown (N=5, unchanged):** `.2` container-stats · `.3` compose-grouping · `.4` restart-action · `.5` audit (pre-filed).

Discovery surfaced no significant deviation → skip 🛠️ (answers confirmed the recommended defaults; child count and audit number unchanged from the epic line as filed).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the PID-28.1 cohort-filing precedent (2-space child indent, `[model]` on every line, em-dash separator, ≤50w descriptions) and the PID-55.1 closure precedent (parent long description refined with the "(Scoped by .1: N=…)" note at `.1` closure).

- [x] Implemented the minimal solution — filed PID-56.2 / .3 / .4 under PID-EPIC-56, between `.1` and the `.5` audit; refined the parent epic's long description with the scoped breakdown.

- [x] Updated/added tests for non-trivial behavior — N/A (pure PLAN.md filing; no executable surface).

**Implementation Notes:**

Wrote 3 child lines (word counts: .2 = 38w, .3 = 29w, .4 = 26w — all under the 50w target). N stayed 5; audit `.5` number unchanged. **Downstream-impact reconciliation scan:** active PLAN entries (PID-EPIC-57 cli-companion, PID-EPIC-58 integrations, PID-060 readme-visuals, PID-030 notarize) share no surface with the Docker panel children → no downstream impact, no existing entries edited.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (markdown-only).

- [x] Ran lint/type-check on changed code — markdown mental-pass: 2-space indent preserved, bold IDs intact, `[model]` + `| shortname` present on every line, em-dash separators consistent, all ≤70w, child IDs sequential `.1`→`.5` under the parent.

- [x] (frontend) N/A — no UI surface in a Discovery filing.

**Testing Notes:** PLAN.md cohort block parses cleanly; `[light]🔧` on `.4` matches the small mechanical diff, `[medium]🧠` on `.2`/`.3`.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `SPEC.md`: no change. `.flowtron/PLAN.md`: this filing IS the change (children added, parent refined). No AI-referenced doc updates land in pure Discovery — contract edits live inside the implementation children.

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-07-02.` (kept in place under the open parent per mid-epic convention) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Filed PID-EPIC-56 (`docker-enhance`) into 3 implementation children + audit and closed Discovery. Resolved three scoping decisions with the user: stats fetch is **one-shot on load/refresh** (`docker stats --no-stream` alongside `docker ps`, no polling timer); compose grouping presents as **per-project section headers** with non-compose containers ungrouped; child split is **one feature per child** — `.2` container-stats (medium), `.3` compose-grouping (medium), `.4` restart-action (light). N=5 unchanged; parent epic description refined with the scoped breakdown.

**Archived:** 2026-07-02
