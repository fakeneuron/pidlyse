---
title: cleaned-tab-stats
status: in-progress
tags: []
created: 2026-07-01
due:
related-tasks: [PID-EPIC-53, PID-53.1, PID-53.2, PID-53.4]
---

# PID-53.3 | cleaned-tab-stats

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-53]] [[PID-53.1]] [[PID-53.2]]

## 🎯 Goal

Add a third "Cleaned" segment to the popover surfacing value stats over a
rolling week (cleaned this week, estimated RAM reclaimed, top stray kinds) plus
a Recently-cleaned list, consuming the [[PID-53.2]] `CleanLogStore` — turning the
persisted confirmed-clean log into visible persistent value.

## ✅ Acceptance

- [ ] Third "Cleaned" segment added to the popover tab picker; selecting it shows
      the cleaned view (presentation only — no new persistence/Core logic)
- [ ] Value stats over a rolling 7-day window via `CleanLog.stats(from:now:window:)`:
      count cleaned this week, estimated RAM reclaimed, top stray kinds
- [ ] Recently-cleaned list (newest-first) showing kind label, project label,
      RAM footprint, and a relative "…ago" timestamp
- [ ] Empty state when no confirmed cleans are logged yet
- [ ] View binds to `engine.cleanLog` (`CleanLogStore.@Published events`); popover
      width stays 320
- [ ] `make test` green; Xcode target builds (new app file wired into pbxproj)

## 🧩 Subtasks

- [ ] Add `.cleaned` to `MenuBarView.Tab` + a third "Cleaned" picker segment,
      route it in the `body` switch (searchField stays gated to `.processes`)
- [ ] Add app-side `CleanedView.swift` (stats strip + top-kinds + recently-cleaned
      list + empty state), bound to `CleanLogStore` as an `@ObservedObject`
- [ ] Wire `CleanedView.swift` into `project.pbxproj` (4 entries, mirror
      `ContainersView.swift`)
- [ ] `make test` + Xcode build green; visual confirmation of the new tab

## 🔗 Related

- [[PID-EPIC-53]] — parent epic (clean-history-stats)
- [[PID-53.1]] — discovery; resolved the three design forks (third-tab placement)
- [[PID-53.2]] — data layer; this task consumes its `CleanLogStore` + `CleanLog.stats`
- [[PID-53.4]] — final audit subtask

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Fresh epic child, no existing implementation. This is the
  presentation layer [[PID-53.1]] scoped and [[PID-53.2]] built the data for —
  the third "Cleaned" tab placement was the operator-resolved fork #3. The
  `CleanLogStore` + `CleanLog.stats` API exist and are unit-tested; still clearly
  wanted.

- [x] Read relevant source files

- [x] **Archive skim** — see Discovery Notes.

- [x] **Drift check** — see Discovery Notes.

- [x] Asked clarifying questions OR logged assumptions — see Discovery Notes.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

*Verified current surface (HEAD):*
- `MenuBarView` has a 2-case `Tab` enum (`.processes`/`.containers`), a
  `.segmented` `tabPicker` with two `Text().tag()` entries, and a `body` `switch`
  routing each tab. `searchField` renders only for `.processes` (guarded). Fixed
  `.frame(width: 320)`. `ContainersView` is the sibling tab view (own `@State`,
  `.frame(height: 360)`, empty-state helper) — the shape to mirror.
- `ScanEngine.cleanLog` is a `let cleanLog = CleanLogStore()` (already exposed for
  this tab, per PID-53.2 comment). `CleanLogStore: ObservableObject` publishes
  `@Published private(set) var events: [CleanEvent]` (oldest-first append order).
- `PidlyseCore.CleanLog.stats(from:now:window:)` → `Stats { count, ramReclaimedKB,
  topKinds: [KindCount{kind, count}] }`, windowed to `[now-window, now]`. `kind` is
  the `ProcessKind` **rawValue** string; map back for display via
  `ProcessKind(rawValue:)?.label ?? kind`.
- `CleanEvent` = `{ kind: String (rawValue), projectLabel: String, rssKB: Int,
  timestamp: Date }`.
- `MenuBarView.ramString(_:)` (KB→"N MB"/"N KB") is `private` — the new view needs
  its own local copy (small, not worth promoting to Core for one call site).

*Archive skim (`archive/pid/`, grep on MenuBarView / ContainersView):*
- Tab UX established by PID-28.4 (`ContainersView` + segmented picker) and refined
  by the PID-EPIC-50 popover-power-ux cohort (PID-50.3 provenance sort, PID-50.5
  quick-filter gated to Processes, PID-50.7 sole-safe-kill shortcut). PID-040
  (popover-realign) fixed the width/height sizing — keep `width: 320` +
  per-tab `height: 360` intact; don't reintroduce dynamic sizing.
- No prior tasknote rendered the clean log (this is its first consumer). PID-53.2
  built the store + `CleanLog.stats` specifically for this tab.

*Drift check:* PLAN line + PID-53.1/.2 notes match current code exactly —
`cleanLog` exposed, `CleanLog.stats` present and tested, third-tab placement is
the resolved fork. No drift.

*Design (presentation-only, mirrors `ContainersView`):*
- Add `.cleaned` to `Tab`; third `Text("Cleaned").tag(Tab.cleaned)` segment; route
  `case .cleaned: CleanedView(store: engine.cleanLog)` in `body`. Three segments at
  width 320 is tight but standard for `.segmented` (labels are short).
- `CleanedView(store: CleanLogStore)` as `@ObservedObject` (nested ObservableObject
  → the subview observes it directly; MenuBarView holding `engine` wouldn't
  auto-refresh on `events` change). `.frame(height: 360)` to match siblings.
