---
title: respawn-detection-core
status: completed
tags: []
created: 2026-08-08
due:
related-tasks: [PID-EPIC-62, PID-62.1, PID-62.3, PID-62.5]
---

# PID-62.2 | respawn-detection-core

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-62]] [[PID-62.1]] [[PID-62.3]] [[PID-62.5]]

## 🎯 Goal

Make `PidlyseCore` able to tell the truth about a kill: verify the process is actually gone after the grace period, and detect the same logical process reappearing under a new PID (session-only respawn cache fed by `ScanEngine`).

## ✅ Acceptance

- [x] `KillCore.kill` reports `.confirmed` only when the process is **verified gone** after the grace period (absent / PID-recycled / zombie); a process still alive under the same identity after the SIGKILL fallback reports a new `.survived` outcome. Pure decision helper unit-tested.
- [x] New pure `PidlyseCore/RespawnHistory.swift`: session-only value type with command-signature normalization, windowed pending-kill records, and per-signature respawn counting — unit-tested (normalization, window expiry, new-PID match, same-identity non-match).
- [x] `ScanEngine` owns the single mutable `RespawnHistory`, feeds it each scan (mirroring `recordScanHistory`) and records verified kills at the existing kill-completion hook; exposes an `isRespawner(_:)` query.
- [x] Signal-only: the respawn cache never touches `riskTier` / `bucket` / the kill bar and adds no UI surface (`PID-62.3` / `PID-62.5` own the UX).
- [x] Clean-log honesty preserved and sharpened — only verified deaths are logged; `.survived` is excluded from the log and from the "reclaimed" figure.
- [x] `make test` green; `make build-cli` builds (CLI updated for the new outcome case; CLI respawn-awareness stays deferred per [[PID-62.1]] clarification #4).
- [x] Docs updated for the changed kill contract: `CLAUDE.md` conventions + `SPEC.md` §Kill Flow.

## 🧩 Subtasks

- [x] `KillCore`: extract the shared `sysctl` read, add the pure liveness/death decision helper, add the `.survived` outcome, verify after the grace period and after the SIGKILL fallback
- [x] Update `.survived` consumers (CLI `kill` command switch; app-side equality checks already exclude it)
- [x] New `PidlyseCore/RespawnHistory.swift` — `Signature` normalization, `recordingKill(...)`, `recording(_:at:)`, `respawnCount(for:)` / `isRespawner(_:)`, tunable detection window
- [x] Wire `ScanEngine` — the single `respawnHistory` instance, per-scan feed, verified-kill record at `recordCleaned`, `isRespawner(_:)` query
- [x] Tests in `PidlyseTests/ScanEngineTests.swift` — new `RespawnHistoryTests` class + `KillCore` verification-decision cases
- [x] Run `make test` + `make build-cli`
- [x] Docs: `CLAUDE.md` conventions paragraph + `SPEC.md` §Kill Flow
- [x] Phase 4 closure (doc-drift sweep, PLAN stub flip nested under the parent, archive)

## 🔗 Related

- [[PID-EPIC-62]] — parent epic (killability-truth)
- [[PID-62.1]] — deep Discovery: constitution, per-child spec, 4 resolved clarifications
- [[PID-62.3]] — consumes the respawn signal + `KillCore` outcomes for the honest-unkillable UX
- [[PID-62.5]] — consumes the verified outcome for the per-row kill lifecycle + honest Clean-all summary

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Foundation child of an active epic; [[PID-62.1]]'s spec for `.2` matches the PLAN line verbatim, and both `.3` and `.5` are written as consumers of the signals this task produces. Nothing upstream has shifted.

- [x] Read relevant source files — `KillCore.swift`, `ScanHistory.swift`, `ProcessItem.swift`, `CleanLog.swift`, `ScanEngine.swift`, `KillService.swift`, `PidlyseCLI/main.swift` (kill paths), `ScanCore.swift` (public surface), `SPEC.md` §Project Structure / §Kill Flow

- [x] **Best Practices Review** — touched responsibilities: (a) `KillCore` owns kill semantics; adding verification keeps that ownership and only sharpens what its existing `KillOutcome` means. (b) The respawn cache is a *new* responsibility → new file `RespawnHistory.swift`, mirroring `ScanHistory`'s pure-value-type / `ScanEngine`-owns-the-instance split rather than bolting state onto `ScanEngine`. Dependency direction unchanged (core ← app; core never imports app). One in-scope refactor identified: `KillCore.startTime(of:)` and the new liveness probe both need the same `sysctl` `kinfo_proc` read — extract a private `procInfo(of:)` rather than duplicate the six-line body. Deferred cleanup: none surfaced.

- [x] **Archive skim** — grepped `archive/pid/` for `KillCore.swift` / `ScanHistory.swift` / `KillService.swift` / `ScanEngine.swift`; load-bearing findings in Discovery Notes below (PID-051, PID-35.3, PID-53.2, PID-55.2, PID-57.2, PID-55.4/PID-061)

- [x] **Drift check** — no drift. Every path and symbol cited by the PLAN line and by [[PID-62.1]]'s spec exists at HEAD: `KillCore.kill/killPosix/startTime(of:)/shouldSendSIGTERM/shouldEscalateToSIGKILL`, `KillOutcome.confirmed/.notKilled`, `ScanHistory` (pure value type + `ScanEngine.scanHistory` single instance + `recordScanHistory` feed), `ScanEngine.recordCleaned` kill-completion hook, `ScanEngine.cwds`. `KillOutcome` has exactly one exhaustive `switch` in the tree (`PidlyseCLI/main.swift:165`).

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — **No clarifications needed.** [[PID-62.1]]'s deep pre-pass already resolved the four open questions (session-only memory, app-only, explanation-replaces-button, empirical target). Explicit assumptions listed in Discovery Notes.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Archive precedents (load-bearing):**

- **PID-051 kill-rescan-flicker** (closed no-bug) — the direct empirical evidence for this task: killing one Chrome playwright-mcp helper tears down the cohort and *"respawned helpers appear on a later scan"*. It also pins the timing this task must live inside — the post-kill rescan fires right after the grace period, so the very first rescan after a kill is where a fast respawn shows up.
- **PID-35.3 kill-path-hardening** — the identity guards (`shouldSendSIGTERM` pre-SIGTERM check, `shouldEscalateToSIGKILL` no-bystander check, scan-time `ProcStartTime` token) are non-negotiable. Verification is layered *after* them; neither guard changes.
- **PID-53.2 clean-log-store** — established that only `.confirmed` outcomes are logged so "RAM reclaimed" stays honest. This task sharpens what `.confirmed` means (verified gone, not merely signal-delivered), which strengthens that invariant rather than breaking it.
- **PID-55.2 scan-history-cache** — the exact template to mirror: pure `struct` with value semantics and a `recording(_:) -> Self` fold, tunable `default*` statics, PID+`ProcStartTime` identity key, session-only (no disk, because a stale sample is meaningless after a relaunch), single mutable instance owned by `ScanEngine`, fed once per scan in the main-queue publish block.
- **PID-57.2 kill-path-to-core** — why `KillCore` is synchronous and run-loop-free (the CLI consumes it directly). Any verification added must stay blocking-and-synchronous; no async/run-loop dependency.
- **PID-55.4 / PID-061** — `SPEC.md` is in the AI-referenced docs registry precisely because it drifted before; §Project Structure and §Kill Flow both need this task's updates at closure.

**Design decisions (assumptions being asserted):**

1. **Verification needs an observable outcome.** `.confirmed` currently means "SIGTERM was delivered", explicitly *not* "stayed dead". Verification is unobservable unless the outcome can say otherwise, so `KillOutcome` gains a third case `.survived` (signals delivered, process still alive under the same identity after the SIGKILL fallback). This is not scope creep into [[PID-62.5]] — that child's PLAN line names a "didn't die" state *"driven by .2 verification"*, i.e. it depends on this case existing.
2. **Zombies count as dead.** A reaped-pending process still has a `kinfo_proc` entry with an unchanged start time, so a naive start-time probe would report a false `.survived`. The probe checks `p_stat == SZOMB` too.
3. **Where to wait.** No extra delay on the SIGTERM path — if the process died during the 2 s grace, `shouldEscalateToSIGKILL` already reads it as gone. Only the SIGKILL branch adds a short settle before re-probing.
4. **EPERM stays folded into `.notKilled`.** Splitting "unkillable / foreign-owned" out is [[PID-62.3]]'s stated deliverable ("thread `KillCore` outcomes to UI"); doing it here would pre-empt that child. Deliberate boundary.
5. **Signature normalization is deliberately small and documented.** Lowercase + whitespace-collapse, then drop two classes of per-launch-volatile token (temp-dir paths; `--*-handle=` / `--*-client=` / `--*-fd=` IPC flags, the Chrome-helper family), then append the resolved cwd. Three rules, each unit-testable. Over-aggressive stripping would over-match unrelated processes and produce dishonest respawner badges in [[PID-62.3]] — the failure mode to avoid.
6. **Respawn = same signature, different identity, inside the window.** A pending kill record is consumed the moment it matches, so one kill can only ever produce one respawn count; records expire after the detection window (default 300 s ≈ two default scan intervals). Same-identity reappearance is explicitly *not* a respawn (that is what `.survived` reports).
7. **Signal-only.** No UI, no `riskTier` / `bucket` / kill-bar influence — same discipline `ScanHistory` holds. [[PID-62.3]] and [[PID-62.5]] surface it.

**Downstream-impact scan:** the changed kill contract touches only sibling children of the same epic, and supports (rather than contradicts) both `.3` and `.5` as filed. Other active PLAN entries — PID-030 (notarize, Future) and PID-063 (docker-scope, Future) — are unaffected. No reconcile edits.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `RespawnHistory` extends the `ScanHistory` shape rather than inventing one: pure `struct`, `default*` tunables, `recording(_:) -> Self` fold, nested `Observation` input type, session-only with no disk, single mutable instance owned by `ScanEngine` and fed in the main-queue publish block. The `KillCore` addition follows that file's own established shape — a `public static` pure decision helper (`isStillRunning`) beside `shouldSendSIGTERM` / `shouldEscalateToSIGKILL`, with the impure probe private. No new shape justified anywhere.

- [x] **Minimal refactor gate** — one refactor, taken for DRY: `startTime(of:)` and the new death check both need the same `sysctl` `kinfo_proc` read, so the six-line body moved into a private `procInfo(of:)` that both call. `startTime(of:)`'s external behavior is deliberately unchanged (a zombie still yields its start time) so the two PID-35.3 identity guards are untouched. No unrelated cleanup taken.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- **`KillCore.swift`** (+75/−17) — `.survived` outcome; `verificationDelay` (0.2 s); `procInfo(of:)` extraction; pure `isStillRunning(snapshot:current:isZombie:)` + its private impure companion; `killPosix` now early-returns `.confirmed` when there is nothing to escalate against, and after the SIGKILL fallback probes the process table instead of assuming success.
- **`RespawnHistory.swift`** (new, 158 lines) — `Signature` (lowercase + whitespace-collapse, drops per-launch temp paths and `--*-handle=` / `--*-client=` / `--*-fd=` IPC flags, appends cwd), `Observation`, private `Watch`, `recordingKill(...)`, `recording(_:at:)`, `respawnCount(for:)` / `isRespawner(_:)`.
- **`ScanEngine.swift`** (+45) — the single `respawnHistory` instance, a private `signature(for:)` SSOT so the kill hook and the scan feed can't derive signatures differently, `armRespawnWatch` called from both `recordCleaned` overloads, `recordRespawnHistory` in the publish block *after* `cwds` is published, and the `isRespawner(_:)` query.
- **`PidlyseCLI/main.swift`** (+3) — the one exhaustive `switch` over `KillOutcome` gains a `.survived` arm with an honest message. Deliberately the whole CLI change: respawn-awareness parity stays deferred.
- **Kept out of scope on purpose:** splitting EPERM out of `.notKilled` (that is [[PID-62.3]]'s "thread `KillCore` outcomes to UI"), and any UI surface for `isRespawner` ([[PID-62.3]] / [[PID-62.5]]). `isRespawner(_:)` is an unconsumed seam at HEAD by design, not dead code.
- **Downstream-impact reconciliation:** re-checked at execution time — no direction-changing decision reached beyond this task. The kill-contract change is consumed by sibling children exactly as their PLAN lines already describe. No PLAN edits beyond this task's own line.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **250/250 passing, 0 failures** (was 229 pre-task; +21 new). `KillCoreTests` 20 (was 14), `RespawnHistoryTests` 16 (new class).

- [x] Ran lint/type-check on changed code — the Swift compiler is the type-check (per `.flowtron/tasknote/README.md` §Project quick commands): `swift build --package-path Packages/PidlyseCore` clean, full `xcodebuild test` clean, `make build-cli` links the `pidlyse` executable. No errors, no warnings. (SourceKit reports phantom "cannot find type `ProcStartTime`" / "no such module" diagnostics on the new package file — an editor-index artifact for SPM sources not in the `.xcodeproj` file list; both real compilers disagree.)

- [x] **Quality assertions** — the `sysctl` body is now written once (`procInfo(of:)`) instead of twice. No dead code: `isRespawner(_:)` is an intentional unconsumed seam for [[PID-62.3]] / [[PID-62.5]], noted as such in its doc comment. Public-surface growth is three symbols, each load-bearing and tested (`KillOutcome.survived`, `KillCore.isStillRunning`, `KillCore.verificationDelay`) plus the new `RespawnHistory` type. The one non-obvious branch — treating a zombie as dead — carries its reason inline. Code-facing docs updated in the same diff: the `KillOutcome` doc comment, `KillCore`'s file header, `ScanEngine.recordCleaned`'s contract line, `CLAUDE.md`, and `SPEC.md`.

- [x] (frontend) Asked the user for visual confirmation — **N/A.** No UI file changed (`MenuBarView.swift` untouched); this child is core + engine only by scope, and the respawn signal has no surface until [[PID-62.3]].

> **Choosing a test strategy (guidance, not a gate).** Default to targeted
> tests on the changed behavior. Where the input space is wide — parsers,
> encoders, round-trips, invariants that must hold across many inputs — a
> property-based test earns its keep; reach for one when example tests would
> leave large gaps. Visual confirmation covers UI surfaces that assertions
> can't. This is engineering judgment folded into Phase 3, never a new
> lifecycle phase or a schema/validator.

**Testing Notes:**

Test strategy: example-based, since both new surfaces are small decision functions rather than wide input spaces. The `KillCore` addition is a 3-input boolean truth table, covered exhaustively (5 cases + a defaults invariant). `RespawnHistory` splits into normalization (5 cases: whitespace/case, cwd disambiguation, temp-path stripping, IPC-handle stripping, and a *negative* case pinning that meaningful flags like `--port` are **kept** — the over-matching failure mode) and the watch lifecycle (new-PID match, same-identity non-match, unrelated-signature non-match, watch-consumption so one kill counts once, re-arming on a second kill, window expiry, and the boundary at exactly `detectionWindow`). Injecting `Date` at every call site is what makes the window testable without sleeping.

Not unit-tested, deliberately and consistently with the existing suite: the impure `sysctl` probe and the `ScanEngine` feed (same exclusion `ScanHistoryTests` documents for its scan feed and `ScanCore.runPS`). The real-process side of the death check is exercised indirectly by the pre-existing `startTime(of:)` liveness tests, which still pass through the refactored `procInfo(of:)`.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — per `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — **updated.** The "Never auto-kills" trust-story bullet claimed the flow ends at SIGKILL; it now states the outcome is verified against the process table rather than assumed, and that a survivor is never counted as a clean. (One sentence; the rest of the feature surface is unchanged, since this child ships no UI.)
  - `AGENTS.md` — **no change.** Flowtron workflow content only; carries no kill-flow, scan, or core-layout references.
  - `CLAUDE.md` — **updated.** `RespawnHistory.swift` added to the core file list; the `ScanHistory`-split paragraph extended to name the respawn cache as the third instance of that split; the kill-flow bullet now carries the three-outcome contract and the "report what happened, not what was attempted" rule for future contributors.
  - `SPEC.md` — **updated.** §Project Structure gains `RespawnHistory.swift` and the `KillCore.swift` line gains "→ death check"; §Kill Flow gains the death-check step (renumbering 4→5, 5→6) and a Respawn detection paragraph.
  - `.flowtron/PLAN.md` — **updated** in this closure (`.2` stub flip, kept nested under the active parent).

- [x] Closed — PLAN.md line flipped to stub form, kept 2-space nested beneath the active `PID-EPIC-62` in `## High` per SPEC/epic.md §"Child placement invariant"; tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] **Evidence-based recap** drafted — see Final Summary (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Made a Pidlyse kill report what actually happened instead of what was attempted, and taught the core to recognise a process that comes back. `KillCore` now re-reads the process table after the SIGKILL fallback: `.confirmed` means verified gone (no entry / PID recycled / unreaped zombie), the new `.survived` means still running under the same identity, and `.notKilled` keeps its "nothing of ours killed anything" meaning — so the clean log's "RAM reclaimed" counts real deaths only. A verified death then arms a watch in the new `RespawnHistory`, and if a later scan surfaces the same command signature under a different PID inside the detection window, that is a respawn: something restarts it, and killing it again won't stick.

Changed: `KillCore.swift` (+75/−17: `.survived`, `verificationDelay`, `procInfo(of:)` DRY extraction, pure `isStillRunning` truth table, verified `killPosix`), new `RespawnHistory.swift` (158 lines, pure value type), `ScanEngine.swift` (+45: single mutable instance, `signature(for:)` SSOT, kill-hook arming, per-scan fold, `isRespawner(_:)`), `PidlyseCLI/main.swift` (+3: the one exhaustive `switch` gains a `.survived` arm), plus `SPEC.md` / `CLAUDE.md` / `README.md`.

Verification: `make test` **250/250, 0 failures** (+21 over the 229 baseline — `KillCoreTests` 14→20, new `RespawnHistoryTests` 16); `swift build --package-path Packages/PidlyseCore` and `make build-cli` both clean, no warnings.

Refactor made: one, for DRY — the duplicated `sysctl` `kinfo_proc` read extracted to a private `procInfo(of:)`, with `startTime(of:)`'s external behavior deliberately preserved so the PID-35.3 identity guards are untouched. Deferred by design: splitting EPERM out of `.notKilled` (that is [[PID-62.3]]'s stated deliverable) and any UI for the respawn signal ([[PID-62.3]] / [[PID-62.5]]); CLI respawn parity stays deferred per [[PID-62.1]] clarification #4. Documentation verdict: 4 of 5 AI-referenced docs updated, `AGENTS.md` correctly unaffected.

Maintainability effect: the epic's two hardest invariants now have one home each — kill truthfulness lives entirely in `KillCore` (a caller can no longer infer death from a signal having been sent), and respawn memory lives in a pure, fully-tested value type that follows the `ScanHistory` split the codebase already knows. `.3`, `.4`, and `.5` consume signals instead of re-deriving them.

**Archived:** 2026-08-08
