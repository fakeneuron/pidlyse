---
title: popover-power-ux discovery
status: in-progress
tags: [discovery, ux]
created: 2026-06-30
related-tasks: [PID-EPIC-50, PID-049]
---

# PID-50.1 | popover-power-ux discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-50]]

## 🎯 Goal

Scope the `PID-EPIC-50` epic (`popover-power-ux`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-50.2..7` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (MenuBarView / ProcessItem / SettingsView / ScanCore sources, SPEC contract impact) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-50.2 .. PID-50.7 filed in .flowtron/PLAN.md (each line under the 50w target / 70w hard cap per SPEC/tasknote-selection.md §"PLAN.md filing-discipline thresholds")
- [ ] Audit line PID-50.8 reviewed and confirmed as-filed (or rewritten if the Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (MenuBarView.swift, ProcessItem.swift, SettingsView.swift, ScanCore.swift) — log in Discovery Notes
- [ ] Skim .flowtron/tasknote/archive/pid/ for relevant precedents (popover-UI, settings) — log load-bearing findings in Discovery Notes
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (per-child boundary + ordering + dependencies) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-50.2 .. PID-50.7; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-50 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-50]] — parent epic
- [[PID-049]] — ux-feature-survey; sourced the Tier 1+2 shortlist this epic triages

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator triaged the [[PID-049]] survey's Tier 1+2 shortlist into this epic via `/ft-epic-discovery`; six in-character popover/settings affordances — clearly multi-child scope.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface (read):**

- `Pidlyse/MenuBarView.swift` — popover content. Rows grouped by `kind` (`grouped()`) within Safe/Review sections; per-kind collapsible groups. `row(_:)` already renders risk dot, PID, `rowDescriptor` (provenance/project label via `engine.cwds[pid].label`), CPU%, RAM, age + info/dismiss/kill buttons. Width 320, content height 360. → home for .2 (context menu), .3 (sort), .4 (footprint), .5 (filter), part of .7.
- `Packages/PidlyseCore/Sources/PidlyseCore/ProcessItem.swift` — `ProcessItem` already carries `cpuPercent`, `rssKB`, `elapsed`, and `command`; `ProcessKind` is a `CaseIterable` enum with `.label`. → **.3 and .4 need no new data**; .6's toggle set keys off `ProcessKind.allCases`.
- `Pidlyse/SettingsView.swift` — `Form` of `Section`s bound to `@ObservedObject engine: ScanEngine`; existing free-text "Ignored processes" (`ignoredNames`, newline-split). → .6 adds a parallel "Scanned kinds" section + a `disabledKinds` set on `ScanEngine`.
- `Pidlyse/AppDelegate.swift` — owns the `NSPopover`. **`popover.behavior = .transient` already set (line 38)**, `NSPopoverDelegate` wired. → relevant to .7.

**Archive skim** (popover/settings precedents): PID-003 (popover-ui, the original two-section layout), PID-040 (popover-realign — popover sizing/arrow drift care), PID-021 (collapsible sections), PID-022/023 (settings-open / right-click-menu), PID-13.2 (cpu-ram-per-row — added the CPU/RAM columns .4 sums). Load-bearing: the popover's width-fixed / height-driven sizing is deliberate (PID-040 comment in AppDelegate) — new header content (.4) and a filter field (.5) must not destabilize the arrow anchor. The `Set.toggle` extension at the bottom of MenuBarView (PID-045) is the idiom for collapse/selection sets.

**Drift check:** Paths/types cited above all match HEAD. **One material drift vs the survey's framing:** the popover is *already* `.transient`, so Esc-to-dismiss and click-outside-to-dismiss may already (partly) work — `.7` must **verify empirically on a build** before adding any event monitor, not assume the behavior is missing. No other drift.

**Resolved scoping** (AskUserQuestion):

| Question | Resolution |
|----------|-----------|
| Sort (.3) — control vs auto | **No sort control.** Reinterpreted to a deterministic **alphabetical auto-sort by the provenance label** (`rowDescriptor`) within each kind group. Scope shrinks → `[light]`. |
| Per-kind toggles (.6) vs substring ignore | **Complement** — add a new "Scanned kinds" toggle section; keep the existing free-text substring ignore. Two distinct tools. |
| Keyboard nav (.7) depth | **Minimal** — ⌘⌫ kills the selected/sole safe row; **no** arrow-key traversal. Plus two operator notes: **Esc dismisses the popover**, and **click-outside dismisses the dropdown** (verify against the already-`.transient` popover). |

**Per-child model rationale:** .2/.3/.4 are small, MenuBarView-local, clear-diff → `[light]🔧`; .5/.6/.7 carry more surface (filter state / Settings+core persistence / popover focus+dismissal) → `[medium]🧠`. Parent + .1 + .8 filed `[medium]🧠`.

**Exit-gate judgment:** Clarifications surfaced and shifted scope (.3 reinterpreted as auto-sort; .7 gained the dismissal requirements). Per the `default-fire-on-clarifications` flavor → **fire the 🛠️ Phase 1→2 gate** before writing the child lines.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the PID-EPIC-13 / EPIC-28 cohort-children filing pattern (2-space indent under parent, `[model]` per line, em-dash separator, ≤50w each)

- [x] Implemented the minimal solution — wrote child lines PID-50.2 .. PID-50.7 into PLAN.md between `.1` and `.8`

- [x] Updated/added tests for non-trivial behavior — N/A (pure PLAN.md filing; no executable code)

**Implementation Notes:**

- Filed **6 child lines** (PID-50.2–.7) under PID-EPIC-50. Word counts (long description, excl. ID/model/shortname): .2 ≈35w · .3 ≈33w · .4 ≈27w · .5 ≈33w · .6 ≈34w · .7 ≈37w — all under the 50w target.
- Per-child models: .2/.3/.4 `[light]🔧`; .5/.6/.7 `[medium]🧠`.
- **No audit-number bump** — N stayed at 8 (Discovery `.1` + 6 children + audit `.8`); audit line PID-50.8 confirmed as-filed.
- **Downstream-impact scan:** active PLAN beyond this cohort = PID-030 (notarize-and-sign, Future Opportunities) only — unrelated surface (signing/notarization vs popover/settings UX). **No downstream impact**; no existing lines edited.
- Scope shifts from Discovery captured in the child lines: .3 filed as auto-sort (not a control); .7 filed with the Esc + click-outside dismissal requirements + the already-`.transient` verify-on-build note.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (PLAN.md prose only)

- [x] Ran lint/type-check on changed code — N/A (PLAN.md prose only)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed)

**Testing Notes:** Markdown mental-pass on the filed block — 2-space child indent on every line ✓ · bold `**PID-50.N**` IDs ✓ · `[model]` tag present on each ✓ · `| shortname` ≤30 chars ✓ · em-dash separator ✓ · all long descriptions ≤70w cap ✓ · no trailing whitespace ✓.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md: no change · AGENTS.md: no change · CLAUDE.md: no change · .flowtron/PLAN.md: the epic+children filing itself (SPEC contract edits land inside the implementation children, not in this Discovery)

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-50 in `## Medium`; parent + cohort move to `## Completed` only when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces inline on conditional skip)

**Final Summary:**

Filed epic **PID-EPIC-50** (`popover-power-ux`) and closed its Discovery. Triaged the [[PID-049]] survey's Tier 1+2 shortlist into six implementation children + an audit: **.2** row-context-menu, **.3** provenance-sort (rescoped to a deterministic alphabetical auto-sort — no control), **.4** reclaimable-footprint header, **.5** quick-filter, **.6** per-kind scan toggles (complements the substring ignore), **.7** popover-keys + Esc/click-outside dismissal (popover already `.transient` → verify on build), **.8** audit (confirmed as-filed, N=8). Design surface inventoried across MenuBarView / ProcessItem / SettingsView / AppDelegate; ProcessItem already carries the CPU/RAM/age data .3/.4 need. No downstream impact on existing entries.

**Archived:** 2026-06-30
