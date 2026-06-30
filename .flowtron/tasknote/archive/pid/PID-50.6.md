---
title: per-kind-toggles
status: in-progress
tags: [ux]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-50.1, PID-049]
---

# PID-50.6 | per-kind-toggles

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Add a "Scanned kinds" Settings section with a per-`ProcessKind` toggle; persist the unchecked set as `disabledKinds` on `ScanEngine` and skip those kinds during the scan — a category-level complement to the existing substring `ignoredNames` ignore.

## ✅ Acceptance

- [ ] `ScanCore.enumerate` takes an injectable `disabledKinds: Set<ProcessKind> = []` and drops items whose `kind` is in the set (applied to the final, post-`collapseWrappers` result)
- [ ] `ScanEngine` holds a `@Published var disabledKinds: Set<ProcessKind>`, persisted to `UserDefaults` as a `[String]` of raw values, and passes it into `enumerate` on each scan
- [ ] `SettingsView` gains a "Scanned kinds" `Section` with one `Toggle` per `ProcessKind.allCases` (checked = scanned), plus a caption explaining the behavior
- [ ] New `ScanCore` unit tests cover disabled-kind filtering (match drops / no-match keeps / empty = no filtering), mirroring the `ignoredNames` test block
- [ ] Build compiles clean (`xcodebuild build -scheme Pidlyse`) and the suite passes (`make test`)

## 🧩 Subtasks

- [ ] `ScanCore.enumerate`: add `disabledKinds: Set<ProcessKind> = []` param; filter the collapsed result by `!disabledKinds.contains($0.kind)`
- [ ] `ScanEngine`: add `@Published var disabledKinds` with UserDefaults persistence (rawValue array, didSet writes); load in `init`; capture + pass into `enumerate` in `scan()`
- [ ] `SettingsView`: add a `kindEnabled(_:)` binding helper + a "Scanned kinds" `Section` (toggle per kind + caption)
- [ ] Add a "disabledKinds filtering" test block to `ScanEngineTests` (match / no-match / empty)
- [ ] Build + `make test` + 👁️ visual confirmation of the Settings section

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-50.1]] — Discovery; scoped this child (Survey item 5)
- [[PID-049]] — ux-feature-survey; sourced the shortlist

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Survey item 5 from [[PID-049]], scoped by [[PID-50.1]] Discovery. Clean three-file change (SettingsView + ScanEngine + ScanCore) with an exact precedent in the `ignoredNames` filter path. No blockers.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source surface (read):**

- `Packages/PidlyseCore/Sources/PidlyseCore/ProcessItem.swift` — `ProcessKind` is a `String`-backed `CaseIterable` enum (12 cases), so it is already `Hashable` (usable in a `Set`) and `RawRepresentable` (rawValue persistence), and `.allCases` drives the toggle list. `.label` gives the user-facing toggle title.
- `Packages/PidlyseCore/Sources/PidlyseCore/ScanCore.swift` — `enumerate(...)` already takes injectable `ignoredNames` / `dismissedPIDs` filters applied as `.filter` steps, then returns `collapseWrappers(all)`. The new `disabledKinds` filter belongs **after** `collapseWrappers`: a collapsed wrapper row takes its `kind` from the meaningful child (e.g. `npm run dev` → `.vite`), so filtering the final result matches what the user actually sees in the row.
- `Pidlyse/ScanEngine.swift` — `ignoredNames` is the exact persistence precedent: `@Published var` + `didSet { UserDefaults.standard.set(..., forKey:) }`, loaded in `init` via `stringArray(forKey:)`, captured into a local in `scan()` and passed to `enumerate`. `disabledKinds` mirrors it, persisting `disabledKinds.map(\.rawValue)` and rehydrating via `ProcessKind(rawValue:)`.
- `Pidlyse/SettingsView.swift` — `Form` with `Section(...)` blocks; `launchAtLogin` shows the computed-`Binding` helper idiom to reuse for `kindEnabled(_:)`. The "Ignored processes" section is the sibling category-filter UI.

**Archive skim** (`grep -l` over `archive/pid/` for the three source paths):

- `ScanCore.swift` — touched by the `ignoredNames`/`dismissedPIDs` filter work and PID-039 (`collapseWrappers`), PID-046 (token-boundary). Confirms the filter-step pattern and the post-collapse ordering rationale.
- `ScanEngine.swift` / `SettingsView.swift` — the `ignoredNames` settings (substring ignore) and PID-50.x popover-ux children. PID-50.5 (quick-filter) is the immediate sibling but is view-local (no core change); this task is the inverse — a persisted core-level filter, so it gets real `ScanCore` tests (unlike .5).
- No prior per-kind / `disabledKinds` toggle exists (grep clean).

