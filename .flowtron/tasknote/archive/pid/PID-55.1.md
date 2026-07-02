---
title: idle-stray-signals — Discovery
status: in-progress
tags: [epic-discovery]
created: 2026-07-01
due:
related-tasks: [PID-EPIC-55, PID-55.4]
---

# PID-55.1 | idle-stray-signals — Discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-55]] [[PID-55.4]]

## 🎯 Goal

Scope the `PID-EPIC-55` (`idle-stray-signals`) shared design and file its implementation children `.2 .. .3` in PLAN.md — deliverable is the filed child scopes, not code.

## ✅ Acceptance

- [ ] Shared design surface inventoried (scan-history cache, idle-signal inputs, surfacing point)
- [ ] Key scoping decisions resolved (UI surfacing, child split, in-memory vs persisted, thresholds)
- [ ] Implementation children `.2` and `.3` filed in PLAN.md with concrete scopes
- [ ] "Signal only — never changes the kill bar / bucket" invariant explicit in each child scope

## 🧩 Subtasks

- [ ] Inventory the shared surface (ScanCore.riskTier, ProcessItem, ScanEngine cross-scan state)
- [ ] Resolve UI-surfacing + child-split decisions with the user
- [ ] File `.2` and `.3` child lines in PLAN.md under PID-EPIC-55
- [ ] Refine the parent epic line if the shared design shifted its framing

## 🔗 Related

- [[PID-EPIC-55]] — parent epic (idle-stray-signals)
- [[PID-55.4]] — audit sibling (final subtask)
- [[PID-036.1]] — discovery precedent (core/ui two-child split shape)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** The epic targets a real gap — CPU is captured but never classified, and each scan is stateless so a single noisy `ps pcpu` snapshot can't distinguish an idle dev server from a busy one. Adding a short scan-history cache + an idle-signal is coherent with the existing signal model and the never-auto-kill posture.

- [x] Read relevant source files — `ScanCore.swift` (riskTier / detectKind), `ProcessItem.swift` (derived signals), `ScanEngine.swift` (per-scan maps + `previousPIDs` cross-scan state), `MenuBarView.swift` (row rendering, CPU% display).

- [x] **Archive skim** — see Discovery Notes.

- [x] **Drift check** — description matches current code: `cpuPercent` is captured (`ScanCore.makeItem`) and displayed (`MenuBarView` row) but not classified; no scan history exists; `startTime` identity token (PID-35.3) available for PID-reuse-safe history keying.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — two design decisions resolved via AskUserQuestion (see Decisions below).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Current state.** `ScanCore.riskTier(kind:hasTTY:isOrphan:isOld:)` computes a `strongStray = !hasTTY && isOrphan && isOld` boolean; CPU never participates. `ProcessItem.cpuPercent` is a single `ps pcpu` snapshot, shown in the row but unused for classification. Scans are stateless except `ScanEngine.previousPIDs` (depth-1, drives new-stray notifications).

**Shared surface for the epic.**
- **Scan-history cache** — a bounded rolling window (depth N) of per-process CPU samples, keyed by (PID + `startTime`) so PID reuse doesn't corrupt a series. Generalizes `previousPIDs`. In-memory (see assumption below).
- **Idle-signal inputs** — sustained low CPU across the window (from the cache) + `isOld` + `!hasTTY` + dev-mode flag corroboration (command-line parse: `--watch`, `--dev`, `--hot`, `NODE_ENV=development`, etc.).
- **Surfacing point** — `MenuBarView.row(...)` (row descriptor / "Why is this here?" expansion). Signal-only; must not touch `riskTier` / `bucket` / the kill bar.

**Precedents.**
- Pure/impure split: `CleanLog` (Core) + `CleanLogStore` (app) — but scan history needs no disk (stale CPU post-restart is meaningless), so simpler.
- `PID-036.1` filed `.2 provenance-core` + `.3 hints-ui` — the core/ui two-child shape this epic mirrors.
- `startTime` identity token (PID-35.3) already exists for reuse-safe keying.

**Guardrails.**
- `PID-049` survey rejected drift toward system-monitoring bloat — keep the surface minimal.
- CLAUDE.md: two buckets only (`safe`/`needsReview`); never kill without explicit action. The idle signal is advisory only.

