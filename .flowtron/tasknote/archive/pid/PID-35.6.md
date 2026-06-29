---
title: security-sweep audit
status: in-progress
tags: [security, audit, epic-close]
created: 2026-06-28
due:
related-tasks: [PID-EPIC-35, PID-35.1, PID-35.2, PID-35.3, PID-35.4, PID-35.5]
---

# PID-35.6 | security-sweep audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-35]]

## 🎯 Goal

Verify the completed `PID-EPIC-35` (`security-sweep`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-35.6 — audit PID-EPIC-35` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-35.6` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-35.6.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-35` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-35.6` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-35]] — parent epic (security-sweep); this audit closes it
- [[PID-35.1]] — Discovery (findings inventory F1–F9, child filing)
- [[PID-35.2]] — stderr-drain (F1)
- [[PID-35.3]] — kill-path-hardening (F2 + F8)
- [[PID-35.4]] — smells-cleanup (F6/F7/F9)
- [[PID-35.5]] — ci-sha-pinning (F5)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md — PID-EPIC-35 under `## Medium`; children .1–.5 all `[x]`, .6 (this audit) is the highest `.N`. No open siblings → full cohort, no early-audit.

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User invoked `/ft-close-epic PID-35.6`; Step 2 pre-flight passed (highest `.N`, parent active, all impl children closed). Goal: capture cohort state at audit time and verify the five remediation children sit coherently against each other and HEAD.

- [x] Read relevant source files — all five archived cohort tasknotes (PID-35.1 discovery + .2/.3/.4/.5 impl children), plus the deliverable surfaces at HEAD (ScanCore/PortRegistry/ProcessItem in PidlyseCore; KillService/DockerService in app; both CI workflows; README §Security).

- [x] **Archive skim** — cohort children are themselves the archive entries; read each Final Summary + Implementation Notes. Non-cohort precedents the cohort builds on (PID-16.2 stdout-drain invariant, PID-18.3 start-time primitive, PID-28.2 DockerService.cliPath) noted but unchanged by this audit.

- [x] **Drift check** — every cited symbol/path present at HEAD, zero drift: F1 `nullDevice` in all 3 helpers (ScanCore.swift:185, PortRegistry.swift:119, DockerService.swift:66); F2/F8 `ProcStartTime` public in PidlyseCore (ProcessItem.swift:61), `ProcessItem.startTime` (:90), `shouldSendSIGTERM` (KillService.swift:90), `isTrustedOwnership` (DockerService.swift:42), `typealias` (KillService.swift:55); F6/F7/F9 `static var effectivePorts` (PortRegistry.swift:54), `hasTokenBoundary` (ScanCore.swift:143), bulk `State.Pid` inspect (KillService.swift:155), `containerPID` removed; F5 SHA pin in both workflows, no mutable `@vN` remaining.

- [x] Asked clarifying questions — **No clarifications needed.** Cohort fully closed, drift-free, tests green; audit scope is unambiguous.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Cohort inventory (5 children, all closed 2026-06-28)

| Child | Cluster | Deliverable |
|---|---|---|
| PID-35.1 discovery | — | Read ~2.1k LOC; confirmed injection-free baseline; inventoried F1–F9; filed .2–.5; folded F3/F4 into PID-030 |
| PID-35.2 stderr-drain | F1 | `standardError = FileHandle.nullDevice` in all 3 shell-out helpers — closes the stderr side of the PID-16.2 drain-before-wait invariant; deadlock removed by construction |
| PID-35.3 kill-path-hardening | F2 + F8 | Scan-time `ProcStartTime` token on `ProcessItem` (moved to PidlyseCore) + `shouldSendSIGTERM` re-verify before initial SIGTERM; `isTrustedOwnership`/`isTrustedExecutable` docker-binary trust gate. +13 tests; README §Security updated |
| PID-35.4 smells-cleanup | F6/F7/F9 | `effectivePorts` `static let`→`static var` (hot-reload); `hasTokenBoundary` token-match in `detectKind`; single bulk `docker inspect` in `findContainerID`; `containerPID` removed. +2 tests |
| PID-35.5 ci-sha-pinning | F5 | `actions/checkout@v4` → `@34e1148…` (v4.3.1) SHA pin in both workflows |

### Cohort state at audit time

- Full cohort closed; no early-audit, no deferred children. F3/F4 folded into PID-030 (Future Opportunities), cross-ref present at PLAN.md:29.
- `make test` → **82 passed, 0 failures** — matches PID-35.4's closing count; no regression across the cohort.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A (verification pass; no new code surface). The audit reads the cohort's existing deliverables against each other and HEAD.

