---
title: kill-path-hardening
status: completed
tags: [security, kill-path, docker]
created: 2026-06-28
due:
related-tasks: [PID-EPIC-35, PID-35.1, PID-18.3, PID-28.2]
---

# PID-35.3 | kill-path-hardening

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-35]]

## 🎯 Goal

Harden the kill flow against two trust gaps found in the PID-EPIC-35 sweep: **F2** — validate the resolved `docker` binary (owned by root/current-user, not world-writable) before exec in `DockerService.cliPath`; **F8** — carry a scan-time start-time identity token on `ProcessItem` and re-verify it immediately before the **initial SIGTERM**, closing the scan→click PID-reuse window the existing guard (SIGKILL-escalation-only) leaves open.

## ✅ Acceptance

- [x] **F8** — `ProcessItem` carries an optional scan-time `startTime` identity token, captured during scan via an injectable provider (ScanCore stays pure/testable; default `nil`)
- [x] **F8** — `KillService.killPosix` re-verifies the token before the initial SIGTERM and aborts (no signal, rescan) when the PID was recycled or the process is gone since scan; when no token is present it falls back to today's behavior (no regression)
- [x] **F8** — the 2 s grace period and the existing SIGKILL-escalation guard are preserved verbatim (CLAUDE.md non-negotiable)
- [x] **F2** — `DockerService.cliPath` only returns a candidate whose resolved binary is owned by root or the current user and is not world-writable; the trust decision is a pure, unit-tested helper
- [x] Pure decision helpers unit-tested (`shouldSendSIGTERM` matrix + `isTrustedOwnership` matrix) in `KillServiceTests` / a `DockerServiceTests` class inside `ScanEngineTests.swift`; impure shell-out/sysctl stays untested per convention
- [x] `make test` green — 80 tests, 0 failures (was 67; +13)
- [x] Phase 4 doc-drift sweep: README §Security bullets 51 (PID-reuse guard now covers the initial signal) + 52 (docker-binary trust check + residual `/usr/local/bin` note) updated

## 🧩 Subtasks

- [x] Move `ProcStartTime` struct from `KillService` → `PidlyseCore` (public, in `ProcessItem.swift`); add `typealias ProcStartTime = PidlyseCore.ProcStartTime` in `KillService` so `KillService.ProcStartTime` (4 test refs) stays valid
- [x] Add `public let startTime: ProcStartTime?` to `ProcessItem` (init param defaulted `nil` → existing call sites compile unchanged)
- [x] Thread an injectable `startTimeProvider: ((Int32) -> ProcStartTime?)? = nil` through `ScanCore.enumerate` → `makeItem`; set `startTime` in the `ProcessItem` init
- [x] Wire prod capture: `ScanEngine.scan` passes `startTimeProvider: KillService.startTime`
- [x] Add pure `KillService.shouldSendSIGTERM(expected:current:)`; change `killPosix` to take `expected:` and verify before SIGTERM (reuse the read token as the SIGKILL snapshot); pass `item.startTime` from both `kill(_:)` paths (incl. docker POSIX fallback)
- [x] F2: split `DockerService.cliPath` into a pure `isTrustedOwnership(ownerUID:permissions:currentUID:)` + an impure `isTrustedExecutable(_:)` (resolves symlinks, stats, applies the policy); cliPath filters on it
- [x] Add `shouldSendSIGTERM` cases to `KillServiceTests` + a `DockerServiceTests` class for `isTrustedOwnership`; add a ScanCore test that an injected provider populates `item.startTime`
- [x] `make test` → green
- [x] Phase 4: README §Security bullets 51 + 52 update; doc-drift sweep; flip PLAN line; archive

## 🔗 Related

