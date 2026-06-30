---
title: row-context-menu
status: in-progress
tags: [ux]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-050.1, PID-049]
---

# PID-50.2 | row-context-menu

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Add a right-click `.contextMenu` to each process row in the popover offering Copy PID · Copy command line · Copy `kill <pid>` · Reveal working directory in Finder — using NSPasteboard / NSWorkspace only, no new shell-out.

## ✅ Acceptance

- [ ] Right-clicking any process row shows a context menu with: Copy PID · Copy command line · Copy `kill <pid>` · Reveal working directory in Finder
- [ ] Copy items place the exact string on `NSPasteboard.general` (PID = bare number; command line = `item.command`; kill = `kill <pid>`)
- [ ] "Reveal working directory in Finder" reveals the cwd via `NSWorkspace`; item omitted when the cwd is unresolved (graceful degrade)
- [ ] No new shell-out — only `NSPasteboard` / `NSWorkspace`
- [ ] Build compiles clean (`xcodebuild build -scheme Pidlyse`) and existing tests pass

## 🧩 Subtasks

- [ ] Add a private `copyToPasteboard(_:)` helper in MenuBarView (clearContents + setString)
- [ ] Attach a `.contextMenu { }` to the row content inside `row(_:)`
- [ ] Add the three Copy buttons (PID, command line, `kill <pid>`) via the helper
- [ ] Add the conditional "Reveal working directory in Finder" button (tilde-expand `fullPath` → file URL → `NSWorkspace.shared.activateFileViewerSelecting`)
- [ ] Build + run targeted tests
- [ ] 👁️ Visual confirmation of the right-click menu on a row

## 🔗 Related

- [[PID-EPIC-50]] — parent epic (popover-power-ux)
- [[PID-050.1]] — Discovery; scoped this child (Survey item 1)
- [[PID-049]] — ux-feature-survey; sourced the shortlist

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Survey item 1 from [[PID-049]], scoped by [[PID-050.1]] Discovery. MenuBarView-local, clear-diff `[light]` affordance; all data already on hand (`item.pid`, `item.command`, `engine.cwds`). No blockers.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source surface (read):**

- `Pidlyse/MenuBarView.swift` — `row(_:)` (line 209) builds each process row as a `VStack`. The `.contextMenu` attaches to that returned view. `rowDescriptor`/`.help` (line 222) already reads `engine.cwds[item.pid]?.fullPath`, so the cwd plumbing for "Reveal in Finder" exists.
- `Packages/PidlyseCore/.../ProcessItem.swift` — `command` (line 76) is the **full command line** (`ps` args column) → "Copy command line". `pid: Int32` → "Copy PID" / "Copy `kill <pid>`".
- `Packages/PidlyseCore/.../CwdResolver.swift` — `ProcessCwd.fullPath` (line 13) is **`~`-abbreviated** (e.g. `~/Code/bidviz`); revealing in Finder needs `(fullPath as NSString).expandingTildeInPath` to recover the real path. `engine.cwds[pid]` is **optional** — unresolved for non-project processes.

**Archive skim:** PID-023 (`right-click-menu`) added a context menu on the **menu-bar icon** (AppKit `NSMenu` on the `NSStatusItem`) — a different surface from a SwiftUI row `.contextMenu`; no reuse, but confirms right-click affordances are in-character. PID-038 promoted the cwd/project label to the always-visible `rowDescriptor` and is the source of the `engine.cwds` map this task reveals. No prior `NSPasteboard` / row `.contextMenu` usage in the codebase (grep clean).

**Drift check:** All cited paths/types match HEAD. One nuance (not drift): `fullPath` is tilde-abbreviated → expand before building the Finder URL. `NSWorkspace.shared` is already imported transitively (used in AppDelegate line 121); MenuBarView imports `SwiftUI` + `PidlyseCore` — `NSPasteboard`/`NSWorkspace` come from AppKit, available via SwiftUI on macOS (no new import expected; add `import AppKit` only if the compiler complains).

**No clarifications needed.** Explicit assumptions:
1. Menu order = PLAN.md order: Copy PID · Copy command line · Copy `kill <pid>` · Reveal working directory in Finder.
2. "Reveal" uses `NSWorkspace.shared.activateFileViewerSelecting([url])` (selects the folder in its parent — the standard "reveal" semantic).
3. When `engine.cwds[item.pid]` is unresolved, the Reveal item is **omitted** (graceful degrade, matching the codebase's "render only when resolvable" pattern), not shown-disabled.
4. Copy PID = bare number string (`String(item.pid)`), not `PID 123`.

**Exit-gate judgment:** Discovery surfaced no significant deviation (sensible-default micro-decisions only, no re-scope/de-scope) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — no existing row `.contextMenu` / `NSPasteboard` in the codebase; PID-023's menu lives on the `NSStatusItem` (AppKit), a different surface. New shape justified: SwiftUI `.contextMenu` is the idiomatic row affordance. Followed the existing private-helper convention (`ramString`/`ageString`) for `copyToPasteboard`, and reused AppDelegate's `NSWorkspace.shared` idiom for the reveal.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (view-only context menu; no pure logic added, nothing unit-testable beyond the existing build)

**Implementation Notes:**

- `Pidlyse/MenuBarView.swift`: appended `.contextMenu { rowContextMenu(item) }` to the row `VStack` in `row(_:)`; added `rowContextMenu(_:)` (`@ViewBuilder`, 4 items) and `copyToPasteboard(_:)` (clearContents + setString) private helpers. +27 lines.
- Reveal item is conditional on `engine.cwds[item.pid]` resolving; `fullPath` tilde-expanded before building the file URL for `NSWorkspace.shared.activateFileViewerSelecting`.
- No new imports needed (`NSPasteboard`/`NSWorkspace`/`URL` resolve through SwiftUI on macOS — build confirmed). No shell-out added.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — full suite (118 tests) passes; no UI test target, so the build is the type-check gate

- [x] Ran lint/type-check on changed code — `xcodebuild build -scheme Pidlyse` → **BUILD SUCCEEDED** (Swift compiler is the type-checker; no separate linter)

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — see bundled ask at the 📦 gate

**Testing Notes:** Build clean; `** TEST SUCCEEDED **` (118 tests, 0 failures). The lone SourceKit "No such module 'PidlyseCore'" diagnostic is a stale indexer artifact on the pre-existing import — `xcodebuild` resolves the local package fine.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** (added a "Right-click a row" feature bullet to the Features list) · `AGENTS.md`: no change · `CLAUDE.md`: no change · `.flowtron/PLAN.md`: `.2` line flipped to stub form (kept nested under PID-EPIC-50; parent + cohort move to `## Completed` only when all children close)

- [x] Closed — PLAN.md line flipped to `Completed 2026-06-30.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Added a right-click `.contextMenu` to every process row in the popover (`MenuBarView.swift`): Copy PID · Copy command line · Copy `kill <pid>` (all via a new `copyToPasteboard` helper on `NSPasteboard.general`) · Reveal working directory in Finder (`NSWorkspace.activateFileViewerSelecting`, conditional on a resolved cwd, tilde-expanded). No new shell-out, no new data — reuses `item.pid` / `item.command` / `engine.cwds`. +27 LOC in MenuBarView; +1 README feature bullet. Build clean, 118 tests pass. First implementation child of PID-EPIC-50 (Survey item 1).

**Archived:** 2026-06-30
</content>
</invoke>
