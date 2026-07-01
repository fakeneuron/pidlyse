---
title: inspector-shell
status: in-progress
tags: [ux, provenance]
created: 2026-06-30
related-tasks: [PID-EPIC-52, PID-52.1, PID-036.3, PID-049]
---

# PID-52.2 | inspector-shell

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-52]] [[PID-52.1]]

## 🎯 Goal

Deepen the inline ⓘ expander (`reasoningBlock`) into a full-context inspector: surface the full command line (today tooltip-only) and the complete parent chain up to launchd, backed by a new ps-based ancestor resolver in PidlyseCore.

## ✅ Acceptance

- [ ] Full command line is visible in the expanded inspector (not only the `.help` tooltip)
- [ ] Parent chain resolves **all** ancestors up to launchd (pid 1), not just scanned strays — new pure PidlyseCore resolver, injectable ps output for tests
- [ ] Resolver mirrors the PortRegistry/CwdResolver split: pure parser + injectable output + a private `Shell.run` shell-out on the pinned `ps` surface (no new binary, per [[PID-049]])
- [ ] Chain is cycle/orphan-safe and degrades gracefully (empty → no line rendered)
- [ ] Targeted unit tests for the new parser + chain walk pass; `xcodebuild build -scheme Pidlyse` type-checks clean

## 🧩 Subtasks

- [ ] Add `AncestryResolver.swift` to PidlyseCore: pure `processTable(psOutput:)` parser + pure `ancestorChain(ofPPID:in:)` walk + private `runPS()` (`ps -axo pid=,ppid=,comm=`) via `Shell.run`
- [ ] Publish `processTable` on `ScanEngine`, resolved once per scan (mirroring `listeningPorts`/`cwds`/`containerOwners`)
- [ ] In `reasoningBlock`: add the full-command-line line; replace the single-level `child of <parent>` with the full chain joined ` ← ` up to launchd
- [ ] Add unit tests for the parser + chain walk (incl. orphan and cycle-safety cases) in `PidlyseTests/ScanEngineTests.swift`
- [ ] Type-check + targeted tests

## 🔗 Related

- [[PID-EPIC-52]] — parent epic (process-inspector)
- [[PID-52.1]] — Discovery: scoped this child (deepen inline expander; full chain to launchd via new ps-ancestor resolver)
- [[PID-036.3]] — added the port + single-level `child of` lines this task deepens
- [[PID-049]] — security guardrail pinning the shell-out surface to ps/lsof/docker only

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Direct implementation of the child scope PID-52.1 filed. The single real gap (parentCommand sees only scanned strays) is confirmed in code; the full-chain resolver lifts exactly that limitation.

- [x] Read relevant source files

- [x] **Archive skim** — logged below

- [x] **Drift check** — logged below

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface (read):**

- `Pidlyse/MenuBarView.swift` — `reasoningBlock(item:isOld:)` (line 350) is the expander body. Full command is **tooltip-only** today (`.help` on the row descriptor, line 287). `child of <parent>` (line 371) calls `ScanCore.parentCommand(ofPPID:in:)` → resolves **only within `engine.items`** (strays). This is the home for both deliverables.
- `Packages/.../ScanCore.swift` — `parentCommand(ofPPID:in:)` (line 140): strays-only, nil for launchd/non-candidates. `runPS()` (line 246) is the `ps -axww` shell-out via `Shell.run`. The candidate ps output is **not exposed** to `ScanEngine`, so ancestry needs its own bulk fetch.
- `Packages/.../ProcessItem.swift` — `command` (full args), `ppid` present; `displayPath` compaction logic is the label model to mirror for ancestor labels.
- `Packages/.../CwdResolver.swift` / `PortRegistry.swift` — the canonical pure-parser + injectable-output + private `Shell.run` split the new resolver mirrors.
- `Pidlyse/ScanEngine.swift` — `scan()` resolves `listeningPorts` / `containerOwners` / `cwds` once per scan on a background queue and publishes each as a map. The new `processTable` slots in identically.

**Archive skim** (load-bearing):

- [[PID-036.3]] — added the port + `child of` lines; **decision: parent resolved over the scan set only** (graceful nil for launchd/non-candidate). Exactly the limitation this task lifts.
- [[PID-038]] — CwdResolver bulk-lsof-once-per-scan; the per-scan published-map pattern `processTable` follows.
- [[PID-042]] / [[PID-35.2]] — all spawns consolidated into `Shell.run`; the new `ps` call routes through it.
- [[PID-049]] — pins the shell-out surface to ps/lsof/docker; a second `ps` invocation stays inside that surface (no new binary).
- [[PID-008]] — origin of the ⓘ expander + `reasoningBlock` `.caption2`/`.secondary` text vocabulary the new lines extend.

**Drift check:** all cited paths/types/line-refs match HEAD. `parentCommand` at ScanCore.swift:140, used at MenuBarView.swift:371, tested at ScanEngineTests.swift:774/781/787. No drift.

**Design decisions (assumptions):**

