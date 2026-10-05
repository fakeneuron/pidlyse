---
title: clean-log-store
status: in-progress
tags: []
created: 2026-07-01
due:
related-tasks: [PID-EPIC-53, PID-53.1, PID-53.3]
---

# PID-53.2 | clean-log-store

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-53]] [[PID-53.1]] [[PID-53.3]]

## 🎯 Goal

Persist a minimal, privacy-first per-process clean log to disk on **confirmed**
kills only, with the `CleanEvent` model + pure stats/retention in PidlyseCore
and an app-side store owning disk I/O + kill-hook wiring — the data layer the
[[PID-53.3]] "Cleaned" tab will consume.

## ✅ Acceptance

- [ ] `CleanEvent` (PidlyseCore, `Codable`): kind rawValue + project label + rssKB
      + timestamp; **no command line**
- [ ] `CleanLog` (PidlyseCore, pure): rolling-window stats (count, RAM reclaimed,
      top kinds) + count-cap retention; unit-tested
- [ ] `KillService` reports a per-item `KillOutcome` (confirmed vs not-killed)
      **without weakening** the grace-period / PID-reuse guards
- [ ] App-side store persists confirmed kills to
      `~/Library/Application Support/Pidlyse/clean-log.json`
- [ ] Kill-hook wiring records only confirmed kills, labelled from scan-time cwds
- [ ] Tests pass (`make test`); Xcode target builds (new app file wired into pbxproj)

## 🧩 Subtasks

- [ ] Add `CleanEvent.swift` to PidlyseCore (Codable model, no command line)
- [ ] Add `CleanLog.swift` to PidlyseCore (pure `stats` + `capped` retention)
- [ ] Extend `KillService` with `KillOutcome`; thread it through single + batch
      completions at each resolution point (guard-refuse / EPERM → notKilled;
      SIGTERM-sent / docker-stop-ok → confirmed)
- [ ] Add app-side `CleanLogStore.swift` (disk I/O + retention) and wire into
      `project.pbxproj` (mirror KillService.swift's 4 entries)
- [ ] Wire capture: `ScanEngine.recordCleaned` builds `CleanEvent`s from confirmed
      outcomes (label from `cwds`) → store; update the 3 MenuBarView kill sites
- [ ] Unit tests for `CleanLog` stats + retention (+ `CleanEvent` round-trip)
- [ ] `make test` + Xcode build green

## 🔗 Related

- [[PID-EPIC-53]] — parent epic (clean-history-stats)
- [[PID-53.1]] — discovery; resolved the three design forks this task implements
- [[PID-53.3]] — presentation layer; consumes this store

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Fresh epic child, no existing implementation. The three design
  forks were resolved by the operator in [[PID-53.1]] (confirmed-only, minimal
  privacy-first event, third tab). This is the data layer those decisions
  specified; still clearly wanted.

- [x] Read relevant source files

- [x] **Archive skim** — see Discovery Notes.

- [x] **Drift check** — see Discovery Notes.

- [x] Asked clarifying questions — 2 design choices confirmed with operator (see below).

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

*Verified current surface (HEAD):*
- `KillService.kill(item/items, containerOwners:, onComplete:)` — `onComplete`
  fires **unconditionally** on every resolution (guard-refuse, EPERM,
  post-grace, docker-stop). No success signal is threaded out (matches .1's
  note). Resolution points in `killPosix`: (1) `!shouldSendSIGTERM` early return
  = recycled/gone since scan; (2) `EPERM` early return = foreign owner (root
  docker daemon); (3) SIGTERM sent → post-grace SIGKILL-or-already-dead. Docker
  path: `dockerStopByName` true → stopped; else falls through to `killPosix`.
- `ProcessItem` carries `kind: ProcessKind`, `rssKB: Int`, `startTime`. Project
  label is **not** on the item — it lives in `ScanEngine.cwds[pid]?.label`
  (git-project label from PID-038, e.g. `bidviz/frontend`), falling back to
  `displayPath`.
- Kill call sites (3, all in `MenuBarView`): `soleSafeKillShortcut` (:70, single),
  "Clean all" (:204, batch `safeItems`), per-row ✕ (:313, single). All pass
  `{ engine.scan() }` as `onComplete` and have `engine` in scope.
- Persistence precedent: `PortRegistry.userPortsFileURL` = Application Support/
  `Pidlyse/ports.json` (`FileManager…applicationSupportDirectory`). No writer
  exists yet — this is the first on-disk **write**.
- Build wiring: `project.pbxproj` has **no** `PBXFileSystemSynchronizedRootGroup`
  → app-side files are referenced explicitly (KillService.swift = 4 entries:
  PBXBuildFile, PBXFileReference, group child, Sources phase). New app file must
  be added the same way. PidlyseCore's `Package.swift` uses bare `.target` (no
  explicit `sources`) → SwiftPM auto-globs; **new Core files need no manifest edit**.
