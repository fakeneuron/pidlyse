---
title: quick-filter
status: in-progress
tags: [ux]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-50.1, PID-049]
---

# PID-50.5 | quick-filter

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Add a search field below the tab picker that filters the Processes tab live by command / project label / listening port — session-scoped, clearing when the popover closes.

## ✅ Acceptance

- [ ] A search field appears below the tab picker, only on the Processes tab (and only when there are processes to filter)
- [ ] Typing filters the visible rows by case-insensitive substring against: `item.command`, the row's project/provenance label (`rowDescriptor`), and any listening port (`engine.listeningPorts`)
- [ ] When the filter excludes everything, the tab shows a "no matches" hint instead of a blank area
- [ ] The filter is session-scoped: closing the popover clears it (next open starts empty)
- [ ] Build compiles clean (`xcodebuild build -scheme Pidlyse`) and the existing test suite passes (`make test`)

## 🧩 Subtasks

- [ ] Add a `@State private var filterText` to MenuBarView
- [ ] Add a `searchField` view and render it below `tabPicker`, gated on the Processes tab + non-empty `engine.items`
- [ ] Add a `matchesFilter(_:)` predicate (command / `rowDescriptor` / listening-port substring) and fold it into `safeItems` / `reviewItems`
- [ ] Add a "no matches" hint inside `content` when the filter empties both sections
- [ ] Clear `filterText` on popover close via `.onDisappear`
- [ ] Build + run targeted tests + 👁️ visual confirmation

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-50.1]] — Discovery; scoped this child (Survey item 4)
- [[PID-049]] — ux-feature-survey; sourced the shortlist

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Survey item 4 from [[PID-049]], scoped by [[PID-50.1]] Discovery. MenuBarView-local; all data already on hand (`item.command`, `rowDescriptor` via `engine.cwds`, `engine.listeningPorts`). No blockers.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source surface (read):**

- `Pidlyse/MenuBarView.swift` — `body` lays out `header → Divider → tabPicker → switch(selectedTab)`. The search field slots between `tabPicker` and the `switch`. `safeItems` / `reviewItems` (lines 337-338) are the bucket-filtered derived arrays feeding the section counts, `groups(for:)`, "Clean all", and `safeReclaimableKB` (.4). `rowDescriptor(_:)` (line 207) yields the project label (`engine.cwds[pid].label`) or the `displayPath` fallback. `engine.listeningPorts[pid]` (line 303) is a `[Int]?` per PID.
- `Pidlyse/AppDelegate.swift` — the `NSHostingController(rootView: MenuBarView(...))` is built **once** in `applicationDidFinishLaunching` (line 40) and reused for every popover open/close. So `@State` **persists** across opens — "clears on close" needs an explicit reset. `.onAppear { engine.scan() }` (line 45) demonstrably fires per-open (scan-on-open depends on it), so the symmetric `.onDisappear` fires per-close → use it to clear the filter.

**Archive skim:** PID-50.2 (row-context-menu) is the immediate predecessor on this file — established the `engine.cwds` / `item.command` access in this view. PID-50.3 (provenance-sort) set the alphabetical `grouped()` sort by `rowDescriptor`. PID-50.4 (reclaimable-footprint) added `safeReclaimableKB` off `safeItems` — folding the filter into `safeItems` makes the reclaimable header track the filtered set automatically. The `Set.toggle` extension (PID-045) idiom is for selection sets, not relevant here. No prior search/filter field in the codebase (grep clean).

**Drift check:** All cited paths/types match HEAD. `rowDescriptor` / `safeItems` / `reviewItems` / `listeningPorts` all present as the PLAN line assumes. No drift.

