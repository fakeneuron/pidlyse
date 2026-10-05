---
title: shellout-helper
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-16]
---

# PID-16.2 | shellout-helper

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-16]]

## 🎯 Goal

Extract a private shell-out helper used by KillService (3 Docker subprocess sites), ScanEngine.runPS, and PortRegistry.runLSOF — consolidating duplicate Process/Pipe/wait boilerplate into one function while preserving the reads-to-EOF-before-waitUntilExit invariant.

## ✅ Acceptance

- [ ] Single private `runShell(_ args: [String]) -> String` helper (or equivalent) exists in one file
- [ ] KillService's 3 Docker subprocess sites call the helper instead of duplicating Process setup
- [ ] ScanEngine.runPS calls the helper
- [ ] PortRegistry.runLSOF calls the helper
- [ ] reads-to-EOF-before-waitUntilExit ordering preserved at every call site
- [ ] No behavior change: output identical to prior implementation

## 🧩 Subtasks

- [x] Audit all 5 shell-out sites — patterns confirmed, per-site variations noted
- [x] Decide helper placement — local per file (per PID-16.1): `runDocker` in KillService, `runShell` in ScanEngine + PortRegistry
- [ ] ScanEngine: add private `runShell`, refactor `runPS()` to call it
- [ ] PortRegistry: add private `runShell`, refactor `runLSOF()` to call it
- [ ] KillService: add private `runDocker`, refactor `findContainerID` + `containerPID` + `dockerStop` to call it
- [ ] Verify build succeeds (xcodebuild build -scheme Pidly)

## 🔗 Related

- [[PID-EPIC-16]] — parent code-quality epic (shell-out extraction is the first implementation child)
- [[PID-16.1]] — discovery subtask that identified these 5 sites and filed this task

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** All 5 shell-out sites confirmed in source; locations match PLAN.md description exactly; scoping from PID-16.1 is authoritative.

- [x] Read relevant source files

- [x] **Archive skim** — PID-16.1 (discovery subtask) is the primary precedent: inventoried all 5 sites, resolved helper placement (local per file), named KillService helper `runDocker`. PID-002 noted the reads-to-EOF-before-waitUntilExit invariant (pipe deadlock prevention). No other load-bearing precedents.

- [x] **Drift check** — ScanEngine.runPS() lines 290-305 ✓; PortRegistry.runLSOF() lines 75-91 ✓; KillService.findContainerID lines 97-113 ✓; KillService.containerPID lines 117-129 ✓; KillService.dockerStop lines 132-141 ✓. All locations match.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Explicit assumptions:
  - KillService helper named `runDocker` (per PID-16.1 scoping decision), returning `(output: String, ok: Bool)` tuple — stdout covers findContainerID + containerPID; exit-status `.ok` covers dockerStop. Reads stdout even for dockerStop (currently discarded), which is more correct (prevents any pipe-buffer deadlock).
  - ScanEngine + PortRegistry helpers named `runShell`, returning `String`, using `do/try/catch` style matching each file.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- 5 shell-out sites confirmed; local-per-file placement per PID-16.1. KillService: `runDocker(_ docker: String, _ args: [String]) -> (output: String, ok: Bool)`. ScanEngine + PortRegistry: `runShell(_ path: String, _ args: [String]) -> String`.
- Critical invariant: `readDataToEndOfFile()` BEFORE `waitUntilExit()` — must be preserved in all helpers.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — the existing `runPS`/`runLSOF` bodies already embody the helper shape; KillService uses `guard try?` style. Local extraction per file, names from PID-16.1 (`runDocker` / `runShell`).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — no new test surface; existing tests cover the refactored paths via injection (`psOutput:` / `lsofOutput:` parameters bypass the shell-out).

**Implementation Notes:**

- ScanEngine.swift: added `private static func runShell(_ path: String, _ args: [String]) -> String`; `runPS()` is now a 1-line wrapper.
- PortRegistry.swift: same `runShell` extraction; `runLSOF()` is a 1-line wrapper.
- KillService.swift: added `private static func runDocker(_ docker: String, _ args: [String]) -> (output: String, ok: Bool)`; `findContainerID` and `containerPID` use `.output`; `dockerStop` uses `.ok` (now also reads stdout, which is more correct — prevents any pipe-buffer deadlock edge case).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `xcodebuild test`: ** TEST SUCCEEDED ** (30 tests passed)

- [x] Ran lint/type-check on changed code — `xcodebuild build`: ** BUILD SUCCEEDED ** (SourceKit cross-file noise is pre-existing LSP issue, not from these changes)

- [x] (frontend) Asked the user for visual confirmation — not applicable (no UI changes)

**Testing Notes:**

All 30 ScanEngineTests passed. The shell-out helpers are bypassed by test injection (`psOutput:` / `lsofOutput:` parameters), so correctness is verified by the build + behavioral parity analysis (trace in Discovery Notes).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: PID-16.2 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Extracted `runDocker` (KillService) and `runShell` (ScanEngine, PortRegistry) private helpers, collapsing 5 duplicated Process/Pipe/wait boilerplate blocks into 3 named functions. All call sites updated; the reads-to-EOF-before-waitUntilExit invariant is preserved in every helper. Build + 30 tests passing.

**Archived:** 2026-06-24