- Tests: single file `PidlyseTests/ScanEngineTests.swift`, pure-function XCTest
  style (`ScanCore`, `KillService` predicates, `DockerCore`, etc.). New pure
  `CleanLog` tests slot in here.

*Archive skim (`archive/pid/`, grep on KillService / persistence):*
- KillService is a hardened path (PID-18.3, PID-35.3: PID-reuse guard,
  `shouldSendSIGTERM`/`shouldEscalateToSIGKILL`; grace period never skipped).
  Change must be **additive** — report outcome alongside existing control flow,
  touch no guard predicate. PID-35.6 security sweep: command lines were never
  persisted; .1 flagged persistence-of-args as the new privacy consideration →
  `CleanEvent` stores **no command line** (fork #2).
- No prior tasknote persisted process metadata (only `UserDefaults` config).
  Core/App split established by DockerCore↔DockerService, ScanCore↔ScanEngine,
  PortRegistry(disk read)↔consumers — `CleanLog`(pure)↔`CleanLogStore`(disk)
  mirrors it exactly.

*Drift check:* PLAN line + .1's design notes match current code exactly
(`KillService.onComplete` fires unconditionally; `cwds` holds the label;
Application Support convention present). No drift.

*Design (implementing .1's resolved forks):*
- **Confirmed = SIGTERM-was-sent (or docker-stop succeeded).** The two
  `.notKilled` cases are exactly `killPosix`'s early returns (recycled/gone,
  EPERM) — precisely the "excludes EPERM daemons + recycled PIDs" fork #1 asked
  for. Once SIGTERM is sent the process dies (SIGTERM took) or is force-SIGKILL'd
  post-grace → confirmed either way; no extra post-kill verification read needed.
- **`CleanEvent`** = `kind: String` (ProcessKind rawValue, stable across kind-enum
  evolution) + `projectLabel: String` + `rssKB: Int` + `timestamp: Date`. Codable.
- **`CleanLog`** (pure): `capped(_:cap:)` count-retention (keep newest N) + `stats(from:now:window:)`
  → `{ count, ramReclaimedKB, topKinds: [KindCount] }` over a rolling window.
- **`CleanLogStore`** (app-side, `ObservableObject`): loads/saves JSON at
  Application Support/`Pidlyse/clean-log.json`, `record(_:)` appends + caps + saves;
  `@Published events` so .3 binds directly.
- **Capture**: `ScanEngine` owns the store + `recordCleaned(item/items, outcome(s))`
  — builds events (label from `cwds`, timestamp now) for `.confirmed` only, records
  **before** the rescan (cwds still valid). MenuBarView forwards outcomes.

*Clarifications confirmed with operator (2026-07-01):*
1. **Confirmed def → SIGTERM-sent = confirmed.** No extra post-grace verification
   read; the two `.notKilled` early-returns (recycled/gone, EPERM) are the exclusions.
2. **Retention → count cap, keep newest N.** `.3`'s window handles "this week" at
   read time; count cap only bounds file growth. Default cap = 1000.

**Phase 1→2 exit:** Discovery surfaced no significant deviation → skip 🛠️. The
epic's .1 plan called for exactly this data layer; clarifications confirmed
recommended defaults within scope, no approach/file/scope change.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — the Core/App split mirrors `DockerCore`↔`DockerService`
  and `ScanCore`↔`ScanEngine`: pure model (`CleanEvent`) + pure logic (`CleanLog`)
  in PidlyseCore, impure disk store (`CleanLogStore`) app-side. Disk path reuses
  `PortRegistry.userPortsFileURL`'s Application Support convention. Outcome
  threading rides KillService's existing early-return structure (no new predicate).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**
- **PidlyseCore:** `CleanEvent.swift` (Codable model, no command line);
  `CleanLog.swift` (`capped(_:cap:)` newest-N retention + `stats(from:now:window:)`
  → count / RAM / freq-ranked `topKinds`).
- **KillService:** added `KillOutcome { confirmed, notKilled }`; single-kill
  `onComplete` now `(KillOutcome)`, batch now `([Int32: KillOutcome])`. The two
  early returns (identity-guard refuse, EPERM) → `.notKilled`; SIGTERM-sent and
  `docker stop` success → `.confirmed`. **No guard predicate touched.**
- **App:** `CleanLogStore.swift` (`ObservableObject`, JSON at
  `Application Support/Pidlyse/clean-log.json`, iso8601 dates, atomic write,
  count cap 1000, injectable url/cap for tests). `ScanEngine` owns the store +
  `recordCleaned(_:outcome:)` / `(_:outcomes:)` — builds events from `.confirmed`
  only, labelled from `cwds`, recorded before the rescan. 3 MenuBarView kill
  sites forward outcomes.
- pbxproj: `CleanLogStore.swift` wired via 4 entries (ids B160/B161) mirroring
  KillService.swift; Core files auto-glob (no `Package.swift` edit).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **149 passed, 0
  failures** (9 new `CleanLogTests`: capped×4, stats×5, Codable round-trip).

- [x] Ran lint/type-check on changed code — full `xcodebuild` compile clean
  (app + Core + tests). SourceKit "No such module" editor warnings are a
  stale-index artifact; the build is ground truth.

- [x] (frontend) Visual confirmation — N/A. Data layer only; no popover/UI change
  in `.2` (the "Cleaned" tab is [[PID-53.3]]).

**Testing Notes:** Pure `CleanLog` logic is fully unit-tested; the impure
`CleanLogStore` disk I/O is not (mirrors the `ScanCore.runPS` / `DockerService`
convention of not unit-testing shell/FS side-effects).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md` — no change (no user-visible surface in
  `.2`; the "Cleaned" tab is [[PID-53.3]]). `AGENTS.md` — no change (no
  core-file/architecture list). `CLAUDE.md` — **updated**: added a Conventions
  bullet for the clean-log Core/App split (mirroring the docker bullet).
  `.flowtron/PLAN.md` — updated (line flipped to stub form; parent epic stays open).

- [x] Closed — PID-53.2 flipped to `Completed 2026-07-01.` in place under
  PID-EPIC-53 (parent stays open); tasknote moved to `archive/pid/`.

- [x] Recap drafted.

**Final Summary:** Built the clean-history data layer. **PidlyseCore:**
`CleanEvent` (Codable, privacy-first — no command line) + `CleanLog` (pure
rolling-window stats: count / RAM reclaimed / freq-ranked top kinds, plus
count-cap retention). **KillService:** added `KillOutcome`; single/batch
completions now thread confirmed-vs-not-killed at each resolution point
(guard-refuse + EPERM → notKilled; SIGTERM-sent / docker-stop → confirmed)
without touching any guard predicate. **App:** `CleanLogStore` persists confirmed
kills as JSON under Application Support (count cap 1000, atomic, iso8601);
`ScanEngine.recordCleaned` builds events labelled from scan-time `cwds` and the 3
MenuBarView kill sites forward outcomes. 9 new `CleanLogTests`; `make test` =
149 passing. New app file wired into `project.pbxproj`; Core files auto-glob.

**Archived:** 2026-07-01
