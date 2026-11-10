---
title: grok-block-adoption
status: completed
tags: [grok, agents-md, natabula]
created: 2026-11-10
due:
related-tasks: []
touches:
  - AGENTS.md
  - CLAUDE.md
---

# CORE-001 | grok-block-adoption

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 natabula NAT-560.3

## 🎯 Goal

Adopt natabula's Grok instruction block v1 (public variant) into Pidlyse's root `AGENTS.md`, with `CLAUDE.md` pointing at `AGENTS.md` exactly once, so natabula's audit passes and no private workflow identifier is published.

## ✅ Acceptance

- [x] Exact public payload appended once to `AGENTS.md` with ordered unique markers; CLAUDE pointer counted exactly once — `python3 ../natabula/scripts/check-grok-block.py . --variant public` (exit 0)
- [x] Public-ID boundary: no private workflow identifier in `AGENTS.md`/`CLAUDE.md` (checker) nor in any reachable commit — `git log --all -S<id>` over the checker's id list → 0 hits
- [x] Checker + checkout fixture suites still green (checkout/closure capability stops live there, not in a second implementation) — `python3 ../natabula/scripts/check-grok-block.test.py` and `python3 ../natabula/scripts/check-grok-checkout-fixtures.py` (exit 0)
- [x] Everything outside the block in `AGENTS.md` preserved; `CLAUDE.md` keeps its `@AGENTS.md` import and Claude-only note — `git diff --stat` (AGENTS.md additions only) + `judgment` on the CLAUDE.md one-line diff
- [x] No push / PR / merge / deploy — `judgment` (explicit operator go required; none given)

## 🧩 Subtasks

- [x] Append `templates/grok-tasknotes/public.md` bytes verbatim to the end of `AGENTS.md`
- [x] De-link the prose `[`AGENTS.md`](AGENTS.md)` in `CLAUDE.md` to plain `` `AGENTS.md` `` so the `@AGENTS.md` import is the single pointer
- [x] Run checker, checker self-test, checkout fixtures, history ID scan
- [x] Closure

## 🔗 Related

- natabula NAT-560.3 — owner routing record that filed this row (`docs/reviews/NAT-560.3-owner-routing.md`, pidlyse = PUBLIC)
- natabula `docs/GROK-TASKNOTES.md` — the standard

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Baseline audit fails exactly as the routing record predicts (`missing/duplicate markers`; `CLAUDE must import/link AGENTS.md exactly once`). Both gaps are small text edits.

- [x] Read relevant source files — `AGENTS.md`, `CLAUDE.md`, natabula `docs/GROK-TASKNOTES.md`, `templates/grok-tasknotes/public.md`, `scripts/check-grok-block.py`.

- [x] **Best Practices Review** — N/A: doc-only, no code/module boundaries.

- [x] **Archive skim** — `CORE-*` → `archive/core/` per README table (re-checked); folder absent → no prior tasknotes.

- [x] **Drift check** — PLAN line matches the NAT-560.3 routing record verbatim (public variant); filing commit `9894763` matches the record's filing SHA. Baseline checker output matches the record's drift column.

- [x] No clarifications needed. Assumptions: (1) public variant (repo routed PUBLIC); (2) "first adoption, absence means append" → block goes at the end of `AGENTS.md`; (3) the duplicate pointer is resolved by keeping the functional `@AGENTS.md` import and turning the prose link into plain code text (dropping the import would stop Claude Code from loading AGENTS.md); (4) the private-workflow bootstrap lives in operator-local instructions outside git, so no repo file carries it.

- [x] Subtasks above populated with ordered steps; YAML `touches:` declared

**Discovery Notes:**

