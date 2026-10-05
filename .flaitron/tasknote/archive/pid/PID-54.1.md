---
title: detection-rules discovery
status: in-progress
tags: []
created: 2026-07-01
due:
related-tasks: [PID-EPIC-54]
---

# PID-54.1 | detection-rules discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-54]]

## 🎯 Goal

Scope the `PID-EPIC-54` epic (`detection-rules`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-54.2 .. PID-54.4` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (detection core, settings/persistence wiring, SPEC contract impact) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-54.2 .. PID-54.4 filed in `.flowtron/PLAN.md` (each line ≤50w target / 70w hard cap)
- [ ] Audit line PID-54.5 reviewed and confirmed as-filed (or rewritten if the Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (detection core, settings/persistence, SPEC contract, docs) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/pid/` for relevant precedents — log load-bearing findings
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (child split, custom-rules depth, protected-list semantics, per-project ignore mechanism) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-54.2 .. PID-54.4; word-count each (≤50w / 70w cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under PID-EPIC-54 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-54]] — parent epic (detection-rules)
- [[PID-EPIC-55]] — idle-stray-signals (adjacent; "dev-mode flag parsing" surface overlaps — reconcile in Phase 2)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-epic-discovery PID-54.1`. The epic (parent + `.1` + `.5` audit lines) was batch-filed in a prior session (PLAN.md High §, lines 11–13) with a placeholder description; this Discovery refines it and files the implementation children. SPEC/epic.md lifecycle step 2 covers running Discovery on a manually-filed epic.

- [x] Read relevant source files

- [x] **Archive skim** — see Discovery Notes

- [x] **Drift check** — see Discovery Notes

- [x] Asked clarifying questions — resolved via AskUserQuestion (table below)

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Shared design surface

**Detection / classification (PidlyseCore):**
- `ProcessKind` enum (`ProcessItem.swift:6–37`) — 12 cases, each with a `label`. `CaseIterable` drives the Settings "Scanned kinds" toggle list + the `disabledKinds` persistence (rawValue). Adding a kind ⇒ add a case + a `label`.
- `ScanCore.detectKind(_:)` (`ScanCore.swift:187–209`) — ordered command-substring matcher; specific cases precede generic fallbacks (`node`/`npm` last). New kinds must slot **before** those fallbacks so a Next.js/Astro server isn't swallowed by `.node`.
- `ScanCore.riskTier(...)` (`ScanCore.swift:229–242`) — **exhaustive switch** over `ProcessKind`; adding cases forces a tier decision (compile-time gate).
- `hasTokenBoundary(_:_:)` (`ScanCore.swift:215–225`) — reusable word-boundary matcher for new kinds.

**Settings / persistence (app-side):**
- `ScanEngine` `@Published`: `ignoredNames: [String]` (substring ignores, UserDefaults), `disabledKinds: Set<ProcessKind>` (category toggles, UserDefaults rawValues), `dismissedPIDs` (session-only). All flow into `ScanCore.enumerate(...)`.
- `SettingsView` — "Ignored processes" `TextEditor` (one substring/line) + "Scanned kinds" toggle list over `ProcessKind.allCases`. This is the pattern any new user-config surface (custom rules / protected list / per-project ignores) extends.
- `enumerate(...)` (`ScanCore.swift:20–49`) already threads `ignoredNames` (substring hide), `dismissedPIDs`, `disabledKinds` (kind hide). A "protect" concept would be a *new* axis: not hide, but force-to-needsReview / lock-from-safe.

**Docs (contract to keep in sync — edits land in children, not here):**
- `SPEC.md` §"Scan Engine" pattern table (`SPEC.md:53–63`) + §"Classification" (`:73–85`) — enumerate the kinds; each new kind adds a row.
- `README.md` — shipped feature surface (custom rules / protected list are user-visible).

### Archive precedents (load-bearing)
- `PID-13.3` (process-patterns) — the precedent for adding `ProcessKind` cases + detectKind entries + risk tiers. Closest template for the `.2` built-in-expansion child.
- `PID-046` (node-bun-tokenboundary) — introduced `hasTokenBoundary` to stop `npm` matching `pnpm` etc. New kinds must reuse it, not raw `contains`.
- `PID-045` (set-toggle-ext) — the "Scanned kinds" per-kind toggle + `disabledKinds` persistence pattern; template for wiring a new user-config `Set`/list into Settings + UserDefaults + `enumerate`.

### Drift
- Epic placeholder lists "vite dev servers" among kinds to add, but `.vite` is **already** a shipped kind (`ProcessItem.swift:12`, detected `ScanCore.swift:201`). Built-in expansion is really about *new* kinds (next/astro/sveltekit/cargo/go run/ollama+LLM servers/electron helpers/more MCP+Playwright variants). Refined `.2` description will say so.
- No other path/line drift; all cited symbols match HEAD.

### Scope shape (4 clusters → 3 child slots)
The placeholder names four themes: (1) expand built-in kinds, (2) user-defined custom rules, (3) persistent protected-processes list, (4) stronger per-project ignores. N=5 leaves 3 implementation slots (.2/.3/.4) — clusters (3) and (4) pair naturally (both are persisted classification-override lists layered onto `enumerate`).

### Resolved scoping (AskUserQuestion, 2026-07-01)

| Question | Resolution |
|----------|-----------|
| Child split (4 themes → 3 slots) | `.2` = expand built-in kinds · `.3` = custom rules · `.4` = protected list **+** per-project ignores (the two persisted override lists paired). N stays 5; audit remains `.5`. |
| Custom-rules depth | **Minimal / max-UX.** One command substring → a friendly display label; always lands in Needs Review (never auto-killable). No user-set risk tiers, no compound/tangled conditions — mirror the simple Ignored-processes editor. |
| Protected-list semantics | Protected matches are kept **out of Safe / "Clean all safe"** (marked 🔒) but stay visible; **easy one-click un-protect** required (user: "make sure we can unlock"). Individual kill stays available — protection blocks the *bulk safe-sweep*, not deliberate action. |
| Per-project ignore mechanism | **cwd path-prefix** via `CwdResolver` — an ignore rule may carry a project-directory prefix and hides only matches whose resolved cwd sits under that tree. |

### Downstream-impact reconciliation scan (new-child-filing trigger)
Scanned active High/Medium/Low/Future for shared surface with the `.2–.4` children (detection core, `detectKind`/`ProcessKind`, `ignoredNames`, `CwdResolver`, `riskTier`, SPEC pattern table):
- **PID-EPIC-55 (idle-stray-signals)** — shares the detection / command-line-parsing surface ("dev-mode flag parsing"). Classification: **complementary, not stale** — EPIC-55 is signal-only (never touches the kill bar) and layers *stray-confidence* on top of *kind identity*; it should build on `.2`'s expanded kinds. Action: **leave** (adjacency noted in this tasknote's Related + here). No edit.
- PID-EPIC-56 (docker-enhance), PID-EPIC-57 (cli-companion), PID-EPIC-58 (integrations), PID-059/060, PID-030 — no shared classification surface (docker-stats / consumer-of-core / icons / notarization). **Unaffected.**
- Verdict: no reconcile edits to existing lines needed.

### Audit line review
`PID-54.5` (audit) reviewed — no scope shift; N stays 5. Confirmed as-filed.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the existing PID epic-cohort filing pattern (2-space indent under parent, `[medium]🧠` on every line, em-dash separator, ≤50w/70w)

- [x] Implemented the minimal solution — wrote `.2/.3/.4` child lines into PLAN.md between `.1` and the `.5` audit

- [x] Updated/added tests — N/A (pure PLAN.md filing; no code surface)

**Implementation Notes:**
- 3 child lines written under PID-EPIC-54. Word counts: `.2` = 47w, `.3` = 49w, `.4` = 48w (all under the 50w target / 70w hard cap).
- N unchanged (5); audit stays `.5`. No audit-number bump.
- Parent epic description refined from its filing-time placeholder to reflect resolved scope (dropped the stale `vite` — already a shipped kind; noted the simplified custom-rules and cwd-scoped ignores).
- Downstream reconciliation: no edits to existing PLAN entries (PID-EPIC-55 is complementary, not stale — see Discovery Notes). No downstream impact requiring a reconcile edit.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (markdown filing)
- [x] Ran lint/type-check on changed code — N/A; markdown mental-pass done (2-space indent preserved, bold IDs intact, `[medium]🧠` on every line, `| shortname` ≤30 chars, em-dash consistent, ≤70w, no trailing whitespace)
- [x] (frontend) Asked the user for visual confirmation — N/A

**Testing Notes:** Markdown mental-pass clean across all three new lines; the `.1`/`.5` neighbors still parse.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` — no change · `AGENTS.md` — no change · `CLAUDE.md` — no change · `.flowtron/PLAN.md` — updated (the child-filing deliverable itself). Contract edits (SPEC Scan-Engine table, README feature surface) land inside the implementation children, not here.
- [x] Closed — PLAN.md `.1` line flipped to stub form and tasknote moved to `.flowtron/tasknote/archive/pid/`
- [x] Recap drafted

**Final Summary:** Refined and scoped PID-EPIC-54 (detection-rules). Inventoried the shared classification surface — `ProcessKind` + `ScanCore.detectKind`/`riskTier`/`hasTokenBoundary` in PidlyseCore, and the `ScanEngine`/`SettingsView` UserDefaults-backed config surface (`ignoredNames`, `disabledKinds`). Resolved four scoping questions with the user and filed three implementation children: `.2` expand-builtin-kinds, `.3` custom-rules (deliberately minimal, max-UX), `.4` protect-and-scope (protected list + cwd-scoped per-project ignores). Audit `.5` confirmed as-filed; N stays 5.

**Archived:** 2026-07-01
