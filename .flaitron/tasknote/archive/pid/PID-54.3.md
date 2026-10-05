---
title: custom-rules
status: in-progress
tags: []
created: 2026-07-01
related-tasks: [PID-EPIC-54, PID-54.1, PID-54.2, PID-54.4]
---

# PID-54.3 | custom-rules

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-54]] · [[PID-54.1]] · [[PID-54.2]]

## 🎯 Goal

Let users define simple custom detection rules — one command substring → a friendly display label — persisted in UserDefaults and consulted by the classifier ahead of the built-in kinds, with every custom match forced into Needs Review (never auto-killable).

## ✅ Acceptance

- [ ] A pure `CustomRule` model lives in `PidlyseCore`; rules thread into `ScanCore.enumerate` and are consulted **ahead of** the built-in `detectKind` matchers
- [ ] A custom-rule match surfaces a process that built-ins would miss, carries the user's friendly label, and always lands in the Needs Review bucket (never `.easy`/`.safe`)
- [ ] Custom rules persist to UserDefaults and are wired into `ScanEngine` (`@Published`, mirroring `ignoredNames`) + a Settings editor mirroring the Ignored-processes list
- [ ] Display consumers (popover group header/row, notifications, Cleaned tab) show the friendly custom label rather than a raw enum label
- [ ] Unit tests: custom rule catches an otherwise-unmatched command; custom precedence over a built-in kind; forced-needsReview tier; empty/malformed rule handling
- [ ] `make test` green
- [ ] SPEC.md §"Scan Engine"/§"Classification" + README feature surface updated for user-defined rules
- [ ] Phase 4 doc-drift sweep across README §"AI-referenced docs"

## 🧩 Subtasks

- [ ] Resolve scoping questions (custom-match representation + grouping · Settings editor format · risk tier · precedence semantics) via AskUserQuestion
- [ ] Add `CustomRule` model + classification hook in `PidlyseCore` (`ScanCore`/`ProcessItem`)
- [ ] Thread `customRules` through `enumerate` → `makeItem`, consulted ahead of `detectKind`
- [ ] Wire `customRules` persistence into `ScanEngine` (UserDefaults, `@Published`) + pass into the scan call
- [ ] Add the Settings editor section (mirror Ignored-processes)
- [ ] Update display consumers to render the friendly label
- [ ] Add unit tests in `ScanEngineTests.swift`; run `make test`
- [ ] Sync SPEC.md + README; Phase 4 closure (doc-drift, PLAN flip, archive)

## 🔗 Related

- [[PID-EPIC-54]] — parent epic (detection-rules)
- [[PID-54.1]] — discovery; scoped this child (minimal / max-UX; mirror Ignored-processes editor)
- [[PID-54.2]] — sibling; expanded built-in kinds (the fallbacks custom rules sit ahead of)
- [[PID-54.4]] — sibling; protected list + cwd-scoped ignores (also layers persisted overrides onto `enumerate`)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Implementation child `.3` of PID-EPIC-54, scoped by the `.1` Discovery. Independent of `.2` (done) and `.4` (sibling). Clear deliverable: user-defined substring→label rules consulted ahead of built-ins, always needsReview.

- [x] Read relevant source files — `ProcessItem.swift` (`ProcessKind`/`ProcessItem`/`Bucket`), `ScanCore.swift` (`enumerate`/`makeItem`/`detectKind`/`riskTier`), `ScanEngine.swift` (`ignoredNames`/`disabledKinds` persistence), `SettingsView.swift` (Ignored-processes editor), `MenuBarView.swift` (`grouped()`/`rowDescriptor`/`row`), `CleanedView.swift` (kind-label fallback).

- [x] **Archive skim** — load-bearing precedents: **PID-16.4** (scanengine-persistence — the `ignoredNames` UserDefaults `@Published`+`didSet` pattern to mirror), **PID-50.6** (per-kind-toggles — `disabledKinds` Set wiring + Settings toggle list), **PID-006** (added the Ignored-processes `TextEditor`), plus **PID-54.1** (scoped this child: minimal / max-UX / mirror Ignored-processes) and **PID-54.2** (the built-in fallbacks custom rules sit ahead of).