**No clarifications needed.** Explicit assumptions:
1. **Filter at the source** — fold `matchesFilter` into `safeItems` / `reviewItems`, so the section counts, "Clean all" scope, and the .4 reclaimable header all reflect the filtered set (narrowing the working set is the intuitive, minimal semantic — vs. hiding rows while counts stay total).
2. **Listening-port match** is substring against the port number's decimal string (query `517` matches `:5173`), consistent with the command/label substring behavior.
3. **Search field gated** on the Processes tab **and** `!engine.items.isEmpty` — no point offering a filter over the empty state.
4. **Clears on close** via `.onDisappear { filterText = "" }` on the root view — keeps view state in the view (ScanEngine owns timer/persistence/notification lifecycle only, per CLAUDE.md), not hoisted into the engine.
5. No new tests — filter logic is view-local (no UI test target; build is the type-check gate), matching the .2/.3/.4 precedent.

**Exit-gate judgment:** Discovery surfaced no significant deviation (sensible-default micro-decisions only, no re-scope/de-scope, same file as planned) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no existing search/filter field in the codebase (grep clean). Followed the popover's caption-font aesthetic and the existing private-helper convention (`rowDescriptor` / `ramString`); reused the established `item.command` / `rowDescriptor` / `engine.listeningPorts` accessors rather than threading new data.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (view-local filter; no UI test target, build is the type-check gate — matches the .2/.3/.4 precedent)

**Implementation Notes:**

- `Pidlyse/MenuBarView.swift` (+~45 LOC):
  - `@State private var filterText` + `.onDisappear { filterText = "" }` on the root view (the hosting controller is reused across opens, so `@State` persists — explicit clear gives session-scoped behavior).
  - `searchField` view (magnifier + plain `TextField` + trailing ✕ clear button), rendered between `tabPicker` and the tab `switch`, gated on `selectedTab == .processes && !engine.items.isEmpty`.
  - `matchesFilter(_:)` predicate: empty query passes all; else case-insensitive substring vs. `item.command`, `rowDescriptor(item)`, or any `engine.listeningPorts[pid]` number. Folded into `safeItems` / `reviewItems` so counts, "Clean all" scope, and the .4 reclaimable header all track the filtered set.
  - "No processes match …" hint inside `content` when the filter empties both sections.
- No new imports, no shell-out, no core changes.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test` → **TEST SUCCEEDED** (118 tests, 0 failures)

- [x] Ran lint/type-check on changed code — `xcodebuild build -scheme Pidlyse` → **BUILD SUCCEEDED** (Swift compiler is the type-checker; no separate linter). The lone SourceKit "No such module 'PidlyseCore'" diagnostic is the known stale-indexer artifact on the pre-existing import (per PID-50.2) — `xcodebuild` resolves the package fine.

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — see bundled ask at the 📦 gate

**Testing Notes:** Build clean; full suite green (118/118). No new tests — the filter is view-local presentation logic with no unit-testable pure surface.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** (added a "Quick filter" Features bullet) · `AGENTS.md`: no change · `CLAUDE.md`: no change (no new conventions; filter is view-local) · `.flowtron/PLAN.md`: `.5` line flipped to stub form (kept nested under PID-EPIC-50; parent + cohort move to `## Completed` only when all children close)

- [x] Closed — PLAN.md line flipped to `Completed 2026-06-30.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Added a live quick-filter to the Processes tab (`MenuBarView.swift`, +~45 LOC): a search field below the tab picker that narrows the visible rows by case-insensitive substring against the command line, the row's project/provenance label (`rowDescriptor`), or any listening port. Folded the `matchesFilter` predicate into `safeItems` / `reviewItems` so the section counts, "Clean all" scope, and the .4 reclaimable header all track the filtered set; a "No processes match …" hint covers the empty-filter case. Session-scoped — `.onDisappear` clears the query on popover close (the hosting controller is reused across opens, so `@State` persists otherwise). No new data, imports, shell-out, or core changes; +1 README feature bullet. Build clean, 118 tests pass. Fourth implementation child of PID-EPIC-50 (Survey item 4).

**Archived:** 2026-06-30
