---
title: scan-history-cache
status: in-progress
tags: []
created: 2026-07-02
due:
related-tasks: [PID-EPIC-55, PID-55.1, PID-55.3]
---

# PID-55.2 | scan-history-cache

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-55]] [[PID-55.1]] [[PID-55.3]]

## 🎯 Goal

Add a pure bounded rolling-window CPU-sample cache in `PidlyseCore`, keyed by PID+startTime (PID-reuse-safe), plus `ScanEngine` wiring to feed it each scan and a "sustained low CPU across window" query — in-memory only, no UI, no kill-bar change.

## ✅ Acceptance

- [ ] New pure `ScanHistory` type in `PidlyseCore`: bounded rolling window of per-process CPU samples, keyed by (PID + `ProcStartTime`), value-semantics (no side effects).
- [ ] `recording(_:)` appends the current scan's samples, caps each series to the window depth (drops oldest), and prunes series for identities absent from the scan (PID-reuse → fresh series).
- [ ] `isSustainedLowCPU(...)` query: true only when a series has ≥ `minimumSamples` and every sample is below the threshold.
- [ ] `ScanEngine` feeds the cache once per scan (main-thread publish step) and exposes the sustained-low-CPU query for `[[PID-55.3]]` to consume.
- [ ] Signal-only invariant preserved: `ScanCore.riskTier` / `bucket` / kill bar untouched; no `@Published` UI surface added.
- [ ] Unit tests for the pure `ScanHistory` (append/cap/prune, PID-reuse keying, query thresholds).

## 🧩 Subtasks

- [ ] Add `Hashable` to `ProcStartTime` so it can key the cache (identity token; minimal one-line conformance).
- [ ] Write `ScanHistory.swift` in `PidlyseCore` (mirrors the `CleanLog` pure-type shape): config depth + static default constants, `Observation` input, `recording(_:)`, `isSustainedLowCPU(...)`, `samples(...)` accessor.
- [ ] Wire `ScanEngine`: hold a `private var scanHistory`, feed it via a private `recordScanHistory(_:)` from the scan's main-thread block, add a `hasSustainedLowCPU(_:)` accessor.
- [ ] Add `ScanHistoryTests` to `PidlyseTests/ScanEngineTests.swift`.
- [ ] `make test`.

## 🔗 Related

- [[PID-EPIC-55]] — parent epic (idle-stray-signals)
- [[PID-55.1]] — discovery (scoped this child + the in-memory / PID+startTime keying decisions)
- [[PID-55.3]] — consumer (idle-dev-signal: combines this query with dev-flag parse + isOld + !hasTTY)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Implements exactly the infra child scoped by [[PID-55.1]]. CPU is captured (`ProcessItem.cpuPercent`) but never classified, and scans are stateless except `previousPIDs` (depth-1). A bounded per-process CPU window is the missing infrastructure for the idle signal, and it fits the existing `CleanLog` pure-type + `previousPIDs` cross-scan-state precedents cleanly.

- [x] Read relevant source files — `ProcessItem.swift` (`ProcStartTime`, `cpuPercent`, `startTime`), `ScanEngine.swift` (`previousPIDs`, main-thread publish block, `fireNotificationIfNeeded` private-method pattern), `CleanLog.swift` (pure bounded-window aggregation precedent), `ScanEngineTests.swift` (test conventions: pure core type → own `XCTestCase` class).

- [x] **Archive skim** — `grep`ped `archive/PID/` for `ScanEngine`/`ProcessItem`/`ProcStartTime` touchers. Load-bearing: PID-18.3/PID-35.3 introduced `ProcStartTime` as the PID-reuse identity token (Equatable, `sec`+`usec`); PID-036.2 established scan-time `[PID: …]` sibling maps; PID-53.2 established the `CleanLog`(pure)/`CleanLogStore`(impure) split this mirrors (but no disk here — stale post-restart CPU is meaningless). No prior tasknote added a cross-scan history cache.

- [x] **Drift check** — description matches current code: `cpuPercent: Double` present on `ProcessItem`, `startTime: ProcStartTime?` present and populated in `ScanEngine.scan` via `startTimeProvider: KillService.startTime`, `previousPIDs` is the only cross-scan state. `ProcStartTime` is `Equatable` but not yet `Hashable` (needs the one-line conformance to key the cache).

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions.

  **No clarifications needed.** [[PID-55.1]] resolved the design (in-memory, PID+startTime keying, expansion-only surfacing deferred to `.3`) and delegated exact values to this child. Explicit assumptions I'm asserting (all `.3`-tunable):
  - Window depth = **5** scans (`ScanHistory.defaultWindowDepth`).
  - "Sustained low CPU" = every sample **< 1.0%** (`defaultLowCPUThreshold`).
  - Minimum samples before a verdict = **3** (`defaultMinimumSamples`) — a just-appeared process isn't prematurely flagged.
  - Signal carrier: a query on the cache (consulted by `.3`), not a new `ProcessItem` field — keeps `ScanCore` untouched.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

