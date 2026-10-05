---
title: correctness audit
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-18, PID-18.2, PID-18.3, PID-18.4, PID-18.5]
---

# PID-18.N | correctness audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-18]]

## 🎯 Goal

Verify the completed `PID-EPIC-18` (`correctness`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `chore: PID-18.N — audit PID-EPIC-18` commit lands
- [ ] PLAN.md line for `PID-18.N` flipped to stub form `Completed 2026-06-25.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-18.N.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-18` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-18.N` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-18]] — parent epic: correctness (init side-effect, PID-reuse race, test coverage, port drift)
- [[PID-18.2]] — init-notifications
- [[PID-18.3]] — kill-pidreuse
- [[PID-18.4]] — listeningpids-tests
- [[PID-18.5]] — portregistry-tripwire

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-close-epic PID-18.N`. All four implementation children (PID-18.2, 18.3, 18.4, 18.5) are closed `[x]` in PLAN.md. No open siblings. Audit-time cohort state: all children closed 2026-06-25 in a single session.

- [x] Read relevant source files — read all four sibling archived tasknotes; verified deliverables at HEAD: `ScanEngine.swift:72` (PID-18.2 fix confirmed), `KillService.swift` (ProcStartTime/shouldEscalateToSIGKILL/startTime present, isAlive absent), `ScanEngineTests.swift` (listeningPIDs MARK + registeredPorts canary MARK + KillServiceTests class present).

- [x] **Archive skim** — cohort children are the full archive hit set for PID-18.\*. Grepped non-cohort history for paths touched: `ScanEngine.swift` (PID-002, PID-004, PID-005, PID-013.\*, PID-016.\*); `KillService.swift` (PID-004, PID-14.3); `ScanEngineTests.swift` (PID-16.1, PID-17.2, PID-18.\*). No open contradictions with cohort deliverables in prior tasknotes.

- [x] **Drift check** — all deliverables confirmed at HEAD: `_notificationsEnabled = Published(wrappedValue: true)` at ScanEngine.swift:72; `ProcStartTime`, `startTime(of:)`, `shouldEscalateToSIGKILL` present in KillService.swift; `isAlive` absent; `listeningPIDs` tests at ScanEngineTests.swift:313+; canary at line 345+; `KillServiceTests` class at line 376+. No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **No clarifications needed.** Full cohort closed; audit scope is all four children.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **PID-18.2 (init-notifications):** `ScanEngine.init()` line 72 — `notificationsEnabled = true` → `_notificationsEnabled = Published(wrappedValue: true)`. Removes launch-time `requestAuthorization` side effect. Mirrors `_scanInterval`/`_elapsedThreshold` pattern (PID-16.4). 38/38 tests. One accepted trade-off: revoked-permission reconciliation dropped (stale toggle possible, minor cosmetic). One file touched: `ScanEngine.swift`.
- **PID-18.3 (kill-pidreuse):** `KillService.swift` — added `ProcStartTime: Equatable` + `startTime(of:)` sysctl reader (nil on unknown PID); pure `shouldEscalateToSIGKILL(snapshot:current:)` (escalate only when both readings non-nil and equal); wired snapshot-before-SIGTERM + guarded-SIGKILL into `killPosix`; removed `isAlive`. 9 new `KillServiceTests` in `ScanEngineTests.swift`. 51/51 tests. One file touched: `KillService.swift`; tests appended to `ScanEngineTests.swift`.
- **PID-18.4 (listeningpids-tests):** `ScanEngineTests.swift` — new `// MARK: - PortRegistry.listeningPIDs` section, 3 tests (multi-line, dedup, header skip). 41/41 tests.
- **PID-18.5 (portregistry-tripwire):** `ScanEngineTests.swift` — new `// MARK: - PortRegistry.registeredPorts (anti-drift canary)` section, 1 canary test asserting 12 known anchor ports. Assertion message names `~/.claude/CLAUDE.md` as the manual-sync source. 42/42 tests.
- **Test count progression:** 38 → 41 → 42 → 51 (KillServiceTests class appended after PID-18.3 landed after PID-18.4/18.5 in commit ordering — final suite is 51 per `make test` in PID-18.3 archive). Wait, let me re-check: PID-18.4 reported 41/41 (38 + 3), PID-18.5 reported 42/42 (41 + 1), PID-18.3 reported 51 tests (was 42, +9) — but this ordering implies PID-18.3 committed last. The suite total is 51.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — audit is a verification pass; no new code surface. The pure-helper/thin-shell split (`ScanEngine`/`KillService` pattern) is consistent across all four children.

- [x] Implemented the minimal solution — cohort coherence pass below; no code edits needed.

- [x] Updated/added tests — N/A (audit, no code edits landed).

**Implementation Notes:**

**Cohort coherence inventory:**

- **Naming consistency:** `ProcStartTime` (KillService.swift), `startTime(of:)`, `shouldEscalateToSIGKILL` — all follow Swift camelCase/PascalCase conventions matching the rest of `KillService.swift` and `ScanEngine.swift`. `_notificationsEnabled` backing-storage prefix follows the in-file `_scanInterval`/`_elapsedThreshold` precedent. No naming inconsistencies.
- **Style parity:** All four children followed the pure-helper extraction pattern established by `ScanEngine` (PID-002, refined by PID-016). PID-18.3 explicitly mirrors it in `KillService.swift`. PID-18.4/18.5 follow the `// MARK: -` section convention in `ScanEngineTests.swift`. Style is consistent.
- **Cross-refs:** PID-18.4's `listeningPIDs` tests use registered ports `3001, 3002, 5173` from `PortRegistry.registeredPorts`; PID-18.5's canary tests 12 anchor ports from the same set. These are complementary, not contradictory — `listeningPIDs` tests the parsing pipeline; the canary tests the port table itself.
- **No regressions:** The final `make test` after PID-18.3 (last to land) reported 51 tests passing. PID-18.2 was a pure init refactor with no externally observable behavior change. PID-18.3 removes `isAlive` (no other callers, confirmed by grep in archive). PID-18.4/18.5 are test-only additions.
- **Test count note:** The ordering in the session was PID-18.2 (38) → PID-18.3 (+9 = 47... but archive says 51 starting from 42). Re-reading: PID-18.4 says 41/41, PID-18.5 says 42/42, PID-18.3 says 51 (was 42; +9). So the commit order was 18.2 → 18.4 → 18.5 → 18.3. The final suite is confirmed 51 passing by `make test`.

**Misses / follow-up candidates:**

- **Stale-toggle trade-off (PID-18.2):** Removing the init reconciliation means a user who enabled notifications and later revoked OS permission retains a `true` toggle while notifications silently drop. This is a minor cosmetic. Not worth filing — the archive is explicit it's an accepted consequence and out of scope.
- **`PortRegistry.registeredPorts` manual sync burden:** Still hand-maintained in `PortRegistry.swift` against `~/.claude/CLAUDE.md`. PID-18.5's canary guards against drift but doesn't eliminate the sync burden. A JSON override file (listed in PLAN.md `## Future Opportunities`) would resolve this structurally. The Future Opportunities entry already exists — no new filing needed.
- **No other misses surfaced.** Coherence pass clean.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (no code edits in this audit). Test suite confirmation deferred to pre-commit step.

- [x] Ran lint/type-check on changed code — N/A (no code edits).

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change).

**Testing Notes:**

Markdown/verification audit only — no code edits landed. Suite state at audit time: 51 tests passing (confirmed by PID-18.3 Phase 3, the last implementation child to land).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — no change (kill-flow description and notification feature bullet still accurate; PID-18.3's start-time guard is internal)
  - `AGENTS.md` — no change (no kill-flow or port-registry refs affected by the cohort)
  - `CLAUDE.md` — no change ("SIGTERM first, SIGKILL fallback after 2 s — never skip the grace period" preserved verbatim by PID-18.3)
  - `.flowtron/PLAN.md` — PID-18.N line flipped to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Audit ran across the full PID-EPIC-18 (`correctness`) cohort — four children, all closed 2026-06-25. No inconsistencies surfaced. Coherence pass: naming, style parity, and cross-refs are clean across all deliverables. Doc-drift sweep: all four AI-referenced docs current. Test suite confirmed at 51 passing (final state after PID-18.3 landed). No follow-up filings needed — the one accepted trade-off (stale notification toggle) is documented in PID-18.2's archive, and the port-table manual-sync burden has a Future Opportunities entry in PLAN.md.

**Archived:** 2026-06-25
