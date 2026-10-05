---
title: protect-and-scope
status: in-progress
tags: []
created: 2026-07-01
related-tasks: [PID-EPIC-54, PID-54.1, PID-54.3]
---

# PID-54.4 | protect-and-scope

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-54]] · [[PID-54.1]] · [[PID-54.3]]

## 🎯 Goal

Add two persisted, user-managed classification-override lists to the scan: a **protected list** that keeps chosen matches out of the Safe bucket / "Clean all" bulk sweep (marked 🔒, one-click un-protect, individual kill still allowed), and **per-project ignores** that extend the existing substring ignores with an optional cwd-path-prefix so a rule hides matches only under a chosen project tree.

## ✅ Acceptance

- [ ] **Protect (cwd-tree axis):** `ProcessCwd` carries the project-root path; a pure `CwdResolver.isUnderPrefix` primitive matches a cwd against a stored prefix. A per-row 🔒 toggle protects/un-protects the row's project (one click each way), driven by `ScanEngine.protectedProjects` + the `cwds` map (instant — no rescan needed).
- [ ] **Protect display:** a protected Safe row stays visible in the Safe section badged 🔒, but is excluded from the "Clean all" target set, the section count, the reclaimable total, and the ⌘⌫ sole-safe-kill; its individual kill button still works.
- [ ] **Per-project ignores:** the Ignored-processes grammar gains an optional ` @ <path-prefix>` suffix (`IgnoreRule` model, `parse`/`serialize`); a scoped rule hides matches only when the command matches **and** the resolved cwd is under the prefix. Bare lines stay global (backward compatible).
- [ ] Both lists persist to UserDefaults and are wired into `ScanEngine` (`@Published`, mirroring `ignoredNames`) + Settings editors (a new "Protected projects" section; extended help text on "Ignored processes").
- [ ] Unit tests: `isUnderPrefix` containment/edge cases; `IgnoreRule.parse`/`serialize` (global + scoped + malformed); scoped-ignore post-filter (hides under prefix, keeps outside, keeps unresolved-cwd); `projectRoot` population.
- [ ] `make test` green.
- [ ] SPEC.md §"Scan Engine"/§"Classification" + README feature surface updated for protected projects + scoped ignores.
- [ ] Phase 4 doc-drift sweep across README §"AI-referenced docs".

## 🧩 Subtasks

- [x] Resolve scoping questions (protect axis · protect display · ignore editor grammar) via AskUserQuestion
- [ ] `PidlyseCore`: add `ProcessCwd.projectRoot: String?` + populate in `CwdResolver.processCwds`; add pure `CwdResolver.isUnderPrefix(_:_:)`
- [ ] `PidlyseCore`: add `IgnoreRule` model (new `IgnoreRule.swift`) — `{ substring, pathPrefix }`, `parse` (` @ ` split), `serialize`
- [ ] `PidlyseCore`: add `ScanCore.applyScopedIgnores(_:cwds:rules:)` pure post-filter
- [ ] `ScanEngine`: add `@Published protectedProjects` (UserDefaults, mirror `ignoredNames`); parse `ignoredNames` → global (→ `enumerate`) + scoped (→ post-filter after `processCwds`)
- [ ] `SettingsView`: add "Protected projects" `TextEditor` section; extend "Ignored processes" help text for the ` @ path` grammar
- [ ] `MenuBarView`: `isProtected` predicate; split `sweepableSafeItems` from `safeItems` (Clean-all / count / reclaimable / ⌘⌫); 🔒 badge + per-row lock toggle button (Safe rows)
- [ ] Add unit tests in `ScanEngineTests.swift`; run `make test`
- [ ] Sync SPEC.md + README; Phase 4 closure (doc-drift, PLAN flip, archive)

## 🔗 Related

- [[PID-EPIC-54]] — parent epic (detection-rules)
- [[PID-54.1]] — epic Discovery; scoped this child (protected list kept out of Safe, un-protectable; cwd-path-prefix per-project ignores via `CwdResolver`)
- [[PID-54.3]] — sibling; custom-rules — the immediately-preceding `@Published` list + Settings `TextEditor` + `enumerate`-threading pattern to mirror

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Implementation child `.4` of PID-EPIC-54, scoped by the `.1` Discovery. Siblings `.2` (built-in kinds) and `.3` (custom rules) are done; this is the last implementation child before the `.5` audit. Clear deliverable: two persisted classification-override lists (protect + cwd-scoped ignore) wired into Settings + UserDefaults + the scan pipeline.