Nil-`startTime` degradation: production always populates `startTime`, but tests / a sysctl miss can leave it `nil`. Keying by `(pid, startTime?)` means all nil-startTime samples for a pid collapse into one series — acceptable degraded behavior, consistent with how the kill path treats a nil token as a legacy fallback. PID-reuse safety holds whenever `startTime` is present (the normal case).

`rescan()` intentionally not touched: it clears `dismissedPIDs` + the notification baseline, but the CPU window remains valid across a manual rescan (the process didn't restart), and `recording(_:)` prunes vanished identities each scan anyway — so the window self-bounds without a reset.

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — extended two in-repo shapes: `CleanLog` (pure bounded-window value type in `PidlyseCore`, side-effect-free, app-side store feeds it) and `previousPIDs` (the depth-1 cross-scan state `ScanHistory` generalizes to depth-N). Fed from the same main-thread publish block as `previousPIDs`/`listeningPorts`; queried via a private-method-then-accessor pattern like `fireNotificationIfNeeded`. No new shape invented.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- `Packages/PidlyseCore/Sources/PidlyseCore/ScanHistory.swift` (new, ~120 LOC): pure value type. `Key(pid, startTime?)` (Hashable) → per-identity `[Double]` series, oldest-first, capped to `windowDepth`. `recording(_:)` folds a scan's `Observation`s into a **new** history, appending+capping observed identities and pruning absent ones (so PID reuse via a new `startTime` key starts empty and dead processes don't linger). `isSustainedLowCPU(...)` returns true only for ≥ `minimumSamples` samples all strictly below `threshold`. Static defaults: depth 5 / <1.0% / min 3.
- `ProcessItem.swift`: added `Hashable` to `ProcStartTime` (one line) so it can key the cache — the identity token was already `Equatable` with two `Int` fields.
- `Pidlyse/ScanEngine.swift`: `private var scanHistory = ScanHistory()`; `recordScanHistory(_:)` called from the scan-publish block (alongside `previousPIDs`); `hasSustainedLowCPU(_:)` accessor for PID-55.3. No `@Published` added, `ScanCore.riskTier`/`bucket`/kill path untouched. `rescan()` deliberately left alone (the CPU window survives a manual rescan; `recording` self-prunes).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: 194 tests, 0 failures (11 new `ScanHistoryTests`).

- [x] Ran lint/type-check on changed code — `swift build` (PidlyseCore) + the full `make test` build compile clean; Swift's compiler is the type-check. No separate linter in this repo.

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI; signal-only infra, surfaced in PID-55.3).

**Testing Notes:** `ScanHistoryTests` (11) covers append order, window-depth capping (oldest dropped), pruning of vanished identities, PID-reuse fresh-series keying, nil-startTime collapse, and the query's all-below-threshold / one-high-sample / below-minimum-samples / strict-threshold / unseen-identity branches, plus the exposed defaults.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (signal-only infra, nothing user-facing shipped — surfaces in `.3`) · `AGENTS.md`: no change · `CLAUDE.md`: **updated** — added `ScanHistory.swift` to the PidlyseCore convention list + a line on the pure/impure split (the update PID-55.1 predicted for `.2`) · `.flowtron/PLAN.md`: `.2` flipped to stub form.

- [x] Closed — PLAN.md `.2` line flipped to `Completed 2026-07-02.` (kept nested under `PID-EPIC-55`; the cohort moves to `## Completed` when the parent closes at audit `.4`) and tasknote moved to `.flowtron/tasknote/archive/PID/`.

- [x] Recap drafted (surfaces inline on conditional skip).

**Final Summary:** Added `PidlyseCore.ScanHistory` — a pure, in-memory rolling-window CPU-sample cache keyed by (PID + `ProcStartTime`) so a recycled PID starts a fresh series. `recording(_:)` folds each scan's samples into a new value (append + cap to depth, prune vanished identities); `isSustainedLowCPU(...)` answers the "sustained low CPU across the window" query (≥ min samples, all below threshold). `ProcStartTime` gained `Hashable` (one line) to key it. `ScanEngine` holds one instance, feeds it from the scan-publish block, and exposes `hasSustainedLowCPU(_:)` for PID-55.3. Signal-only: no `@Published`, no UI, `ScanCore.riskTier`/`bucket`/kill path untouched. 11 new `ScanHistoryTests`; 194 tests pass. Files: `ScanHistory.swift` (new), `ProcessItem.swift`, `ScanEngine.swift`, `ScanEngineTests.swift`, `CLAUDE.md`.

**Archived:** 2026-07-02
