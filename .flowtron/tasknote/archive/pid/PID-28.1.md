---
title: docker-panel discovery
status: in-progress
tags: [epic-28, discovery, docker]
created: 2026-06-26
due:
related-tasks: [PID-EPIC-28]
---

# PID-28.1 | docker-panel discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-28]]

## 🎯 Goal

Scope the `PID-EPIC-28` epic (`docker-panel`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-28.2..4` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (KillService docker plumbing, PidlyCore model layer, MenuBarView/UI surfacing, SettingsView wiring) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-28.2 .. PID-28.4 filed in `.flowtron/PLAN.md` (each line ≤50w target / 70w hard cap)
- [ ] Audit line PID-28.5 reviewed and confirmed as-filed (or renumbered if Discovery shifts N)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (KillService docker helpers, PidlyCore, MenuBarView, ScanEngine, SettingsView) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/pid/` for relevant precedents (docker paths, panel/UI, port registry) — log load-bearing findings
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (panel surfacing, action set, model layer location, docker-absent UX) — record in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-28.2 .. PID-28.4; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under PID-EPIC-28 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip `.1` PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-28]] — parent epic: Docker/container management panel

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-epic-discovery` on the pre-filed PID-EPIC-28 shell. The Docker CLI plumbing already exists in `KillService`, so a container-management panel is a natural, well-motivated extension.

- [x] Read relevant source files — `KillService.swift` (private docker helpers: `dockerCLIPath`/`runDocker`/`dockerStop`/`findContainerID`/`containerPID`), `MenuBarView.swift` (320pt popover, two-section process list owned via `AppDelegate`), `ProcessItem.swift` (`ProcessKind.docker` exists for stray *processes* only — not container management), `PidlyApp.swift` (Settings scene only; popover lives in AppDelegate), `SettingsView.swift` (Form pattern).

- [x] **Archive skim** — `PID-16.2` (`shellout-helper`, code-quality epic) cleaned the `runDocker` shell-out helper; all docker CLI access is centralized in `KillService` private statics today. `PID-27.2` is the precedent for extracting impure-vs-pure into PidlyCore (ScanCore split). No prior container-management work.

- [x] **Drift check** — No drift. Epic line's "building on `KillService`'s existing docker paths" matches HEAD (all 5 private docker helpers present). `ProcessKind.docker` exists but is orthogonal (classifies stray container *root PIDs*, not the container inventory this epic lists).

- [x] Asked clarifying questions — resolved scoping table below.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Resolved scoping (via AskUserQuestion):**

| Question | Decision |
|---|---|
| Panel surface | **Tab in the popover** — Processes/Containers segmented control at the top of the existing 320pt popover (no separate window) |
| Action set | **Stop + Remove** — `docker stop` + `docker rm` on running containers (`docker ps`, not `-a`); explicit-click, no auto-action |
| Model layer | **Split** — app-side `DockerService` owns impure `docker` shell-outs; pure `docker ps` parser + typed `Container` model live in `PidlyCore` (unit-testable), mirroring the ScanEngine/ScanCore split |

**Architecture inventory:**
- Docker CLI access centralized in `KillService` (app-side, private). The `.2` DockerService extraction shares it without breaking the existing docker-stop kill path.
- Popover is AppKit-bridged (`AppDelegate` owns `NSStatusItem` + popover + `ScanEngine`); the `.4` tab restructure lives inside `MenuBarView`.
- PidlyCore = pure, testable core (ScanCore/ProcessItem/PortRegistry). Container model + parser belong here per the chosen split.

**Final child breakdown (N=5):** `.2` docker-service · `.3` container-actions · `.4` container-panel-ui · `.5` audit (pre-filed).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the CORE-EPIC-057 / PID-EPIC-16 cohort-filing precedent (2-space child indent, `[model]` on every line, em-dash separator, ≤50w descriptions).

- [x] Implemented the minimal solution — filed PID-28.2 / .3 / .4 under PID-EPIC-28, between `.1` and the `.5` audit.

- [x] Updated/added tests for non-trivial behavior — N/A (pure PLAN.md filing; no executable surface).

**Implementation Notes:**

Wrote 3 child lines (word counts: .2 = 30w, .3 = 28w, .4 = 28w — all under the 50w target). N stayed 5; audit `.5` number unchanged. **Downstream-impact reconciliation scan:** rest of active PLAN (High/Medium/Future empty; Low holds only the PID-EPIC-28 cohort) shares no surface with the new children → no downstream impact, no existing entries edited.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (markdown-only).

- [x] Ran lint/type-check on changed code — markdown mental-pass: 2-space indent preserved, bold IDs intact, `[model]` + `| shortname` present on every line, em-dash separators consistent, all ≤70w, no trailing whitespace.

- [x] (frontend) N/A — no UI surface in a Discovery filing.

**Testing Notes:** PLAN.md cohort block parses cleanly; child IDs sequential `.1`→`.5` under the parent.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: this filing IS the change (children added). No AI-referenced doc updates land in pure Discovery — contract edits live inside the implementation children.

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-06-26.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Filed PID-EPIC-28 (`docker-panel`) into 3 implementation children + audit and closed Discovery. Resolved three scoping decisions with the user: container panel ships as a **Processes/Containers segmented tab** in the existing popover; actions are **stop + remove** on running containers; the model layer **splits** into an app-side `DockerService` (impure `docker` shell-outs, extracted from `KillService`) plus a pure parser + typed `Container` model in `PidlyCore`. Children: `.2` docker-service, `.3` container-actions, `.4` container-panel-ui. N=5 unchanged.

**Archived:** 2026-06-26
