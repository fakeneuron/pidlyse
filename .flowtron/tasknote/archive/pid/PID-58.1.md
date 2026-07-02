---
title: discovery
status: completed
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-58, PID-EPIC-57]
---

# PID-58.1 | discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-58]] [[PID-EPIC-57]]

## 🎯 Goal

Scope the shared design for exposing Pidlyse actions to external launchers (URL scheme + Raycast/Shortcuts/AppleScript bridges) and file implementation children `.2..3` for [[PID-EPIC-58]] in PLAN.md.

## ✅ Acceptance

- [x] Shared design surface inventoried for the epic (app entry points, headless action layer, CLI reuse, security posture) — captured in Discovery Notes
- [x] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [x] Concrete child scopes for PID-58.2 .. PID-58.3 filed in .flowtron/PLAN.md (each line under the 50w target / 70w hard cap per SPEC/tasknote-selection.md §"PLAN.md filing-discipline thresholds")
- [x] Parent epic description refined per the filing placeholder ("refined at .1 closure")
- [x] Audit line PID-58.4 reviewed and confirmed as-filed (or rewritten if the Discovery surfaces a scope shift)
- [x] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [x] Inventory shared design surface (URL-scheme wiring, action-layer gap, AppIntents/Raycast/AppleScript options, security posture) — log in Discovery Notes
- [x] Skim .flowtron/tasknote/archive/pid/ for relevant precedents — log load-bearing findings in Discovery Notes
- [x] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [x] Surface open scoping questions via AskUserQuestion (URL destructive posture, bridge set, child split) — record answers in a "Resolved scoping" table
- [x] Draft refined long descriptions for PID-58.2 .. PID-58.3 + parent refinement; word-count each (≤50w target / 70w hard cap)
- [x] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-58 with 2-space indent + refine the parent description
- [x] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [x] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-58]] — parent epic (integrations: URL scheme + external-launcher bridges)
- [[PID-EPIC-57]] — cli-companion; the epic filing flags a likely dependency on the CLI surface

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Epic filed 2026-07-02 at PID-EPIC-58 filing time; the flagged dependency ([[PID-EPIC-57]] cli-companion) closed 2026-07-02, so the CLI surface the bridges can ride on now exists. No integration surface (URL scheme, AppIntents, AppleScript) has shipped — the epic is live and unduplicated.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface inventory:**

- **App entry points** — `Pidlyse/Info.plist` has no `CFBundleURLTypes` today; a `pidlyse://` scheme needs that key + an `application(_:open:)` handler in `AppDelegate`. The app is `LSUIElement` with `NSApplicationDelegateAdaptor` — URL opens route to the delegate cleanly even with no windows.
- **No headless action layer in the app** — the "Clean all" sweep set (safe bucket minus protected projects, PID-54.4) is computed *view-side* in `MenuBarView` (`sweepableItems`, MenuBarView.swift:503) and calls `KillService.kill`. An external trigger (URL / AppIntent) can't go through the view; it needs an engine-side "clean all safe" entry point — the same set the CLI's `commandClean()` already derives in `main.swift` from core primitives. Extracting/hosting that sweep action on `ScanEngine` (or a small coordinator) is the shared plumbing both .2 and .3 ride on.
- **CLI companion shipped (PID-57.3)** — `pidlyse list/clean/kill` with full defaults-domain parity + shared clean-log. Raycast script commands can wrap the installed CLI with zero app changes; Shortcuts/AppIntents run in-app and want the engine-side action instead.
- **Shortcuts** — AppIntents framework is native on the macOS 14+ target; intents exposed there are invocable from Shortcuts, Spotlight, AND Raycast (which lists Shortcuts), so one AppIntents surface covers two launchers.
- **AppleScript** — would need `NSAppleScriptEnabled` + an `.sdef`; heavyweight, and `osascript` users can already `do shell script "pidlyse clean"` via the CLI.
- **Clean-log** — any new trigger path that kills must append `.confirmed` outcomes via the shared `CleanLogFile`/`recordCleaned` rules (PID-53.2) so the Cleaned tab stays truthful.

**Archive skim (load-bearing):**

- [[PID-35.1]] (security-sweep discovery) — audited baseline explicitly records "no network, **no NSAppleScript**" as a security positive. A URL scheme and any sdef bridge deliberately expand the app's external attack surface; the drive-by vector (a web page or app opening `pidlyse://clean`) must be weighed against the "never kill without explicit user action" non-negotiable.
- [[PID-57.1]] / [[PID-57.3]] — CLI scoping precedent: full settings parity via the `com.fakeneuron.pidlyse` defaults domain, shared clean-log, zero external deps, hand-rolled parsing. The CLI's `commandClean()` is the reference implementation of a headless "Clean all".
- [[PID-54.1]] / [[PID-56.1]] — reconciliation scans list EPIC-58 as unaffected by the detection/docker cohorts; no stale cross-refs to honor.

