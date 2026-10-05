---
title: listeningpids-tests
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-18, PID-18.2, PID-18.3, PID-18.5]
---

# PID-18.4 | listeningpids-tests

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-18]]

## 🎯 Goal

Add unit tests for `PortRegistry.listeningPIDs(lsofOutput:)` covering multi-line input, PID dedup, and header-line skip.

## ✅ Acceptance

- [ ] Test: multi-line `lsof` output parses multiple distinct PIDs
- [ ] Test: duplicate PIDs from multiple port bindings are deduplicated
- [ ] Test: header line ("COMMAND PID …") is skipped and does not produce a PID
- [ ] All tests pass via `make test`

## 🧩 Subtasks

- [ ] Read `PortRegistry.swift` to confirm the exact signature and parsing logic of `listeningPIDs(lsofOutput:)`
- [ ] Locate or create the Swift test target/file that covers `PortRegistry`
- [ ] Write test: multi-line input → correct PID set
- [ ] Write test: PID dedup (same PID appears on multiple lines)
- [ ] Write test: header-line skip
- [ ] Run `make test` and confirm all pass

## 🔗 Related

- [[PID-EPIC-18]] — parent epic: Kill path correctness / Init-time side-effects / Manual port-table sync
- [[PID-18.2]] — init-notifications (sibling, completed)
- [[PID-18.3]] — kill-pidreuse (sibling, in-flight)
- [[PID-18.5]] — portregistry-tripwire (sibling, next)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** `PortRegistry.listeningPIDs(lsofOutput:)` exists at `PortRegistry.swift:44` with an injectable parameter — designed for unit testing. Only `parsePIDAndPort` helper tests exist; `listeningPIDs` itself has no coverage. All 3 required cases are direct.

- [x] Read relevant source files — `PortRegistry.swift` (listeningPIDs:44, parsePIDAndPort:62); `PidlyTests/ScanEngineTests.swift` (parsePIDAndPort tests at lines 296-312, MARK pattern, XCTest conventions).

- [x] **Archive skim** — PID-18.2: SourceKit cross-file false positives on `PortRegistry` are pre-existing editor noise; `make test` is the ground truth. No prior tasknote wrote `listeningPIDs` tests.

- [x] **Drift check** — `listeningPIDs(lsofOutput:)` at `PortRegistry.swift:44` matches the task description exactly. `parsePIDAndPort` helper at line 62. `ScanEngineTests.swift` has the established test pattern. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **No clarifications needed.** Explicit assumptions:
  - Tests go in `ScanEngineTests.swift` in a new `// MARK: - PortRegistry.listeningPIDs` section after the existing `parsePIDAndPort` MARK.
  - Use registered ports already in `PortRegistry.registeredPorts` (3001, 3002, 5173) to avoid fragility.
  - Header-line skip is already tested at the `parsePIDAndPort` level; the `listeningPIDs`-level test verifies the full pipeline still ignores it.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- `listeningPIDs` splits on `\n`, calls `parsePIDAndPort` per line, collects into `Set<Int32>`. Dedup is automatic via Set. Header skip is via `parsePIDAndPort` returning nil when `fields[1]` ("PID") fails `Int32` init.
- PID-18.2 archive finding: SourceKit false positives for PortRegistry in editor are noise; build + `make test` remain ground truth.
- Discovery surfaced no significant scope deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `ScanEngineTests.swift` has an established `// MARK: - PortRegistry.parsePIDAndPort` section with direct static-call + XCTAssertEqual/XCTAssertNil tests. Extended that pattern with a new `// MARK: - PortRegistry.listeningPIDs` section; no new shape needed.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 3 new tests added to `ScanEngineTests.swift`: `testListeningPIDs_multiLine_returnsAllRegisteredPIDs`, `testListeningPIDs_duplicatePID_deduplicates`, `testListeningPIDs_headerLine_skipped`.

**Implementation Notes:**

Added 3 tests in a new `// MARK: - PortRegistry.listeningPIDs` section at the end of `ScanEngineTests.swift`. Uses registered ports already in `PortRegistry.registeredPorts` (3001, 3002, 5173). Dedup relies on the `Set<Int32>` return type; header skip relies on `parsePIDAndPort` returning nil when "PID" fails `Int32` init.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 41/41 passed (38 prior + 3 new), `** TEST SUCCEEDED **`.

- [x] Ran lint/type-check on changed code — build runs inside `make test`, 0 errors. SourceKit `No such module 'XCTest'` is pre-existing editor noise (same as PID-18.2).

- [x] (frontend) Asked the user for visual confirmation — n/a (no UI change; test-only).

**Testing Notes:**

41/41 tests pass. The 3 new `listeningPIDs` tests exercise: multi-line parsing, dedup via Set semantics, and header-line skip via `parsePIDAndPort` returning nil for non-integer PID field.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: PID-18.4 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added 3 unit tests for `PortRegistry.listeningPIDs(lsofOutput:)` in a new `// MARK: - PortRegistry.listeningPIDs` section of `ScanEngineTests.swift`, covering multi-line input, PID dedup (via Set semantics), and header-line skip (via `parsePIDAndPort` returning nil). 41/41 tests pass.

**Archived:** 2026-06-25
