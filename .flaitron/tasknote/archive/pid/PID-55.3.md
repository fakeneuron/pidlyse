---
title: idle-dev-signal
status: in-progress
tags: []
created: 2026-07-02
related-tasks: [PID-EPIC-55, PID-55.1, PID-55.2, PID-55.4]
---

# PID-55.3 | idle-dev-signal

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-55]] [[PID-55.1]] [[PID-55.2]] [[PID-55.4]]

## 🎯 Goal

Combine [[PID-55.2]]'s sustained-low-CPU query with a pure dev-mode flag parse (`--watch`/`--dev`/`--hot`/`NODE_ENV`), process age, and absent TTY into a confident "idle dev server" signal, surfaced as one reasoning line in the "Why is this here?" expansion only — never touching `riskTier`/`bucket`/kill bar.

## ✅ Acceptance

- [ ] New pure dev-mode flag parser in `PidlyseCore.ScanCore` (mirrors `detectKind`/`hasTokenBoundary` shape): detects `--watch`, `--dev`, `--hot`, `NODE_ENV=development`/`NODE_ENV development`, and similar dev-mode markers in a command line.
- [ ] An "idle dev server" verdict combines sustained-low-CPU (`ScanEngine.hasSustainedLowCPU`) + `isOld` + `!hasTTY` + the dev-flag parse per the resolved semantics (see Decisions).
- [ ] Verdict surfaces as a single reasoning line in `MenuBarView.reasoningBlock` (expansion only) — no row chip, graceful-degrade (line absent when not idle).
- [ ] Signal-only invariant preserved: `ScanCore.riskTier`/`bucket`/kill bar untouched; no new `@Published` UI-driving state added.
- [ ] Unit tests for the pure dev-flag parser (positive markers + negative/word-boundary false positives).
- [ ] `make test` green.

## 🧩 Subtasks

- [ ] Add pure `ScanCore.hasDevModeFlag(_:)` (+ any helper) in `PidlyseCore`.
- [ ] Add the idle-dev-server verdict glue (engine accessor folding the `.2` query + pure signals).
- [ ] Render the reasoning line in `MenuBarView.reasoningBlock`.
- [ ] Add dev-flag parse tests to `PidlyseTests/ScanEngineTests.swift`.
- [ ] `make test`.

## 🔗 Related

- [[PID-EPIC-55]] — parent epic (idle-stray-signals)
- [[PID-55.1]] — discovery (resolved expansion-only surfacing + infra/signal child split)
- [[PID-55.2]] — infra predecessor (`ScanHistory` + `ScanEngine.hasSustainedLowCPU`)
- [[PID-55.4]] — audit sibling (final subtask)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Implements exactly the signal child scoped by [[PID-55.1]]. The `.2` infra (`ScanHistory` + `ScanEngine.hasSustainedLowCPU`) is shipped and awaits a consumer; CPU is now sampled across scans but never surfaced. Adding a dev-flag parse + folding the signals into an expansion-only reasoning line completes the epic's signal path and fits the never-auto-kill / no-bloat posture.

- [x] Read relevant source files — `ProcessItem.swift` (`hasTTY`, `isOrphan`, `elapsed`, `cpuPercent`, derived signals), `ScanCore.swift` (`detectKind`/`hasTokenBoundary` pure-parse pattern to mirror, `riskTier` to leave untouched), `ScanEngine.swift` (`hasSustainedLowCPU(_:)` from `.2`, `elapsedThreshold`), `MenuBarView.swift` (`reasoningBlock`/`criterionTag`, `isOld = elapsed >= engine.elapsedThreshold`).

- [x] **Archive skim** — see Discovery Notes.

