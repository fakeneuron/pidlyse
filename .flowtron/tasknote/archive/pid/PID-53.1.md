---
title: clean-history-stats discovery
status: in-progress
tags: []
created: 2026-06-30
due:
related-tasks: [PID-EPIC-53, PID-53.4]
---

# PID-53.1 | clean-history-stats discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-53]] [[PID-53.4]]

## 🎯 Goal

Scope the shared design for the `clean-history-stats` epic — persist a log of
cleaned processes and surface value stats + a "Recently cleaned" view — and
file the implementation children `.2` and `.3` into PLAN.md.

## ✅ Acceptance

- [ ] Shared design decided: capture point, event model, storage, stats
      semantics, view placement, privacy posture
- [ ] Children `.2` and `.3` filed in PLAN.md under PID-EPIC-53 with clear,
      non-overlapping scope
- [ ] Deliverable is the filed child task list, not code

## 🧩 Subtasks

- [ ] Confirm the epic's shared-design decisions (clarifying questions)
- [ ] Decide the `.2` / `.3` split boundary
- [ ] Write the `.2` and `.3` PLAN.md lines
- [ ] Close per epic Discovery flow

## 🔗 Related

- [[PID-EPIC-53]] — parent epic (clean-history-stats)
- [[PID-53.4]] — final audit subtask (files at close of the epic)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [ ] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Epic is freshly filed and the feature (persistent clean log +
  value stats + Recently-cleaned view) has no existing implementation. The
  session-scoped `safeReclaimableKB` footprint is the natural predecessor this
  extends. No drift; work is clearly still wanted.

- [x] Read relevant source files

- [x] **Archive skim** — see Discovery Notes.

- [x] **Drift check** — see Discovery Notes.

- [x] Asked clarifying questions — three design forks resolved (see below).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

*Current surface (verified at HEAD):*
- Session footprint: `MenuBarView.safeReclaimableKB` (:457) = Σ `rssKB` of
  safe items → "~X MB reclaimable" header (:200). Transient; recomputed per scan.
- Kill flow: `KillService.kill(_:containerOwners:onComplete:)` → `onComplete`
  triggers `engine.scan()`. **`onComplete` fires regardless of outcome** — on a
  real kill, on EPERM (root docker daemon), and on recycled/gone PIDs
  (`killPosix` guard + EPERM branch both call `onComplete`). No success signal
  is threaded out today.
- Persistence: only `UserDefaults` config on `ScanEngine`. No structured/on-disk
  store exists.
- UI: `MenuBarView` 2-segment picker (Processes/Containers), fixed width 320.

*Archive skim (`archive/pid/`):*
- KillService touched by PID-003/004/005, PID-18.3, PID-27.x, PID-28.x,
  PID-35.3 (kill-path hardening — PID-reuse guard, `ProcStartTime`), PID-50.7.
  Kill is a *hardened, protected* path (grace period never skipped; PID-reuse
  re-verification). Any change to thread a success signal out must not weaken it.
- Persistence: no prior tasknote persisted **process metadata** — only config
  (`UserDefaults` in PID-006/010/016.x/027.x/050.x). A clean log is the first
  on-disk record of scanned processes.
- PID-EPIC-35 security sweep (PID-35.1/35.6): app is unsandboxed by necessity;
  trust-boundary review covered shell-out + kill race but **not persistence of
  command lines** (nothing persisted then). New consideration for this epic.

*Load-bearing design decisions (shared across .2/.3):*
1. **Capture point / accuracy.** Log optimistically at click, or record only a
   *confirmed* kill? Confirmed requires threading an outcome out of
   `KillService` (a protected path). Optimistic over-counts EPERM daemons /
   recycled PIDs that reappear next scan, corrupting "RAM reclaimed".
2. **Event model.** Per-process record (needed for top-kinds + RAM math):
   timestamp, kind (rawValue), project/displayPath label, rssKB (estimate
   captured at kill), pid. "Clean all" logs N per-process events, not one batch.
3. **Privacy — what to store.** Full command line (richest history detail, may
   embed secrets like `--api-key=…`) vs. minimal (kind + project label + rssKB
   + timestamp, no raw command). App is unsandboxed; file is world-readable-ish.
