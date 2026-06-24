---
title: bun-guard
status: completed
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-14]
---

# PID-14.2 | bun-guard

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-14]]

## 🎯 Goal

Tighten `bun`/`node` detection in ScanEngine so `bundle` (and similar prefixes) are not falsely caught, and bare `node` binary invocations are correctly identified.

## ✅ Acceptance

- [x] `bundle` (e.g., Ruby bundler) is not classified as a `bun` process
- [x] `node` invoked directly (path ends with `/node`) is detected as a node process
- [x] Existing legitimate `bun` and `node` matches still fire

## 🧩 Subtasks

- [x] Fix `bun` detection: replace `s.contains("bun")` with `s.hasPrefix("bun ") || s == "bun" || s.contains("/bun ") || s.hasSuffix("/bun")`
- [x] Fix `node` detection: replace `s.contains("node ")` with `s.contains("node ") || s.hasSuffix("node")`
- [x] Add tests: `bundle install` → nil; bare `node` → `.node`; path-only `/usr/local/bin/node` → `.node`
- [x] Run test suite (xcodebuild test)

## 🔗 Related

- [[PID-EPIC-14]] — parent epic: detectKind false positives + docker-stop clarity

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Both issues confirmed in `ScanEngine.detectKind()` at lines 264-265. No drift.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

Both issues confirmed in `ScanEngine.detectKind()`:
- Line 264: `s.contains("bun")` — catches `bundle install` (Ruby bundler) as false positive
- Line 265: `s.contains("node ")` — misses bare `node` with no args (no trailing space)

PID-13.3 archive confirms these were intentional choices ("broad-match philosophy" for bun; trailing space to avoid `inode`/`nodestore` for node) — EPIC-14 discovery flagged `bundle` as a real false-positive casualty and bare `node` as a miss worth fixing.

Tests exist in `ScanEngineTests.swift`; existing `bun run dev` and `node server.js` cases will remain valid after fix.

No clarifications needed. Explicit assumptions: fix stays within `detectKind()`; no ProcessKind or riskTier changes needed.

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

Pattern survey: extended the existing `contains()`-chain in `detectKind()` — same style, minimal delta.

Changes:
- `ScanEngine.swift` line 264: `s.contains("bun")` → `s.hasPrefix("bun ") || s == "bun" || s.contains("/bun ") || s.hasSuffix("/bun")`
- `ScanEngine.swift` line 265: `s.contains("node ")` → `s.contains("node ") || s.hasSuffix("node")`
- `ScanEngineTests.swift`: added `testDetectKind_bundle_notBun()` (2 assertions) and `testDetectKind_bareNode_isNode()` (2 assertions)

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

`xcodebuild test` — 39/39 passed (2 new tests green, 37 prior all green). Build clean. No frontend changes.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - `README.md` — no change
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `.flowtron/PLAN.md` — updated: PID-14.2 line flipped to stub form

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Tightened `bun`/`node` detection in `ScanEngine.detectKind()`: word-boundary guards prevent `bundle install` from matching as `.bun`, and `hasSuffix("node")` catches bare `node` invocations with no args. 2 files changed, 2 new tests added; 39/39 passing.

**Archived:** 2026-06-24
