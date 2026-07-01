---
title: process-inspector audit
status: in-progress
tags: [audit, ux]
created: 2026-06-30
related-tasks: [PID-EPIC-52, PID-52.1, PID-52.2, PID-52.3]
---

# PID-52.4 | process-inspector audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-52]]

## 🎯 Goal

Verify the completed `PID-EPIC-52` (`process-inspector`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-52.4 — audit PID-EPIC-52` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-52.4` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-52.4.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-52` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-52.4` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-52]] — parent epic (process-inspector)
- [[PID-52.1]] — Discovery: scoped the cohort
- [[PID-52.2]] — inspector-shell (command line + parent chain; `AncestryResolver`)
- [[PID-52.3]] — inspector-open-files (on-demand `lsof`; `OpenFilesResolver`)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator invoked `/ft-close-epic PID-52.4`; Step 2 pre-flight passed — `.4` is the highest child of `PID-EPIC-52`, no open siblings (`.1`/`.2`/`.3` all closed 2026-06-30). Capture cohort state and verify integration coherence.

- [x] Read relevant source files

- [x] **Archive skim** — read all three cohort children's archived tasknotes (logged below)

- [x] **Drift check** — cited deliverables verified against HEAD (logged below)

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — **No clarifications needed**; the one finding (README staleness) is an unambiguous in-scope inline fix, not a user decision.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort state (all closed 2026-06-30):**

- **PID-52.1** (`discovery`) — scoped the vertical split (.2 shell+data / .3 open-files); confirmed audit `.4` as-filed (N=4). No code.
- **PID-52.2** (`inspector-shell`) — new `AncestryResolver.swift` in PidlyseCore (`ProcessNode` + pure `processTable(psOutput:)` + `ancestorChain(ofPPID:in:)` cycle-guarded walk + private `ps -axo pid=,ppid=,comm=` via `Shell.run`); `ScanEngine` publishes `processTable` per-scan; `reasoningBlock` shows the full command line (was `.help` tooltip) + full `child of … ← launchd` chain. `parentCommand` kept as a still-valid public helper. 9 unit tests. CLAUDE.md core-file list updated.
- **PID-52.3** (`inspector-open-files`) — new `OpenFilesResolver.swift` in PidlyseCore (`OpenFile`/`OpenFileList` + pure `parseOpenFiles(lsofOutput:)` numeric-fd/REG+socket filter + `openFiles(forPID:…)` composer + private `lsof -p <pid> -Fftn` via `Shell.run`); `ScanEngine` gained on-demand `openFiles` cache + `loadOpenFiles(for:)` (first on-demand provenance fetch); `reasoningBlock` appends the capped (15 + `+N more`) list, triggered by `.onAppear`. 10 unit tests. CLAUDE.md core-file list updated.

**Drift check (vs HEAD):**

- Both new files present: `Packages/PidlyseCore/Sources/PidlyseCore/AncestryResolver.swift`, `OpenFilesResolver.swift` ✓
- `CLAUDE.md` Conventions core-file list (line 18) already lists **both** `AncestryResolver.swift` and `OpenFilesResolver.swift` — both children's doc-drift updates landed ✓
- `ScanEngine.swift`: `processTable` per-scan map + `openFiles` on-demand cache + `loadOpenFiles(for:)` all present and correctly commented ✓
- `MenuBarView.swift`: `reasoningBlock` renders command line + `ancestorChain` chain + open-files list; `.onAppear { engine.loadOpenFiles(for:) }` wired ✓
- Working tree clean except this new tasknote ✓

**Coherence findings:**

- **Naming/style parity — consistent.** Both resolvers mirror the canonical `PortRegistry`/`CwdResolver` split (pure injectable parser + private `Shell.run` shell-out). `@Published private(set)` provenance maps in `ScanEngine` share one idiom; `openFiles` correctly diverges to on-demand with in-comment justification. Static-func call sites (`AncestryResolver.processTable()`, `OpenFilesResolver.openFiles(forPID:)`) parallel `PortRegistry.listeningPorts()`.
- **No contradictory cross-refs.** ScanEngine comments cite PID-037.3 / PID-52.3 / `AncestryResolver.ancestorChain` accurately.
- **No regressions** in earlier-shipped surfaces — `reasoningBlock` composes all three provenance lines cleanly; `parentCommand` retained (unused in-app, valid helper) per .2's flagged decision.

