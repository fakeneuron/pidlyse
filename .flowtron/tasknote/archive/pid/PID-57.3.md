---
title: cli-target
status: completed
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-57, PID-57.1, PID-57.2]
---

# PID-57.3 | cli-target

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-57]] [[PID-57.1]] [[PID-57.2]]

## 🎯 Goal

Add a `pidlyse` SPM executable target — `list [--safe]`, `clean`, `kill <pid>` with hand-rolled arg parsing and zero new deps — that reads the app's defaults domain for full rule parity, appends confirmed kills to the shared clean-log, and wires into the Makefile; never auto-kills.

## ✅ Acceptance

- [x] `swift build --package-path Packages/PidlyseCore --product pidlyse` produces a `pidlyse` binary; zero external dependencies (hand-rolled arg parsing)
- [x] `pidlyse list` prints scan candidates with full app-rule parity — `elapsedThreshold`, global + scoped ignores, disabled kinds, custom rules read from the `com.fakeneuron.pidlyse` defaults domain; protected rows marked 🔒; `--safe` filters to the safe bucket
- [x] `pidlyse clean` kills exactly the app's "Clean all" sweep set (safe bucket minus protected), via `KillCore.kill` (SIGTERM → 2 s grace → SIGKILL, docker-stop routing, identity guards); per-item outcome printed
- [x] `pidlyse kill <pid>` kills a *scanned candidate* by PID (any bucket, incl. needsReview — explicit user action); refuses PIDs that aren't scan candidates
- [x] Confirmed kills append to the shared `~/Library/Application Support/Pidlyse/clean-log.json` in the app's exact format (single format SSOT — no CLI-side re-implementation drift)
- [x] Never auto-kills: kills happen only on explicit `clean` / `kill` invocation; no daemon/timer surface
- [x] Makefile gains `build-cli` / `install-cli`; `make test` green including new tests for the pure CLI logic
- [x] Docs updated: CLAUDE.md conventions, SPEC.md structure, README build/install

## 🧩 Subtasks

- [x] `Package.swift`: add `.executableTarget` (dir `Sources/PidlyseCLI/`) + `.executable(name: "pidlyse")` product depending on `PidlyseCore`
- [x] Core `CLICore.swift`: pure command grammar (`list [--safe]` / `clean` / `kill <pid>` / help) parse + table/duration/RAM formatting — testable from `PidlyseTests` (mirrors the ScanCore/ScanEngine split)
- [x] Core `CleanLogFile.swift`: shared clean-log disk I/O (load / append-capped / atomic save, ISO-8601 + sorted-keys format SSOT); refactor app `CleanLogStore` to delegate to it
- [x] Executable `Sources/PidlyseCLI/main.swift`: defaults-domain settings read, ScanEngine-parity scan pipeline (portMap → containerOwners → enumerate → cwds → scoped ignores), command dispatch, DispatchGroup bulk kill, clean-log append, exit codes
- [x] Tests in `PidlyseTests`: CLICore parse/format matrices + CleanLogFile round-trip against a temp file
- [x] Makefile: `build-cli` (swift build -c release) + `install-cli` (/usr/local/bin) targets
- [x] Docs: CLAUDE.md convention bullets (CLI target + clean-log split revision), SPEC.md structure, README
- [x] `make test` green; standalone `swift build` of the package green; manual smoke `pidlyse list`

## 🔗 Related