- Stats strip from `CleanLog.stats(from: store.events, now: Date(), window: 7*86400)`:
  "N this week", "~X MB reclaimed", top kinds as a short chip/label row.
- Recently-cleaned list: `store.events.reversed()` (newest-first), display-capped
  to the newest 50 to bound the view; each row = kind label + projectLabel + RAM +
  relative time (`RelativeDateTimeFormatter`, native "…ago").
- Empty state ("No cleaned processes yet.") when `store.events.isEmpty`, matching
  the `ContainersView` empty helper aesthetic.

*Assumptions (no operator ask needed — all within the .1-resolved design):*
1. Window for the headline stats = rolling **7 days** ("this week", the PLAN
   wording). One window for all three headline figures.
2. Recently-cleaned list shows **all-time** recent (newest 50 of the capped-1000
   log), not windowed — "recently cleaned" reads as a history list, distinct from
   the windowed value stats above it.
3. Reuse the existing "caption/secondary" popover aesthetic (fonts, spacing,
   empty-state style) rather than introducing new visual language.

**Phase 1→2 exit:** Discovery surfaced no significant deviation → skip 🛠️. The
epic's .1 plan called for exactly this presentation layer against the .2 store;
the design mirrors the established sibling-tab pattern with no scope/approach/file
change.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `CleanedView` mirrors `ContainersView` exactly: sibling
  tab view, `.frame(height: 360)`, `empty(_:)` helper, `ScrollView` + `VStack`
  body. The stats strip / section headers reuse the Processes-tab caption/
  subheadline aesthetic (`safeSection` "~X reclaimable" phrasing, `criterionTag`
  chip shape). `ramString` is duplicated locally (the `MenuBarView` copy is
  `private`; one call site doesn't warrant promoting to Core).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A. The stats/retention logic
  is pure `PidlyseCore.CleanLog`, already unit-tested in PID-53.2 (9 `CleanLogTests`);
  this task is a presentation-only consumer with no new testable pure logic (mirrors
  `ContainersView` carrying no unit tests).

**Implementation Notes:**
- **`Pidlyse/CleanedView.swift`** (new, ~150 LOC): `@ObservedObject store:
  CleanLogStore`. Empty state ("No cleaned processes yet.") when `events` empty;
  otherwise a stats strip (from `CleanLog.stats(from:now:window: 7*86400)` — "N
  cleaned", "~X reclaimed", top-3 kind chips) above a newest-first "Recently
  cleaned" list (`events.reversed().prefix(50)`, kind label + project label + RAM +
  native `RelativeDateTimeFormatter` "…ago"). Kind rawValue → label via
  `ProcessKind(rawValue:)?.label ?? kind`.
- **`Pidlyse/MenuBarView.swift`**: added `.cleaned` to `Tab`, a third "Cleaned"
  picker segment, and the `body` switch route `CleanedView(store: engine.cleanLog)`.
  Header refresh switch gets a `.cleaned: break` case + is `.disabled` on that tab
  (live-bound, nothing to refresh); `refreshHelp` computed property replaces the
  two-way `.help` ternary to stay tab-accurate. `searchField` stays gated to
  `.processes` (unchanged).
- **`Pidlyse.xcodeproj/project.pbxproj`**: `CleanedView.swift` wired via 4 entries
  (ids B162/B163) mirroring `ContainersView.swift`.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **149 passed, 0
  failures**. No new tests (presentation-only; pure logic already covered).

- [x] Ran lint/type-check on changed code — full `xcodebuild test` build compiles
  clean (app + Core + tests). SourceKit "No such module 'PidlyseCore'" editor
  warnings are the stale-index artifact noted in PID-53.2; the build is ground truth.

- [x] (frontend) Asked the user for visual confirmation — operator confirmed the
  three-segment picker + Cleaned tab (stats strip / Recently-cleaned list / empty
  state / disabled refresh) 2026-07-01.

**Testing Notes:** Build + full suite green (149 passing). Operator confirmed the
new tab visually.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md` — **updated**: this is the user-visible
  surface PID-53.2 deferred to `.3`; added a "Cleaned tab" Features bullet and
  extended the segmented-toggle mention to Processes / Containers / Cleaned.
  `AGENTS.md` — no change (no core-file/feature list). `CLAUDE.md` — no change (the
  PID-53.2 clean-log Conventions bullet already covers the plumbing; the view is a
  plain consumer, no new architectural rule). `.flowtron/PLAN.md` — updated (line
  flipped to stub form; parent epic stays open).

- [x] Closed — PID-53.3 flipped to `Completed 2026-07-01.` in place under
  PID-EPIC-53 (parent stays open); tasknote moved to `archive/pid/`.

- [x] Recap drafted.

**Final Summary:** Shipped the "Cleaned" popover tab — the presentation layer that
turns PID-53.2's persisted confirmed-clean log into visible persistent value. New
`Pidlyse/CleanedView.swift` (~150 LOC, `@ObservedObject CleanLogStore`) renders a
rolling-week stats strip (count cleaned / ~RAM reclaimed / top-3 kind chips, via the
pure `CleanLog.stats(from:now:window: 7*86400)`) above a newest-first "Recently
cleaned" list (kind label · project label · RAM · native `RelativeDateTimeFormatter`
"…ago"), with an empty state and a display cap of 50 rows. `MenuBarView` gained a
`.cleaned` `Tab` case, a third "Cleaned" segment, the body-switch route, and a
`refreshHelp` property + disabled/`break` handling so the header `↻` stays
tab-accurate (the tab is live-bound). Presentation-only — no new Core/persistence
logic, so no new tests (pure stats already covered by PID-53.2's 9 `CleanLogTests`).
`CleanedView.swift` wired into `project.pbxproj` (4 entries). `make test` = 149
passing; operator confirmed the tab visually.

**Archived:** 2026-07-01