- [[PID-EPIC-35]] — parent security sweep (F2 + F8 are this child's cluster)
- [[PID-35.1]] — Discovery that inventoried F2 + F8
- [[PID-18.3]] — kill-pidreuse; established the `startTime(of:)` + `shouldEscalateToSIGKILL` start-time primitive this extends from kill-time to scan-time
- [[PID-28.2]] — docker-service; established `DockerService.cliPath` (the F2 surface)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Both findings are real and located at HEAD. F8: `killPosix` (KillService.swift:90) snapshots start-time *at kill time*, so only the SIGKILL escalation is identity-guarded — the (potentially long) scan→click window before the initial SIGTERM is unguarded. F2: `DockerService.cliPath` (DockerService.swift:11-14) returns the first `isExecutableFile` hit with no ownership/permission check. Both are the PID-EPIC-35 child cluster the operator triaged into this task.

- [x] Read relevant source files — `DockerService.swift` (cliPath/run), `KillService.swift` (killPosix, startTime, shouldEscalateToSIGKILL, ProcStartTime, docker path), `ProcessItem.swift`, `ScanCore.swift` (enumerate/makeItem), `ScanEngine.swift` (scan wiring), `PidlyseTests/ScanEngineTests.swift`, README §Security

- [x] **Archive skim** — see Discovery Notes (PID-18.3, PID-28.2, PID-004, PID-35.1/35.2 load-bearing)

- [x] **Drift check** — no drift. `DockerService.cliPath()` at DockerService.swift:11-14 unchanged; `KillService.killPosix` snapshots at kill time (line 90), confirming the F8 "escalation-only" observation; `ProcStartTime`/`startTime(of:)`/`shouldEscalateToSIGKILL` present as PID-18.3 left them.

- [x] Asked clarifying questions — resolved via AskUserQuestion (see "Resolved scoping")

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Archive skim (load-bearing)

- **PID-18.3 (kill-pidreuse)** — established `ProcStartTime` (nested in `KillService`), the `startTime(of:)` sysctl reader, and the pure `shouldEscalateToSIGKILL(snapshot:current:)` decision, snapshotting *at kill time*. F8 extends exactly this: the same start-time token, but captured at **scan** time and checked before the initial SIGTERM. Mandated conventions: pure helper tested, impure sysctl untested; tests in a `KillServiceTests` class inside `ScanEngineTests.swift`; the CLAUDE.md "SIGTERM → 2 s → SIGKILL, never skip grace" rule is load-bearing and must be preserved.
- **PID-28.2 (docker-service)** — created `DockerService.cliPath`/`run` (extracted from `KillService`); the F2 surface. Convention: `DockerService` owns impure docker CLI access; pure logic is the testable surface.
- **PID-004 (kill-hardening)** — original SIGTERM→2s→SIGKILL + EPERM silent-rescan flow.
- **PID-35.1 / PID-35.2** — sweep discovery (F-numbering) + the just-landed stderr-drain fix on the same three shell-out helpers.

### F8 design (scan-time start-time token)

The only artifact travelling scan→kill-button is `ProcessItem`, so the identity token must ride on it. Plan keeps `ScanCore` pure by **injection** (consistent with its existing `psOutput`/`registeredPIDs` injectable-default pattern):

- `ProcStartTime` moves to `PidlyseCore` (public) so `ProcessItem` can hold it; `KillService` keeps a `typealias` → zero churn on the 4 `KillService.ProcStartTime` test refs.
- `enumerate`/`makeItem` gain `startTimeProvider: ((Int32) -> ProcStartTime?)? = nil`; prod (`ScanEngine.scan`, already on a bg queue) passes `KillService.startTime`; tests pass nothing (`nil` → no sysctl, deterministic).
- `killPosix(_:expected:onComplete:)` reads `current = startTime(of: pid)` once, gates SIGTERM on a new pure `shouldSendSIGTERM(expected:current:)`, and reuses `current` as the SIGKILL snapshot.
- `shouldSendSIGTERM` semantics (robust, no-regression): `expected == nil` → `true` (legacy fallback — no scan-time identity to enforce, behaves exactly like today, so a wiring miss can never silently no-op every kill); `expected` set & `current == nil` → `false` (gone); both set → `expected == current`.

### F2 design (lenient trust check)

In `cliPath`, after `isExecutableFile`, resolve symlinks and stat the real target; accept only if owner ∈ {root, current uid} **and** not world-writable (`perms & 0o002 == 0`). Pure `isTrustedOwnership(ownerUID:permissions:currentUID:)` (tested) + impure `isTrustedExecutable(_:)` (filesystem read). **Residual risk (accepted, documented):** `/usr/local/bin` is group-writable by `admin` on Intel by design — rejecting group-writable would silently break Docker detection there, so it's out of scope; noted in a code comment + README §Security bullet 52.

### Resolved scoping

| Question | Answer |
|---|---|
| F8 approach | **Scan-time start-time token** on `ProcessItem`, verified before SIGTERM (precise; reuses the PID-18.3 primitive) — over the surgical KillService-only command re-resolve |
| F2 strictness | **Lenient** — owner root/current-user + not world-writable; document the residual `/usr/local/bin` admin-group risk (over a strict group-writable/parent-dir check that would false-positive on Intel) |

**Phase 1→2 exit:** Discovery surfaced a **significant scope shape** — the chosen F8 approach reaches beyond a single file into the `PidlyseCore` core model (`ProcessItem` gains a field, `ProcStartTime` moves modules) plus the `ScanCore`/`ScanEngine` scan path, not just `KillService`. Cross-cutting change → **fired 🛠️**; operator approved ("go").

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended existing shapes rather than inventing: F8 reuses the PID-18.3 start-time primitive (`ProcStartTime`/`startTime(of:)`/pure decision helper) and ScanCore's injectable-default convention (`psOutput`/`registeredPIDs` → `startTimeProvider`); F2 mirrors the PID-18.3/PID-28.2 pure-decision + impure-shell split (`isTrustedOwnership` pure, `isTrustedExecutable` impure), matching KillService's tested-pure/untested-impure pattern.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `PidlyseCore/ProcessItem.swift` — moved `ProcStartTime` here as a `public struct` (so `ProcessItem` can hold it); added `public let startTime: ProcStartTime?` with a defaulted init param (existing call sites + tests unchanged).
- `PidlyseCore/ScanCore.swift` — added injectable `startTimeProvider` to `enumerate` + `makeItem`; `makeItem` captures `startTimeProvider.flatMap { $0(p.pid) }` into the item. No live sysctl in ScanCore (purity/testability preserved).
- `Pidlyse/ScanEngine.swift` — `scan()` passes `startTimeProvider: KillService.startTime` (runs on the existing bg queue).
- `Pidlyse/KillService.swift` — replaced the nested `ProcStartTime` struct with `typealias ProcStartTime = PidlyseCore.ProcStartTime`; added pure `shouldSendSIGTERM(expected:current:)`; `killPosix` now takes `expected:`, reads `current` once, gates SIGTERM on `shouldSendSIGTERM`, and reuses `current` as the SIGKILL snapshot. The 2 s grace + `shouldEscalateToSIGKILL` are byte-for-byte unchanged. Both `kill(_:)` paths (incl. docker POSIX fallback) pass `item.startTime`.
- `Pidlyse/DockerService.swift` — `cliPath` filters on `isTrustedExecutable` (resolves symlinks, stats owner+perms) → pure `isTrustedOwnership(ownerUID:permissions:currentUID:)`. Residual `/usr/local/bin` risk documented in-code.
- **Downstream-impact:** none beyond the EPIC-35 cohort. `ProcStartTime` move + `ProcessItem` field are additive (defaulted), so no other PLAN entry's surface shifts. PID-35.4 (smells-cleanup) touches `PortRegistry.effectivePorts`/`detectKind`/`findContainerID` — disjoint from these edits.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **80 tests, 0 failures** (was 67; +5 `shouldSendSIGTERM`, +6 `DockerServiceTests`, +2 `ScanCoreStartTimeTests`).

- [x] Ran lint/type-check on changed code — compiled clean via the test build (the Swift compiler is the type-check; no separate linter). The SourceKit "No such module 'PidlyseCore' / 'XCTest'" diagnostics are stale-IDE-index noise (same false positive PID-35.2 documented), contradicted by the successful `xcodebuild`.

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI surface changed).

