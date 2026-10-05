---
title: container-panel-ui
status: completed
tags: [epic-28, docker, ui]
created: 2026-06-26
due:
related-tasks: [PID-EPIC-28, PID-28.1, PID-28.2, PID-28.3]
---

# PID-28.4 | container-panel-ui

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-28]] [[PID-28.3]]

## 🎯 Goal

Add a Processes/Containers segmented tab to the popover and a new SwiftUI view that lists running containers (name/image/status/ports) with per-row stop/remove buttons, plus a docker-absent empty state — wiring the `DockerService` actions from [[PID-28.3]] to the UI.

## ✅ Acceptance

- [ ] Popover gains a Processes/Containers segmented control; Processes tab is the existing list, Containers tab is the new view
- [ ] Containers tab lists running containers with name / image / status / ports
- [ ] Each container row has stop + remove buttons that call `DockerService.stop`/`remove` and refresh the list on completion
- [ ] Docker-absent empty state (Docker not installed) distinct from docker-present-but-no-containers empty state
- [ ] All `docker` access stays in `DockerService` (no shell-outs in the view), per CLAUDE.md
- [ ] No auto-action — stop/remove only on explicit click, per CLAUDE.md
- [ ] `make test` green; app target compiles clean
- [ ] Phase 4 doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs"

## 🧩 Subtasks

- [ ] Resolve scoping questions (state ownership, tab/header layout, auto-refresh) via AskUserQuestion
- [ ] Add container state source + off-main load (per resolved state-ownership decision)
- [ ] Add the segmented Picker tab switch to `MenuBarView`
- [ ] Build the containers list view (rows: name/image/status/ports + stop/remove buttons)
- [ ] Add the two empty states (docker-absent / no-running-containers)
- [ ] Register any new `.swift` file in `project.pbxproj` (explicit refs, not synchronized)
- [ ] Run `make test` + build; fix to green
- [ ] Visual confirmation of the panel

## 🔗 Related

- [[PID-EPIC-28]] — parent epic: Docker/container management panel
- [[PID-28.3]] — container-actions: `DockerService.stop`/`remove` this UI wires to per-row buttons
- [[PID-28.2]] — docker-service: `DockerService.listContainers`/`isInstalled` the panel reads
- [[PID-28.1]] — discovery: resolved the segmented-tab surface + stop/remove action set

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Final implementation child of PID-EPIC-28. `DockerService` (list + stop + remove + `isInstalled`) and the `Container` model exist from [[PID-28.2]]/[[PID-28.3]]; this task is the UI that surfaces them. Surface (segmented tab in the popover) + action set (stop/remove) pre-resolved in [[PID-28.1]].

- [x] Read relevant source files — `MenuBarView.swift` (popover content, `width:320`/`height:360` content frame, shared header with rescan/settings/quit, grouped collapsible sections, `row(_:)` shape with per-row borderless buttons), `DockerService.swift` (`isInstalled`/`listContainers`/`stop`/`remove` — all impure shell-outs, off-main with `[Container]` on main via `onComplete`), `Container.swift` (id/name/image/status/ports value type), `AppDelegate.swift` (popover built once with `MenuBarView(engine:)`), `ScanEngine.swift` (the lifecycle-owner pattern: `@Published` + off-main dispatch), `SettingsView.swift` (style).

- [x] **Archive skim** — [[PID-28.3]] added `stop`/`remove` (async, deliver refreshed `[Container]` on main; `onComplete` defaults to no-op). [[PID-28.2]] created `DockerService` + `listContainers`/`isInstalled`. [[PID-28.1]] resolved segmented-tab surface, stop+remove actions, running-only (`docker ps`) list. `PID-27.2` is the ScanEngine/ScanCore split precedent. No prior container-UI work.

- [x] **Drift check** — No drift. `DockerService.isInstalled`/`listContainers`/`stop`/`remove` present at HEAD as cited. `MenuBarView` is the popover content (`width:320`). Xcode project uses **explicit** `PBXFileReference` entries (not file-system-synchronized groups) → a new `.swift` file requires a `project.pbxproj` edit (BuildFile + FileReference + group + Sources phase), mirroring the existing `DockerService.swift` quartet.

- [x] Asked clarifying questions — resolved scoping table below.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Resolved scoping (via AskUserQuestion):**

| Question | Decision |
|---|---|
| Container list state ownership | **Local `@State` in the view** — `ContainersView` holds `@State var containers`; no new `ObservableObject`. There's no timer/persistence/notification lifecycle to own (the things that justify `ScanEngine`), so a dedicated engine would be ceremony. |
| Segmented-control placement / header | **Picker below the shared header** — the existing Pidly header (rescan/settings/quit) stays shared at top; the `Processes`/`Containers` segmented `Picker` sits just below the divider. The header refresh button (`↻`) becomes **tab-aware**: rescans processes on the Processes tab, reloads containers on the Containers tab. |
| Container refresh cadence | **On-appear + manual only** — load off-main when the Containers tab appears / popover opens; reload on stop/remove completion and on the manual `↻`. **No timer** (avoids a speculative second timer lifecycle). |