- [x] Implemented the minimal solution — verification work; coherence findings below. No inline fixes needed (no inconsistencies surfaced).

- [x] Updated/added tests for non-trivial behavior — N/A (no code edits).

**Implementation Notes:**

### Coherence findings — no inconsistencies surfaced

- **Single impure docker access point holds (positive coherence).** PID-35.4's F9 rewrite routes its new bulk `docker inspect` through `DockerService.run` (KillService.swift:155), so it automatically inherits *both* PID-35.2's `nullDevice` stderr fix (F1) and PID-35.3's `isTrustedExecutable` binary-trust gate (F2). The CLAUDE.md "all docker invocations live in DockerService" convention kept the three fixes composable rather than divergent.
- **Start-time primitive extended, not duplicated.** PID-35.3 moved `ProcStartTime` to PidlyseCore and reused PID-18.3's `startTime(of:)`/`shouldEscalateToSIGKILL` rather than forking a parallel token type. `KillService` keeps a `typealias` so the four pre-existing `KillService.ProcStartTime` test refs stayed valid — additive, no churn.
- **Kill-flow non-negotiable preserved.** SIGTERM → 2 s grace → SIGKILL is byte-for-byte intact across the cohort (PID-35.3 added a *pre*-SIGTERM identity gate without touching the grace/escalation path). CLAUDE.md invariant honored.
- **Doc parity.** README §Security narrative coherently carries the F2 (docker-binary trust + residual `/usr/local/bin` gap) and F8 (PID-reuse refuses *either* signal) updates from PID-35.3 in one voice; no contradictory or stale cross-refs against the shipped code. (PID-35.3's tasknote cites "README bullets 51/52" by line number — the section has since been reworded into prose, but that reference lives inside an archived tasknote, not a live doc, so no action.)
- **F-numbering + naming consistency.** All five children reference the shared F1–F9 inventory from PID-35.1 consistently; shell-out helper names, cluster→child mapping, and `[[wikilink]]` cross-refs are uniform across the cohort.

### Misses / follow-ups

- **None.** Zero drift, no regressions, no coherence inconsistencies. No `/ft-file-followup` candidates to file. F3/F4 remain correctly parked in PID-030 (deferred, gated on Apple Developer enrollment) per the Discovery decision.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **82 tests, 0 failures**. Confirms the cohort sits green end-to-end (no audit code edits; run is a regression check over the assembled cohort).

- [x] Ran lint/type-check on changed code — N/A (no code edits; this audit changes only PLAN.md + the tasknote). Drift-check greps in Phase 1 stand in for a structural lint of the cohort deliverables.

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI surface; audit is doc/verification only).

**Testing Notes:** No new test surface. The 82/0 run is a regression gate over the closed cohort, matching PID-35.4's closing count exactly — nothing drifted or broke after the last child landed.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md)** — `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — **no change.** The F2/F8 §Security updates already landed in PID-35.3; this audit verified them coherent and adds nothing.
  - `AGENTS.md` — **no change.** No kill-flow / shell-out / docker-resolution policy to update.
  - `CLAUDE.md` — **no change.** The SIGTERM→2s→SIGKILL non-negotiable and the "docker plumbing stays in DockerService" convention both still hold post-cohort (the audit confirmed they were honored).
  - `.flowtron/PLAN.md` — **updated** (this closure: `.6` flipped to stub; parent flip + cohort move on operator confirm).

- [x] Closed — PLAN.md `.6` line flipped to stub form `Completed 2026-06-28.`; tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Audited the closed PID-EPIC-35 (`security-sweep`) cohort — **no inconsistencies surfaced, no follow-ups to file.** The five children (.1 discovery + .2 stderr-drain/F1, .3 kill-path-hardening/F2+F8, .4 smells-cleanup/F6/F7/F9, .5 ci-sha-pinning/F5) sit coherently against each other and HEAD: every cited symbol/path verified present with zero drift, and `make test` is green at 82/0 (matching PID-35.4's closing count — no regression). Key coherence win: the single-impure-docker-access-point convention (CLAUDE.md) kept the three docker-touching fixes composable — PID-35.4's bulk `docker inspect` automatically inherits PID-35.2's stderr `nullDevice` and PID-35.3's binary-trust gate because all route through `DockerService.run`. The kill-flow non-negotiable (SIGTERM→2s→SIGKILL) is byte-for-byte intact; PID-35.3 added only a pre-SIGTERM identity gate. README §Security carries the F2/F8 doc updates in one voice with no stale cross-refs. F3/F4 remain correctly parked in PID-030 (deferred, Apple-enrollment-gated). No code edits landed — closure is PLAN.md flip + tasknote archive only.

**Archived:** 2026-06-28