**Decisions (AskUserQuestion, 2026-07-01).**
1. **Signal surfacing → expansion only.** The idle signal appears only as a reasoning line in the "Why is this here?" expansion panel — no row-level chip. Most conservative; respects the no-bloat posture and keeps the row vocabulary (risk dot / 🔒) unchanged.
2. **Child split → infra / signal.** `.2 scan-history-cache` (pure PidlyseCore infra + ScanEngine wiring, no UI) and `.3 idle-dev-signal` (history consumer + dev-flag parse + expansion surfacing). Mirrors the `PID-036` core/ui split; each child independently testable.

**Explicit assumptions (child tasks confirm exact values).**
- **In-memory, not persisted.** The scan-history cache lives in `ScanEngine` for the session only — a CPU sample from before an app restart is meaningless, so no disk I/O (simpler than the `CleanLog`/`CleanLogStore` precedent).
- **Thresholds (defaults, tunable in `.2`/`.3`):** window depth ~4–5 scans; "sustained low CPU" ≈ every sample in the window < ~1% CPU; requires a minimum sample count so a just-appeared process isn't prematurely flagged idle.
- **Signal carrier:** `.3` decides between a new derived field on `ProcessItem` populated by `ScanEngine`, or a scan-time `[PID: IdleSignal]` map sibling to `listeningPorts`/`cwds`. Either keeps `ScanCore.riskTier` untouched.

**Deliverable.** Children `.2 scan-history-cache` and `.3 idle-dev-signal` filed under `PID-EPIC-55` in PLAN.md; parent line refined with the scoped N=4 shape + surfacing decision.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — matched the epic to two in-repo precedents: `PID-036.1`'s core/ui two-child split and the `CleanLog`/`CleanLogStore` pure/impure discipline; `previousPIDs` as the existing cross-scan-state shape the history cache extends.

- [x] Implemented the minimal solution — Discovery deliverable: filed `.2` + `.3` child scopes in PLAN.md (no code this subtask).

- [x] Updated/added tests for non-trivial behavior — N/A (Discovery subtask; the implementation children carry their own tests).

**Implementation Notes:** Filed `PID-55.2` (scan-history-cache) and `PID-55.3` (idle-dev-signal) under the parent epic; refined the `PID-EPIC-55` line with the scoped `N=4` shape and the expansion-only surfacing decision.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (no code changed; PLAN.md + tasknote markdown only).

- [x] Ran lint/type-check on changed code — N/A (no code changed).

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changed).

**Testing Notes:** Deliverable is the filed child list; verified the new PLAN.md lines parse (bold ID, `[medium]`, shortname, `— ` description) and both sit ≤70w.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (no feature shipped — scoping only) · `AGENTS.md`: no change · `CLAUDE.md`: no change (the ScanCore/ScanEngine convention lines update when `.2`/`.3` add `ScanHistory`, not now) · `.flowtron/PLAN.md`: children `.2`/`.3` filed + parent refined + `.1` closure flip.

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-07-02.` (kept nested under `PID-EPIC-55`; the cohort moves to `## Completed` when the parent closes at audit `.4`) and tasknote moved to `.flowtron/tasknote/archive/pid/`.

- [x] Recap drafted (surfaces inline on conditional skip).

**Final Summary:** Scoped `PID-EPIC-55` (`idle-stray-signals`) and filed its two implementation children. Discovery found CPU is captured but never classified and scans are stateless (only `previousPIDs`, depth-1). Two decisions resolved with the operator: signal surfaces in the **"Why is this here?" expansion only** (no row chip — no-bloat posture), and the children split **infra / signal**. Filed `PID-55.2 scan-history-cache` (pure PidlyseCore rolling-window CPU cache keyed by PID+startTime + ScanEngine wiring, in-memory, no UI) and `PID-55.3 idle-dev-signal` (consume the history + parse dev-mode flags → confident idle signal, expansion-surfaced; never touches `riskTier`/`bucket`/kill bar). Parent line refined to N=4. No code changed this subtask.

**Archived:** 2026-07-02