- **New file `AncestryResolver.swift` in PidlyseCore** — pure `processTable(psOutput:) -> [Int32: ProcNode]` (ProcNode = ppid + compact label) + pure `ancestorChain(ofPPID:in:) -> [String]` (nearest-parent → launchd, cycle-safe via a `seen` set) + private `runPS()` shelling `ps -axo pid=,ppid=,comm=` through `Shell.run`. Second lightweight `ps` (comm, whole table incl. non-strays) rather than reusing the candidate scan output, which isn't exposed and is pre-filtered.
- **Per-scan resolution** — `ScanEngine` publishes `processTable`, resolved once per scan alongside the other maps. Mirrors the dominant provenance pattern; keeps the view synchronous (no async-on-expand). On-demand is reserved for .3's lsof (heavier, per-row).
- **`parentCommand` kept** — public + 3 tests; my change stops using it in the view but it stays a valid pure helper (no churn, additive per write-once conventions). Flagged, not silently deleted.
- **Chain ends at launchd** — every expanded row will now show `… ← launchd`; that is literally "complete parent chain to launchd." Orphans (ppid 1) render `child of launchd`.

**Resolved scoping** (AskUserQuestion):

| Question | Resolution |
|----------|-----------|
| Inspector line rendering | **Wrap both fully** — the full command line and the `child of … ← launchd` chain each wrap to multiple lines so the whole value is visible when expanded (no truncation). Popover grows taller on long commands / deep chains; acceptable in the expanded detail view. |

**Exit-gate judgment:** Discovery surfaced no significant deviation → skip 🛠️. Direct implementation of the PID-52.1-filed child scope; the one clarification set a rendering micro-decision (wrap), not a change of approach or target files.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — mirrored `CwdResolver`/`PortRegistry`: public model struct (`ProcessNode` like `ProcessCwd`) + pure injectable parser (`processTable`/`parseLine` like `parseCwds`) + private `Shell.run` shell-out (`runPS` like `runLSOF`). `parseLine` reuses `ScanCore.parsePSLine`'s field-splitting idiom.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- **`Packages/.../AncestryResolver.swift`** (new) — `ProcessNode` (ppid + compact label) + `processTable(psOutput:)` (pure, injectable) + `parseLine` + `compactLabel` + `ancestorChain(ofPPID:in:)` (nearest→launchd walk, `seen`-set cycle guard) + private `runPS()` shelling `ps -axo pid=,ppid=,comm=` via `Shell.run`.
- **`Pidlyse/ScanEngine.swift`** — published `processTable: [Int32: ProcessNode]`, resolved once per scan on the background queue (`AncestryResolver.processTable()`) alongside ports/owners/cwds.
- **`Pidlyse/MenuBarView.swift`** — `reasoningBlock` now shows (a) the full command line as a wrapped, selectable, monospaced line (was `.help` tooltip only) and (b) the full `child of A ← B ← launchd` chain (wrapped, no truncation) replacing the single-level `child of` — per the "wrap both fully" resolution.
- **`parentCommand` kept** — now unused in-app but a valid public helper with 3 passing tests; left in place (additive, no churn), as flagged in Discovery.
- **9 unit tests** added in `PidlyseTests/ScanEngineTests.swift` (`AncestryResolverTests`): parse/compaction (incl. spaces-in-comm, bare-name, malformed), table build, chain walk, orphan→launchd, missing-ancestor, cycle-bounded.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `AncestryResolverTests` (9) + `ScanCoreParentResolutionTests` (3) → 12 passed, 0 failures

- [x] Ran lint/type-check on changed code — `xcodebuild build -scheme Pidlyse` → **BUILD SUCCEEDED** (SourceKit "no such module" diagnostics were stale-index false positives; the real compile is clean)

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — see below

**Testing Notes:** Change is contained (new PidlyseCore resolver + view lines); targeted suite + full app type-check suffice. Visual confirmation requested from the operator (menu-bar UI can't be asserted headlessly).

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (the `/bin/ps` shell-out surface it documents already covers the new `ps` call) · `AGENTS.md`: no change (doesn't enumerate core files) · `CLAUDE.md`: **updated** — added `AncestryResolver.swift` to the PidlyseCore core-file list (Conventions §, line 18) · `.flowtron/PLAN.md`: the `.2` stub flip itself

- [x] Closed — PLAN.md `.2` line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-52 in `## High`; parent + cohort move to `## Completed` only when `.3`/`.4` close) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Deepened the inline ⓘ inspector (`reasoningBlock`) for **PID-EPIC-52**: the full command line is now a visible, wrapped, selectable line (was `.help` tooltip only), and the single-level `child of <parent>` is replaced by the **complete ancestor chain to launchd** (`child of node ← zsh ← login ← launchd`, wrapped). Backed by a new pure `AncestryResolver` in PidlyseCore — `processTable(psOutput:)` + `parseLine` + `ancestorChain(ofPPID:in:)` (cycle-guarded walk) + a private `ps -axo pid=,ppid=,comm=` shell-out via `Shell.run` — which walks the *whole* process table, lifting `ScanCore.parentCommand`'s scanned-strays-only limitation (kept as a still-valid public helper). `ScanEngine` publishes `processTable`, resolved once per scan alongside ports/owners/cwds. Files: `AncestryResolver.swift` (new, ~90 LOC), `ScanEngine.swift`, `MenuBarView.swift`, `CLAUDE.md`; 9 new unit tests. Build clean; 12 targeted tests pass.

**Archived:** 2026-06-30
