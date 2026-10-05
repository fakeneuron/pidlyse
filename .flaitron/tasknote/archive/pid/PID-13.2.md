---
title: cpu-ram-per-row
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13]
---

# PID-13.2 | cpu-ram-per-row

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Add `%cpu` and `rss` columns to the `ps` shell-out, surface them as new fields on `ProcessItem`, and render a compact `0.1% · 48 MB` annotation on each popover row.

## ✅ Acceptance

- [ ] `ScanEngine.runPS()` requests `pcpu=,rss=` columns
- [ ] `ScanEngine.parsePSLine()` parses 6 fixed fields (pid, ppid, etime, tty, pcpu, rss) before args
- [ ] `ProcessItem` carries `cpuPercent: Double` and `rssKB: Int`
- [ ] `ScanEngine.makeItem()` threads new fields through to `ProcessItem`
- [ ] `MenuBarView.row()` shows compact `0.1% · 48 MB` annotation
- [ ] `ScanEngineTests` updated/passing for any parsing changes

## 🧩 Subtasks

- [ ] Update `ScanEngine.runPS()` arguments to include `pcpu=,rss=`
- [ ] Update `ScanEngine.parsePSLine()` to parse 6 fixed fields and return `pcpu`/`rss`
- [ ] Add `cpuPercent: Double` and `rssKB: Int` to `ProcessItem`
- [ ] Update `ScanEngine.makeItem()` to pass `cpuPercent`/`rssKB` through to `ProcessItem`
- [ ] Add compact CPU/RAM annotation to `MenuBarView.row()`
- [ ] Update `ScanEngineTests` for parse changes; verify tests pass

## 🔗 Related

- [[PID-EPIC-13]] — parent epic
- [[PID-13.1]] — discovery that scoped this task

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Task scope is clear and well-defined from PID-13.1 Discovery. All three files cited (`ScanEngine.swift`, `ProcessItem.swift`, `MenuBarView.swift`) exist and match the task description exactly.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source state (confirmed):**
- `ScanEngine.runPS()` (line 241): `ps -axww -o pid=,ppid=,etime=,tty=,args=` — 5 columns, need to add `pcpu=,rss=` before `args=`
- `parsePSLine()` (line 159): loops 4 times to extract fixed fields, then takes remainder as `args`. Need to loop 6 times (add pcpu, rss slots).
- `makeItem()` (line 136): calls `parsePSLine()` and passes fields to `ProcessItem`. Needs to thread `cpuPercent`/`rssKB` through.
- `ProcessItem` (line 49): struct has 7 fields; no cpu/rss. Need to add `cpuPercent: Double` and `rssKB: Int`.
- `MenuBarView.row()` (line 119): shows circle, PID, displayPath, age string, then action buttons. Compact annotation fits alongside or below the PID/displayPath `VStack`.

**Archive skim:** PID-13.1.md confirms design intent ("CPU/RAM per-row display via new `ps` columns + `ProcessItem` fields"). No earlier tasknotes touched these specific fields.

**Drift check:** All file paths, function names, and field names match current code exactly. No drift.

**No clarifications needed.** Explicit assumptions:
- RSS column from `ps` is in KB (macOS default); display as `X MB` (divide by 1024, round) — or `X KB` for sub-MB values.
- `%cpu` is `pcpu` in ps format specifiers; returns a float string like `0.1`.
- Annotation placement: secondary text line inside the existing `VStack(alignment: .leading, spacing: 2)` that already holds PID and displayPath — keeps the row compact.
- No test for `MenuBarView` rendering; `ScanEngineTests` covers parsing only.

Discovery surfaced no significant deviation → skip 🛠️.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

**Pattern survey:** Extended the existing `parsePSLine` loop-and-extract pattern (4 fields → 6), added fields to `ProcessItem` following the existing stored-property convention, and added the annotation as a third `Text` line in the existing 2-line `VStack` in `MenuBarView.row()`.

**Changes:**
- `ScanEngine.runPS()`: added `pcpu=,rss=` to `-o` format string
- `ScanEngine.parsePSLine()`: loop count 4→6; return tuple gains `pcpu: String, rss: String`
- `ScanEngine.makeItem()`: parses `pcpu`→`Double`, `rss`→`Int`; passes through to both `ProcessItem` inits
- `ProcessItem`: added `cpuPercent: Double`, `rssKB: Int` stored properties
- `MenuBarView.row()`: two fixed-width trailing `Text` columns (cpu% 36pt, ram 48pt) via new `ramString()` helper; `resourceAnnotation` approach dropped after user feedback
- `ScanEngineTests`: updated all 6-column `parsePSLine` test inputs + `ProcessItem` initializers

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

`xcodebuild test` — 20/20 passed (including new `pcpu`/`rss` field assertions in `testParsePSLine_withSpacesInArgs`). Build succeeded clean. User confirmed columns look good; revised from single annotation to two fixed-width trailing columns (36pt cpu%, 48pt ram) per user feedback.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - `README.md` — no change (PID-13.4 owns the README refresh)
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `.flowtron/PLAN.md` — updated: PID-13.2 line flipped to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Added per-row CPU% and RSS columns to Pidly's popover. `ps` now requests `pcpu=,rss=` alongside the existing columns; `parsePSLine` parses 6 fixed fields; `ProcessItem` carries `cpuPercent: Double` and `rssKB: Int`; `MenuBarView.row()` renders them as two fixed-width trailing columns (36pt `0.1%`, 48pt `48 MB`) before the age string. All 20 tests pass.

**Archived:** 2026-06-24
