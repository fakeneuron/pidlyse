---
title: process-inspector discovery
status: in-progress
tags: [discovery, ux]
created: 2026-06-30
related-tasks: [PID-EPIC-52, PID-036.3, PID-038]
---

# PID-52.1 | process-inspector discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-52]]

## 🎯 Goal

Scope the `PID-EPIC-52` epic (`process-inspector`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-52.2` and `PID-52.3` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried (MenuBarView `reasoningBlock` / ProcessItem / ScanCore ppid helpers / PortRegistry + CwdResolver lsof split / Shell) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table
- [ ] Concrete child scopes for PID-52.2 and PID-52.3 filed in .flowtron/PLAN.md (each ≤50w target / 70w hard cap per SPEC/tasknote-selection.md)
- [ ] Audit line PID-52.4 reviewed and confirmed as-filed (or rewritten if Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (MenuBarView.swift `reasoningBlock`/`row`, ProcessItem.swift, ScanCore.swift ppid helpers, PortRegistry.swift + CwdResolver.swift lsof pattern, Shell.swift) — log in Discovery Notes
- [ ] Skim .flowtron/tasknote/archive/pid/ for relevant precedents (why-is-this-here, provenance, lsof plumbing) — log load-bearing findings
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (presentation model, open-files scope, ppid-chain depth, child split) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-52.2 and PID-52.3; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-52 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-52]] — parent epic (process-inspector)
- [[PID-036.3]] — provenance hints; added the ppid/port/container lines in `reasoningBlock` this epic deepens
- [[PID-038]] — cwd/project resolution; the CwdResolver bulk-lsof split this epic's open-files fetch mirrors

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator filed PID-EPIC-52 via /ft-epic-discovery to deepen the shipped "Why is this here?" expandable into a full-context inspector (command line, ports, ppid chain, open files) — clearly multi-child scope.

- [x] Read relevant source files

- [x] **Archive skim** — logged below

- [x] **Drift check** — logged below

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface (read):**

- `Pidlyse/MenuBarView.swift` — `row(_:)` (line 274) renders the row + `.contextMenu`; the ⓘ button (line 298) toggles `expandedPIDs`, gating `reasoningBlock(item:isOld:)` (line 350). `reasoningBlock` already shows: criterion tags (no tty/orphan/old), a `tty · ppid · age` monospaced line, listening ports (`engine.listeningPorts[pid]`), a **single-level** `child of <parent>` (via `ScanCore.parentCommand`), and container owner. → **home for .2** (deepen this block) and **.3** (append open-files). Full command line is currently **tooltip-only** (`.help`, line 287), not shown.
- `Packages/.../ProcessItem.swift` — `command` (full `ps` args), `ppid`, `cpuPercent`, `rssKB`, `elapsed` all present. `displayPath` = compact label. → **.2 needs no new ProcessItem data** for the command line; the ppid chain does (see below).
- `Packages/.../ScanCore.swift` — `parentCommand(ofPPID:in:)` (line 140) resolves **only among `engine.items`** (scanned strays). A full chain to launchd needs a **new ps-based ancestor resolver** — mid-chain ancestors (e.g. a login shell) are not stray candidates and are absent from `items`. `runPS()` (line 246) is the `ps -axww` shell-out via `Shell.run`.
- `Packages/.../PortRegistry.swift` + `CwdResolver.swift` — the **canonical lsof split .3 mirrors**: pure parser + `lsofOutput: String? = nil` injectable for unit tests + private `runLSOF()` delegating to `Shell.run("/usr/sbin/lsof", …)`. CwdResolver already does a **per-PID-scoped** lsof (`-a -p <list> -d cwd -Fpn`) — the exact shape .3's on-demand `lsof -p <pid>` extends.
- `Packages/.../Shell.swift` — `Shell.run(path, args)` is the only sanctioned spawn primitive; open-files stays on `/usr/sbin/lsof` (inside the pinned ps/lsof/docker surface — no new binary, per [[PID-049]] security guardrail).

**Archive skim** (load-bearing):

- [[PID-008]] — origin of the ⓘ inline expander + `reasoningBlock` + `criterionTag`; the `.caption2`/`.secondary` text vocabulary .2 extends. Established multi-row simultaneous expansion (`expandedPIDs: Set<Int32>`).
- [[PID-036.3]] — added the port + `child of` lines; **decision: parent resolved over the scan set only** (graceful-degrade nil for launchd/non-candidate). This is exactly the limitation .2's full-chain resolver lifts.
- [[PID-038]] — the CwdResolver bulk-lsof-once-per-scan pattern; .3 deliberately diverges to **on-demand** (per-row, not per-scan) to keep scans cheap.
- [[PID-042]] / [[PID-35.2]] — consolidated all spawns into `Shell.run`; .3 must route its lsof through it, not hand-roll a `Process`.
- [[PID-049]] — ux-feature-survey; the Sloth entry ("GUI for lsof") is the transferable inspiration, and its **security guardrail** pins the shell-out surface to ps/lsof/docker only.

**Drift check:** all cited paths/types/line-refs match HEAD. Two nuances surfaced (not blocking): (1) the **row itself is not clickable** today — only the ⓘ button toggles expansion; the epic's "click a process row" is satisfied by the existing ⓘ affordance (no row-tap gesture added, staying minimal). (2) `parentCommand` scoping (strays-only) is the single real gap driving .2's new resolver — flagged, not silently corrected.

**Resolved scoping** (AskUserQuestion):

| Question | Resolution |
|----------|-----------|
| Presentation model | **Deepen the inline ⓘ expander** — grow `reasoningBlock` into the full-context view; no separate sheet/panel. Matches the epic framing, lowest risk to the fixed-width/height-driven popover (PID-040). |
| Open-files scope + fetch | **Filtered, on-demand** — fetch `lsof -p <pid>` only when a row expands (never per-scan); filter to regular files + sockets, drop dylib/framework noise, cap the list. |
| Parent-chain depth | **Full chain to launchd** — walk ppid ancestors to pid 1, each labelled; needs a new ps-based ancestor resolver in PidlyseCore. |
| Child split | **.2 shell+data / .3 open-files** (vertical) — each child ships visible value; mirrors the EPIC-50 per-affordance precedent. |

**Drafted child lines** (2-space indent under PID-EPIC-52; word-counts exclude ID/model/shortname):

- **.2** `[medium]🧠 | inspector-shell` — Deepen the inline ⓘ expander into a full-context inspector: show the full command line (today tooltip-only) and the complete parent chain to launchd. Add a ps-based ancestor resolver in PidlyseCore (`parentCommand` only sees scanned strays). Listening ports already render. *(~39w)*
- **.3** `[medium]🧠 | inspector-open-files` — Add an open-files list to the inspector, fetched on-demand via `lsof -p <pid>` when a row expands (never per-scan). New pure PidlyseCore parser mirroring PortRegistry/CwdResolver (injectable output, `Shell.run` shell-out); filter to regular files + sockets, drop dylib noise, cap length. *(~40w)*

**Per-child model rationale:** both `[medium]🧠` — each adds new PidlyseCore plumbing (.2 an ancestor resolver, .3 an lsof parser + on-demand service) beyond a clear-diff view tweak, so neither is `[light]`. Parent + .1 + .4 already `[medium]`.

**Audit line:** PID-52.4 confirmed **as-filed** — N stays at 4 (Discovery .1 + children .2/.3 + audit .4); no number bump.

**Downstream-impact scan:** active PLAN entries sharing this surface = the other epics' Discovery/audit placeholders (PID-EPIC-53/54/55/56/57) — none touch the `reasoningBlock`/inspector surface concretely yet (all still un-scoped `.1` Discovery lines). PID-030 (notarize) is unrelated. **No downstream edits** to existing lines.

**Exit-gate judgment:** Discovery surfaced material scope shaping — the four clarifications concretised a new ps-ancestor resolver (.2) and an on-demand-filtered lsof parser (.3). Though the deliverable (file .2/.3) is unchanged and the operator confirmed the recommended path, the child content is now non-trivial and load-bearing → **fire 🛠️** for operator eyes on the exact PLAN lines before writing them (Discovery's whole deliverable IS those lines).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the EPIC-50 cohort-children filing pattern (2-space indent under parent, `[model]` per line, `| shortname`, em-dash separator, ≤50w each)

- [x] Implemented the minimal solution — wrote child lines PID-52.2 and PID-52.3 into PLAN.md between `.1` and the `.4` audit

- [x] Updated/added tests for non-trivial behavior — N/A (pure PLAN.md filing; no executable code)

**Implementation Notes:**

- Filed **2 child lines** (PID-52.2, PID-52.3) under PID-EPIC-52. Word counts (long description, excl. ID/model/shortname): .2 ≈39w · .3 ≈40w — both under the 50w target.
- Both `[medium]🧠` (each adds new PidlyseCore plumbing — a ps-ancestor resolver / an lsof parser + on-demand service).
- **No audit-number bump** — N stayed at 4 (Discovery `.1` + children `.2`/`.3` + audit `.4`); PID-52.4 confirmed as-filed.
- **Downstream-impact scan:** no active PLAN entry shares the inspector/`reasoningBlock` surface concretely (sibling epics are still un-scoped `.1` Discovery lines); no existing lines edited.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (PLAN.md prose only)

- [x] Ran lint/type-check on changed code — N/A (PLAN.md prose only)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed)

**Testing Notes:** Markdown mental-pass on the filed block — 2-space child indent on both lines ✓ · bold `**PID-52.N**` IDs ✓ · `[model]` tag present ✓ · `| shortname` ≤30 chars ✓ · em-dash separator ✓ · long descriptions ≤70w cap ✓ · no trailing whitespace ✓.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md: no change · AGENTS.md: no change · CLAUDE.md: no change · .flowtron/PLAN.md: the child filing itself (SPEC/README contract edits land inside the implementation children, not in this Discovery)

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-52 in `## High`; parent + cohort move to `## Completed` only when all children close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces inline on conditional skip)

**Final Summary:**

Filed the two implementation children for **PID-EPIC-52** (`process-inspector`) and closed its Discovery. Confirmed the recommended vertical split: **.2** inspector-shell — deepen the inline ⓘ `reasoningBlock` into a full-context view (full command line, currently tooltip-only, + full parent chain to launchd via a new ps-based ancestor resolver, since `parentCommand` only sees scanned strays); **.3** inspector-open-files — on-demand `lsof -p <pid>` open-files list (new pure PidlyseCore parser mirroring the PortRegistry/CwdResolver split, filtered to regular files + sockets, capped). Design surface inventoried across MenuBarView / ProcessItem / ScanCore / PortRegistry / CwdResolver / Shell; listening ports already render (PID-036.3); open-files stays inside the pinned ps/lsof/docker shell-out surface. Audit **.4** confirmed as-filed (N=4). No downstream impact.

**Archived:** 2026-06-30
