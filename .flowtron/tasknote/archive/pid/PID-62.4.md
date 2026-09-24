---
title: tree-redundancy-collapse
status: completed
tags: []
created: 2026-09-23
due:
related-tasks: [PID-EPIC-62, PID-62.2, PID-62.3, PID-039]
touches:
  - Packages/PidlyseCore/Sources/PidlyseCore/ScanCore.swift
  - Packages/PidlyseCore/Sources/PidlyseCore/ProcessItem.swift
  - Packages/PidlyseCore/Sources/PidlyseCore/KillCore.swift
  - Packages/PidlyseCore/Sources/PidlyseCore/Killability.swift
  - Packages/PidlyseCore/Sources/PidlyseCLI/main.swift
  - Pidlyse/ScanEngine.swift
  - Pidlyse/MenuBarView.swift
  - PidlyseTests/ScanEngineTests.swift
  - SPEC.md
  - CLAUDE.md
---

# PID-62.4 | tree-redundancy-collapse

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-62]]

## 🎯 Goal

Collapse scanned parent+child process chains that live and die together (`sh -c npm run dev` → npm → vite, `uv run` → uvicorn, `next dev` → next-server, playwright-mcp → Chrome brood) into one logical row, and make that row's kill take down, and verify, every member.

## ✅ Acceptance

- [x] A scanned process whose direct parent is also scanned folds into its topmost scanned ancestor's row (any depth, any fan-out). The row keeps the root's identity (pid/ppid/tty/startTime/uid/elapsed), the label (kind/command/customLabel) of the first non-launcher member, the most cautious riskTier of all members, and summed CPU/RAM. Members are carried on `ProcessItem.members`. Docker-kind processes never join a group. — `make test` (`ScanCoreTreeCollapseTests`)
- [x] Group kill: root first via the existing SIGTERM → 2 s → SIGKILL path, then any member still alive is killed concurrently, each with its own PID-reuse guard. A pure aggregation reports the row outcome: `.confirmed` only if every member is verified gone. — `make test` (`KillCoreTests` group-outcome cases)
- [x] A dismissed group row stays dismissed as a whole: the dismiss filter runs after the collapse, so the leftover members don't re-form a smaller group. — `make test`
- [x] Killability treats a group as foreign-owned when any member is foreign-owned, in both the app and the CLI `clean` (one core helper). — `make test` (`KillabilityTests`)
- [x] Clean-all, ⌘⌫, the section counts and the clean log count each group once. Respawn signatures come from the group's representative command plus the root's cwd. — `judgment`: follows from one row per group; confirm by reading the diff
- [x] The inspector shows a "group of N" member line, the row shows a ×N count, and the port hint lists the union of member ports. — 👁️ popover visual check
- [x] SPEC.md §Classification/§Kill Flow and CLAUDE.md conventions describe the tree collapse. — `grep -q "collapseTrees" SPEC.md CLAUDE.md`
- [x] Build clean and full suite green. — `make test`

## 🧩 Subtasks

- [x] Core: `ProcessItem.members` (default `[]`) + `ScanCore.collapseTrees(_:)`, which replaces `collapseWrappers` (launcher detection = npm/npx wrapper ∪ `sh|bash|zsh -c` ∪ `uv run`; docker excluded; max tier; summed resources)
- [x] Core: `enumerate` moves the dismissed-PID filter after the collapse
- [x] Core: `KillCore.kill` runs the root, then leftover members concurrently; pure `KillCore.groupOutcome(root:members:)`
- [x] Core: `Killability.groupOwnerUID(_:currentUID:)`, used by `ScanEngine.killability` and CLI `clean`
- [x] App: MenuBarView ×N count, "group of N" inspector line, member-port union in the hint and filter
- [x] Tests: rewrite `ScanCoreWrapperCollapseTests` → `ScanCoreTreeCollapseTests`; add group-outcome and groupOwnerUID tests
- [x] Docs: SPEC.md + CLAUDE.md
- [x] `make test`, `make build-cli` + `pidlyse list` on the live table, then the popover visual check