**Drift check:** Parent line cites the [[PID-EPIC-57]] dependency as "likely" — now resolved (epic completed 2026-07-02); the CLI surface exists at `Packages/PidlyseCore/Sources/PidlyseCLI/main.swift`. No other paths/concepts cited by the epic line; no drift.

**Resolved scoping (AskUserQuestion, 2026-07-02):**

| Question | Resolution |
|---|---|
| URL-scheme destructive posture | **Direct clean + result notification** — `pidlyse://clean` runs the safe sweep immediately (launcher invocation = the explicit user action) and posts a notification with the outcome; browsers already gate scheme opens, and a malicious local app could kill directly anyway |
| Bridge set | **AppIntents (Shortcuts/Spotlight/Raycast-via-Shortcuts) + Raycast script commands wrapping the CLI**; AppleScript `.sdef` dropped — heavyweight, re-expands the PID-35.1-audited surface, `osascript` users have `do shell script "pidlyse clean"` |
| Child split | **.2 url-scheme + engine-side action layer, .3 bridges** — extraction-first, mirroring the PID-57 split; .3 rides on .2's headless action |

**Drafted child lines (word counts: .2 = 35w, .3 = 32w — both under the 50w target):**

- `**PID-58.2** [medium]🧠 | url-scheme` — Register `pidlyse://` (CFBundleURLTypes + AppDelegate routing) with `clean`/`scan` verbs. Extract an engine-side headless "clean all safe" action (safe minus protected, clean-log append) shared by all external triggers; `clean` acts directly and posts a result notification.
- `**PID-58.3** [medium]🧠 | bridges` — Shortcuts bridge via AppIntents ("Clean safe strays", "Scan now") on the .2 action layer, plus sample Raycast script commands wrapping the installed CLI (`integrations/raycast/` + docs). AppleScript dropped — CLI covers `osascript` users.

Model token: `[medium]🧠` per child — both are well-scoped multi-step design work, matching the PID-57.2/.3 precedent. Parent stays `[medium]🧠` as filed; audit `.4` number unchanged, N stays 4.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior (N/A — pure PLAN.md filing, no executable code surface)

**Implementation Notes:**

Pattern followed the [[PID-57.1]] cohort-children filing precedent (2-space indent, `[model]` on every line, em-dash separator, parent refined at the same edit). Wrote 2 child lines (word counts: .2 = 35w, .3 = 32w — both under the 50w target) and refined the parent description per its filing placeholder (33w — records the direct-clean+notification posture, the AppIntents + Raycast-script bridge set, and the AppleScript drop). N stayed 4; audit `.4` number unchanged. **Downstream-impact reconciliation scan:** active PLAN entries — PID-060 (readme-visuals: popover screenshots, no integration surface) and PID-030 (notarize: signing/DMG scope; URL scheme + AppIntents run fine ad-hoc signed) — both **unaffected/leave**; no existing entries edited.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code (N/A — markdown-only)

- [x] Ran lint/type-check on changed code (N/A — markdown mental-pass: indent, bold IDs, `[model]` tags, shortnames ≤30 chars, em-dashes, word caps, no trailing whitespace — all pass)

- [x] (frontend) Asked the user for visual confirmation (N/A — no frontend)

**Testing Notes:** Markdown mental-pass on the PLAN.md block: 2-space child indent preserved on .1–.4; `[medium]🧠` on all lines matching the cohort; shortnames `url-scheme` (10) and `bridges` (7) within cap; descriptions 35w/32w, parent 33w; `[[PID-EPIC-57]]` wikilink in the parent description is a deliberate cross-ref (relatedTasks signal); backtick spans (`pidlyse://`, `integrations/raycast/`, `osascript`) keep illustrative text out of the wikilink-integrity grep.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Scoped PID-EPIC-58 (integrations): inventoried the shared design surface (no `CFBundleURLTypes`/URL handling today; the "Clean all" sweep set is view-side in `MenuBarView` so external triggers need an engine-side headless action; the [[PID-EPIC-57]] CLI is the ready-made Raycast substrate; PID-35.1's "no AppleScript / no network" security baseline weighs against an `.sdef`), resolved 3 scoping questions with the operator (direct `pidlyse://clean` + result notification, AppIntents + Raycast script commands with AppleScript dropped, extraction-first child split), and filed children .2 (url-scheme, 35w) + .3 (bridges, 32w) under the parent in PLAN.md. Parent description refined per its filing placeholder (33w); audit .4 confirmed as-filed, N stays 4; downstream reconciliation found PID-060/PID-030 unaffected.

Doc-drift sweep: `README.md` no change · `AGENTS.md` no change · `CLAUDE.md` no change (URL-scheme/AppIntents conventions land in .2/.3) · `SPEC.md` no change (integration surfaces documented when the children ship) · `.flowtron/PLAN.md` updated in-task (children + parent refinement + .1 stub flip).

**Archived:** 2026-07-02