**Testing Notes:** New tests cover the two pure decisions exhaustively (`shouldSendSIGTERM`: same / recycled / usec-near-miss / gone-with-token / no-token×2; `isTrustedOwnership`: root / current-user / group-writable-allowed / world-writable-rejected / root-but-world-writable / foreign-owner) plus the scan-time capture wiring (provider populates `startTime`; default leaves it `nil`). Impure `startTime(of:)` sysctl + `isTrustedExecutable` filesystem read stay untested by convention.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — **updated**: §Security bullet 51 (PID-reuse guard now refuses *either* signal on a scan→click recycle) + bullet 52 (docker-binary trust check + residual `/usr/local/bin` note).
  - `AGENTS.md` — no change (no kill-flow / docker-resolution refs).
  - `CLAUDE.md` — no change; the "SIGTERM → 2 s → SIGKILL — never skip the grace period" non-negotiable is preserved verbatim, and the docker-plumbing-stays-in-DockerService convention still holds (the trust check lives in `DockerService`).
  - `.flowtron/PLAN.md` — `.3` line flipped to stub form (this closure).

- [x] Closed — PLAN.md `.3` line flipped to `Completed 2026-06-28.` (kept nested under PID-EPIC-35; parent flips when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Closed F2 + F8 from the PID-EPIC-35 security sweep. **F8 (PID-reuse before SIGTERM):** the kill path only verified process identity before the *SIGKILL escalation*, so a PID recycled in the (possibly long) window between the scan and the user's kill click could take the initial SIGTERM — hitting an innocent bystander. Now each scanned process carries a start-time identity token (`ProcStartTime`, moved to `PidlyseCore` so `ProcessItem` can hold it; captured via an injectable `startTimeProvider` that keeps `ScanCore` pure), and `KillService.killPosix` re-reads + compares it before SIGTERM via the new pure `shouldSendSIGTERM` — aborting (rescan, no signal) on a recycle or a gone process, falling back to legacy behavior when no token was captured (never a regression). The 2 s grace + SIGKILL guard are untouched. **F2 (docker-binary trust):** `DockerService.cliPath` now exec's a candidate only after verifying the resolved binary is owned by root/you and not world-writable (pure `isTrustedOwnership` + impure `isTrustedExecutable`), blocking a trojan `docker` in a world-writable/foreign-owned path; the residual Intel `/usr/local/bin` admin-group-writability gap is documented in-code + README. `make test` → 80 passing (+13). README §Security bullets 51/52 updated.

**Archived:** 2026-06-28
