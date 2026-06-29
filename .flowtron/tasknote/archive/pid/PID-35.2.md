---
title: stderr-drain
status: in-progress
tags: [security, shell-out]
created: 2026-06-28
related-tasks: [PID-EPIC-35, PID-35.1, PID-16.2]
---

# PID-35.2 | stderr-drain

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-35]]

## 🎯 Goal

Eliminate the latent pipe-buffer deadlock (F1): the three shell-out helpers set `standardError = Pipe()` but never drain it, so a subprocess writing >64 KB to stderr blocks forever on `waitUntilExit()`.

## ✅ Acceptance

- [x] All three shell-out helpers no longer hold an undrained stderr `Pipe()` — stderr routed to `FileHandle.nullDevice`, so it can never fill a buffer and wedge `waitUntilExit()`
- [x] Behavior preserved: stdout still drained to EOF before `waitUntilExit`; return values (stdout string / `(output, ok)` tuple) unchanged
- [x] Test approach resolved per the Phase 1 clarification → **no regression test** (deadlock eliminated by construction; honors the `ScanEngineTests:487` no-impure-shell-out-testing convention)
- [x] `make test` green — 67 tests, 0 failures

## 🧩 Subtasks

- [x] Set `task.standardError = FileHandle.nullDevice` in `ScanCore.runShell`
- [x] Same in `PortRegistry.runShell`
- [x] Same in `DockerService.run`
- [x] Run `make test` — confirm green (no behavior change)
- [x] No regression test (Phase 1 clarification) — document rationale

## 🔗 Related

- [[PID-EPIC-35]] — parent security sweep
- [[PID-35.1]] — Discovery that found F1
- [[PID-16.2]] — shellout-helper; established the stdout drain-before-wait invariant (applied to stdout only — this task closes the stderr gap)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** F1 from PID-35.1 — a concrete, located latent bug across three known callsites. Fix is small; the only open question is the test approach (see clarification).

- [x] Read relevant source files — `ScanCore.runShell` (Packages/PidlyseCore/.../ScanCore.swift:155), `PortRegistry.runShell` (PortRegistry.swift:108), `DockerService.run` (DockerService.swift:24); `PidlyseTests/ScanEngineTests.swift`

- [x] **Archive skim** — PID-16.2 (shellout-helper) extracted these helpers and established the `readDataToEndOfFile()`-before-`waitUntilExit()` invariant for **stdout**; stderr was left as an undrained `Pipe()`. PID-002 first noted the deadlock-prevention invariant. This task closes the stderr side of the same invariant.

- [x] **Drift check** — all three helpers present and identical in shape at HEAD; each sets `task.standardError = Pipe()` and never reads it. No drift.

- [x] Clarifying questions surfaced (fix mechanism + test approach) — resolved via AskUserQuestion: `FileHandle.nullDevice`, no regression test

- [x] Subtasks populated with concrete, ordered steps

**Discovery Notes:**

The three helpers are byte-similar (per-file local placement was a deliberate PID-16.1/16.2 decision — do NOT consolidate them here, that's out of scope):

| Helper | File | stderr today |
|---|---|---|
| `ScanCore.runShell` | ScanCore.swift:155 | `task.standardError = Pipe()` — never read |
| `PortRegistry.runShell` | PortRegistry.swift:108 | same |
| `DockerService.run` | DockerService.swift:24 | same |

None of the three ever *use* stderr output — they return stdout (and, for `DockerService.run`, exit status). So the intent is "discard stderr." The minimal fix that preserves that intent while removing the deadlock is to route stderr to `FileHandle.nullDevice` (no pipe → no buffer to fill). The realistic trigger is `docker` emitting a verbose error >64 KB.

**Test-approach collision (clarification needed):** `ScanEngineTests.swift:487` documents the convention "the impure DockerService shell-out is not unit-tested (mirrors ScanCore.runPS)." A genuine deadlock regression test would need to (a) expose a `private static` helper across two modules + the app target and (b) run a real subprocess emitting >64 KB to stderr behind an `XCTestExpectation` timeout (mildly timing-based). That conflicts with the established "pure logic tested, impure shell-out not" pattern. Resolving with the user before writing.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — three helpers deliberately duplicated per-file (PID-16.1/16.2 decision); edited each in place, did NOT consolidate (out of scope)

- [x] Implemented the minimal solution — `task.standardError = FileHandle.nullDevice` + an explanatory comment in all three helpers

- [x] Updated/added tests for non-trivial behavior — N/A by Phase 1 clarification (impure shell-out not unit-tested per `ScanEngineTests:487`; deadlock eliminated by construction)

**Implementation Notes:**

- Changed (one line + 3-line comment each): `ScanCore.runShell` (ScanCore.swift), `PortRegistry.runShell` (PortRegistry.swift), `DockerService.run` (DockerService.swift).
- Why `nullDevice` over draining: the helpers never read stderr, so discard-to-`/dev/null` preserves intent exactly while removing the buffer that could fill. No pipe = no deadlock, no extra thread.
- The pre-existing stdout invariant (`readDataToEndOfFile()` before `waitUntilExit()`) is untouched and still correct.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 67 tests, 0 failures (build compiled all 3 edited files → fix type-checks)

- [x] Ran lint/type-check on changed code — compiled clean via the test build. (One spurious SourceKit "No such module 'PidlyseCore'" in DockerService.swift — stale IDE index; `xcodebuild` compiled the file fine.)

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no UI change)

**Testing Notes:** No new tests by design (Phase 1 clarification). Regression coverage is structural: routing stderr to the null device makes the pipe-buffer deadlock impossible by construction.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` no change · `AGENTS.md` no change · `CLAUDE.md` no change · `.flowtron/PLAN.md` updated (this closure). No user-facing behavior or command changed.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-28.`; tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Closed F1 from the PID-EPIC-35 security sweep: the three shell-out helpers (`ScanCore.runShell`, `PortRegistry.runShell`, `DockerService.run`) each set `standardError = Pipe()` but never drained it — a subprocess writing >64 KB to stderr (realistically `docker` on a verbose error) would fill the pipe buffer and hang `waitUntilExit()` forever, wedging the scan/kill background thread. Fix: route stderr to `FileHandle.nullDevice` in all three, eliminating the deadlock by construction while preserving the existing discard-stderr behavior. This closes the stderr side of the drain-before-wait invariant PID-16.2 established for stdout. No regression test (per Phase 1 clarification — impure shell-out is not unit-tested by convention, and the bug class is removed structurally). `make test` green: 67 tests, 0 failures.

**Archived:** 2026-06-28
