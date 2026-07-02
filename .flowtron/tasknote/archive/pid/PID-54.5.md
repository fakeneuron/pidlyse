---
title: detection-rules audit
status: in-progress
tags: []
created: 2026-07-01
due:
related-tasks: [PID-EPIC-54, PID-54.1, PID-54.2, PID-54.3, PID-54.4]
---

# PID-54.5 | detection-rules audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-54]]

## 🎯 Goal

Verify the completed `PID-EPIC-54` (`detection-rules`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [x] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [x] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [x] No regressions surfaced in earlier-shipped cohort children's surfaces
- [x] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [x] Single `chore: PID-54.5 — audit PID-EPIC-54` commit lands (no code edits)
- [x] PLAN.md line for `PID-54.5` flipped to stub form `Completed 2026-07-01.`
- [x] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-54.5.md`
- [x] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-54` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [x] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [x] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [x] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [x] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [x] Phase 4: flip `PID-54.5` PLAN line to stub form + archive tasknote
- [x] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-54]] — parent epic (detection-rules)
- [[PID-54.1]] — discovery
- [[PID-54.2]] — expand-builtin-kinds
- [[PID-54.3]] — custom-rules
- [[PID-54.4]] — protect-and-scope

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-close-epic PID-54.5`. Pre-flight passed: PID-54.5 is the highest-numbered child (`.5`); all sibling children `.1`–`.4` are `[x]`; no open siblings; no existing tasknote or archive entry.

- [x] Read relevant source files — read all four archived cohort tasknotes (PID-54.1–.4 Final Summaries + Implementation Notes), plus current `ProcessItem.swift`, `ScanCore.swift`, `CustomRule.swift`, `IgnoreRule.swift`, `CwdResolver.swift`, and the four AI-referenced docs.

- [x] **Archive skim** — cohort children are the relevant archive entries for this audit; read in full above. No earlier non-cohort tasknotes in `archive/pid/` touch the exact same enum/classification surface (the closest precedent PID-13.3 was superseded by the cohort's work).

- [x] **Drift check** — all paths and symbols cited in the cohort tasknotes verified against HEAD. No drift found (see Discovery Notes).

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions — No clarifications needed. Cohort scope is well-defined: all four children closed with green `make test`, scope aligns with `.1` Discovery.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Cohort deliverables inventory

- **PID-54.1** (discovery) — Pure filing task. Refined the PID-EPIC-54 parent description; resolved 4 scoping questions; filed `.2`/`.3`/`.4` child lines. No code changes.
- **PID-54.2** (expand-builtin-kinds) — Added 7 new `ProcessKind` cases (`nextjs`, `astro`, `cargo`, `goRun`, `electron`, `llmServer`, `mcpServer`) + labels + `detectKind` matchers (via `hasTokenBoundary`/`isGoRun`) slotted before generic `npm`/`bun`/`node` fallbacks + `riskTier` arms. 11 unit tests. Files touched: `ProcessItem.swift`, `ScanCore.swift`, `ScanEngineTests.swift`, `SPEC.md`, `README.md`.
- **PID-54.3** (custom-rules) — New `CustomRule.swift` in PidlyseCore. `.custom` sentinel `ProcessKind` + `ProcessItem.customLabel`/`displayLabel`. `enumerate`/`makeItem` consult custom rules **before** `detectKind`. `ScanEngine.customRules` UserDefaults persistence. "Custom rules" `TextEditor` in Settings. Popover row / notifications / clean log use `displayLabel`. 9 unit tests. Files: `CustomRule.swift` (new), `ProcessItem.swift`, `ScanCore.swift`, `ScanEngine.swift`, `SettingsView.swift`, `MenuBarView.swift`, `SPEC.md`, `README.md`, `CLAUDE.md`.
- **PID-54.4** (protect-and-scope) — New `IgnoreRule.swift` in PidlyseCore. `ProcessCwd.projectRoot` field + `CwdResolver.isUnderPrefix` pure helper. `ScanCore.applyScopedIgnores` post-filter (scoped rules applied after cwd resolution). `ScanEngine.protectedProjects` UserDefaults persistence. "Protected projects" `TextEditor` in Settings + extended "Ignored processes" help text. `MenuBarView` protect overlay (`isProtected`, `sweepableSafeItems`, 🔒 badge, lock toggle). 14 unit tests. Files: `IgnoreRule.swift` (new), `CwdResolver.swift`, `ScanCore.swift`, `ScanEngine.swift`, `SettingsView.swift`, `MenuBarView.swift`, `SPEC.md`, `README.md`, `CLAUDE.md`.

### Drift check results
All symbols and paths verified at HEAD match what the tasknotes document. No drift.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A for this audit (verification pass, no new code surface).

- [x] Implemented the minimal solution — cohort coherence pass (see Implementation Notes).

- [x] Updated/added tests — N/A (no code edits landed).

**Implementation Notes:**

### Cohort coherence findings

**Naming/style consistency:**
- All 7 new `ProcessKind` cases follow the existing `camelCase` convention and have non-empty `label` strings ✓
- `CustomRule` and `IgnoreRule` both follow the pure-model-in-Core split established by prior tasknotes (`CleanEvent`, `CleanLog`, `Container`) — dedicated files, no app-side logic ✓
- `parse`/`serialize`/`firstMatch` naming on `CustomRule` mirrors the expected patterns; `parse`/`serialize` on `IgnoreRule` is consistent ✓
- `ProcessCwd.projectRoot` fits the existing `ProcessCwd` struct shape (optional field, defaulted) ✓

**Cross-ref consistency:**
- `.4`'s `applyScopedIgnores` correctly references `CwdResolver.isUnderPrefix`, which is defined in the same `CwdResolver.swift` file ✓
- `.3`'s `CustomRule.firstMatch` is called in `ScanCore.makeItem` before `detectKind` — precedence is enforced at the one classification entry point ✓
- `displayLabel` (`.3`) is used in `ScanEngine.makeCleanEvent` for the Cleaned tab, in notifications, and in `MenuBarView.rowDescriptor` — all display consumers updated consistently ✓

**Style parity:**
- `ignoredNames`, `customRules`, `protectedProjects` — all three follow the same `@Published var … : [String]` UserDefaults `didSet`+`init`-load persistence shape ✓
- All three Settings sections follow the `TextEditor` / one-item-per-line editor pattern ✓
- `sweepableSafeItems = safeItems.filter { !isProtected($0) }` is the clean separation between "listed" and "eligible for bulk sweep" ✓

**No regressions found:**
- The `riskTier` switch is exhaustive (Swift's compiler enforces this) ✓
- `.llmServer` appears in both the top-level "never easy kill" guard and the exhaustive switch arm (`case .docker, .uvicorn, .node, .llmServer: return .high`) — this is intentional duplication to satisfy the exhaustive switch; the comment is explicit ✓
- `customRules = []` default in `enumerate` means zero behavior change for callers that don't pass it ✓
- Bare `ignoredNames` lines still parse as global `IgnoreRule`s with `pathPrefix == nil` and flow through the unchanged `enumerate` path — backward-compatible ✓

**No misses found.** No follow-up filings needed.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (this audit applies no code edits). Each implementation child ran `make test` to green at closure: `.2` 160/0, `.3` 169/0, `.4` 183/0.

- [x] Ran lint/type-check on changed code — N/A (no code changes). Lint/type-check was run by each implementation child.

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI changes in this audit task).

**Testing Notes:** Pure markdown audit pass. All code-level test coverage was established and verified within the implementation children.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — **no change** (updated in PID-54.2 for 19-kind count + new kinds list, and in PID-54.4 for Settings lines; current content is accurate)
  - `AGENTS.md` — **no change** (workflow guide only; no feature/core-file surface updated by this cohort)
  - `CLAUDE.md` — **no change** (updated in PID-54.3 for `CustomRule.swift` and PID-54.4 for `IgnoreRule.swift`; both entries verified present)
  - `.flowtron/PLAN.md` — **updated** (PID-54.5 line flipped to stub form below)

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-07-01.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:** Audited the PID-EPIC-54 (detection-rules) cohort. Inventoried all four children: `.1` scoped the epic and filed children (no code); `.2` added 7 new `ProcessKind` cases with matchers + risk tiers + 11 tests; `.3` added user-defined custom detection rules (`CustomRule.swift`, `.custom` sentinel kind, `displayLabel`, Settings editor, 9 tests); `.4` added protected-project overlay and cwd-scoped per-project ignores (`IgnoreRule.swift`, `CwdResolver.isUnderPrefix`, `applyScopedIgnores`, 14 tests). Coherence pass: naming/style/pattern consistent across all children, no regressions in earlier-shipped surfaces, no contradictory cross-refs. No misses; no follow-up filings needed. Doc-drift: no further updates required (AI-referenced docs were all updated by implementation children). `make test` was green at each child's closure (183/0 at .4).

**Archived:** 2026-07-01
