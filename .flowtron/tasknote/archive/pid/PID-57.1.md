---
title: cli-companion discovery
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-57]
---

# PID-57.1 | cli-companion discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-57]]

## 🎯 Goal

Scope the `PID-EPIC-57` epic (`cli-companion`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-57.2..3` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (sources, adopter wiring, SPEC contract impact, templates) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for PID-57.2 .. PID-57.3 filed in .flowtron/PLAN.md (each line under the 50w target / 70w hard cap per SPEC/tasknote-selection.md §"PLAN.md filing-discipline thresholds")
- [ ] Audit line PID-57.4 reviewed and confirmed as-filed (or rewritten if the Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (source files, project structure, kill-logic split, build/packaging impact) — log in Discovery Notes
- [ ] Skim .flowtron/tasknote/archive/pid/ for relevant precedents — log load-bearing findings in Discovery Notes
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (typical: per-child shortname + scope + kill-logic placement policy) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for PID-57.2 .. PID-57.3; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-57 with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-57]] — parent epic: terminal companion binary sharing PidlyseCore

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Epic filed 2026-07-02 via /ft-epic-discovery cross-session handoff; PidlyseCore already exists as the shared package (PID-27.2) and PID-53.1 explicitly kept CleanLog in core for this consumer. Nothing has shipped a CLI surface since filing — the epic is live and unduplicated.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/pid/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface inventory:**

- `Packages/PidlyseCore/` — local SPM package (library product only, macOS 14+, zero external deps). Package.swift comment still cites the abandoned PID-EPIC-27 helper as the second consumer; the CLI becomes the real one. Scan + classification are fully reusable today: `ScanCore.enumerate(...)` is pure given inputs; `CustomRule`/`IgnoreRule` parse from strings; `CleanEvent`/`CleanLog` already in core (kept there by PID-53.1 explicitly for cli-companion).
- **Kill logic is app-side** — `Pidlyse/KillService.swift` holds the SIGTERM → 2 s grace → SIGKILL path with PID-reuse identity guards (pure decision fns `shouldSendSIGTERM`/`shouldEscalateToSIGKILL` + `sysctl` start-time reader), built on `DispatchQueue` with main-queue callbacks. Docker kills route through app-side `DockerService` (`docker stop` by container name from the scan-time `containerOwners` map). A CLI `clean`/`kill` needs this shared: extraction into core (with a synchronous call shape usable without a run loop) is the natural .2.
- `Pidlyse/DockerService.swift` — impure docker CLI layer (trusted-path resolution, `run`, `listContainers`, `containerOwners`); already delegates spawning to core `Shell.run`. Sharing it means moving it (or its non-UI subset) into PidlyseCore — a deliberate CLAUDE.md convention update ("app-side DockerService" → core) that lands inside the children.
- **Settings inputs the CLI must replicate** — `ScanEngine` feeds `enumerate` from `UserDefaults.standard`: `elapsedThreshold`, `ignoredNames` (→ `IgnoreRule` split global/scoped), `protectedProjects`, `disabledKinds`, `customRules`. App defaults domain: `com.fakeneuron.pidlyse` — a CLI process can read it via `UserDefaults(suiteName:)`/CFPreferences for rule parity.
- `CleanLogStore` (app-side) writes `~/Library/Application Support/Pidlyse/clean-log.json`; CLI cleans appending there is possible (shared file, last-writer-wins risk is negligible for a single-user tool) — scoping question.
- **Build/packaging** — Makefile is xcodebuild-only (`test`/`build-release`/`install`/`dmg`); an SPM executable adds `swift build`-based targets and an install story (`/usr/local/bin` copy or symlink). DMG/app-bundle embedding is out of scope unless the user says otherwise.

**Archive skim (load-bearing):**

- [[PID-27.2]] — created `PidlyseCore` exactly for a second non-app consumer; app links it statically; cross-module API already `public`. Target-kind decision (local Swift Package) was operator-confirmed.
- [[PID-029]] — tore out the EPIC-27 helper target; core survived as a benign refactor. Precedent for xcodeproj surgery if the CLI needs project wiring (it shouldn't — pure SPM).
- [[PID-53.1]] — "CleanEvent/CleanLog live in PidlyseCore, so PID-EPIC-57 (cli-companion) could later reuse them" — direct forward-pointer to this epic.
- [[PID-35.3]] — kill-path identity hardening (ProcStartTime in core, guards in KillService); any kill-logic move must preserve these guards byte-for-byte in behavior.

**Drift check:** PLAN line says the target shares PidlyseCore's "scan, classification, and kill logic" — **drift: kill logic is NOT in PidlyseCore today** (only the `ProcStartTime` token is; `KillService` is app-target). The epic therefore implies a core-side kill extraction as prerequisite work, which shapes child .2. All other cited concepts (SPM package, never-auto-kill posture) match HEAD.

**Resolved scoping (AskUserQuestion, 2026-07-02):**

| Question | Resolution |
|---|---|
| Child split | **.2 kill-core extraction, .3 cli-target** — extraction first, executable on top |
| App-settings parity | **Full parity** — CLI reads the app's defaults domain (`com.fakeneuron.pidlyse`); no override flags in v1; app stays the settings UI |
| Clean-log integration | **Yes, shared log** — CLI confirmed kills append to `clean-log.json`; single-user, concurrent-write risk accepted |
| Arg parsing | **Hand-rolled** — small switch over `CommandLine.arguments`; repo stays zero-external-deps |

**Drafted child lines (word counts: .2 = 38w, .3 = 37w — both under the 50w target):**

- `**PID-57.2** [medium]🧠 | kill-core-extraction` — Move kill logic into PidlyseCore: synchronous SIGTERM → 2 s grace → SIGKILL path preserving the PID-35.3 identity guards, docker-stop routing, and the impure docker CLI layer (DockerService). App keeps thin async wrappers; behavior unchanged; tests migrate; CLAUDE.md convention notes updated.
- `**PID-57.3** [medium]🧠 | cli-target` — Add `pidlyse` SPM executable target: `list [--safe]`, `clean`, `kill <pid>` (hand-rolled arg parsing, zero new deps). Reads the app's defaults domain for full rule parity; confirmed kills append to the shared clean-log. Makefile build/install wiring; never auto-kills.

Model token: `[medium]🧠` per child — both are well-scoped multi-step design work; precedent PID-27.2 (shared-scan-core) and PID-28.2 (docker-service) ran `[medium]`. Parent/audit stay `[heavy]🧠` as filed. N stays 4; audit `.4` number unchanged.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior (N/A — pure PLAN.md filing, no executable code surface)

**Implementation Notes:**

Pattern followed the PID-56.1 cohort-children filing precedent (2-space indent, `[model]` on every line, em-dash separator). Wrote 2 child lines (word counts: .2 = 38w, .3 = 37w — both under the 50w target). Parent epic description refined at closure per the filing placeholder: now records the kill-extraction prerequisite (the drift finding), settings parity, and clean-log integration (42w). N stayed 4; audit `.4` number unchanged. **Downstream-impact reconciliation scan:** PID-EPIC-58 (integrations) already wikilinks [[PID-EPIC-57]] as a dependency — unaffected/leave; PID-030 (notarize) scopes the app DMG only — unaffected/leave; PID-060 (readme-visuals) is popover screenshots — unaffected/leave. No existing entries edited.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code (N/A — markdown-only)

- [x] Ran lint/type-check on changed code (N/A — markdown mental-pass: indent, bold IDs, `[model]` tags, shortnames ≤30 chars, em-dashes, word caps, no trailing whitespace — all pass)

- [x] (frontend) Asked the user for visual confirmation (N/A — no frontend)

**Testing Notes:** Markdown mental-pass on the PLAN.md block: 2-space child indent preserved on .1–.4; `[medium]🧠` on new lines, `[heavy]🧠` retained on parent/.1/.4; shortnames `kill-core-extraction` (20) and `cli-target` (10) within cap; descriptions 38w/37w; parent 42w.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Scoped PID-EPIC-57 (cli-companion): inventoried the shared design surface (ScanCore/CustomRule/IgnoreRule/CleanLog CLI-ready in core; kill logic app-side — flagged as the epic's real prerequisite), resolved 4 scoping questions with the operator (extraction-first child split, full app-settings parity via the `com.fakeneuron.pidlyse` defaults domain, shared clean-log writes, hand-rolled arg parsing / zero deps), and filed children .2 (kill-core-extraction, 38w) + .3 (cli-target, 37w) under the parent in PLAN.md. Parent description refined; audit .4 confirmed as-filed; no downstream PLAN impact.

Doc-drift sweep: `README.md` no change · `AGENTS.md` no change · `CLAUDE.md` no change (convention updates land in .2) · `SPEC.md` no change (contract edits land in the children) · `.flowtron/PLAN.md` updated in-task (children + parent refinement + .1 stub flip).

**Archived:** 2026-07-02