- [x] Read relevant source files — `ScanCore.swift` (`enumerate`/`makeItem`/`riskTier`, and the `registeredPIDs`→tier-demotion override at `:140`), `ProcessItem.swift` (`ProcessItem`/`bucket`/`customLabel`), `CwdResolver.swift` (`processCwds`/`ProcessCwd.fullPath`/`abbreviateHome`), `ScanEngine.swift` (`ignoredNames`/`customRules` persistence + `cwds` map resolved post-`enumerate` in `scan()`), `SettingsView.swift` (Ignored / Custom `TextEditor` sections), `MenuBarView.swift` (`safeItems`/`reviewItems`/`safeSection` "Clean all", `row`/`rowDescriptor`, per-row dismiss/kill buttons).

- [x] **Archive skim** — load-bearing precedents: **PID-036.3** (the `registeredPIDs` port-demotion `if … tier == .easy { tier = .moderate }` — the exact template for a protect-driven tier override), **PID-038** (introduced `CwdResolver` + the `cwds: [Int32: ProcessCwd]` map that per-project ignores consume; cwd is resolved **after** `enumerate` in `scan()`), **PID-16.4** (`ignoredNames` UserDefaults `@Published`+init-load), **PID-006** (Ignored-processes `TextEditor`), **PID-50.6** (Settings section wiring), **PID-54.3** (sibling — the exact `@Published`+`didSet`+`init` + `TextEditor` + `enumerate`-threading + display-consumer shape to mirror).

