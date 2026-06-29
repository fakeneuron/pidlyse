---
title: smells-cleanup
status: in-progress
tags: []
created: 2026-06-28
due:
related-tasks: [PID-EPIC-35]
---

# PID-35.4 | smells-cleanup

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-35]]

## 🎯 Goal

Fix three code smells flagged as F6/F7/F9 in the PID-EPIC-35 security sweep: hot-reload PortRegistry.effectivePorts per scan, tighten detectKind to token-boundary matching, and resolve PID→container once per docker-kill.

## ✅ Acceptance

- [ ] `PortRegistry.effectivePorts` is recomputed from disk on each scan (no restart required to pick up ports.json edits)
- [ ] `detectKind` matching avoids substring collisions (e.g. "bun" inside "bundown") via token-boundary checks
- [ ] Docker kill resolves PID→container once per kill invocation, not once per running container

## 🧩 Subtasks

- [ ] Read relevant source files (PortRegistry.swift, ScanCore.swift, KillService.swift / DockerService.swift)
- [ ] F6: recompute effectivePorts per scan in PortRegistry / ScanCore
- [ ] F7: tighten detectKind substring matching toward token boundaries
- [ ] F9: resolve PID→container once per docker-kill
- [ ] Build and confirm `make test` green

## 🔗 Related

- [[PID-EPIC-35]] — parent security-sweep epic
- [[PID-35.3]] — kill-path hardening (predecessor)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** All three symbols confirmed at expected locations; scope exactly matches PLAN.md description.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- `PortRegistry.effectivePorts` is `static let` on line 54 — computed once at startup via `mergedPorts(userJSON: loadUserPortsJSON())`. Used by `parsePIDAndPort` (called in a loop from `listeningPIDs`). Fix: `static var` computed property + capture once in `listeningPIDs`; add optional `ports: Set<Int>? = nil` param to `parsePIDAndPort` so tests remain unchanged.
- `detectKind` uses raw `s.contains("npm")` which matches `pnpm run dev` (real false-positive) and `s.contains("jest")` which matches paths like `/user/jest-examples/server`. Adding `hasTokenBoundary(_:_:)` helper (checks hasPrefix/slash/dot/space boundaries). All 7 `contains` checks replaced. Existing test inputs traced — all pass. `bun` guard is unchanged (already token-safe).
- `findContainerID` calls `docker inspect` once per running container ID (loop at lines 149-151). Fix: one bulk `docker inspect --format '{{.Id}}\t{{.State.Pid}}' <all-ids>` call, parse tab-separated lines by content (not by index, so resilient to docker skipping unknown IDs). `containerPID` (lines 155-159) becomes unused — remove it.
- Archive hits: PID-35.1 (source of F6/F7/F9 findings), PID-35.3 (docker CLI trust check, stderr-drain pattern). No load-bearing constraints that affect our approach.
- No clarifications needed.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `bun` guard in `detectKind` is the established pattern for token-boundary matching; used it as the model for the new `hasTokenBoundary` helper.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- **F6 (PortRegistry.swift):** Changed `static let effectivePorts` to `static var effectivePorts` (computed property, re-reads disk each access). `listeningPIDs` captures `effectivePorts` once before the loop and passes it to `parsePIDAndPort`. Added `ports: Set<Int>? = nil` param to `parsePIDAndPort` (nil → uses `effectivePorts`); existing test calls remain unchanged.
- **F7 (ScanCore.swift):** Added `private static func hasTokenBoundary(_:_:)` checking hasPrefix, `/token`, `.token.`, and ` token` boundaries. Replaced 7 raw `s.contains(X)` checks in `detectKind` with `hasTokenBoundary` calls. `bun` and `node` guards unchanged (already token-safe). Added 2 regression tests: `testDetectKind_pnpmIsNotNpm` and `testDetectKind_jestPathIsNotJest`.
- **F9 (KillService.swift):** Rewrote `findContainerID` to bulk-inspect all running container IDs in a single `docker inspect --format '{{.Id}}\t{{.State.Pid}}' <ids...>` call (2 CLI calls total vs. 1 + N). Parses tab-separated lines by content (resilient to docker skipping unresolvable IDs). Removed now-unused `containerPID(containerID:)`.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

`make test` → 82 tests, 0 failures (up from 80; 2 new F7 regression tests added). Build compiled cleanly.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - README.md: no change
  - AGENTS.md: no change
  - CLAUDE.md: no change
  - PLAN.md: updated at closure below

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Fixed three code smells from the PID-EPIC-35 security sweep: PortRegistry.effectivePorts now reloads ports.json on each scan (no restart needed), detectKind uses token-boundary matching to prevent pnpm/jest-path false positives, and docker-kill resolves PID→container with a single bulk `docker inspect` call. 4 files changed, 2 regression tests added; 82 tests pass.

**Archived:** 2026-06-28