- [[PID-EPIC-57]] — parent epic: cli-companion
- [[PID-57.1]] — discovery: scoped children .2–.3, design decisions for the CLI surface
- [[PID-57.2]] — kill-core-extraction: moved kill path + DockerService into PidlyseCore (prerequisite, landed)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Prerequisite [[PID-57.2]] landed today (`be9f08e`) — `KillCore` + `DockerService` are in `PidlyseCore` and the package builds standalone; no CLI surface exists at HEAD. This is the epic's live implementation child, scoped by the [[PID-57.1]] operator-resolved table (full parity / shared clean-log / hand-rolled args / zero deps).

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Source survey (files read):** core `Package.swift` (library-only product, macOS 14, zero deps — header already cites the cli-companion as the consumer), `KillCore.swift` (blocking `kill(_:containerOwners:)` designed for run-loop-free consumers — exactly the CLI's call shape), `ScanCore.swift` (`enumerate` fully injectable; `applyScopedIgnores` needs the cwd map), `ProcessItem.swift` (`bucket` derived from `riskTier`; `displayLabel`/`displayPath` reusable in table output), app `ScanEngine.swift` (the parity contract — defaults keys `elapsedThreshold`/`ignoredNames`/`disabledKinds`/`customRules`/`protectedProjects`; scan pipeline order: `PortRegistry.listeningPorts()` → `DockerService.containerOwners()` → `enumerate(startTimeProvider: KillCore.startTime)` → `CwdResolver.processCwds` → `applyScopedIgnores`), app `CleanLogStore.swift` (ISO-8601 + prettyPrinted/sortedKeys JSON, cap 1000, atomic write), `MenuBarView.swift` sweep logic (`sweepableSafeItems` = safe bucket minus `isProtected` via `CwdResolver.isUnderPrefix`; protected rows stay individually killable), `Makefile`, `.gitignore` (`.build/` already ignored).

**Key facts for parity:**
- Defaults domain `com.fakeneuron.pidlyse` (pbxproj `PRODUCT_BUNDLE_IDENTIFIER`); CLI reads it via `UserDefaults(suiteName:)`. `dismissedPIDs` is session-only in the app (never persisted) → CLI has no dismissed set, correctly.
- `scanInterval` / `notificationsEnabled` are app-lifecycle settings — irrelevant to a one-shot CLI.
- Clean-all sweep set = safe bucket minus protected (`CwdResolver.isUnderPrefix` over the scan-time cwd map); individual kills ignore protection — CLI `clean` / `kill <pid>` mirror both.
- `KillService`'s bulk shape (DispatchGroup + global queue, PID-57.2) ports to the CLI as DispatchGroup + `wait()` so multi-item `clean` doesn't serialize 2 s graces.

**Archive skim (load-bearing):** [[PID-57.1]] (operator scoping table: full parity, shared log, hand-rolled args, zero deps), [[PID-57.2]] (extraction landed; "no new SPM test target — `make test` stays the single suite"; pbxproj untouched by SPM-side additions), [[PID-53.2]] (`KillOutcome.confirmed`-only logging; privacy — no command line persisted in clean events), [[PID-27.2]] (PidlyseCore created for a second consumer; API already `public`), [[PID-20.2]] (Makefile target conventions: plain xcodebuild recipes, `.PHONY` list). Broader grep hits (PID-17.x, PID-31, …) are CI/DMG-side — not load-bearing here.

**Drift check:** PLAN line's citations all match HEAD — SPM package exists, `KillCore`/`DockerService`/`CleanEvent`/`CleanLog` in core, defaults domain correct, Makefile has no CLI targets yet. No drift.

**No clarifications needed.** Explicit assumptions (all extend the [[PID-57.1]] scoping table + [[PID-57.2]] precedent):
1. **Executable target lives in the existing package** (`Sources/PidlyseCLI/`, product `pidlyse`) — a second package would duplicate the platform/deps declaration for no gain.
2. **Pure CLI logic (`CLICore.swift`) goes in `PidlyseCore`** so `PidlyseTests` can test it via `make test` (the single-suite decision from 57.2); the executable target stays a thin impure `main.swift`. Mirrors the `ScanEngine`↔`ScanCore` split.
3. **Clean-log disk I/O moves to core (`CleanLogFile.swift`) with `CleanLogStore` delegating** — two consumers now write the same file; a CLI-side re-implementation of the encoder settings is silent format-drift risk. Same rationale that moved impure `DockerService` into core in 57.2. CLAUDE.md clean-log bullet updated accordingly.
4. **`kill <pid>` accepts any *scanned candidate*** (both buckets — explicit user action, matching per-row kill buttons) but refuses arbitrary non-candidate PIDs — the identity-token + classification path only exists for scanned items, and refusing keeps the tool honest about its scope.
5. **`clean` runs without an interactive confirm** — invoking the command *is* the explicit user action, matching the app's one-click "Clean all" (no dialog). "Never auto-kills" = no timer/daemon kills, which the CLI structurally cannot do (one-shot process).

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

Extended the established core/app splits throughout — the CLI is a new *consumer* of existing shapes, not a new shape:

- **`Package.swift`**: added `.executableTarget(name: "PidlyseCLI")` + `.executable(name: "pidlyse")` product to the existing package (no second package, no pbxproj edits — SPM-only surface).
- **New core `CLICore.swift`** (~150 LOC): pure command grammar (`Command` enum, `parse(_:) -> Result<Command, ParseError>`, `message(for:)`, `usage`) + output formatting (`formatElapsed`/`formatRSS`/`truncate`/`listTable`). Mirrors the `ScanEngine`↔`ScanCore` split so `PidlyseTests` covers it via `make test`. Bare `pidlyse` parses as `help` — never scans or kills.
- **New core `CleanLogFile.swift`** (~65 LOC): the clean-log disk I/O extracted from `CleanLogStore` (load / atomic save / `append(_:)` load-append-save for one-shot writers), single encoder/decoder definition (ISO-8601, prettyPrinted+sortedKeys) so the two writers can't drift formats. `CleanLogStore` rewritten to keep only the `@Published` binding + main-thread lifecycle, delegating I/O (retention statics now live on `CleanLogFile`; no external references existed).
- **New `Sources/PidlyseCLI/main.swift`** (~190 LOC): thin impure shell — `Settings.load()` reads the five scan-relevant keys from `UserDefaults(suiteName: "com.fakeneuron.pidlyse")` with the same global/scoped ignore split as `ScanEngine.scan()`; `runScan` replicates the app's pipeline order (portMap → containerOwners → enumerate with `KillCore.startTime` → cwds → scoped ignores) + eager protected-overlay resolution; `killAll` mirrors `KillService`'s bulk shape (DispatchGroup + global queue, `group.wait()`) so multi-item cleans don't serialize 2 s graces; `recordCleaned` applies the `ScanEngine.recordCleaned` rules (`.confirmed` only, custom-label-as-kind, displayPath fallback). Exit codes: 0 ok, 1 kill failure/refusal, 64 (EX_USAGE) parse errors to stderr.
- **`clean` semantics**: exactly the app's sweep set (`bucket == .safe && !protected`); **`kill <pid>`**: any-bucket but *scanned candidates only* — refuses arbitrary PIDs.
- **Makefile**: `build-cli` (swift build -c release) + `install-cli` (`install -m 755` → /usr/local/bin, sudo note); `.PHONY` updated.
- **Tests** (+18): `CLICoreTests` (parse matrix incl. every error case, elapsed/RSS/truncate formatting, table render + 🔒 marker + truncation) and `CleanLogFileTests` (missing/malformed file, round-trip, append merge/cap, empty-append read-only, ISO-8601 format contract) appended to `PidlyseTests/ScanEngineTests.swift`.
- **One real bug caught by tests**: `String.padding(toLength:)` counts UTF-16 units, clipping the 🔒 (2 units) mid-emoji — replaced with a `Character`-count `pad` helper.
- **Docs**: SPEC.md (structure entries + new "CLI Companion" section), README (Build & Run paragraph), CLAUDE.md (Build line, clean-log bullet rewritten for the `CleanLogFile` split, new cli-companion convention bullet), tasknote README quick-commands line.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (N/A — no app-UI change; CLI output smoke-tested live below)

**Testing Notes:** `make test` — **222 tests, 0 failures** (204 prior + 18 new; the first run caught the UTF-16 padding bug, fixed, re-run green). `swift build --package-path Packages/PidlyseCore` — clean (standalone package incl. executable target). `make build-release` — BUILD SUCCEEDED (app unaffected by the CleanLogStore refactor). Live smoke on the release binary: bare `pidlyse` prints usage; `pidlyse list` rendered 34 real candidates with correct cwd project labels, bucket demotions, and truncated commands; `pidlyse list --safe` → "No safe-to-clean processes." (correct — everything running was review-tier); `pidlyse bogus` → stderr message + usage, exit 64; `pidlyse kill 1` → refusal message, exit 1. No SwiftLint in repo; compiler is the type-checker.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update

- [x] Closed — PLAN.md line flipped to stub form `Completed YYYY-MM-DD.` (see SPEC/tasknote-selection.md §"`## Completed` archive convention") and tasknote moved to `.flowtron/tasknote/archive/<area>/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Shipped the `pidlyse` terminal companion (the epic's payload): an `.executableTarget` in the existing `PidlyseCore` package with `list [--safe]` / `clean` / `kill <pid>` / `help`, hand-rolled arg parsing, zero external deps. Full app parity — settings read from the `com.fakeneuron.pidlyse` defaults domain (threshold, global+scoped ignores, disabled kinds, custom rules, protected projects), the scan replicates `ScanEngine.scan()`'s exact pipeline, and kills route through the shared `KillCore` path (identity guards, docker-stop routing, 2 s grace) with confirmed kills appending to the shared clean-log so CLI cleans surface in the app's "Cleaned" tab. Pure grammar/formatting live in core (`CLICore.swift`, 18 new tests via `make test`); the clean-log disk I/O was extracted to core (`CleanLogFile.swift`) as the single format definition for both writers, with `CleanLogStore` reduced to the `@Published` binding. `clean` sweeps exactly the app's "Clean all" set (safe minus protected); `kill <pid>` refuses non-candidates; bare `pidlyse` prints usage and never scans or kills. Makefile: `build-cli` / `install-cli`. 222/222 tests, standalone package build, app Release build, and a live smoke run (34 real candidates listed with correct labels/buckets; refusal + usage exit codes verified) all green.

Doc-drift sweep: `README.md` **updated** (Build & Run gains the CLI paragraph) · `AGENTS.md` no change (workflow-only content) · `CLAUDE.md` **updated** (Build line + clean-log bullet rewritten for the `CleanLogFile` split + new cli-companion convention bullet) · `SPEC.md` **updated** (structure entries for `CLICore.swift`/`CleanLogFile.swift`/`Sources/PidlyseCLI/`; `CleanLogStore` row reworded; new "CLI Companion" section) · `.flowtron/PLAN.md` updated in-task (.3 stub flip). Also: tasknote `README.md` quick-commands gains the `build-cli` line.

**Archived:** 2026-07-02