- [x] **Drift check** — all cited symbols match HEAD: `detectKind` `ScanCore.swift:187`, `enumerate` `:20`, `makeItem` `:109`, `riskTier` `:255`; `ProcessKind` `ProcessItem.swift:6`; `ScanEngine.ignoredNames` `:69`; `SettingsView` "Ignored processes" `:80`; `grouped()` `MenuBarView.swift:485` (groups by `ProcessKind`), `collapsedKinds: Set<ProcessKind>`, `rowDescriptor` `:292`; `CleanedView` label fallback `:86`/`:107`. No drift.

- [x] Asked clarifying questions — resolved via AskUserQuestion (table below)

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Central tension
Custom rules produce a **dynamic label with no built-in `ProcessKind`**, but the popover groups rows by `ProcessKind` (`grouped()` iterates `ProcessKind.allCases`; `collapsedKinds: Set<ProcessKind>`; header = `kind.label`) and the Cleaned tab keys off `kind.rawValue`. Representing a custom match therefore needs a sentinel kind + a side-channel label.

### Resolved scoping (AskUserQuestion, 2026-07-01)

| Question | Resolution |
|----------|-----------|
| Custom-match representation + grouping | **Single `.custom` sentinel kind, friendly label per row.** All custom matches group under one "Custom rules" header; each row's descriptor shows its own label. No change to the `grouped()`/`collapsedKinds` machinery (rejected per-rule group headers as over-minimal-budget). |
| Settings editor format | **`TextEditor`, one `substring = label` per line** — mirrors the Ignored-processes editor exactly (parse on edit). |
| Precedence when a process matches both a custom rule and a built-in | **Custom rule wins (relabel).** Consulted ahead of `detectKind`; overrides the built-in kind and forces needsReview. |