**Implementation shape:**
- All three forks resolved toward the minimal option consistent with the filed scope.
- `listContainers()` is a **synchronous** shell-out — to keep `docker` off the main thread *and* out of the view (per CLAUDE.md), add a thin async `list(onComplete:)` wrapper to `DockerService` (dispatch off-main → deliver `[Container]` on main), mirroring `stop`/`remove`'s `performThenRefresh` pattern. The view's `@State` load + manual refresh call it; stop/remove already deliver the refreshed list.
- New file `ContainersView.swift` → explicit `project.pbxproj` quartet (BuildFile + FileReference + group membership + Sources phase), mirroring `DockerService.swift`'s entries.

**Phase 1→2 exit:** Discovery surfaced no significant deviation — three clarifications resolved anticipated forks (already placeholdered in the subtask list) toward the minimal options; same files, same approach, consistent with the filed segmented-tab + stop/remove scope. The only addition is a thin async `list` wrapper inside the existing `DockerService` surface → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended existing shapes rather than inventing: `ContainersView` mirrors `MenuBarView`'s row/empty-state/`ScrollView`-with-fixed-360-height style (caption fonts, borderless buttons, secondary/tertiary foregrounds); the new `DockerService.list(onComplete:)` mirrors `stop`/`remove`'s `performThenRefresh` off-main→main pattern; the segmented `Picker` is standard SwiftUI. Local `@State` for the container list (no engine) per the resolved scoping.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A. The new surface is all impure (shell-out wrapper `list`) or pure-presentation (SwiftUI view); no new branching logic to unit-test. The pure docker parsing (`DockerCore.parsePS`) is unchanged and stays covered by `DockerCoreTests`.

**Implementation Notes:**

- `Pidly/DockerService.swift` — added `list(onComplete:)`: a thin async wrapper that runs the blocking `docker ps` shell-out off-main and delivers `[Container]` on main, so the view loads/refreshes without freezing the popover and never touches `docker`/`DispatchQueue` itself.
- `Pidly/ContainersView.swift` (new) — the Containers tab. Local `@State var containers` + `loading`; loads via `DockerService.list` on `.onAppear` and on `refreshToken` change. Rows show name (bold) / image / ports (monospaced, only when non-empty) / status, with `stop.circle` + red `trash` buttons calling `DockerService.stop`/`remove` (each refreshes the list via `onComplete`). Two empty states: `Docker isn’t installed.` (via `DockerService.isInstalled`) vs `No running containers.` / `Loading…`.
- `Pidly/MenuBarView.swift` — added a private `Tab` enum, `selectedTab` state, a `containerRefreshToken`, the segmented `tabPicker` (below the shared header/divider), and a `switch` on `selectedTab` for the content. The shared header `↻` is now tab-aware (`engine.rescan()` on Processes, `containerRefreshToken += 1` on Containers) with a tab-specific tooltip.
- `Pidly.xcodeproj/project.pbxproj` — registered `ContainersView.swift` (explicit refs: BuildFile `B150` + FileReference `B151` + group membership + Sources phase), mirroring the `DockerService.swift` quartet (project uses explicit refs, not synchronized groups).
- **No auto-action:** stop/remove only fire from button taps; the list loads on appear/manual-refresh only (no timer) — per CLAUDE.md.
- **Downstream-impact:** none. Final EPIC-28 implementation child; no active PLAN entries outside the cohort share this surface. The `.5` audit follows.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 67 tests, 0 failures. The new `ContainersView.swift` compiled as part of the app-target test build, confirming the `project.pbxproj` wiring.

- [x] Ran lint/type-check on changed code — app target compiled clean (Swift compiler is the type-check; no separate linter). The SourceKit "No such module 'PidlyCore'" diagnostics on the three touched files were stale indexing, contradicted by the successful build (same transient as [[PID-28.2]]/[[PID-28.3]]).

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — surfaced the 👁️ CONFIRM ask (segmented control / container rows / tab-aware ↻ / stop+remove / both empty states); user replied "go", authorizing closure.

**Testing Notes:** No new tests — the added surface is impure (`list` shell-out wrapper) or presentation (`ContainersView`); the pure `DockerCore.parsePS` is unchanged and stays covered by the 7 `DockerCoreTests`.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** — added a "Docker containers tab" bullet to §Features (this task ships the first user-visible container surface; .2/.3 deferred the README note until the UI landed). `AGENTS.md`: no change (no feature/docker surface enumerated). `CLAUDE.md`: no change — the docker-split convention already mandates `DockerService` owning all `docker` access; `ContainersView` + the new `list` wrapper comply. `.flowtron/PLAN.md`: this filing IS the change (`.4` flipped to stub).

- [x] Closed — PLAN.md `.4` line flipped to `Completed 2026-06-26.` (kept nested under PID-EPIC-28; parent flips after the `.5` audit) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Shipped the Docker containers panel — the final EPIC-28 implementation child. Added a **Processes / Containers** segmented control below the popover header (`MenuBarView`), and a new `ContainersView` that lists running containers (name / image / status / ports) with per-row **stop** (`docker stop`) and **stop + remove** (`docker stop` → `docker rm`) buttons wired to `DockerService` from [[PID-28.3]]. State is local `@State` (no engine — no timer/persistence lifecycle to own), loading off-main via a new `DockerService.list(onComplete:)` wrapper that keeps the `docker ps` shell-out off the main thread and out of the view. The shared header `↻` is now tab-aware (rescan processes / reload containers). Two empty states: *Docker isn't installed* vs *No running containers*. New file registered in `project.pbxproj` (explicit refs). `make test` green (67 tests, 0 failures). README §Features updated with the new tab. Only the `.5` audit remains before PID-EPIC-28 closes.

**Archived:** 2026-06-26