- [x] **Drift check** — description matches current code. `PID-55.2` shipped `ScanEngine.hasSustainedLowCPU(_:)` (verified present, lines 298–303) and `ScanHistory` in `PidlyseCore`. `isOld` is computed view-side in `MenuBarView.row` as `item.elapsed >= engine.elapsedThreshold` and passed to `reasoningBlock`. `hasTTY` is on `ProcessItem`. No dev-flag parser exists yet. The example flags (`--watch`/`--dev`/`NODE_ENV`) are not currently parsed anywhere.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — one design fork resolved via AskUserQuestion (see Decisions).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Consumer point.** The signal is expansion-only (locked by [[PID-55.1]] decision 1 — no row chip). `MenuBarView.reasoningBlock(item:isOld:)` is the surface; it already renders `criterionTag`s ("no tty"/"orphan"/"old") and provenance lines, degrading gracefully (a line is absent when its input is absent). The idle-dev line slots in there.

**Signal carrier.** [[PID-55.2]] decided the carrier is a *query on the cache* (`hasSustainedLowCPU`), not a new `ProcessItem` field — keeps `ScanCore` untouched. The idle verdict = `hasSustainedLowCPU(item)` (engine, needs history state) + `isOld` + `!hasTTY` + dev-flag parse (pure). The stateful part must be an engine accessor; the dev-flag parse is pure `ScanCore`. Cleanest shape: pure `ScanCore.hasDevModeFlag(_:)` + a thin `ScanEngine.isIdleDevServer(_:)` folding the four inputs (engine owns `elapsedThreshold`, so it can compute `isOld` itself).

**Pattern to extend.** `detectKind`/`hasTokenBoundary` (pure static token-matching on a lowercased command) is the exact shape for the dev-flag parse — reuse `hasTokenBoundary` for flag tokens to avoid substring false positives (e.g. `--devtools` vs `--dev`).