4. **Storage.** JSON file in `~/Library/Application Support/Pidlyse/` vs.
   `UserDefaults`. A growing log favors a file. Retention: cap by count or age.
5. **Stats semantics.** "Cleaned this week" = rolling 7 days (default). RAM
   reclaimed = Σ rssKB over a window. Top stray kinds = frequency by kind.
6. **View placement.** Third segment ("History"/"Cleaned") vs. a stats strip +
   list elsewhere. Three tabs at width 320 is tight but feasible.

*Split proposal (Core/App convention mirrors PortRegistry/DockerCore):*
- **.2 — persistence + capture (data layer):** `CleanEvent` model + pure
  aggregation/stats logic in PidlyseCore (`CleanLog.swift`); app-side store owns
  disk I/O + the kill-hook wiring; extend `KillService` to report kill outcome
  if "confirmed only" is chosen. No/minimal UI. Unit-tested stats.
- **.3 — stats + Recently-cleaned view (presentation layer):** consume the .2
  store to render the value stats (this week / RAM / top kinds) and the
  Recently-cleaned list in the popover.

*Resolved design forks (operator, 2026-06-30):*
1. **Capture accuracy → Confirmed kills only.** `.2` extends `KillService` to
   report whether the process actually died (additive; must not weaken the
   grace-period / PID-reuse guards) and logs only confirmed kills. Excludes
   EPERM daemons + recycled PIDs so "RAM reclaimed" stays honest.
2. **What to persist → Minimal (privacy-first).** `CleanEvent` = kind +
   project/displayPath label + rssKB + timestamp. **No raw command line** —
   avoids writing secrets in process args to a world-readable file.
3. **View placement → Third segmented tab.** `.3` adds a "Cleaned" segment
   beside Processes/Containers for the stats strip + Recently-cleaned list.

*Downstream-impact scan:* no active PLAN entry conflicts. `CleanEvent`/stats
live in PidlyseCore, so [[PID-EPIC-57]] (cli-companion) could later reuse them —
noted, no reconcile action needed.

*Child split filed → `.2` = clean-log-store, `.3` = cleaned-tab-stats.*

**Phase 1→2 exit:** Discovery surfaced no significant deviation → skip 🛠️.
The epic's planned child count (`.2..3`) held exactly; clarifications shaped
child content within scope, not the scope itself.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — the `.2`/`.3` split mirrors the established
  Core/App convention (pure model + logic in PidlyseCore à la
  PortRegistry/DockerCore; impure I/O + wiring app-side à la ScanEngine's
  UserDefaults ownership) and the prior epic Discovery→Impl→Audit shape
  (PID-EPIC-52, PID-EPIC-37).

- [x] Implemented the minimal solution — filed `PID-53.2` (clean-log-store)
  and `PID-53.3` (cleaned-tab-stats) under PID-EPIC-53 in PLAN.md.

- [x] Updated/added tests — N/A (Discovery deliverable is the filed child
  list, not code).

**Implementation Notes:** Deliverable is planning, not code — see the filed
PLAN.md lines and the resolved design forks in Discovery Notes.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite — N/A (no code changed).

- [x] Ran lint/type-check — N/A (markdown-only edits).

- [x] (frontend) Visual confirmation — N/A.

**Testing Notes:** Planning-only task; no build/test surface touched.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — AI-referenced docs: `README.md` — no change (no
  shipped feature yet); `AGENTS.md` — no change; `CLAUDE.md` — no change;
  `.flowtron/PLAN.md` — updated (the `.2`/`.3` filing is this task's artifact).

- [x] Closed — PID-53.1 PLAN.md line flipped to stub form (in place under
  PID-EPIC-53; parent stays open) and tasknote moved to `archive/pid/`.

- [x] Recap drafted.

**Final Summary:** Scoped the clean-history-stats epic and filed two
implementation children. Resolved three design forks with the operator:
(1) log **confirmed kills only** — `.2` extends `KillService` to report real
deaths; (2) persist a **minimal, privacy-first** `CleanEvent` (kind + project
label + rssKB + timestamp, no command line); (3) surface via a **third
"Cleaned" popover tab**. Split is data-layer (`.2` clean-log-store, PidlyseCore
model + pure stats + app store + kill-hook) → presentation-layer (`.3`
cleaned-tab-stats). No downstream PLAN conflicts.

**Archived:** 2026-06-30
