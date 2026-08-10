---
title: honest-unkillable-ux
status: blocked
tags: []
created: 2026-08-08
related-tasks: [PID-EPIC-62, PID-62.1, PID-62.2, PID-62.5]
---

# PID-62.3 | honest-unkillable-ux

[← PLAN.md](../PLAN.md) · ⏸ Blocked · 🔗 [[PID-EPIC-62]] [[PID-62.1]] [[PID-62.2]] [[PID-62.5]]

> **⏸ Parked 2026-08-10** at the Phase 3 visual-confirmation step, by operator
> request (not a code blocker). Implementation is complete and green: 271/271
> tests, core + CLI + Release app all build clean. **Everything below is
> uncommitted working-tree state.** What remains: the 👁️ visual confirmation
> (see Testing Notes for exactly what to look at), then Phase 4 closure.

## 🎯 Goal

Stop offering a kill button on rows Pidlyse cannot actually kill: foreign-owned (EPERM) processes and detected respawners get an explicit state, an explanation in place of the button, and an inspector reasoning line — as an overlay on the existing two buckets, never a third bucket.

## ✅ Acceptance

- [ ] `KillCore.KillOutcome` gains `.unkillable` — EPERM split out of `.notKilled`, which keeps its "identity guard refused" meaning. The one exhaustive CLI `switch` reports it honestly; clean-log honesty unchanged (still `.confirmed` only).
- [ ] Foreign ownership is known **before** a click: `ProcessItem` carries the owning `uid`, resolved at scan time from the `kinfo_proc` read `KillCore` already performs (new injectable `uidProvider`, `nil`-defaulted — `ps` column layout untouched).
- [ ] New pure `PidlyseCore/Killability.swift`: `Killability` (`killable` / `unkillable` / `respawner`), the foreign-owner predicate, the "managed by X" attribution, and the one-per-state explanation sentence — unit-tested, with the sentence living in exactly one place so tooltip and inspector can't drift.
- [ ] `ScanEngine` folds the signals into `killability(_:)` (uid check **or** a session-remembered EPERM outcome; respawn from [[PID-62.2]]'s `isRespawner`) and remembers `.unkillable` outcomes at the existing kill hook.
- [ ] Overlay, not a bucket: `riskTier` / `bucket` are untouched; affected rows stay listed in their section, show a badge + explanatory tooltip where ✕ was, and carry the explanation as an inspector reasoning line beside the idle-dev-server line.
- [ ] Unkillable / respawner rows are excluded from the sweep set (`Clean all`, ⌘⌫, the section count and reclaimable total) via one engine-side `isSweepable(_:)` SSOT shared with the popover — same overlay shape 🔒 protection established in PID-54.4.
- [ ] `make test` green; `make build-cli` builds; visual confirmation of the two new row states.
- [ ] Docs updated: `SPEC.md` (§Project Structure, §Classification overlay, §Kill Flow outcomes), `CLAUDE.md` conventions, `README.md` foreign-owner bullet.

## 🧩 Subtasks

- [ ] `KillCore`: add `.unkillable`, return it on the EPERM branch, add `ownerUID(of:)` on the shared `procInfo(of:)`; update the CLI `switch`
- [ ] `ProcessItem`: add `uid: uid_t?` (defaulted, so existing constructions are untouched); `ScanCore.enumerate`/`makeItem`: add the `nil`-defaulted `uidProvider`
- [ ] New `PidlyseCore/Killability.swift` — state enum, `isForeignOwned(uid:currentUID:)`, `manager(ancestors:containerOwner:)`, `explanation`
- [ ] `ScanEngine`: pass `KillCore.ownerUID` into the scan, remember `.unkillable` outcomes at the kill hook, expose `killability(_:)` + `isSweepable(_:)`, narrow `sweepableSafeItems`
- [ ] `MenuBarView`: badge + tooltip in place of ✕, inspector reasoning line, sweep-set filter delegated to `isSweepable`
- [ ] Tests in `PidlyseTests/ScanEngineTests.swift` — new `KillabilityTests` (state precedence, owner predicate, manager attribution, explanation text) + a `.unkillable` outcome case
- [ ] `make test` + `make build-cli`; 👁️ visual confirmation of both row states
- [ ] Docs: `SPEC.md`, `CLAUDE.md`, `README.md`
- [ ] Phase 4 closure (doc-drift sweep, PLAN stub flip nested under the parent, archive)

## 🔗 Related

- [[PID-EPIC-62]] — parent epic (killability-truth)
- [[PID-62.1]] — deep Discovery: constitution (kill button = a promise), clarification #2 (explanation replaces button), #3 (session-only respawn memory)
- [[PID-62.2]] — produces the signals this task surfaces: verified `KillOutcome`s + `ScanEngine.isRespawner(_:)`
- [[PID-62.5]] — consumes the same outcomes for the per-row kill lifecycle + honest Clean-all summary

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Third child of an active epic, and the one that pays out its constitution's first principle ("a kill affordance is a promise"). [[PID-62.2]] deliberately left both seams open for it — `isRespawner(_:)` is an unconsumed query at HEAD, and EPERM is still folded into `.notKilled` with a code comment naming this task as the splitter. Nothing upstream has shifted.

- [x] Read relevant source files — `KillCore.swift`, `RespawnHistory.swift`, `ScanCore.swift`, `ProcessItem.swift`, `AncestryResolver.swift` (full); `ScanEngine.swift`, `KillService.swift`, `MenuBarView.swift` (full); `PidlyseCLI/main.swift` (kill paths), `SPEC.md` §Kill Flow, `README.md` §Security

- [x] **Best Practices Review** — touched responsibilities: (a) `KillCore` owns kill semantics — splitting EPERM out sharpens an existing outcome rather than adding a responsibility; (b) *deriving* killability is new and pure → new `Killability.swift` in core, not logic smeared across `MenuBarView`; (c) `ScanEngine` keeps its established role as the impure folder of core signals (`isIdleDevServer` is the exact precedent). Dependency direction unchanged (core never imports app). Nearby duplication found: `MenuBarView.sweepableSafeItems` re-derives the engine's sweep predicate, and the new killability filter would have to be written twice — in-scope fix is one engine-side `isSweepable(_:)` both call, extending the PID-58.2 SSOT. Deferred cleanup: none surfaced.

- [x] **Archive skim** — grepped `archive/pid/` for `MenuBarView.swift` / `KillService.swift` / `KillCore.swift` (68 hits); load-bearing findings in Discovery Notes below (PID-54.4, PID-008, PID-55.3, PID-051, PID-50.7, PID-53.2)

- [x] **Drift check** — no drift. Every symbol this task builds on exists at HEAD: `KillCore.procInfo(of:)` (private, PID-62.2's DRY extraction — the uid read rides on it), the EPERM branch in `killPosix` returning `.notKilled`, `ScanEngine.isRespawner(_:)` / `isProtected(_:)` / `sweepableSafeItems` / `recordCleaned` (both overloads), `AncestryResolver.ancestorChain(ofPPID:in:)`, `MenuBarView.row(_:)`'s kill button + `reasoningBlock(item:isOld:)`. `KillOutcome` still has exactly one exhaustive `switch` in the tree (`PidlyseCLI/main.swift:165`).

- [x] Asked clarifying questions — **3 asked, 3 resolved** (table below). One answer widens scope beyond the PLAN line's literal reading; see the Phase 1→2 gate.

- [x] Subtasks above populated with concrete, ordered steps

**Clarifications:**

| # | Question | Resolution |
|---|----------|------------|
| 1 | How does a row become "unkillable" — reactively (EPERM threaded out of a failed kill) or proactively (owner known at scan time)? | **Both.** Scan-time owner check is the primary signal, the threaded EPERM outcome is the backstop. Widens scope past the PLAN line's "thread `KillCore` outcomes to UI", but delivers the constitution's principle 1 without a dead-end click first. |
| 2 | Should unkillable / respawner rows still be swept by "Clean all" / ⌘⌫? | **Exclude, like 🔒 protected.** Out of the sweep set, the section count, and the reclaimable total; still listed and badged in place. |
| 3 | What replaces the ✕ button? | **Badge + tooltip; detail in the inspector.** Row height unchanged; the full sentence renders in the ⓘ expansion beside the idle-dev-server line. |

**Discovery Notes:**

**Archive precedents (load-bearing):**

- **PID-54.4 protected-projects** — the exact overlay this task copies: a state that keeps a row *listed* in its section but out of "Clean all", the count, the reclaimable total, and ⌘⌫, rendered as a badge in the leading dot slot, computed view-side from a `@Published` map so it updates without a rescan. It also set the "engine-side predicate, view-side render" split (`ScanEngine.isProtected`) that `isSweepable(_:)` extends.
- **PID-008 / PID-55.3 inspector reasoning** — the ⓘ expansion is where per-row explanation belongs; PID-55.3's idle-dev-server line is the shape to match (rendered only when the signal fires, absent otherwise — graceful degrade, never touching the risk dot or the kill bar). The new killability line sits beside it.
- **PID-051 kill-rescan-flicker** — closed no-bug: the churn users see after killing a Chrome playwright-mcp helper is real teardown *and real respawn*. This task is where that observation finally reaches the user as words.
- **PID-50.7 ⌘⌫ shortcut** — reads `sweepableSafeItems`, so narrowing that one property covers the shortcut too; no separate guard needed.
- **PID-53.2 clean-log-store** — only `.confirmed` is logged. Adding a fourth `KillOutcome` case must not widen that; the guard stays an equality check against `.confirmed`.

**Design decisions (assumptions being asserted):**

1. **The uid comes from the sysctl read the scan already does, not from a new `ps` column.** `ScanCore.enumerate` already invokes a per-candidate `startTimeProvider` (`KillCore.startTime`), which reads a full `kinfo_proc`; the owning uid sits in the same struct. A `uidProvider` sibling costs one extra micro-syscall per candidate and leaves `parsePSLine`'s column layout — and its 23 test fixtures, and the CLI's identical pipeline — completely untouched. Adding a `uid=` column to `ps` was the alternative and was rejected on blast radius, not on principle.
2. **Unknown uid degrades to killable.** `uid == nil` (no provider injected — every existing unit test) means "we don't know", and the honest response to not knowing is to leave the button alone, exactly as `startTime == nil` leaves the identity guard permissive.
3. **`.unkillable` is a fourth outcome, not an associated value on `.notKilled`.** `notKilled` keeps precisely one meaning (the identity guard refused to signal anything); EPERM is a different fact about the world and deserves its own case. The CLI's single exhaustive `switch` is the only forced update.
4. **EPERM memory is engine-side, not a fifth core value type.** [[PID-62.2]]'s `RespawnHistory` earned a pure type because it holds *logic* (normalization, windows, matching). Remembering "this identity returned EPERM" is a set, not logic — a private `[Int32: ProcStartTime?]` in `ScanEngine`, identity-checked on read so a recycled PID doesn't inherit the state. The *derivation* that consumes it is pure and lives in core.
5. **Precedence: unkillable outranks respawner.** They are near-disjoint in practice (respawn detection requires a verified kill, which a foreign-owned process never gets), but the order is fixed so the state is a total function, and "we never got to kill it" is the more fundamental truth.
6. **One sentence, one home.** `Killability.explanation` is the single source for both the tooltip and the inspector line, so the two surfaces cannot drift — the same reason `ScanEngine.signature(for:)` exists.

**Downstream-impact scan:** the widened scope (decision 1) stays inside this task — `ProcessItem` gains an optional field and `enumerate` an optional provider, both additive and `nil`-defaulted, so [[PID-62.4]] and [[PID-62.5]] are unaffected as filed and the CLI pipeline needs no change. Other active PLAN entries: PID-030 (notarize, Future) unaffected; PID-063 (docker-scope trim, Future) is *supported* rather than contradicted — labeling root-owned Docker rows unkillable is evidence for that question, not a decision on it. **No reconcile edits.**

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `Killability` follows the pure-core / impure-engine / dumb-view split the codebase already runs three times (`ScanHistory` → `hasSustainedLowCPU`, `RespawnHistory` → `isRespawner`, `CwdResolver` → `isProtected`): pure derivation + presentation string in core, impure fact-gathering in `ScanEngine`, rendering in `MenuBarView`. The row surface extends PID-54.4's protected overlay rather than inventing a state model. `KillOutcome` gained a case in the shape PID-62.2 established. No new shape needed justifying.

- [x] **Minimal refactor gate** — two, both taken to prevent duplication the change would otherwise have introduced: (1) `ScanEngine`'s two `recordCleaned` overloads had already duplicated their per-item body, and adding the `.unkillable` arm would have duplicated it a third and fourth time → extracted `private func record(_:outcome:)`; (2) `MenuBarView.sweepableSafeItems` re-derived the engine's sweep predicate, and the killability filter would have had to be written in both → extracted `ScanEngine.isSweepable(_:)`, which both now call. No unrelated cleanup taken.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- **`KillCore.swift`** (+22/−9) — `KillOutcome.unkillable` split out of `.notKilled`, which keeps exactly one meaning (identity guard refused); the EPERM branch returns it; new public `ownerUID(of:)` riding on PID-62.2's `procInfo(of:)`, so the uid costs no new `sysctl` shape.
- **`ProcessItem.swift`** (+10) — `uid: uid_t?`, defaulted `nil` in the initializer so every existing construction (and all 23 `ps`-fixture tests) is untouched.
- **`ScanCore.swift`** (+13/−4) — `uidProvider` sibling to `startTimeProvider` on `enumerate` + `makeItem`, both `nil`-defaulted; `collapseWrappers` carries the wrapper's uid onto the merged row (identity comes from the wrapper root, and the owner is part of identity).
- **`Killability.swift`** (new, 108 lines) — the state enum, `isForeignOwned`, `ownerLabel`, `manager`, and `explanation`. Pure, no UI imports; SF Symbol names deliberately stay in the view.
- **`ScanEngine.swift`** (+58/−13) — `uidProvider: KillCore.ownerUID` into the scan, `killDeniedIdentities` session map + `currentUID`, the `record(_:outcome:)` extraction, `killability(_:)` (ancestor walk computed lazily — only respawner rows pay for it), `isSweepable(_:)`, narrowed `sweepableSafeItems`.
- **`MenuBarView.swift`** (+37/−9) — badge-instead-of-button in `row`, `killabilityBadge`, the inspector explanation line, `sweepableSafeItems` delegated to `isSweepable`.
- **`PidlyseCLI/main.swift`** (+12/−3) — the one exhaustive `switch` gains `.unkillable` with an honest message; `uidProvider` added for scan-pipeline parity; `commandClean` excludes foreign-owned rows so CLAUDE.md's "`clean` sweeps exactly the app's Clean-all set" stays literally true. The **respawn** half of the overlay stays app-only per [[PID-62.1]] clarification #4 (a one-shot CLI has no session memory to exclude from).
- **Deliberately out of scope:** the per-row kill *lifecycle* ("killing… → gone / didn't die") and the honest Clean-all outcome summary — both are [[PID-62.5]]'s stated deliverable. This task removes affordances and explains; it doesn't narrate kills in progress.
- **Downstream-impact reconciliation:** re-checked at execution time. The widened scope stayed additive (`nil`-defaulted field + provider), so no sibling child's PLAN line needs an edit, and PID-030 / PID-063 are untouched. No PLAN edits beyond this task's own line.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **271/271 passing, 0 failures** (250 pre-task; +21 new `KillabilityTests`)

- [x] Ran lint/type-check on changed code — the Swift compiler is the type-check (per `.flowtron/tasknote/README.md` §Project quick commands): `swift build --package-path Packages/PidlyseCore`, `make build-cli`, and `make build-release` all clean, no warnings. (SourceKit again reported phantom "No such module `PidlyseCore`" / "no member `unkillable`" diagnostics on the package sources mid-edit — the same stale-index artifact PID-62.2 recorded; all four real compilers disagree.)

- [x] **Quality assertions** — the two duplications the change would have introduced were extracted instead (`ScanEngine.record(_:outcome:)`, `ScanEngine.isSweepable(_:)`), so the diff leaves less repetition than it found. No dead code: every new symbol has a consumer in this same diff — including `Killability.isForeignOwned`, which both the app derivation and the CLI sweep filter call. Public-surface growth is one type (`Killability`), one `KillOutcome` case, one `ProcessItem` field, one `KillCore` function, one `ScanCore` parameter — each load-bearing and tested. The one non-obvious ordering decision (unkillable outranks respawner) carries its reason inline *and* a test pinning it. Code-facing docs updated in the same diff: `KillOutcome`'s doc comment, `KillCore`'s file header, `ScanCore.makeItem`'s + `collapseWrappers`' contract lines, `ScanEngine.recordCleaned`, both `sweepableSafeItems`.

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — **asked, awaiting the operator; this is the one open item.**

> **Choosing a test strategy (guidance, not a gate).** Default to targeted
> tests on the changed behavior. Where the input space is wide — parsers,
> encoders, round-trips, invariants that must hold across many inputs — a
> property-based test earns its keep; reach for one when example tests would
> leave large gaps. Visual confirmation covers UI surfaces that assertions
> can't. This is engineering judgment folded into Phase 3, never a new
> lifecycle phase or a schema/validator.

**Testing Notes:**

Test strategy: example-based. Both new surfaces are small total functions over a
handful of discrete inputs (a 5-fact derivation, three label helpers), not wide
input spaces, so example tests leave no meaningful gap and a property test would
add machinery without coverage. 21 cases across five groups — the foreign-owner
predicate (including the *negative* case that pins "unknown uid never removes an
affordance"), owner labels, respawn attribution precedence, state derivation
(including unkillable-outranks-respawner), the exact explanation strings for all
four states, and the scan plumbing that carries a uid onto a `ProcessItem`.

**The uid read was verified against the live kernel**, not merely assumed correct:
a throwaway script confirmed `kp_eproc.e_ucred.cr_uid` returns `0` for launchd,
`501` for self, and `nil` for a non-existent PID. Struct-offset bugs of that shape
are exactly what a green unit suite will not catch.

Not unit-tested, deliberately and consistently with the existing suite: the impure
`sysctl` read and the `ScanEngine` fold (the same exclusion `ScanHistoryTests` /
`RespawnHistoryTests` already document for their scan feeds).

### ⏸ Outstanding on resume — the 👁️ visual confirmation

`build/Release/Pidlyse.app` was built from this working tree and launched (the
stale Debug instance from DerivedData was quit first). If it is no longer running,
`make build-release && open build/Release/Pidlyse.app`. What to check:

1. **Processes** tab → **Needs review** → expand the **Docker** group (starts
   collapsed — it's high-risk tier). **PID 561** `com.docker.vmnetd` is root-owned
   (verified via `ps -o uid=`), so it should show the 🚫 `nosign` badge where ✕
   normally sits, with hover text *"unkillable — owned by root; Pidlyse never
   escalates"*, and the same sentence as a line in its ⓘ inspector. Every other
   Docker row on this machine is uid 501 and must keep a working ✕.
2. **"Safe to clean (N)"** count and the reclaimable total must exclude any badged
   row.
3. The respawner state (↻ `arrow.triangle.2.circlepath`, *"respawns — managed by
   …; kill won't stick"*) can't be staged on demand — it needs a verified kill that
   comes back inside the 5-minute window. The `playwright-mcp` rows are the
   likeliest candidates if you want to exercise it.

## 🚀 Phase 4: Closure

- [ ] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [ ] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` and placed per SPEC/tasknote-selection.md §"`## Completed` archive convention" (standalone → top of `## Completed`; epic child → kept nested beneath its active parent), then tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [ ] **Evidence-based recap** drafted — changed files/LOC where meaningful, verification commands/results, refactors made or deferred with rationale, documentation verdict, and concrete maintainability effect (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

**Archived:** YYYY-MM-DD
