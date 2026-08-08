---
title: killability-truth discovery
status: completed
tags: []
created: 2026-08-07
due:
related-tasks: [PID-EPIC-62]
---

# PID-62.1 | killability-truth discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-62]]

## 🎯 Goal

Scope the `PID-EPIC-62` epic (`killability-truth`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-62.2..5` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [x] Shared design surface inventoried for the epic (sources, adopter wiring, SPEC contract impact, templates) — captured in Discovery Notes
- [x] Open scoping questions resolved with the user via AskUserQuestion — captured in the deep pre-pass Clarifications table (referenced from Discovery Notes)
- [x] Concrete child scopes for PID-62.2 .. PID-62.5 filed in .flowtron/PLAN.md (all under the 70w hard cap; .2/.3 slightly over the 50w target, kept for precision)
- [x] Audit line PID-62.N reviewed and confirmed as-filed (no scope shift surfaced)
- [x] Phase 4 doc-drift sweep at closure: no AI-referenced doc updates land in this pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [x] Inventory shared design surface (source files, adopter-wiring surfaces, SPEC contract impact, templates) — log in Discovery Notes
- [x] Skim .flowtron/tasknote/archive/pid/ for relevant precedents — log load-bearing findings in Discovery Notes
- [x] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [x] Surface open scoping questions via AskUserQuestion (typical: per-child shortname + scope + adopter-wiring policy) — resolved via deep pre-pass Clarifications table
- [x] Draft refined long descriptions for PID-62.2 .. PID-62.5; word-count each (≤50w target / 70w hard cap)
- [x] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-62 with 2-space indent
- [x] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [x] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-62]] — parent epic (killability-truth)

## 🧭 Deep Pre-pass

### Constitution

**Principles (what this epic optimizes for):**

1. **A kill affordance is a promise.** A kill button appears only where we reasonably believe the process will die *and stay dead*. Rows we cannot deliver that for (foreign-owned/EPERM, supervisor-managed respawners) must say so honestly instead of offering a dead-end button.
2. **Truth over optimism in feedback.** Post-kill UI reflects the verified outcome (gone at rescan), never optimistic removal. Reappearance of the same logical process under a new PID is detected and surfaced as "respawned — kill won't stick", not silently re-listed as a fresh candidate.
3. **Respawn handling is honest explanation, not escalation.** For respawners, explain *who* restarts it (parent supervisor, launchd, Docker restart policy) and what would genuinely stop it — never fight a supervisor with kill loops.
4. **One logical unit, one row.** Process trees that live and die together (e.g. `npm run dev` → `node` → `vite`) surface as one killable unit; redundant per-PID rows for the same logical thing are collapsed.

**Non-negotiables (existing invariants this epic must preserve):**

- Two kill-action buckets only (`safe` / `needsReview`); a process is never killed without explicit user action.
- SIGTERM → 2 s grace → SIGKILL, never skipped; PID-reuse identity guards (PID-35.3) stay intact.
- Foreground-only app — no background daemon/helper (PID-EPIC-27 abandonment stands).
- Core/app split: pure logic in `PidlyseCore`; app-side owns only timer/persistence/UI glue. CLI-companion pipeline parity (PID-57.3) — scan-input changes land in both pipelines.
- Privacy: clean log records only confirmed deaths; no command lines persisted.

**Out of scope:**

- No privileged escalation (no sudo/root kills of foreign-owned processes) — EPERM items get honest labeling, not force.
- No auto-kill of anything, ever — including detected respawners.
- Signing/notarization posture unchanged (PID-030 stays deferred).

### Specification

WHAT the epic delivers, per anticipated implementation child (M=4; Discovery may revise):

**.2 — kill-verification + respawn-detection core (foundation).**
Deliverable: `PidlyseCore` logic that (a) verifies a kill actually stuck — post-kill rescan confirms the PID is gone — and (b) detects respawn: after a confirmed kill, the same *logical* process (command-signature match, e.g. normalized args + cwd) reappearing under a new PID within a detection window is flagged as a respawner. Persisted per-signature respawn count (session-scoped at minimum). Acceptance shape: pure, unit-tested core (signature normalization, respawn matcher, window logic); `ScanEngine` feeds it like `ScanHistory`; CLI pipeline parity noted. Interaction: every other child consumes its signals.

**.3 — honest unkillable/respawner classification + UX.**
Deliverable: rows the app cannot genuinely kill stop pretending. EPERM/foreign-owned items (today: silent `.notKilled`, row just reappears) get an explicit "unkillable — owned by root/another user" state; detected respawners get "respawns — managed by <parent/launchd/docker restart policy>; kill won't stick" reasoning + a demoted/replaced kill affordance. Acceptance shape: classification stays two buckets (state is an overlay like 🔒 protection, not a third bucket); inspector reasoning line added; unit tests on the overlay derivation. Interaction: consumes .2's respawn signals + `KillCore`'s EPERM outcome (which needs threading to the UI).

**.4 — process-tree redundancy collapse.**
Deliverable: parent+child chains that live and die together (`npm run dev` → `node` → `vite`; Chrome helper broods) render as one logical row (group kill = root kill, children follow), with expandable members. Acceptance shape: pure grouping logic in core (building on `AncestryResolver`), tests on chain detection and group-kill ordering; sweep/`Clean all` counts each group once. Interaction: respawn signatures from .2 apply per logical group, not per PID.

**.5 — kill-feedback UX + stability pass.**
Deliverable: visible per-row kill lifecycle ("killing… → gone / didn't die / respawned") replacing today's fire-and-hope rescan; "Clean all" reports an honest outcome summary (N killed, M didn't die, K respawned). Plus targeted stability fixes surfaced during Discovery (scan churn/flicker, stale rows). Acceptance shape: UI states driven by .2's verification results; manual visual confirmation + unit tests on outcome aggregation. Interaction: terminal child — integrates .2/.3/.4 surfaces into the popover.

### Clarifications

| # | Question | Resolution |
|---|----------|------------|
| 1 | Which processes observed never dying after a kill? | MCP servers / node tooling — operator believes it's **playwright-mcp**; plus "let Discovery find out" (empirical kill-and-observe per kind). Docker explicitly NOT a kill target for the operator (they'd use Docker Desktop) — docker-scope trim question parked as sidequest [[PID-063]], out of this epic. |
| 2 | Kill affordance for detected respawner / unkillable rows? | **Explanation replaces button** — kill button removed; row explains why it won't die and what would actually stop it. |
| 3 | Respawn memory persistence? | **Session-only**, in-memory like `ScanHistory`; resets on relaunch, a respawner re-earns its badge after one kill attempt. |
| 4 | CLI companion respawn-awareness? | **App-only this epic**; CLI keeps current behavior, parity filed later if wanted. |

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Operator explicitly invoked `/ft-epic-discovery --deep` — the app's core promise (kills that stick) is undermined by respawners/unkillables offered as killable; epic scope confirmed.

- [x] Read relevant source files — `SPEC.md` (§Scan Engine / §Classification / §Kill Flow), `KillCore.swift` (full), `ScanHistory.swift` (full), `ScanEngine.swift` (kill wiring), core source inventory

- [x] **Best Practices Review** — N/A for the Discovery itself (pure PLAN filing); the shared design surface for children is inventoried below (core/app split, signal-only convention, SSOT sweep set)

- [x] **Archive skim** — see Discovery Notes: PID-051, PID-039, PID-35.3, PID-53.2, PID-55.2/.3 load-bearing

- [x] **Drift check** — all cited paths exist at HEAD (`KillCore.swift`, `ScanHistory.swift`, `ScanEngine.swift`, `AncestryResolver.swift`); CLAUDE.md conventions (KillOutcome, cleanAllSafe SSOT, signal-only ScanHistory) match code; no drift

- [x] Asked clarifying questions — resolved during deep pre-pass; see `## 🧭 Deep Pre-pass` §Clarifications (4 resolved: playwright-mcp is the suspected respawner + empirical verification wanted; explanation-replaces-button; session-only memory; app-only, CLI later). Docker-scope question parked as sidequest [[PID-063]].

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface inventory:**
- `PidlyseCore`: `KillCore.swift` (kill outcomes — `.confirmed` means "SIGTERM delivered", NOT "stayed dead"; EPERM → silent `.notKilled`), `ScanCore.swift` (enumerate + classification), `ScanHistory.swift` (the pattern for the .2 respawn cache — pure value type, PID+ProcStartTime keyed, session-only, ScanEngine owns the instance), `AncestryResolver.swift` (ancestor chains — .4 builds on it), `ProcessItem.swift`.
- App side: `ScanEngine.swift` (scan pipeline, `cleanAllSafe`/`sweepableSafeItems` SSOT, `recordCleaned` hook), `KillService.swift` (async wrapper), `MenuBarView.swift` (kill buttons, reasoning lines).
- Contract surfaces: SPEC.md §Classification/§Kill Flow will need updating in children (not here); CLI pipeline parity explicitly deferred (clarification #4).
- Convention constraint: respawn/unkillable state is an **overlay** (like 🔒 protection), never a third bucket; two kill-action buckets preserved.

**Archive precedents (load-bearing):**
- **PID-051 kill-rescan-flicker** — closed no-bug: the "list clears then repopulates" is *real Chrome teardown/respawn churn*, not a render bug. Direct empirical evidence for this epic's respawn detection; .2 turns that documented churn into a first-class signal.
- **PID-039 npm-surface-dedup** — prior redundancy collapse on the npm surface; .4 extends it (and PID-50.3's deterministic `grouped()` ordering), doesn't duplicate it.
- **PID-35.3 kill-path-hardening** — identity guards (scan-time start-time token, no-bystander SIGKILL) are non-negotiable and stay intact under .2's verification layer.
- **PID-53.2 clean-log-store** — `KillOutcome` threading precedent; only `.confirmed` logged. .2 refines what "confirmed" means (delivered ≠ stayed dead) — clean-log honesty must be preserved.
- **PID-55.2/.3 scan-history-cache / idle-dev-signal** — the pure-cache + signal-only pattern the respawn cache mirrors; note .3 *does* change affordances (button removal), which is deliberately beyond signal-only and is the epic's core UX decision (constitution principle 1).

**Resolved scoping:** see `## 🧭 Deep Pre-pass` §Clarifications table (4 questions resolved there; no new questions surfaced during Phase 1 reads).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the CORE-EPIC-057-style cohort-children filing pattern (2-space indent, `[model]` on every line, em-dash separator, per-child cap discipline); local precedent PID-EPIC-58 cohort

- [x] **Minimal refactor gate** — N/A (pure PLAN.md filing; no code touched)

- [x] Implemented the minimal solution — 4 child lines written under PID-EPIC-62, between `.1` and `.N`

- [x] Updated/added tests for non-trivial behavior — N/A (no executable surface)

**Implementation Notes:**

- 4 child lines filed (M=4, unchanged from filing-time estimate). Word counts: .2 ≈ 45w, .3 ≈ 44w, .4 ≈ 40w, .5 ≈ 36w — all under the 70w hard cap; .2/.3 slightly over the 50w target but within cap, kept for precision.
- Models: .2 `[heavy]🧠` (design-bearing core: signature normalization + verification semantics); .3/.4/.5 `[medium]🧠`.
- Downstream-impact reconciliation scan: rest of active PLAN = PID-030 (notarize, Future — unaffected) and PID-063 (docker-scope sidequest, Future — tangential to .3's EPERM labeling, but the epic does not change docker scope → leave). **No downstream impact; no reconcile edits.**
- Sidequest PID-063 parked mid-pre-pass (operator request, clarification #1); stub + PLAN line written this session.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (markdown-only)

- [x] Ran lint/type-check on changed code — N/A; markdown mental-pass instead: 2-space child indent ✓, bold IDs ✓, `[model]` on every line ✓, shortnames ≤30 chars ✓ (21/19/24/22), em-dash separators ✓, ≤70w cap ✓, no trailing whitespace ✓, wikilinks/cross-refs parse ✓

- [x] **Quality assertions** — N/A (no code); PLAN lines carry no duplication with existing entries (PID-039/PID-051 referenced, not re-filed)

- [x] (frontend) Asked the user for visual confirmation — N/A

> **Choosing a test strategy (guidance, not a gate).** Default to targeted
> tests on the changed behavior. Where the input space is wide — parsers,
> encoders, round-trips, invariants that must hold across many inputs — a
> property-based test earns its keep; reach for one when example tests would
> leave large gaps. Visual confirmation covers UI surfaces that assertions
> can't. This is engineering judgment folded into Phase 3, never a new
> lifecycle phase or a schema/validator.

**Testing Notes:**

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (feature surface unchanged by pure filing). `AGENTS.md`: no change. `CLAUDE.md`: no change (SPEC/kill-flow contract edits land inside children .2–.5). `SPEC.md`: no change now — .2/.3/.4/.5 will each update §Classification/§Kill Flow as they land. `.flowtron/PLAN.md`: updated this session (epic cohort + PID-063).

- [x] Closed — PLAN.md `.1` line flipped to stub form, kept nested under PID-EPIC-62 in `## High`; tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] **Evidence-based recap** drafted — see Final Summary (surfaces inline on conditional skip)

**Final Summary:**

Filed PID-EPIC-62 (`killability-truth`, High, `[heavy]🧠`) and closed its `.1` deep Discovery in one motion. Deep pre-pass produced a Constitution (kill button = promise it sticks; verified-outcome feedback; honest explanation over escalation; one logical unit per row — with two-bucket, grace-period, foreground-only invariants preserved), a per-child Specification, and 4 resolved clarifications (playwright-mcp suspected respawner + empirical verification; explanation replaces button; session-only respawn memory; app-only CLI parity). Phase 1 grounded the scope in code: `KillCore.confirmed` means delivered-not-stayed-dead, EPERM is silently swallowed, `ScanHistory` is the respawn-cache template, PID-051's "no-bug" churn is direct respawn evidence, PID-039 is the dedup precedent. Filed children: .2 respawn-detection-core `[heavy]`, .3 honest-unkillable-ux, .4 tree-redundancy-collapse, .5 kill-feedback-stability (all `[medium]`; M=4 unchanged; `.N` audit confirmed as-filed). No downstream impact on PID-030/PID-063. Side deliverable: PID-063 docker-scope sidequest parked (Future). Parent epic description refined at closure. No code changed; no tests to run.

**Archived:** 2026-08-08