## 🔗 Related

- [[PID-EPIC-62]] — parent epic (killability-truth)
- [[PID-039]] — npm-surface-dedup; `collapseWrappers` (the 1:1 case) is what this generalizes (`supersedes` its 1:1 guard)
- [[PID-62.2]] — respawn signatures, applied per logical group here
- [[PID-62.3]] — killability overlay; the group-owner fold feeds it
- [[PID-62.5]] — next child: per-row kill lifecycle UX consumes the group outcome

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** The live `pidlyse list` (2026-09-23) still shows redundant rows for one logical unit: `sh -cu cd frontend && npm run dev` + merged npm/vite (bidviz, marscharts); `sh -cu` → `uv run uvicorn` → python uvicorn (3 rows); merged `next dev` + `next-server` (+ turbopack `pool_entry` node, 3 rows); merged wrangler + wrangler-dist node; `uv run pytest` + python pytest. PID-039 only folds an npm/npx wrapper with exactly one direct scanned child.

- [x] Read relevant source files — `ScanCore.swift` (enumerate, collapseWrappers, riskTier), `ProcessItem.swift`, `AncestryResolver.swift`, `KillCore.swift`, `KillService.swift`, `Killability.swift` (derive/isForeignOwned), `ScanEngine.swift` (scan pipeline, record, killability, signature), `MenuBarView.swift` (row, reasoningBlock, grouped, filter), CLI `main.swift` (runScan, killAll, clean), SPEC.md §Classification/§Kill Flow