- Checker's pointer regex counts both `^@AGENTS.md$` and any `[..](AGENTS.md)` link after stripping inline code spans, so `[`AGENTS.md`](AGENTS.md)` still counts → 2 pointers today.
- Public-ID boundary baseline: the 8 identifiers the checker uses (private payload ≥25-char tokens + 3 lifecycle record IDs) → 0 hits across `git log --all -S` and `git grep` over every reachable revision. Values written only to session scratchpad, never printed.
- The standard leaves connector capability and live lifecycle writes unverifiable by the checker; the public block itself encodes the stop ("stop and report before task repo work"). Checkout behavior fixtures stay with natabula's existing runner.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended an existing pattern or justified a new shape

- [x] **Minimal refactor gate** — refactored only for Acceptance or touched-path coherence; deferred unrelated cleanup

- [x] Implemented the minimal solution

- [x] Updated/added tests — N/A: no code; natabula's checker is the test.

**Implementation Notes:**

- Pattern: natabula's "first adoption, absence means append" — payload bytes appended verbatim (LF, no CRLF in source) after one blank line at the end of `AGENTS.md`; no other AGENTS.md line touched.
- `CLAUDE.md`: prose link `[`AGENTS.md`](AGENTS.md)` → `` `AGENTS.md` ``; the `@AGENTS.md` import is now the sole pointer. File stays a regular file (not converted to a symlink) to keep its Claude-only note.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] **Verification receipt** — each Acceptance verify command in Testing Notes as `command → exit code` (+ first failure line); changed code free of duplication, dead code, and stale docs (otherwise `N/A` with reason)

- [x] **External review** — a non-author context graded the diff against `## ✅ Acceptance`; findings recorded below (**blocker** → back to Phase 2; **note** → fixed or filed), or `N/A` with reason

- [x] (frontend) N/A — doc-only change, no UI.

**Choosing a test strategy:** see SPEC.md §"🧪 Phase 3: Testing & Linting".

**Testing Notes:**

- `python3 ../natabula/scripts/check-grok-block.py . --variant public` → 0 (`exact public payload and CLAUDE pointer`); baseline before edit → 1 (both findings).
- `python3 ../natabula/scripts/check-grok-block.test.py` → 0
- `python3 ../natabula/scripts/check-grok-checkout-fixtures.py` → 0
- Public-ID boundary: `grep -c -F -f <ids>` on AGENTS.md / CLAUDE.md → 0 / 0; `git log --all -S<id>` × 8 ids → 0 hits; `git grep` over all revisions → 0.
- `git diff --numstat` → AGENTS.md 7/0, CLAUDE.md 1/1 — additions only in AGENTS.md.
- Lint/type-check: N/A (markdown only). Targeted tests: the checker above.
- External review: N/A — the 8-line diff is a verbatim copy of the canonical payload, byte-verified by natabula's checker (a non-author oracle), plus a one-link de-link in CLAUDE.md.
- No push / PR / merge / deploy performed.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — per `.flaitron/tasknote/README.md` §"AI-referenced docs" entry: "no change" or the update

- [x] Closed — Acceptance ticked or annotated (`N/A` / not met + reason), YAML `status: completed`, PLAN.md line → `Completed YYYY-MM-DD.` stub (standalone → top of `## Completed`; epic child → stays nested under its parent), then tasknote moved to `.flaitron/tasknote/archive/<area>/`

- [x] **Evidence-based recap** drafted — changed files, verification results, refactors, doc verdict, `touches:` reconciliation (`git diff --name-only` vs declared), maintainability effect

- [x] **Learnings** — N/A: the block itself is the always-loaded addition.

**Final Summary:**

- Doc-drift sweep: `AGENTS.md` updated (the deliverable); `CLAUDE.md` updated (pointer); `README.md`, `SPEC.md`, `PLAN.md` — no change beyond the closure flip.
- Changed files: `AGENTS.md`, `CLAUDE.md` (+ PLAN, tasknote). `touches:` reconciliation: matches declared set exactly.
- Fleet adoption/source DONE is not claimed here — natabula NAT-560.N owns that reconciliation.

**Archived:** 2026-11-10
