---
title: code-quality discovery
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-16]
---

# PID-16.1 | code-quality discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-16]]

## 🎯 Goal

Scope the `PID-EPIC-16` epic (`code-quality`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-16.2`–`PID-16.4` in `.flowtron/PLAN.md` (and a bumped `.N` if Discovery surfaces additional scope).

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (duplication sites, persistence coupling shape, perf/UX opportunities) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-16.2, PID-16.3, PID-16.4 filed in `.flowtron/PLAN.md` (each line under the 50w target / 70w hard cap)
- [ ] Audit line PID-16.5 reviewed and confirmed as-filed (or rewritten if Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: no AI-referenced doc updates expected for pure Discovery filing

## 🧩 Subtasks

- [ ] Inventory shared design surface (shell-out duplication sites, makeItem alloc shape, ScanEngine persistence coupling, perf/UX candidates) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/pid/` for relevant precedents — log load-bearing findings in Discovery Notes
- [ ] Drift check on cited paths and code locations — flag any drift
- [ ] Surface open scoping questions via AskUserQuestion (per-child shortname + scope) — record answers in "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-16.2–PID-16.4; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under PID-EPIC-16 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip PID-16.1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-16]] — parent epic: code-quality

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User confirmed epic scope; all three duplication sites confirmed in source. N=5 shape is correct (discovery + 3 implementation children + audit). No additional perf/UX scope surfaced beyond the three filed children.

- [x] Read relevant source files

- [x] **Archive skim** — PID-002 noted "reads-to-EOF before `waitUntilExit` to avoid pipe deadlock" for `runPS` — critical invariant for any shell-out helper. No other load-bearing precedents for the three refactor surfaces.

- [x] **Drift check** — all 5 shell-out sites confirmed at cited locations; `makeItem` double-alloc confirmed lines 190-200 of `ScanEngine.swift`; `ScanEngine.init` persistence pattern confirmed.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Shell-out duplication inventory (5 sites):**
  1. `ScanEngine.runPS()` lines 290-305 — Process/Pipe/wait for `/bin/ps`
  2. `PortRegistry.runLSOF()` lines 75-91 — Process/Pipe/wait for `lsof`
  3. `KillService.findContainerID(docker:for:)` lines 98-112
  4. `KillService.containerPID(docker:containerID:)` lines 117-129
  5. `KillService.dockerStop(docker:containerID:)` lines 132-141
  Key constraint: must read to EOF before `waitUntilExit` (pipe deadlock prevention, per PID-002).

- **makeItem double-alloc:** `ScanEngine.makeItem` lines 190-200 constructs a draft `ProcessItem` (riskTier: .moderate) solely to access `hasTTY`/`isOrphan`. Both are trivially computable from `p.tty` and `p.ppid` inline: `hasTTY = !(["??","?","-",""].contains(p.tty.trimmingCharacters(in:.whitespaces)))`, `isOrphan = p.ppid == 1`.

- **ScanEngine persistence:** `@Published` `didSet` handlers write to UserDefaults; `init` conditionally re-reads and assigns, triggering spurious `didSet` → `startTimer()` when a saved value matches the default. Safe refactor: read all values into local vars in `init`, then assign to backing storage directly or use `_scanInterval.wrappedValue` style to avoid `didSet`.

- **Resolved scoping:**
  | Question | Decision |
  |---|---|
  | Shell-out helper placement | Local to each file (KillService gets its own private `runDocker` helper; ScanEngine and PortRegistry each get a local private helper) |

- **No additional perf/UX scope:** `riskColor(_:)` in `MenuBarView` and the hardcoded frame height are intentional design choices; not included.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — CORE-EPIC-057 cohort children are the filing-pattern precedent (2-space indent, `[model]` on every line, em-dash separator, ≤70w descriptions)

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — PLAN.md filing only; no executable code surface

**Implementation Notes:**

- Wrote 3 child lines (PID-16.2, PID-16.3, PID-16.4) under PID-EPIC-16 in `.flowtron/PLAN.md`, between the `.1` discovery line and the `.5` audit line.
- Word counts: PID-16.2 ~33w, PID-16.3 ~20w, PID-16.4 ~22w — all within 50w target.
- Audit line PID-16.5 confirmed as-filed; N=5 is correct.
- Downstream-impact reconciliation scan: no active entries impacted (all High/Medium/Low completed; Future Opportunities unaffected).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — PLAN.md filing only; no test surface

- [x] Ran lint/type-check on changed code — markdown mental-pass complete; all child lines well-formed

- [x] (frontend) Asked the user for visual confirmation — not applicable

**Testing Notes:**

Markdown mental-pass: 2-space indents, bold IDs, [light]🔧 tags, em-dashes, shortnames, word counts all verified clean.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change. `AGENTS.md`: no change. `CLAUDE.md`: no change. `.flowtron/PLAN.md`: .1 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Filed `PID-EPIC-16` (`code-quality`) with 3 scoped implementation children: `shellout-helper` (extract private shell-out helper in 3 files, 5 sites), `makeitem-alloc` (remove draft ProcessItem double-allocation in makeItem), `scanengine-persistence` (fix spurious startTimer calls from @Published didSet in init). N=5 shape confirmed; no downstream impact.

**Archived:** 2026-06-24