- [x] **Best Practices Review** — Grouping is scan + classification logic, so it lives in `ScanCore` (CLAUDE.md: don't scatter). It generalizes `collapseWrappers` in place rather than adding a second collapse pass (DRY). Group kill lives in `KillCore`, so the CLI inherits it with no pipeline change (parity by construction). The group owner-uid fold is one core helper shared by app and CLI. The view only renders. Dependencies still point one way: app → core.

- [x] **Archive skim** — PID-039 (1:1 npm collapse: root identity + child label; its 1:1 guard is superseded here, and its "kill root, subtree dies" assumption fails for `sh -cu` roots). PID-62.1 (constitution principle 4 "one logical unit, one row"; .4 spec: group kill, expandable members, counted once, per-group signatures). PID-62.3 (killability overlay, `isSweepable` SSOT). PID-051 (Chrome churn under playwright-mcp). PID-52.2 (AncestryResolver is for the inspector's full chain and isn't needed for grouping; the scanned-set ppid link is enough).

- [x] **Drift check** — Cited paths exist. The PLAN line says "extends PID-039 npm-surface-dedup + AncestryResolver"; the grouping needs only the scanned-set ppid linkage, so AncestryResolver stays untouched. That is a narrowing and doesn't change scope. Live observation: Chrome helpers under `--isolated` playwright-mcp don't match `.chromeHelper` today (no `ms-playwright-mcp` in their args), so the Chrome-brood fold only applies when they are scanned. Out of scope to change detection. No SPEC contract conflict: two buckets and grace period preserved, group is a row not a bucket.

- [x] Asked clarifying questions — AskUserQuestion, 3 resolved: (1) group kill = **root, then leftovers** (per-member identity guard, confirmed only if all gone); (2) group tier = **most cautious member**; (3) members UI = **inspector line** + ×N count, no per-member kill.
  Assumptions: fold on direct scanned-parent links only (no walking through unscanned intermediates); docker never groups (epic scope, [[PID-063]]); a dismissed row dismisses the whole group.

- [x] Subtasks above populated with concrete, ordered steps, and YAML `touches:` declared

**Discovery Notes:**

- Live trees (ps ancestry): `just dev` → `sh -cu cd frontend && npm run dev` (scanned .npm) → `npm run dev` → `node .bin/vite`; `sh -cu` → `uv run uvicorn` → `.venv/bin/python uvicorn`; `npm run dev` → `node next dev` → `next-server` → `pool_entry` node; `uv run pytest` → python pytest; playwright-mcp node → Chrome main → helpers.
- Representative (label) = first member in BFS order that isn't a launcher. Launchers: npm/npx wrapper (existing `isNpmWrapper`), `sh|bash|zsh -c…` shells, `uv run`. Results: sh→npm→vite labels as vite; sh→uv→python labels as the python uvicorn; next groups label as `next dev`.
- Existing test changes by design: "wrapper with two scanned children unchanged" and "non-wrapper parent unchanged" both become merges under the generalized rule.
- Side finding (not in scope): Claude Code's own `/bin/zsh -c source …shell-snapshot…` processes classify as `.npm` (the snapshot text contains `npm`), which is a false positive. Candidate follow-up.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — Generalized PID-039's `collapseWrappers` in place as `collapseTrees`: same pure post-filter inside `enumerate`, same root-identity / representative-label merge. `ProcessItem.members` is a plain additive field, not a new type. Group kill extends `KillCore.kill`, so the app wrapper and CLI `killAll` get it for free. The owner fold lives with its sibling predicate in `Killability`.

- [x] **Minimal refactor gate** — Only in-scope refactors: `collapseWrappers` → `collapseTrees` (superseded, not duplicated), the dismissed-filter move (a group must dismiss as a unit), and the disabled-kinds move (review finding #2). `RiskTier` gained a synthesized `Comparable` for the max-tier fold. Deferred: the Chrome `--isolated` detection gap and the Claude shell-snapshot `.npm` false positive (Discovery side findings).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `ProcessItem.swift`: `members: [ProcessItem]` (default `[]`); `RiskTier: Comparable`.
- `ScanCore.swift`: `collapseTrees` plus `belongsWithParent` (parent is a launcher ‖ same kind ‖ child is a Chrome helper ‖ child is a `.node` worker under a non-node parent) plus `isLauncher` (npm/npx ∪ `sh|bash|zsh -c` ∪ `uv run`). BFS members; representative = first non-launcher; max tier; summed CPU/RSS. Docker excluded. In `enumerate`, disabled kinds now filter before the collapse and dismissals after.
- `KillCore.swift`: `kill` runs the root, then `concurrentPerform` over the members (each through `killPosix` with its own identity guard); an `.unkillable` root short-circuits. The pure `groupOutcome` folds the answers.
- `Killability.swift`: `groupOwnerUID` (first foreign member, else the root uid). Used by `ScanEngine.killability` and CLI `commandClean`.
- `MenuBarView.swift`: ×N count next to the PID, "group of N — PID … · …" inspector line, `listeningPorts(_:)` union used by both the port hint and the quick-filter.
- Unchanged, but consuming one row per group: `sweepableSafeItems`, `cleanAllSafe`, `recordCleaned`/clean log, `signature(for:)` (representative command + root cwd), `ScanHistory`, notifications.
- Downstream-impact scan: the group outcome is what PID-62.5's per-row lifecycle consumes. That's additive, and its PLAN line still holds, so no reconcile edit.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] **Verification receipt** — see Testing Notes

- [x] **External review** — `/code-review medium` on the working-tree diff; 3 findings, see Testing Notes

- [x] (frontend) Asked the user for visual confirmation (emphasized `👁️ **CONFIRM**` ask on its own line) — operator: "good"

**Choosing a test strategy:** see SPEC.md §"🧪 Phase 3: Testing & Linting".

**Testing Notes:**

- `make test` → 0 (290 tests, 0 failures; first run after the review fixes had 2 failures in `testCollapse_tierIsMostCautiousMember`, whose fixture paired unrelated kinds that no longer link, so it was re-fixtured to a same-kind pair)
- `make test 2>&1 | grep warning: | grep -v onChange/deprecated` → no new warnings
- `make build-cli && pidlyse list` → live table: bidviz vite (sh → npm → vite), bidviz uvicorn (sh → uv → python, 3→1), bidviz pytest (uv → python), the three Next.js trees (incl. turbopack `pool_entry`), and wrangler are each one row; playwright-mcp rows unchanged (1 per instance)
- `grep -q "collapseTrees" SPEC.md CLAUDE.md` → 0
- Quality: `collapseWrappers` fully removed (no dead code); new public surface = `members`, `collapseTrees`, `groupOutcome`, `groupOwnerUID`, each with a consumer + tests
- External review (`/code-review medium`, working-tree diff):
  1. **blocker**: any scanned child folded into any scanned parent, so a `node`-run agent CLI would swallow its MCP servers (tier escalation, kill hits the live agent). **Fixed:** `belongsWithParent` link rule + `testCollapse_agentNodeParent_doesNotSwallowMCPChildren`, `testCollapse_nodeWorkerUnderFrameworkServer_folds`. Phase 3 re-ran from the top.
  2. **note**: disabled kinds judged only on the representative. **Fixed:** filter per process before the collapse + `testEnumerate_disabledKind_filtersPerProcessBeforeCollapse`.
  3. **note**: group kill kept going after an `.unkillable` root, and a foreign member marked a dead root unkillable. **Fixed:** root short-circuit; a member that is `unkillable` after the root died reports `.survived` (tests updated).
  - Remark (not graded): with many surviving members, `concurrentPerform` is bounded by core count, so each batch pays its own 2 s grace. Accepted: members normally die with their root and return at once.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep**. `README.md`: updated, with a new "One row per logical process" feature bullet. `AGENTS.md`: no change (flowtron block + project guide unaffected). `CLAUDE.md`: updated, with a new tree-grouping convention bullet. `SPEC.md`: updated, with §Classification "Tree collapse" and §Kill Flow step 5 (group kill, renumbered 6–7). `.flowtron/PLAN.md`: PID-62.4 flipped to stub, kept nested under PID-EPIC-62.

- [x] Closed — Acceptance ticked, status `completed`, PLAN stub nested under the active epic, moved to `archive/pid/`

- [x] **Evidence-based recap** drafted — see Final Summary

- [x] **Learnings** — Already in CLAUDE.md (the grouping SSOT bullet). The broader lesson, that being in the scanned set doesn't mean a parent and child die together, is written into the `belongsWithParent` doc comment and SPEC. Nothing more for AGENTS.md.

**Final Summary:**

Chains of processes that live and die together now surface as one row. `ScanCore.collapseTrees` generalizes PID-039's 1:1 npm merge: it follows any depth and fan-out, but a child only links to its parent through `belongsWithParent` (launcher parent, same kind, Chrome helper, or a node worker under a framework server). The row keeps the root's identity, the representative's label, the most cautious tier, and summed resources, with the other processes on `ProcessItem.members`. `KillCore.kill` kills the root, then any survivors concurrently with per-member identity guards, and `groupOutcome` folds the results (an unkillable root short-circuits; a surviving or foreign member → survived). `Killability.groupOwnerUID` feeds the app overlay and CLI `clean`. Disabled kinds filter per process before the collapse; dismissals after. The popover shows a ×N count, a "group of N" inspector line, and the union of member ports.

- Verification: `make test` 290/290, no new warnings. Live `pidlyse list` collapses the uvicorn chain 3→1, the Next.js / vite / pytest / wrangler chains to 1 row each, and leaves playwright-mcp rows unchanged. Operator visual confirm: "good".
- External review: 1 blocker (an agent `node` parent would swallow its MCP children), fixed with the link rule + tests. 2 notes (disabled-kinds semantics, unkillable fold), both fixed.
- `touches:` reconciliation: every declared path was edited. Undeclared: `README.md` (doc-drift) and `.flowtron/PLAN.md` + this tasknote (closure). `AncestryResolver.swift` stayed untouched, as scoped in Discovery.
- Deferred side findings: Chrome helpers under `--isolated` playwright-mcp go undetected; Claude Code `zsh -c` shell-snapshot processes misclassify as `.npm`.

**Archived:** 2026-09-23