**Drift check:** All cited symbols match HEAD — `ProcessKind.allCases`/`.label`/`.rawValue`, `enumerate`'s filter-then-`collapseWrappers` shape, `ScanEngine.ignoredNames` persistence idiom, `SettingsView` `Section`/`Binding` helpers. No drift.

**No clarifications needed.** Explicit assumptions:
1. **Store the disabled (unchecked) set**, not the enabled set — PLAN says `disabledKinds`; a fresh install has an empty set = everything scanned (sensible default, no migration), exactly like empty `ignoredNames`.
2. **Filter after `collapseWrappers`** — filter on the final displayed `kind` so a merged wrapper row is judged by its child's kind (what the row shows), not the wrapper's.
3. **Persist as `[String]` rawValues** in UserDefaults under `"disabledKinds"`, mirroring `ignoredNames`; unknown/retired rawValues on load are dropped via `compactMap { ProcessKind(rawValue:) }`.
4. **Toggle semantics: checked = scanned.** The toggle list is `ProcessKind.allCases` in declaration order, titled by `.label`.
5. **Real `ScanCore` tests** for the new pure filter (match / no-match / empty), since this adds a unit-testable core surface — unlike the view-local .5.

**Exit-gate judgment:** Discovery surfaced no significant deviation (exact precedent, scoped as planned, sensible-default micro-decisions only) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the existing `enumerate` filter-step idiom (`ignoredNames`/`dismissedPIDs`) for the core filter, the `ignoredNames` `@Published` + `didSet` + `init`-load UserDefaults idiom for persistence, and the `launchAtLogin` computed-`Binding` helper for the per-kind toggle. No new shape invented.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — added a `disabledKinds` filtering test block to `ScanEngineTests` (match drops / no-match keeps / empty = no filtering), mirroring the `ignoredNames` block, since this adds a unit-testable core surface

**Implementation Notes:**

- `ScanCore.swift` (+~6 LOC): `enumerate` gains `disabledKinds: Set<ProcessKind> = []`; the filter runs **after** `collapseWrappers` so a merged wrapper row is judged by its displayed (child) kind.
- `ScanEngine.swift` (+~12 LOC): `@Published var disabledKinds: Set<ProcessKind>` persisted to UserDefaults as `[String]` rawValues (`didSet`), rehydrated in `init` via `compactMap(ProcessKind.init(rawValue:))`, captured + passed into `enumerate` in `scan()`.
- `SettingsView.swift` (+~22 LOC): `import PidlyseCore`, a `kindEnabled(_:)` computed-`Binding` helper, and a "Scanned kinds" `Section` with a `Toggle` per `ProcessKind.allCases` (checked = scanned) + an explanatory caption.
- `ScanEngineTests.swift` (+~24 LOC): 3 `disabledKinds` filtering tests.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `xcodebuild test` → **TEST SUCCEEDED** (121 tests, 0 failures; +3 new `disabledKinds` tests over the prior 118)

- [x] Ran lint/type-check on changed code — the test build compiles app + core clean (Swift compiler is the type-checker; no separate linter). The SourceKit "No such module 'PidlyseCore'" / "Cannot find 'Shell'" diagnostics are the known stale-indexer artifacts (per PID-50.2/50.5) — `xcodebuild` resolves the package fine.

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — bundled at the 📦 gate

**Testing Notes:** Suite green (121/121). The new core filter is unit-tested; the Settings toggle is view-local presentation logic over the tested predicate.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** (added "per-kind scan toggles" to the Settings feature bullet) · `AGENTS.md`: no change (no new conventions; mirrors the existing `ignoredNames` filter idiom) · `CLAUDE.md`: no change (scan/classification stays in `PidlyseCore`; no new split to document) · `.flowtron/PLAN.md`: `.6` line flipped to stub form (kept nested under PID-EPIC-50; parent + cohort move to `## Completed` only when all children close)

- [x] Closed — PLAN.md line flipped to `Completed 2026-06-30.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Added per-kind scan toggles. `ScanCore.enumerate` takes an injectable `disabledKinds: Set<ProcessKind>` and drops matching items after the wrapper collapse (so merged rows are judged by their displayed kind); `ScanEngine` persists the set as UserDefaults rawValues and passes it into each scan; `SettingsView` gains a "Scanned kinds" section with a toggle per kind. Mirrors the existing substring `ignoredNames` ignore at the category level. +3 `ScanCore` unit tests (121/121 green), +1 README Settings bullet; no new imports beyond `PidlyseCore` in the view, no shell-out. Fifth implementation child of PID-EPIC-50 (Survey item 5).

**Archived:** 2026-06-30
