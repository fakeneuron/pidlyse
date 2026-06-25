---
title: portregistry-tripwire
status: in-progress
tags: []
created: 2026-06-25
related-tasks: [PID-EPIC-18, PID-18.2, PID-18.3, PID-18.4]
---

# PID-18.5 | portregistry-tripwire

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-18]]

## 🎯 Goal

Add a canary test that asserts specific known ports are present in `PortRegistry.registeredPorts`, acting as an anti-drift tripwire so accidental edits to the manually-synced port table get caught by `make test`.

## ✅ Acceptance

- [ ] Test asserts a representative spread of specific known ports are members of `PortRegistry.registeredPorts`
- [ ] Test references the manual-sync source (`~/.claude/CLAUDE.md` §"Localhost Port Registry") so the tripwire's purpose is self-documenting
- [ ] All tests pass via `make test`

## 🧩 Subtasks

- [ ] Confirm current `registeredPorts` contents and pick a stable representative canary set
- [ ] Add a `// MARK: - PortRegistry.registeredPorts (anti-drift canary)` section to `ScanEngineTests.swift`
- [ ] Write the canary test asserting membership of the chosen known ports
- [ ] Run `make test` and confirm all pass

## 🔗 Related

- [[PID-EPIC-18]] — parent epic: Kill path correctness / Init-time side-effects / Manual port-table sync
- [[PID-18.2]] — init-notifications (sibling, completed)
- [[PID-18.3]] — kill-pidreuse (sibling, in-flight)
- [[PID-18.4]] — listeningpids-tests (sibling, completed — immediate predecessor pattern)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** `PortRegistry.registeredPorts` (`PortRegistry.swift:10`) is a hand-maintained mirror of the global CLAUDE.md port table with no test coverage. A canary asserting known-port membership is the anti-drift guard the epic calls for. Clear, scoped, mechanical.

- [x] Read relevant source files — `PortRegistry.swift` (`registeredPorts:10`, 21 distinct ports); `PidlyTests/ScanEngineTests.swift` (established `// MARK: - PortRegistry.*` sections, XCTest static-call conventions).

- [x] **Archive skim** — PID-005 created `registeredPorts` (then 15 ports, now 21) and noted the caseless-enum/static-helper style. PID-18.4 added `listeningPIDs` tests in a new MARK section of `ScanEngineTests.swift` and confirmed SourceKit cross-file warnings on `PortRegistry` are pre-existing editor noise — `make test` is ground truth.

- [x] **Drift check** — Task names a `PortRegistryTests` file, but the established convention (PID-005, PID-18.4) keeps `PortRegistry` tests in `ScanEngineTests.swift`. Following convention — adding to `ScanEngineTests.swift`, not creating a new file. The deliverable (canary for the port table) is unchanged; this is a naming-only drift, not a scope deviation. `registeredPorts` is at `PortRegistry.swift:10` as described.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **No clarifications needed.** Explicit assumptions:
  - "Canary asserting specific known ports" → assert membership of a curated representative spread of ports (one anchor per active project), NOT an exact full-set equality and NOT a count assertion — the latter two break on every legitimate port add, whereas the task wording asks for "specific known ports."
  - Tests go in `ScanEngineTests.swift` in a new `// MARK:` section, following PID-18.4's precedent (not a separate `PortRegistryTests` file).
  - Canary ports chosen from stable, long-lived project allocations already in `registeredPorts`.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- `registeredPorts` currently holds 21 distinct ports across ~14 projects + Docker canonical ports.
- A canary can only pin the *current* PortRegistry.swift contents (it has no access to the global CLAUDE.md table at test time); its value is catching accidental deletions/corruption of the Swift table and serving as a written reminder to keep the manual sync current.
- Discovery surfaced no significant scope deviation (only a naming-convention drift, resolved by following precedent) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended the `// MARK: - PortRegistry.*` section pattern already in `ScanEngineTests.swift` (PID-18.4 precedent). Static-call + `XCTAssertTrue` membership checks; no new shape needed.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 1 canary test `testRegisteredPorts_canaryKnownPorts` added in a new `// MARK: - PortRegistry.registeredPorts (anti-drift canary)` section.

**Implementation Notes:**

Added one canary test asserting membership of 12 anchor ports (one per active project) in `PortRegistry.registeredPorts`. Each port carries a project comment; the assertion message names the manual-sync source (`~/.claude/CLAUDE.md`) so a failure points straight at the drift. Chose representative-membership over exact-set/count assertions so legitimate port additions don't break the tripwire.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 42/42 passed (41 prior + 1 canary), `** TEST SUCCEEDED **`.

- [x] Ran lint/type-check on changed code — build runs inside `make test`, 0 errors. SourceKit `No such module 'XCTest'` is pre-existing editor noise (confirmed in PID-18.4/PID-18.2 archives).

- [x] (frontend) Asked the user for visual confirmation — n/a (no UI change; test-only).

**Testing Notes:**

42/42 tests pass. The canary asserts 12 known project anchor ports are present; if the manual port table drifts (an accidental deletion/corruption), the test fails under `make test` with a message naming the sync source.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change (no ports added, just a guard test). `.flowtron/PLAN.md`: PID-18.5 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added one anti-drift canary test `testRegisteredPorts_canaryKnownPorts` to `ScanEngineTests.swift` (new `// MARK:` section), asserting 12 known project anchor ports are present in `PortRegistry.registeredPorts`. The assertion message names the manual-sync source (`~/.claude/CLAUDE.md`) so a failure points straight at the drift. Followed the established convention of housing `PortRegistry` tests in `ScanEngineTests.swift` rather than a separate file. 42/42 tests pass.

**Archived:** 2026-06-25
