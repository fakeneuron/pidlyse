---
title: feature-expansion audit
status: in-progress
tags: []
created: 2026-06-24
due:
related-tasks: [PID-EPIC-13, PID-13.1, PID-13.2, PID-13.3, PID-13.4, PID-13.5]
---

# PID-13.6 | feature-expansion audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-13]]

## 🎯 Goal

Verify the completed `PID-EPIC-13` (`feature-expansion`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-13.6 — audit PID-EPIC-13` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-13.6` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-13.6.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-13` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-13.6` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-13]] — parent epic
- [[PID-13.1]] — discovery
- [[PID-13.2]] — cpu-ram-per-row
- [[PID-13.3]] — process-patterns
- [[PID-13.4]] — app-description
- [[PID-13.5]] — notifications

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-close-epic PID-13.6`. Pre-flight passed: PID-13.6 is the highest `.N` child; all implementation siblings (PID-13.1–PID-13.5) are `[x]`; no open siblings; parent epic `PID-EPIC-13` is not yet in `## Completed`.

- [x] Read relevant source files

- [x] **Archive skim** — read all 5 cohort sibling archived tasknotes; deliverables captured in Discovery Notes below

- [x] **Drift check** — verified all paths cited in cohort children's Final Summaries exist at HEAD:
  - `Pidly/ScanEngine.swift` — present; `pcpu`/`rss` fields, vite/bun/node detection, notifications machinery all confirmed
  - `Pidly/ProcessItem.swift` — present; `cpuPercent: Double`, `rssKB: Int`, `.vite`/`.bun`/`.node` cases all confirmed
  - `Pidly/MenuBarView.swift` — present
  - `Pidly/SettingsView.swift` — present; `Toggle("Alert on new strays", isOn: $engine.notificationsEnabled)` confirmed
  - `README.md` — present; feature set updated by PID-13.4. No drift on existing content; one gap found (see Implementation Notes).
  No drift on function names, field names, or file paths.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Cohort fully closed; full archive access; no scope ambiguity.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Cohort deliverables inventory:**
- **PID-13.1** (discovery): Filed PID-13.2..PID-13.5 scopes in PLAN.md; confirmed PID-13.6 audit line as-filed. No code changes.
- **PID-13.2** (cpu-ram-per-row): `ScanEngine.runPS()` now requests `pcpu=,rss=`; `parsePSLine` parses 6 fixed fields; `ProcessItem` carries `cpuPercent: Double` and `rssKB: Int`; `MenuBarView.row()` renders two fixed-width trailing columns (36pt cpu%, 48pt RAM). Tests: 20 → 20/20 passing.
- **PID-13.3** (process-patterns): Added `.vite`, `.bun`, `.node` `ProcessKind` cases with labels "Vite", "Bun", "Node"; extended `detectKind` if-chain; assigned risk tiers (vite/bun = npm-tier, node = always-high). Tests: 20 → 35/35 passing (15 new).
- **PID-13.4** (app-description): Rewrote `README.md`: new tagline, Features section listing 12 process kinds, per-row signals (CPU%/RAM/age/risk-tier dots/"why" detail), kill flow, dismiss, settings. In-app copy reviewed — no changes (already clean).
- **PID-13.5** (notifications): Added `UserNotifications` opt-in: `@Published var notificationsEnabled` with UserDefaults persistence + permission request on enable; `previousPIDs` tracking to fire only for genuinely new strays; `rescan()` resets baseline; `fireNotificationIfNeeded` posts system notification. SettingsView: new "Notifications" section with toggle. Tests: 35/35 (no new tests — UNUserNotificationCenter is integration). README not updated (judgment call in PID-13.5).

**Gap found:** `README.md` Settings bullet does not mention the notification toggle added in PID-13.5. PID-13.5's Phase 4 explicitly chose "no change" for README; this is a legitimate documentation gap to correct in the audit. The fix is one-word addition to the settings line.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A for most audit work; one inline fix applied (README settings bullet), following the exact pattern PID-13.4 established for the README.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — N/A (one-line text fix; no logic changed)

**Implementation Notes:**

**Cohort coherence inventory:**
- Naming consistency: all three new `ProcessKind` cases (`.vite`, `.bun`, `.node`) follow the existing snake_case enum convention; their labels ("Vite", "Bun", "Node") follow the existing Title Case label convention. No contradictions with prior cases.
- Style parity: `cpuPercent`/`rssKB` field naming follows the existing `camelCase` convention in `ProcessItem`. The `ramString()` helper in `MenuBarView` follows the existing private-helper pattern.
- Risk tier assignment: node classified as always-high (consistent with docker/uvicorn guard); vite/bun at npm-tier (consistent with npm). No contradictory cross-refs between PID-13.2 and PID-13.3 deliverables.
- `notificationsEnabled` pattern in `ScanEngine` mirrors `scanInterval`/`elapsedThreshold` exactly (same `@Published var` + UserDefaults `didSet` + init load shape). Consistent with existing settings architecture.
- No contradictory cross-refs found across the cohort.

**Inline fix applied:**
- `README.md` line 15: added `notification alerts (opt-in)` to the Settings bullet to reflect the PID-13.5 `notificationsEnabled` toggle.

**No follow-up misses requiring `/ft-file-followup`** — the README gap is small enough to fix inline; all other surfaces are coherent.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (audit verification pass; inline fix is text-only, no Swift modified)

- [x] Ran lint/type-check on changed code — N/A (markdown-only change)

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (not a UI change)

**Testing Notes:**

Audit is a verification pass over existing cohort deliverables. Confirmed test count: 35/35 at HEAD (per PID-13.3 and PID-13.5 closures). Inline fix is one-line markdown; no build step required.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

  - `README.md` — **updated**: Settings bullet now includes "notification alerts (opt-in)" to reflect PID-13.5's `notificationsEnabled` toggle (was missing; fixed inline in this audit).
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `.flowtron/PLAN.md` — updated: PID-13.6 line flipped to stub form `Completed 2026-06-24.`

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-24.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Audit of `PID-EPIC-13` (feature-expansion) cohort complete. Five implementation children inventoried (PID-13.1–PID-13.5): all deliverables confirmed at HEAD with no drift. Cohort is coherent — naming, style, and risk-tier conventions are consistent across all children. One inline fix: `README.md` Settings bullet was missing the `notificationsEnabled` notification toggle added in PID-13.5; corrected in this audit. No follow-up misses requiring `/ft-file-followup`.

**Archived:** 2026-06-24
