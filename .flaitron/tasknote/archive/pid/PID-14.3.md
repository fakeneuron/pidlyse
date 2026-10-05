---
title: docker-stop-note
status: completed
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-14]
---

# PID-14.3 | docker-stop-note

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-14]]

## 🎯 Goal

Document / clarify that `dockerStopByPID` targets container root PIDs, not host daemon processes; remove or annotate the dead path accordingly.

## ✅ Acceptance

- [ ] `dockerStopByPID` intent is clearly commented or renamed so the distinction from host-daemon killing is unambiguous
- [ ] Dead code path (if any) is removed or annotated with a rationale
- [ ] No behavioral change — documentation / annotation only

## 🧩 Subtasks

- [ ] Update `dockerStopByPID` doc comment: replace "the container that owns `pid`" with explicit language that it matches `pid` against each container's `State.Pid` (root/init process on the host)
- [ ] Update `containerPID` doc comment: add that `State.Pid` is the container root PID visible on the host
- [ ] Update the routing comment in `kill()` to note that the docker-stop path only succeeds for container root PIDs; daemon/helper processes fall through to POSIX

## 🔗 Related

- [[PID-EPIC-14]] — parent epic: correctness — detectKind false positives + docker-stop clarity

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** `dockerStopByPID` exists in `KillService.swift:83`. The comment on line 81 says "the container that owns `pid`" which misleads readers into thinking it handles any docker-classified process, when it only matches container root PIDs via `State.Pid`. The dead path is the docker-stop branch for daemon/helper processes — always falls through to POSIX. Pure annotation fix, no behavioral change.

- [x] Read relevant source files

- [x] **Archive skim** — PID-14.2 (bun-guard): focused on ScanEngine classification, no docker-stop context. PID-13.6 (audit): only risk-tier assignment notes for docker/uvicorn/node. No load-bearing prior findings.

- [x] **Drift check** — `dockerStopByPID` at KillService.swift:83, `findContainerID` at :94, `containerPID` at :113 — all present, match task description. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Assumptions: (1) "dead path" means the docker-stop branch for non-container-root docker processes, not literally unreachable code; (2) fix is annotation-only — no behavioral change; (3) target is `KillService.swift` only.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

`dockerStopByPID` receives `item.pid` — the PID as observed by `ps aux`. It lists all containers (`docker ps -q`), then for each calls `docker inspect --format {{.State.Pid}}` to get the container's root/init PID on the host (`State.Pid`). If any container's `State.Pid` equals `item.pid`, it runs `docker stop` on that container. This only succeeds when `item.pid` IS a container root process. For the Docker Desktop daemon (`dockerd`) or helper processes — also classified as `.docker` by ScanEngine — `findContainerID` always returns nil, so the docker-stop path is effectively unreachable for those inputs. They fall through to `killPosix`, which gets EPERM (root-owned daemon) and handles it silently.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing comments in KillService.swift use terse `///` doc-comment style; matched that style. `findContainerID` already used "root PID" phrasing — extended it consistently.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — comment-only change, no behavior to test

**Implementation Notes:**

Three comment updates in `KillService.swift`:
1. `kill()` doc (line 17): clarified docker-stop path is only for container root PIDs; daemon/helpers fall through to POSIX
2. `dockerStopByPID` doc (line 82): replaced "owns `pid`" with explicit `State.Pid` matching semantics and fallback note
3. `containerPID` doc (line 115): added `State.Pid` parenthetical ("container's init process as seen on the host")

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — comment-only; no behavior changed, no test applicable

- [x] Ran lint/type-check on changed code — SourceKit shows cross-file scope errors for `ProcessItem` but these are IDE-only artifacts (type resolves in full Xcode build); no real lint issues

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no UI change)

**Testing Notes:**

Comment-only change to `KillService.swift`. No behavioral surface altered.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md: no change. AGENTS.md: no change (no docker-stop refs). CLAUDE.md: no change (kill-flow rule still accurate). PLAN.md: updated as closure.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:**

Annotated three comments in `KillService.swift` to make explicit that `dockerStopByPID` matches `item.pid` against each container's `State.Pid` (root/init process on the host), not arbitrary docker-classified processes. Docker daemon and helper PIDs never match and fall through to POSIX signals — this path is now documented rather than implied.

**Archived:** 2026-06-24