**Archive skim.** `grep`ped `archive/pid/` for `ScanCore`/`reasoningBlock`/dev-flag prior art. Load-bearing: PID-54.2 (`hasTokenBoundary` word-boundary discipline — the token-match convention to reuse; expanded dev-server kinds); PID-036.3/PID-052.x (the `reasoningBlock` graceful-degrade line pattern — render only when resolvable); PID-039 (wrapper collapse — a collapsed `npm run dev` row carries the *child's* command, so the dev-flag parse sees the real dev command, good); PID-049 (survey rejected system-monitoring bloat — keep the signal minimal, one line). No prior tasknote parsed dev-mode flags.

**Guardrails.** CLAUDE.md: two buckets only, signal-only; never touch the kill bar. [[PID-55.1]]: expansion only, advisory. Keep the surface to a single reasoning line.

**Design fork (→ clarifying question).** Whether the dev-mode flag is **AND-required** (signal fires only when a dev-flag is present → high precision, "confident", but misses flagless dev servers like a bare `vite`) or **corroborating** (idle = low CPU + old + no TTY fires on its own; the dev-flag strengthens wording). This materially changes which rows show the signal, so it's worth one operator confirm.

**Decision (AskUserQuestion, 2026-07-02).** **Required (strict AND).** The idle-dev-server verdict fires only when **all** of `hasSustainedLowCPU(item)` + `isOld` + `!hasTTY` + `hasDevModeFlag(command)` hold. High-precision / "confident" reading — a flagless dev server (bare `vite`, `next dev`) deliberately does not surface the line. Simplifies the surface too: one boolean verdict, one reasoning line ("idle dev server"), no wording branch.

**Explicit assumptions (dev-flag marker set).** `hasDevModeFlag` matches, case-insensitively: `--watch`, `--dev`, `--hot`, `--reload`, and a `NODE_ENV=development` / `NODE_ENV development` marker. Uses the `hasTokenBoundary` discipline (PID-54.2) so `--dev` doesn't match `--devtools`. `dev`/`watch` as bare subcommands (e.g. `next dev`) are intentionally **not** matched — only explicit `--`-flag / env-var forms count, keeping the parser high-precision and unambiguous.

**Exit-gate judgment.** Discovery surfaced no significant deviation (one in-scope design detail resolved; files to edit and subtask list unchanged) → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended three in-repo shapes, invented none: `ScanCore.detectKind`/`hasTokenBoundary` (pure static token-match on a lowercased command — reused `hasTokenBoundary` verbatim for the flag tokens, inheriting the PID-54.2 word-boundary discipline); `.2`'s `ScanEngine.hasSustainedLowCPU` engine accessor (the verdict glue mirrors it); `reasoningBlock`'s graceful-degrade line pattern (PID-036.3 / PID-52.x — render only when the input resolves).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `Packages/PidlyseCore/Sources/PidlyseCore/ScanCore.swift`: added pure `hasDevModeFlag(_:)` — matches `--watch`/`--dev`/`--hot`/`--reload` via the existing `hasTokenBoundary` (so `--dev` ≠ `--devtools`, `--no-watch` ≠ `--watch`) plus a `node_env=development` / `node_env development` substring. High-precision by design: bare `dev`/`watch` subcommands don't match. `riskTier` untouched.
- `Pidlyse/ScanEngine.swift`: added `isIdleDevServer(_:)` folding `hasSustainedLowCPU(item) && item.elapsed >= elapsedThreshold && !item.hasTTY && ScanCore.hasDevModeFlag(item.command)` — the strict-AND reading resolved in Discovery. No new `@Published`; kill path untouched.
- `Pidlyse/MenuBarView.swift`: one conditional reasoning line in `reasoningBlock` ("idle dev server — sustained low CPU across recent scans"), rendered only when `engine.isIdleDevServer(item)`, placed right after the criterion-tag row (verdict-then-evidence). Graceful-degrade like the sibling provenance lines.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 197 tests, 0 failures (was 194; +3 new `hasDevModeFlag` tests). **TEST SUCCEEDED.**

- [x] Ran lint/type-check on changed code — the `make test` build compiles the app + `PidlyseCore` clean; Swift's compiler is the type-check (no separate linter). SourceKit "No such module" warnings in-editor are cross-file/target resolution noise, disproven by the clean build.

- [x] (frontend) Asked the user for visual confirmation — 👁️ ask offered (see recap). The exact trigger is impractical to reproduce on demand (needs a real dev server showing <1% CPU across ≥3 scans + old + no tty + a dev flag), so it's offered as optional later verification; the render is a standard secondary caption matching its siblings and the verdict logic is unit-tested.

**Testing Notes:** `hasDevModeFlag` tests cover explicit flags (incl. trailing-token + case-insensitive), `NODE_ENV=development`/` development` (and `production` rejected), and word-boundary false positives (`--devtools`, `--no-watch`, bare `next dev`/`npm run watch`).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: **updated** — the "why is this here?" inspector enumeration (line 10) gained the sustained-low-CPU "idle dev server" signal · `AGENTS.md`: no change (no inspector/signal detail) · `CLAUDE.md`: **updated** — extended the `ScanHistory` convention line with the `.3` consumer (dev-flag parse in core → `isIdleDevServer` glue → `MenuBarView` line, still signal-only) · `.flowtron/PLAN.md`: `.3` flipped to stub form.

- [x] Closed — PLAN.md `.3` line flipped to `Completed 2026-07-02.` (kept nested under `PID-EPIC-55`; cohort moves to `## Completed` when the parent closes at audit `.4`) and tasknote moved to `.flowtron/tasknote/archive/pid/`.

- [x] Recap drafted (surfaces inline on conditional skip).

**Final Summary:** Completed the `idle-stray-signals` epic's signal path — the consumer for `.2`'s scan-history infra. Added pure `ScanCore.hasDevModeFlag` (detects `--watch`/`--dev`/`--hot`/`--reload` + `NODE_ENV=development`, high-precision via the PID-54.2 token-boundary helper), `ScanEngine.isIdleDevServer` (strict-AND of sustained-low-CPU + old + no-TTY + dev-flag — the reading resolved with the operator), and one graceful-degrade reasoning line in `MenuBarView.reasoningBlock` surfacing the verdict in the "Why is this here?" expansion only. Signal-only: `riskTier`/`bucket`/kill bar untouched, no new `@Published`. 3 new tests; 197 pass. Files: `ScanCore.swift`, `ScanEngine.swift`, `MenuBarView.swift`, `ScanEngineTests.swift`, `README.md`, `CLAUDE.md`.

**Archived:** 2026-07-02
