---
title: kill-feedback-stability
status: completed
tags: []
created: 2026-09-23
due:
related-tasks: [PID-EPIC-62, PID-62.2, PID-62.3, PID-62.4, PID-051]
touches:
  - Packages/PidlyseCore/Sources/PidlyseCore/KillFeedback.swift
  - Packages/PidlyseCore/Sources/PidlyseCore/RespawnHistory.swift
  - Packages/PidlyseCore/Sources/PidlyseCLI/main.swift
  - Pidlyse/ScanEngine.swift
  - Pidlyse/MenuBarView.swift
  - Pidlyse/AppDelegate.swift
  - Pidlyse/PidlyseApp.swift
  - PidlyseTests/ScanEngineTests.swift
  - SPEC.md
  - CLAUDE.md
  - README.md
---

# PID-62.5 | kill-feedback-stability

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-62]]

## 🎯 Goal

Make a kill narrate what actually happened: each killed row walks "killing… → gone / respawned / didn't die / can't kill / skipped" from the verified `KillOutcome` + the post-kill respawn check, Clean all (popover, URL scheme, Shortcuts, CLI) reports an honest breakdown, and the scan pipeline stops dropping post-kill rescans or republishing dismissed/killed rows.

## ✅ Acceptance

- [x] New pure `PidlyseCore/KillFeedback.swift`: `KillPhase` (from a `KillOutcome`, plus `.killing` / `.respawned`, one label each) and `KillReport` (per-outcome counts, respawned ⊆ killed, reclaimed KB from rows that stayed gone, one summary line). — `make test` (`KillFeedbackTests`)
- [x] One engine kill path: `ScanEngine.kill(_:completion:)` sets `.killing`, records outcomes (clean log + respawn arming unchanged), rescans, checks respawn against the pre-kill baseline, and returns a `KillReport`. Row ✕, ⌘⌫, popover Clean all and `cleanAllSafe` all call it. — `judgment`: read the diff; `grep -c "KillService.kill" Pidlyse/MenuBarView.swift` → 0
- [x] Kill state is keyed by pid + scan-time start time, survives intervening scans, and clears ~3 s after its final phase. A row that is killing or just killed isn't sweepable. Verified-gone rows linger ~3 s as a dimmed "gone" / "respawned" row before they're removed. — `👁️` popover check: **confirmed** with dummy strays (operator saw `killing…` → green `gone`; respawner → new 🔄 row; a sibling keeps its ✕)
- [x] Popover Clean all shows the report as an inline line under the Safe header for ~8 s. The `pidlyse://clean` notification and the Shortcuts dialog use the same `KillReport` line. CLI `clean` prints per-row phase labels and the same summary line (no respawn count: the CLI has no session memory). — `make test` + `make build-cli` → 0. The popover Clean-all line was **not visually confirmed** (the operator killed the aging dummies individually). It is covered by `KillFeedbackTests` and the same `engine.kill` path the confirmed single-row kills use.
- [x] Stability: (a) a `scan()` requested while one is in flight queues one follow-up scan instead of being dropped, and completions wait for a scan that started after the request; (b) dismissed PIDs are filtered again at publish. — `judgment`: read the diff (engine timing isn't unit-testable without an injectable scanner)
- [x] SPEC.md §Kill Flow, CLAUDE.md conventions, README describe the lifecycle and the report. — `grep -q "KillReport" SPEC.md CLAUDE.md`
- [x] Build clean and full suite green. — `make test`

## 🧩 Subtasks

- [x] Core: `KillFeedback.swift` (`KillPhase`, `KillReport`) + tests
- [x] Engine: scan coalescing + completions; dismissed re-filter at publish
- [x] Engine: `killStatuses` (pid → startTime, phase, token), `killPhase(for:)`, `departedItems` ghosts, `kill(_:completion:)` with respawn baseline; `isSweepable` excludes in-flight rows; `cleanAllSafe` → `KillReport`; notification text
- [x] View: row ✕ / ⌘⌫ / Clean all → `engine.kill`; phase label in place of ✕; ghost rows merged into the render; inline report line
- [x] Headless: `PidlyseApp` intent dialog + AppDelegate notification on `KillReport`
- [x] CLI: `commandClean` per-row labels + `KillReport` line
- [x] Docs: SPEC.md, CLAUDE.md, README.md
- [x] `make test`, `make build-cli`, `make build-release`; 👁️ popover check

## 🔗 Related

- [[PID-EPIC-62]] — parent epic (killability-truth)
- [[PID-62.2]] — verified `KillOutcome` + `RespawnHistory` (respawn signal consumed here)
- [[PID-62.3]] — killability overlay + `isSweepable` SSOT (extended to exclude in-flight rows)
- [[PID-62.4]] — group kill outcome (one row, one outcome)
- [[PID-051]] — kill-rescan churn evidence; post-kill rescan timing

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Terminal implementation child of an active epic. Its inputs all exist at HEAD: `.survived` / `.unkillable` outcomes, `RespawnHistory.respawnCount`, and the group outcome. The popover still does fire-and-rescan (`KillService.kill { record; scan() }` at three call sites), and every Clean-all summary reports only `cleaned of requested`.

- [x] Read relevant source files: `ScanEngine.swift`, `KillService.swift`, `MenuBarView.swift` (full); `RespawnHistory.swift` + `KillCore.KillOutcome` (API); `PidlyseApp.swift` (intent), `AppDelegate.swift` (URL clean), CLI `main.swift` (`commandClean`, `commandKill`), `CLICore.formatRSS`

- [x] **Best Practices Review**: The outcome→phase mapping, its labels, and the report aggregation are pure, so they go in core (`KillFeedback.swift`). That follows the `Killability.explanation` "one sentence, one home" precedent, and gives the popover, notification, Shortcuts and CLI one source. The kill orchestration moves out of the view into the engine: there are three duplicated `KillService.kill { record; scan }` bodies in `MenuBarView` plus `cleanAllSafe`, and they collapse to one `ScanEngine.kill`. The view keeps only rendering. `CleanSummary` is replaced by `KillReport` rather than kept alongside it. Dependencies still point app → core.

- [x] **Archive skim**: PID-051 (post-kill rescan lands ~2 s after the click, inside Chrome teardown, so respawns show on a *later* scan. The immediate check catches fast respawns; slower ones still reach the row via .3's badge). PID-62.2 (respawn = same signature under a new identity within 300 s; one watch per kill; `respawnCount` is the delta source). PID-62.3 (`isSweepable` SSOT; `record(_:outcome:)` single hook; `.unkillable` remembered). PID-62.4 (a group reports one outcome keyed by root pid). PID-58.2 (`cleanAllSafe` is the shared headless layer; `CleanSummary` consumers: AppDelegate notification + `CleanSafeStraysIntent`).

- [x] **Drift check**: No drift. PLAN line's "driven by .2 verification" holds (`KillOutcome` has confirmed/survived/unkillable/notKilled). "Stale rows" and "scan churn" are not code-cited in the line; Discovery found the concrete causes (below). No SPEC contract conflict: grace period, two buckets, explicit-action-only all untouched.

- [x] Asked clarifying questions: AskUserQuestion, 4 resolved:
  1. Gone row → **linger ~3 s** dimmed as "gone", then removed.
  2. Clean-all summary → **inline line under the Safe header**, ~8 s.
  3. Headless → **all three** (URL notification, Shortcuts dialog, CLI `clean`) share the core `KillReport` line. The CLI reports no respawns.
  4. Stability → **all three**: coalesce dropped rescans; re-filter dismissals at publish; key kill state by pid + start time so it survives scans.

- [x] Subtasks above populated with concrete, ordered steps, and YAML `touches:` declared

**Discovery Notes:**

- **Stale-row root cause:** `ScanEngine.scan()` returns immediately while `isScanning`. The popover's `onAppear` scan, the 120 s timer, and a second kill completing can all be in flight when a kill completes. When that happens the post-kill `scan()` is dropped, and the in-flight scan (enumerated *before* the death) republishes the killed row. The row then stays until the next timer tick (up to 120 s).
- **Dismiss race:** `scan()` snapshots `dismissedPIDs` at start. A row dismissed during the scan is republished by it.
- **Respawn attribution:** `record(.confirmed)` arms the watch. The next scan's `recordRespawnHistory` consumes it on a match. The per-kill "respawned" verdict = `respawnCount(signature)` after the follow-up scan > the count captured before arming. The signature is captured at the kill hook, while `cwds` still holds the pre-kill entry.
- **Phase vocabulary:** `.confirmed` → gone, `.survived` → didn't die, `.unkillable` → can't kill, `.notKilled` → skipped (the identity guard refused because the PID was reused). Plus `.killing` (in flight) and `.respawned` (gone, then came back).
- **Reclaimed:** only rows that stayed gone count. A respawned process's memory came right back.
- Assumption: the immediate post-kill rescan is the respawn check window for *feedback*. A later respawn isn't narrated on the ghost row (it has expired by then), but still surfaces as .3's respawner badge on the new row.

Discovery surfaced no significant deviation → skip 🛠️ (clarifications stay inside the PLAN line's scope: lifecycle, honest summary, targeted stability fixes).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey**: `KillFeedback.swift` follows the `Killability` shape. The pure vocabulary lives in core with its one label/detail string per case, the engine folds in the impure facts (outcomes, respawn counts), and the view only renders. The engine's `kill(_:completion:)` extends the PID-58.2 `cleanAllSafe` action layer (engine-owned orchestration) to every trigger, rather than adding a fifth call site in the view. `KillReport` replaces `CleanSummary` (a superset), and the two don't coexist.

- [x] **Minimal refactor gate**: Two refactors, both in scope. (1) Four duplicated `KillService.kill { recordCleaned; scan() }` bodies (three in `MenuBarView`, one in `cleanAllSafe`) collapse into `ScanEngine.kill`. The lifecycle would otherwise have had to be written four times. The public `recordCleaned` overloads became unused outside the engine: the single-item one was removed and the batch one made private. (2) `CleanSummary` → `KillReport` (acceptance). No unrelated cleanup.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `KillFeedback.swift` (new): `KillPhase` (6 cases, `init(KillOutcome)`, `label`, `detail`, `isDeparted`), `KillReport` (counts, `reclaimedKB` from `.gone` only, `headline` / `details` / `summaryLine`, formatted with `CLICore.formatRSS`).
- `ScanEngine.swift`: `scan(then:)` queues one follow-up scan plus completions instead of dropping a request; dismissals are re-applied at publish. Adds `killStatuses` (pid → startTime, phase, token), `departedItems`, `killPhase(for:)`, `kill(_:completion:)` (signature + respawn baseline captured before `recordCleaned` arms the watch, respawn check after the follow-up scan, 3 s linger clear gated by token). `isSweepable` excludes rows with a phase. `cleanAllSafe` → `kill(sweepableSafeItems)`. The notification uses `headline` / `details`.
- `MenuBarView.swift`: ✕ / ⌘⌫ / Clean all → `engine.kill`; `killPhaseLabel` (spinner while killing, colored verdict, `detail` tooltip) in place of ✕; departed rows at 0.5 opacity; `safeRows` / `reviewRows` merge the lingering rows into the render only; 8 s inline `summaryLine` under the Safe header.
- `PidlyseApp.swift` (intent dialog → `summaryLine`, `import PidlyseCore`), `AppDelegate.swift` (renamed closure param), `KillService.swift` (doc line), CLI `commandClean` (per-row phase label + `summaryLine`).
- Downstream-impact scan: the CLI summary text changed (`Cleaned X/Y` → `Cleaned X of Y · …`). Nothing parses it: `integrations/` and the README were grepped. Remaining PLAN entries: `.N` audit (unaffected, will sweep these docs), PID-030 / PID-063 unaffected. No reconcile edits.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] **Verification receipt**: see Testing Notes

- [x] **External review**: `/code-review medium` on the working tree, three passes. Pass 1 found 1 blocker and pass 2 found 2 blockers, all fixed, each followed by a Phase 3 re-run. Pass 3 found 2 notes, filed as PID-069. See Testing Notes.

- [x] (frontend) Asked the user for visual confirmation (emphasized `👁️ **CONFIRM**` ask on its own line): confirmed with harmless dummy strays (`sleep` renamed via `exec -a`, plus a restart-loop supervisor), with `ps` checked against the popover. Stays-dead → `killing…` → green `gone`, then the row left. One of two identical siblings killed → gone, and the twin kept its ✕. The respawner came back under a new PID with the 🔄 badge. The Clean-all line was not seen (the operator killed the dummies individually). Operator feedback filed as [[PID-070]]: PID wraps / `81,113` grouping, identical rows indistinguishable, 🔄 badge reads as a button.

**Choosing a test strategy:** see SPEC.md §"🧪 Phase 3: Testing & Linting".

**Testing Notes:**

- `make test` → 0 (301 tests, 0 failures: 290 before this task, +9 `KillFeedbackTests`, +2 `RespawnHistoryTests`)
- `make test 2>&1 | grep warning:` on the changed files → no warnings
- `swift build --package-path Packages/PidlyseCore` → 0; `make build-cli` → 0; `make build-release` → BUILD SUCCEEDED
- `grep -c "KillService.kill" Pidlyse/MenuBarView.swift` → 0
- `grep -q "KillReport" SPEC.md CLAUDE.md` → 0
- Quality: four duplicated kill bodies collapsed into `ScanEngine.kill`. `CleanSummary` removed (superseded by `KillReport`). The single-item `recordCleaned` was removed because this diff left it unused. New public surface is `KillPhase` + `KillReport` only, both tested. Stale doc lines fixed: `KillService` header, `recordCleaned` / `armRespawnWatch` contracts, `RespawnHistory` watch docs, the SPEC respawn definition.
- External review (`/code-review medium`, working tree):
  1. **blocker** (pass 1): `RespawnHistory` counted any same-signature process under a new identity, including a sibling already running at kill time. Now load-bearing for the verdict, so killing one of two identical `node server.js` read "respawned". **Fixed:** a respawn must have started at or after the kill began, and an unknown start time never counts. The engine passes the kill-start time. Tests: `testRespawn_siblingAlreadyRunningAtKillTime_isNotCounted`, `testRespawn_unknownStartTime_isNotCounted`, with fixtures re-dated.
  2. **blocker** (pass 2): signatures and clean-log labels were built from `cwds` after the ≥ 2 s kill, so an intervening scan could strip the cwd and a real respawn read "gone". **Fixed:** the cwd is snapshotted in `kill` before signalling and threaded through `record` / `armRespawnWatch` / `makeCleanEvent`.
  3. **blocker** (pass 2): two same-signature targets in one Clean all were both marked respawned off one count rise. **Fixed:** each rise per signature is claimed by one row.
  4. **note** ×2 (pass 3): the same two gaps across *separate* kill calls within ~2 s (shared baseline; watch overwrite hides an earlier respawn). Both stem from one watch per signature. **Filed:** [[PID-069]] (Low, `aa537c9`).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep**: `README.md` updated (new "Honest kill feedback" bullet). `AGENTS.md` no change (project guide + flowtron block unaffected). `CLAUDE.md` updated (`ScanEngine.kill` / `KillFeedback` convention in the clean-log bullet). `SPEC.md` updated (Project Structure `KillFeedback.swift`; Kill Flow step 6 coalescing, step 7 lifecycle, Clean-all `KillReport`; respawn definition "started after the kill began"; CLI `clean` row). `.flowtron/PLAN.md` PID-62.5 flipped to stub, nested under PID-EPIC-62; PID-069 / PID-070 filed earlier (`aa537c9`, `ac1b488`).

- [x] Closed — every `## ✅ Acceptance` criterion ticked or explicitly annotated (`N/A` / not-met with a one-line reason), YAML `status:` flipped to `completed`, PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` and placed (standalone → top of `## Completed`; epic child → kept nested beneath its active parent — see SPEC/plan-filing.md §"`## Completed` archive convention" if unclear), then tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] **Evidence-based recap** drafted — changed files/LOC where meaningful, verification commands/results, refactors made or deferred with rationale, documentation verdict, the `touches:` scope reconciliation (`git diff --name-only` vs declared; name undeclared paths), and concrete maintainability effect (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

- [x] **Learnings**: One lesson, already carried in the CLAUDE.md bullet and the `RespawnHistory` doc comments. A signal that was advisory becomes load-bearing once it drives a verdict, so its false positives need re-auditing when that happens. Here, same-signature siblings counted as respawns. Nothing more for AGENTS.md.

**Final Summary:**

A kill now reports what actually happened. Every trigger (row ✕, ⌘⌫, Clean all, `pidlyse://clean`, Shortcuts) goes through one `ScanEngine.kill`. It marks rows `killing…`, records the verified outcomes, rescans, and relabels a verified death as `respawned` when the same signature came back under a new process started after the kill. It returns a `KillReport`. The core `KillFeedback.swift` (`KillPhase` + `KillReport`) gives the popover, notification, Shortcuts dialog and CLI the same labels and summary line. Stability: a `scan()` requested mid-scan now queues a follow-up instead of being dropped (the stale-row cause), dismissals are re-applied at publish, and kill state is keyed by pid + start time so it survives intervening scans.

- Changes: 12 files, +520/−125. New `KillFeedback.swift` (110). `ScanEngine.swift` (+259/−) holds the kill lifecycle, scan coalescing, and the cwd snapshot. `MenuBarView.swift` has the phase label, lingering rows, and the report line. `RespawnHistory.swift` requires respawns to start after the kill. The CLI, intent, and AppDelegate adopt `KillReport`. Docs: SPEC / CLAUDE / README.
- Verification: `make test` 301/301 (+11), no new warnings; `make build-cli`, `make build-release` clean; operator visual check with dummy strays, cross-checked against `ps`. The Clean-all line was not seen on screen (unit-tested; same path).
- External review: 3 passes. 3 blockers fixed (sibling counted as a respawn; post-kill cwd loss; double attribution within one batch). 2 notes filed as [[PID-069]].
- Refactors: four duplicated kill bodies → `ScanEngine.kill`; `CleanSummary` → `KillReport`; single-item `recordCleaned` removed. Deferred: [[PID-069]] (per-identity respawn watches, which also stops the respawner badge spreading to identical siblings), [[PID-070]] (row legibility).
- `touches:` reconciliation: every declared path was edited. Undeclared: `Pidlyse/KillService.swift` (one doc line) and `.flowtron/PLAN.md` + this tasknote (closure).
- Maintainability: one kill path instead of four, and one outcome vocabulary across four surfaces, so the popover, notification, Shortcuts and CLI can't drift apart.

**Archived:** 2026-09-24