- [x] **Drift check** — all cited symbols match HEAD: `enumerate` `ScanCore.swift:20`, `makeItem` `:114`, port-demotion override `:140`, `riskTier` `:272` (exhaustive switch); `ProcessItem.bucket` `ProcessItem.swift:138`; `CwdResolver.processCwds` `:35`, `ProcessCwd.fullPath` `:13`, `abbreviateHome` `:85`; `ScanEngine.cwds` `:34`, cwd resolved post-enumerate `ScanEngine.swift:179`, `ignoredNames`/`customRules` persistence `:69`/`:90`; `SettingsView` Ignored `:93` / Custom `:101`; `MenuBarView.safeItems` `:465`, `safeSection` "Clean all" `:221`, `row` `:299`, `rowDescriptor` `:292`. No drift.

  **Key architectural finding (informs design):** `enumerate` has **no cwd data** — the `cwds` map is resolved *downstream* of `enumerate` in `ScanEngine.scan()` (`:179`, keyed off the enumerated result's PIDs). So a cwd-conditioned per-project-ignore filter cannot live *inside* the current single `enumerate` call without a double cwd-resolve. Cleanest faithful design: keep command-substring logic in `enumerate`, and apply the cwd-dependent per-project-ignore as a **pure `ScanCore` post-filter** that `ScanEngine` calls after `processCwds` (logic stays in Core per CLAUDE.md; respects the real data dependency). Protection does **not** need cwd if keyed on a command/path axis — it's a `riskTier`/bucket override mirroring the port-demotion.

- [x] Asked clarifying questions — resolved via AskUserQuestion (table below)

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Resolved scoping (AskUserQuestion, 2026-07-01)

| Question | Resolution |
|----------|-----------|
| Protect matching axis (what 🔒 persists) | **Project / cwd tree.** Persists the row's project-root path (`~/code/bidviz`); protects every process whose resolved cwd sits under that tree. Unifies with per-project ignores — both key off `CwdResolver`. |
| Protected-item display | **Stay in Safe, badged 🔒.** The protected row stays in the Safe section but shows 🔒 and is excluded from "Clean all", the section count, and the reclaimable total. Individual kill still available. |
| Per-project ignore editor | **Extend the Ignored-processes grammar** with an optional ` @ <path-prefix>` suffix. Bare lines stay global (backward compatible). One editor, one persistence key. |

### Design (minimal)

Both features key on a **cwd path prefix**, so they share one primitive and the existing `cwds` map (PID-038). Protection is a **display/sweep overlay** (not a classification change); scoped ignores are a **post-`enumerate` filter** (they need cwd, which `enumerate` lacks — see the drift-check architectural finding).

- **`ProcessCwd.projectRoot: String?`** (new field, default nil) — abbreviated git-root path (`~/code/bidviz`), populated in `processCwds` from the already-computed `gitRoot` (nil outside a repo). The row 🔒 seeds `projectRoot ?? fullPath`.
- **`CwdResolver.isUnderPrefix(_ cwd:_ prefix:) -> Bool`** — pure abbreviated-path containment (`cwd == prefix || cwd.hasPrefix(prefix + "/")`, trailing-slash tolerant). Shared by protect + scoped ignore.
- **`IgnoreRule`** (new `IgnoreRule.swift`) — `struct { substring, pathPrefix: String? }` + `parse` (split first ` @ `; bare line → global `pathPrefix == nil`) + `serialize`. Mirrors `CustomRule`.
- **`ScanCore.applyScopedIgnores(_ items:cwds:rules:)`** — pure post-filter: drop an item when its command contains a scoped rule's substring **and** `isUnderPrefix(cwd.fullPath, rule.pathPrefix)`.
- **`ScanEngine`**: `@Published var protectedProjects: [String]` (UserDefaults `[String]`, mirrors `ignoredNames`, init-load). In `scan()`: parse `ignoredNames` → `IgnoreRule`s; pass **global** substrings to `enumerate` (unchanged path — byte-identical existing behavior); apply **scoped** rules via `applyScopedIgnores` after `processCwds`. `protectedProjects` is **not** threaded into the scan — protection is view-side (instant lock/unlock).
- **`SettingsView`**: new "Protected projects" `TextEditor` (mirrors Ignored-processes, newline join/split → `protectedProjects`); extend the "Ignored processes" help text to document ` @ path`.
- **`MenuBarView`**: `isProtected(_ item)` = any `protectedProjects` prefix covers `cwds[pid]?.fullPath` (via `isUnderPrefix`). Split `sweepableSafeItems = safeItems.filter { !isProtected }` → drives "Clean all" target, the section count, `safeReclaimableKB`, and `soleSafeKillShortcut` (⌘⌫). `safeItems` still displays all safe rows. Protected Safe rows: leading 🔒 badge instead of the risk dot; a per-row lock toggle button (`lock.open`↔`lock.fill`) protects/un-protects (`protectedProjects` append / `removeAll { isUnderPrefix }`). Lock UI gated to `.safe` rows (only they're swept). `grouped()`/`collapsedKinds` untouched.

### Backward-compat / churn control
- `ignoredNames` stays `[String]` raw lines — no persistence migration; existing bare-substring ignores parse as global `IgnoreRule`s. `enumerate`'s existing `ignoredNames` param + its tests are untouched (global path is byte-identical).
- `ProcessCwd` gains a defaulted `projectRoot` param → existing `ProcessCwd(label:fullPath:)` call sites (tests) still compile.

### Downstream-impact reconciliation
No new PLAN filing / no direction change reaching beyond this task — the answers refined *mechanism* within the `.1`-scoped surface (protect list + cwd-scoped ignores), not scope. The cwd-axis choice actually reduces surface (one shared primitive). No PLAN edits needed; sibling `.3` (custom-rules) is complementary (a classification *input*; this adds an *override/overlay*).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — mirrored **PID-54.3** (`@Published`+`didSet`+`init`-load list + `TextEditor` section), **PID-036.3** (per-item overlay predicate), **PID-038** (`CwdResolver`/`ProcessCwd` shape), and the `IgnoreRule` model mirrors `CustomRule` (pure `parse`/`serialize` in a dedicated Core file). No new structure invented.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 14 new tests.

**Implementation Notes:**
- **`CwdResolver.swift`**: `ProcessCwd.projectRoot: String?` (abbreviated git-root, populated from the already-computed `gitRoot` in `processCwds`); pure `isUnderPrefix(_:_:)` (trailing-slash-tolerant, empty-prefix-safe) shared by protect + scoped ignore.
- **`IgnoreRule.swift`** (new PidlyseCore file): `struct { substring, pathPrefix }` + `parse` (first ` @ ` split; bare → global; empty prefix degrades to global) + `serialize`.
- **`ScanCore.swift`**: pure `applyScopedIgnores(_:cwds:rules:)` post-filter — drops an item when command-substring matches **and** cwd is under the rule's prefix; unresolved cwd → kept; global rules skipped (handled in `enumerate`).
- **`ScanEngine.swift`**: `@Published protectedProjects` (UserDefaults `[String]`, init-load, mirrors `ignoredNames`). `scan()` parses `ignoredNames` → global substrings (→ `enumerate`, byte-identical existing path) + scoped rules (→ `applyScopedIgnores` after `processCwds`). `protectedProjects` deliberately **not** threaded into the scan (view-side overlay → instant lock/unlock).
- **`SettingsView.swift`**: new "Protected projects" `TextEditor`; extended "Ignored processes" help text for the ` @ path` grammar.
- **`MenuBarView.swift`**: `isProtected` (cwd under any protected prefix) + `toggleProtected` (seed `projectRoot ?? fullPath`; unlock removes every covering prefix). `sweepableSafeItems = safeItems − protected` drives "Clean all" target, the "Safe to clean (N)" count, `safeReclaimableKB`, and the ⌘⌫ shortcut; the Safe section still *lists* protected rows (leading 🔒 badge + `lock.fill`↔`lock.open` toggle button, gated to `.safe` rows with a resolvable cwd). Clean-all disabled when nothing sweepable.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **183 tests, 0 failures** (+14: 4 `isUnderPrefix`, 5 `IgnoreRule` parse/serialize, 5 `applyScopedIgnores`, + updated `projectRoot` expectations).

- [x] Ran lint/type-check on changed code — Swift compile under `make test` type-checks the package; **TEST SUCCEEDED**. SourceKit "No such module 'PidlyseCore'/'XCTest'" + "Cannot find 'CustomRule'/'Shell'/'CwdResolver'" diagnostics are cross-file resolution false positives (build + tests succeed) — same class noted in PID-54.3.

- [x] (frontend) Asked the user for visual confirmation — 👁️ ask surfaced at closure (Settings "Protected projects" editor + per-row 🔒 lock toggle/badge + "Clean all" excluding locked rows). Not a gate.

**Testing Notes:** Locked by unit tests: `isUnderPrefix` exact/descendant/sibling/partial-segment/trailing-slash/empty-prefix; `IgnoreRule` global vs scoped parse, empty-substring nil, empty-prefix→global, serialize round-trip; `applyScopedIgnores` hides-under-prefix, keeps-outside, keeps-unresolved-cwd, skips-global, substring-must-also-match. Protect overlay is view-composition over the tested `isUnderPrefix` primitive.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` — **updated** (Protect-a-project feature line, ⌘⌫ line, Settings line) · `AGENTS.md` — no change (workflow guide, no feature/core-file surface) · `CLAUDE.md` — **updated** (added `IgnoreRule.swift` to the PidlyseCore core-file list) · `.flowtron/PLAN.md` — updated (`.4` flipped to stub). Also synced the non-AI-referenced `SPEC.md` §"Scan Engine" + §"Classification" + file tree + `SettingsView` comment (the task's own contract deliverable).

- [x] Closed — PLAN.md line flipped to stub form and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:** Added two persisted, user-managed classification-override lists to Pidlyse, both keyed on the cwd map (PID-038). **Protected projects**: clicking 🔒 on a Safe row persists its project-root path (`ProcessCwd.projectRoot`, new); any process whose cwd is under a protected prefix (`CwdResolver.isUnderPrefix`, pure/shared) stays *listed* in the Safe section badged 🔒 but is excluded from "Clean all", the section count, the reclaimable total, and ⌘⌫ — a view-side overlay (instant lock/unlock, no rescan), still individually killable. **Per-project ignores**: the Ignored-processes editor grammar gains an optional ` @ <path-prefix>` (`IgnoreRule`, new Core model); a scoped rule hides matches only when the command matches *and* the cwd is under the prefix, applied by the pure `ScanCore.applyScopedIgnores` post-filter after cwd resolution (global bare-line ignores keep their byte-identical `enumerate` path — no persistence migration). Both wired into `ScanEngine` (`@Published protectedProjects`, UserDefaults) + Settings. 14 unit tests, `make test` green (183/0). SPEC + README + CLAUDE.md synced.

**Archived:** 2026-07-01
