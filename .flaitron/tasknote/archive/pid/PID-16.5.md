---
title: code-quality audit
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-16, PID-16.1, PID-16.2, PID-16.3, PID-16.4]
---

# PID-16.5 | code-quality audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-16]]

## 🎯 Goal

Verify the completed `PID-EPIC-16` (`code-quality`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [x] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [x] No regressions surfaced in earlier-shipped cohort children's surfaces
- [x] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [x] Single `chore: PID-16.5 — audit PID-EPIC-16` commit lands (no code edits)
- [x] PLAN.md line for `PID-16.5` flipped to stub form `Completed 2026-06-24.`
- [x] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-16.5.md`
- [x] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-16` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [x] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [x] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [x] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [x] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [x] Phase 4: flip `PID-16.5` PLAN line to stub form + archive tasknote
- [x] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-16]] — parent epic: code-quality
- [[PID-16.1]] — discovery subtask
- [[PID-16.2]] — shellout-helper
- [[PID-16.3]] — makeitem-alloc
- [[PID-16.4]] — scanengine-persistence

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User invoked `/ft-close-epic PID-16.5`. All four implementation siblings confirmed closed and archived. PID-16.5 is the highest `.N` child. No open siblings; no early-audit exemption needed.

- [x] Read relevant source files

  Read all four archived tasknotes (PID-16.1 through PID-16.4) and verified cohort deliverables in HEAD: `ScanEngine.swift`, `PortRegistry.swift`, `KillService.swift`.

- [x] **Archive skim** — Cohort children are themselves the archive entries. No non-cohort tasknotes touch `ScanEngine.makeItem`, `PortRegistry.runShell`, or `KillService.runDocker` beyond what the cohort covered.

- [x] **Drift check** — All deliverables verified in HEAD (see Discovery Notes). No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. All four children closed, all deliverables verified in source.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort child inventory (deliverables):**

- **PID-16.1 (discovery):** Filed 3 implementation children (PID-16.2–16.4) in PLAN.md. Identified 5 shell-out sites, double-alloc in `makeItem`, and double-`startTimer` in `init`. No code edits. Audit line PID-16.5 confirmed as-filed.
- **PID-16.2 (shellout-helper):** Extracted `private static func runShell(_ path: String, _ args: [String]) -> String` in `ScanEngine.swift` (line 292) and `PortRegistry.swift` (line 77); `runPS()`/`runLSOF()` are now 1-line wrappers. Extracted `private static func runDocker(_ docker: String, _ args: [String]) -> (output: String, ok: Bool)` in `KillService.swift` (line 85); `findContainerID`/`containerPID`/`dockerStop` updated. Reads-to-EOF invariant preserved. 30 tests passed.
- **PID-16.3 (makeitem-alloc):** Removed draft `ProcessItem` allocation in `ScanEngine.makeItem`; replaced 3 lines with inline `let hasTTY` (line 193) and `let isOrphan` (line 194) computed from `p.tty`/`p.ppid`. 30 tests passed.
- **PID-16.4 (scanengine-persistence):** Rewrote `ScanEngine.init()` to assign `_elapsedThreshold`, `_ignoredNames`, `_scanInterval` via `Published(wrappedValue:)` (bypasses `didSet`); `notificationsEnabled` kept as normal assignment to preserve auth-request side effect. `startTimer()` now called exactly once (line 73). 38 tests passed.

**HEAD verification:**
- `runShell` confirmed at `ScanEngine.swift:292`, `PortRegistry.swift:77` ✓
- `runDocker` confirmed at `KillService.swift:85` ✓
- `hasTTY`/`isOrphan` inline in `ScanEngine.makeItem` at lines 193-194 ✓
- `_scanInterval = Published(wrappedValue:)` at line 71; `startTimer()` once at line 73 ✓
- `startTimer()` at line 20 is inside `scanInterval.didSet` (correct; not in init) ✓

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A: audit is a verification pass over existing deliverables; no new code surface.

- [x] Implemented the minimal solution

  Verification pass complete (see Implementation Notes). No inline fixes needed.

- [x] Updated/added tests — N/A: no code edits.

**Implementation Notes:**

**Cohort coherence findings:**

- **Naming consistency:** `runShell` is used in both `ScanEngine` and `PortRegistry` — correct parallel naming for the same signature. `runDocker` in `KillService` uses a distinct name for the Docker-specific `(output: String, ok: Bool)` tuple variant — appropriate divergence, not an inconsistency.
- **Style parity:** All three helpers use `private static func`, Process/Pipe/wait pattern, and `readDataToEndOfFile()` before `waitUntilExit()`. Consistent across the cohort.
- **No contradictory cross-refs:** PID-16.3 and PID-16.4 both cite PID-16.1 as the discovery source — consistent. PID-16.2 and PID-16.3 both note 30 tests passing; PID-16.4 notes 38 (test suite grew by 8 between PID-16.2 and PID-16.4, which is plausible from other closed tasks). No contradiction — test count is monotonic.
- **No regressions:** Each child ran build + full test suite at closure. PID-16.4 was the final child; its 38-test pass is the latest clean signal.
- **No misses surfaced.** No `/ft-file-followup` candidates.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A: markdown-only audit pass; no code edits.

- [x] Ran lint/type-check on changed code — N/A: no code edits.

- [x] (frontend) Asked the user for visual confirmation — N/A: Swift/macOS, no UI change.

**Testing Notes:**

Audit is verification-only. No code touched. Build + test state inherited from PID-16.4 closure (38/38 passed, build succeeded).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (user-facing surface unchanged by code-quality refactors). `AGENTS.md`: no change (flowtron workflow conventions unchanged). `CLAUDE.md`: no change (Claude-specific directives unaffected). `.flowtron/PLAN.md`: PID-16.5 line flipped to stub form (closure action, not a doc-drift update).

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Audit of `PID-EPIC-16` (`code-quality`) cohort — no inconsistencies surfaced. All four deliverables confirmed in HEAD: `runShell`/`runDocker` shell-out helpers extracted (PID-16.2), `hasTTY`/`isOrphan` inlined in `makeItem` (PID-16.3), `ScanEngine.init` persistence simplified to single `startTimer()` call (PID-16.4). Naming, style, and cross-refs are consistent across the cohort. No regressions; no follow-up filings needed.

**Archived:** 2026-06-24