### Design (minimal)
- **`CustomRule` (new file `PidlyseCore/.../CustomRule.swift`)** — `struct { substring, label }` + pure statics: `parse(line)` (split first `=`; label falls back to substring; empty substring → nil), `serialize(rule)`, `firstMatch(command, in:)` (case-insensitive substring, first wins). Unit-testable.
- **`ProcessKind.custom`** (rawValue `custom`, label `Custom rules`) + `.custom` arm in the exhaustive `riskTier` switch → fixed `.moderate` (never `.easy` → always needsReview, regardless of stray signals).
- **`ProcessItem.customLabel: String?`** (new stored prop, default nil) + `displayLabel { customLabel ?? kind.label }`.
- **`ScanCore.enumerate`/`makeItem`** gain `customRules: [CustomRule] = []`; `makeItem` checks `CustomRule.firstMatch` **before** `detectKind` — match → `.custom` + `customLabel`.
- **`ScanEngine`** — `@Published var customRules` (UserDefaults `[String]` of serialized lines, mirroring `ignoredNames`), passed into the scan call. `makeCleanEvent` uses `displayLabel` for `.custom` (so the Cleaned tab's `ProcessKind(rawValue:)?.label ?? kc.kind` fallback shows the friendly label). Notifications use `displayLabel`.
- **`SettingsView`** — new "Custom rules" `TextEditor` section; exclude `.custom` from the "Scanned kinds" toggle list.
- **`MenuBarView.rowDescriptor`** — return `customLabel` for `.custom` items. `grouped()`/header unchanged (`.custom` flows through `allCases`; `.moderate` → group starts expanded).

### Downstream-impact reconciliation
Sibling `.4` (protect-and-scope) also layers persisted override lists onto `enumerate` — complementary, not conflicting (this adds a classification input; `.4` adds classification-override lists). No PLAN edits needed.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed **PID-16.4** (`ignoredNames` `@Published`+`didSet`+init-load persistence), **PID-50.6** (Settings section wiring), **PID-54.2** (kind + `riskTier` arm) and the `enumerate`/`makeItem` threading shape used by `ignoredNames`/`disabledKinds`/`dismissedPIDs`. No new structure invented — `CustomRule` mirrors the existing pure-model-in-Core split.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — 9 new tests.

**Implementation Notes:**
- **`CustomRule.swift`** (new PidlyseCore file): `struct { substring, label }` + pure `parse` (split first `=`, label falls back to substring, empty substring → nil), `serialize`, `firstMatch` (case-insensitive substring, first-wins).
- **`ProcessItem.swift`**: `.custom` kind (label "Custom rules") + `ProcessItem.customLabel: String?` + `displayLabel { customLabel ?? kind.label }`.
- **`ScanCore.swift`**: `customRules` threaded through `enumerate`→`makeItem`; `makeItem` checks `CustomRule.firstMatch` **before** `detectKind` (custom relabels a built-in). `riskTier` `.custom` arm → fixed `.moderate` (never easy → always needsReview).
- **`ScanEngine.swift`**: `@Published customRules` persisted to UserDefaults as `[String]` serialized lines (mirrors `ignoredNames`), loaded in `init`, passed into the scan call. Notifications + `makeCleanEvent` use `displayLabel` (custom cleans show the friendly label in the Cleaned tab via its `ProcessKind(rawValue:)?.label ?? kc.kind` fallback).
- **`SettingsView.swift`**: new "Custom rules" `TextEditor` section (mirrors Ignored-processes); `.custom` excluded from the "Scanned kinds" toggle list.
- **`MenuBarView.swift`**: `rowDescriptor` returns the friendly label for `.custom` rows. Grouping/`collapsedKinds` machinery untouched — `.custom` flows through `allCases` as a single "Custom rules" group (`.moderate` → starts expanded).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **169 tests, 0 failures** (+9 new: 5 `CustomRule` parse/serialize/firstMatch + 4 `enumerate` custom-rule classification).

- [x] Ran lint/type-check on changed code — Swift compile under `make test` type-checks the package; **TEST SUCCEEDED**. SourceKit "No such module 'PidlyseCore'/'XCTest'" + "Cannot find 'CustomRule'/'Shell'" diagnostics are cross-file resolution false positives (build + tests succeed).

- [x] (frontend) Asked the user for visual confirmation — 👁️ ask surfaced at closure (Settings "Custom rules" editor + popover "Custom rules" group). Not a gate.

**Testing Notes:** Custom-match behavior locked by unit tests: catches an otherwise-unmatched command, wins over a built-in kind, forced needsReview even as a strong stray, and no-op when the rule list is empty. Parse edge cases (bare substring → self-label, empty → nil, round-trip) covered.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` — **updated** (Settings feature line + custom detection rules) · `AGENTS.md` — no change · `CLAUDE.md` — **updated** (added `CustomRule.swift` to the PidlyseCore core-file list) · `.flowtron/PLAN.md` — updated (`.3` flipped to stub). Also synced the non-AI-referenced `SPEC.md` §"Scan Engine" + §"Classification" (the task's own contract deliverable).

- [x] Closed — PLAN.md line flipped to stub form and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted

**Final Summary:** Added user-defined custom detection rules to Pidlyse. A new pure `CustomRule` model in PidlyseCore (`substring → friendly label`, with `parse`/`serialize`/`firstMatch`) is threaded through `ScanCore.enumerate`/`makeItem` and consulted **ahead of** the built-in `detectKind` matchers — a custom match relabels even a built-in kind and is forced into Needs Review via a fixed-`.moderate` `.custom` risk tier (never auto-killable). Rules persist to UserDefaults and edit through a "Custom rules" `TextEditor` in Settings that mirrors the Ignored-processes list; matches surface under one "Custom rules" popover group with each row showing its friendly label, and the friendly label also flows into new-stray notifications and the Cleaned tab. 9 unit tests, `make test` green (169/0). SPEC + README + CLAUDE.md synced.

**Archived:** 2026-07-01