**Doc-drift sweep (fixed line) — see Phase 4.** One cumulative miss surfaced: README line 10's expandable-detail enumeration still reads "its scanned parent process" and omits the full command line + open files — stale after the cohort deepened this exact block. Each per-task Phase 4 deferred README ("doesn't enumerate the inspector's contents"), but line 10 *does* partly enumerate it → the audit's cumulative sweep catches it. Resolved via inline fix (Phase 2).

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A code-wise; the audit is a verification pass over the shipped cohort. The one inline fix follows the README's existing parenthetical feature-enumeration style.

- [x] Implemented the minimal solution — applied the one in-scope inline doc fix (README line 10)

- [x] Updated/added tests for non-trivial behavior — N/A (README markdown only)

**Implementation Notes:**

**Cohort inventoried (deliverables read against each other):**

- **.2 inspector-shell** — `AncestryResolver` (full parent chain to launchd) + full command line in `reasoningBlock`.
- **.3 inspector-open-files** — `OpenFilesResolver` (on-demand `lsof`) + capped open-files list appended to the same block.
- Both mirror the `PortRegistry`/`CwdResolver` pure-parser + `Shell.run` split; `ScanEngine` provenance maps share one `@Published private(set)` idiom (`.3` diverges to on-demand by design).

**Coherence: no inconsistencies surfaced** — naming/style parity holds, cross-refs accurate, no regressions in `.2`'s surfaces from `.3`'s additions, `parentCommand` retained as a valid helper.

**Inline fix applied:**

- `README.md:10` — expandable-detail enumeration refreshed to match the deepened inspector: renamed "detail" → "inspector" (the epic's framing), added "the full command line" and "its open files + sockets", and replaced the stale "its scanned parent process" with "its full parent chain up to launchd". Cumulative staleness the per-task `.2`/`.3` Phase 4 sweeps each deferred as "README doesn't enumerate the inspector's contents" — but line 10 *does* partly enumerate them, so the audit's cumulative sweep is the correct catch point.

**Misses logged as `/ft-file-followup` candidates:** none — the sole finding was resolved inline.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (README markdown only; no code compiled)

- [x] Ran lint/type-check on changed code — N/A (markdown prose)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed; README doc edit only)

**Testing Notes:** Markdown-prose verification only. The inline fix is a single feature-line edit; no source touched, so the shipped-and-verified cohort build (9 + 10 targeted tests green across `.2`/`.3`) stands unchanged.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** (line 10 inspector enumeration — full command line, full parent chain to launchd, open files + sockets) · `AGENTS.md`: no change (doesn't enumerate core files or inspector contents) · `CLAUDE.md`: no change (both `AncestryResolver.swift`/`OpenFilesResolver.swift` already in the core-file list from `.2`/`.3`) · `.flowtron/PLAN.md`: the `.4` stub flip + parent-epic flip

- [x] Closed — PLAN.md `.4` line flipped to stub form `Completed 2026-06-30.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Audited the completed **PID-EPIC-52** (`process-inspector`) cohort — Discovery `.1`, `inspector-shell` `.2`, `inspector-open-files` `.3`. The cohort sits coherently: both new PidlyseCore resolvers (`AncestryResolver`, `OpenFilesResolver`) mirror the canonical `PortRegistry`/`CwdResolver` pure-parser + `Shell.run` split, `ScanEngine`'s provenance maps share one idiom (`.3`'s on-demand `openFiles` cache is a deliberate, documented divergence), cross-refs are accurate, and `.3`'s additions caused no regression in `.2`'s surfaces. The fixed doc-drift sweep caught one cumulative miss the per-task Phase 4 closures deferred: README line 10 still described the expandable detail as showing "its scanned parent process" and omitted the now-visible full command line and open-files list — fixed inline (the only edit this audit landed). No follow-ups filed.

**Archived:** 2026-06-30
