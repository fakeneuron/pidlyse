---
title: inspector-open-files
status: in-progress
tags: [ux, provenance]
created: 2026-06-30
related-tasks: [PID-EPIC-52, PID-52.1, PID-52.2, PID-038, PID-049]
---

# PID-52.3 | inspector-open-files

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-52]] [[PID-52.1]] [[PID-52.2]]

## 🎯 Goal

Add an on-demand open-files list to the inline ⓘ inspector — fetched via `lsof -p <pid>` only when a row expands (never per-scan) — backed by a new pure PidlyseCore parser mirroring the CwdResolver/PortRegistry lsof split, filtered to real open files + sockets with dylib/framework noise dropped and the list capped.

## ✅ Acceptance

- [ ] Expanding a row shows its open files + sockets; the list never runs during a scan (on-demand per-row only)
- [ ] New pure PidlyseCore resolver: injectable `lsofOutput` parser + private `Shell.run` shell-out on the pinned `/usr/sbin/lsof` surface (no new binary, per [[PID-049]])
- [ ] Filter drops dylib/framework/mapped-text noise (numeric-fd records only, type ∈ REG + sockets); list capped with an overflow indicator
- [ ] Degrades gracefully — a process with nothing to show renders no open-files line (mirrors the other provenance hints)
- [ ] Targeted unit tests for the parser + filter + cap pass; `xcodebuild build -scheme Pidlyse` type-checks clean

## 🧩 Subtasks

- [ ] Add `OpenFilesResolver.swift` to PidlyseCore: `OpenFile` model + pure `parseOpenFiles(lsofOutput:)` (numeric-fd + REG/socket filter + noise drop + cap) + private `runLSOF(pid:)` (`lsof -p <pid> -Fftn`) via `Shell.run`
- [ ] Wire on-demand fetch app-side: published `openFiles` cache + `loadOpenFiles(for:)` in `ScanEngine`, triggered when the ⓘ button expands a row
- [ ] Render the open-files list in `reasoningBlock` (wrapped, capped, graceful-degrade), mirroring the command-line / chain lines from [[PID-52.2]]
- [ ] Add unit tests for the parser (numeric-fd filter, dylib drop, socket keep, cap/overflow) in `PidlyseTests/`
- [ ] Type-check + targeted tests; visual confirmation from operator

## 🔗 Related

- [[PID-EPIC-52]] — parent epic (process-inspector)
- [[PID-52.1]] — Discovery: scoped this child (on-demand filtered lsof, capped)
- [[PID-52.2]] — sibling: deepened the same `reasoningBlock` (command line + parent chain); this appends the open-files list
- [[PID-038]] — CwdResolver's per-PID-scoped lsof + injectable-parser split this mirrors (diverges to on-demand, not per-scan)
- [[PID-049]] — security guardrail pinning the shell-out surface to ps/lsof/docker only

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Direct implementation of the child scope PID-52.1 filed; the final feature line of PID-EPIC-52. On-demand lsof + pure-parser split confirmed in code (CwdResolver is the exact mirror).

- [x] Read relevant source files

- [x] **Archive skim** — logged below

- [x] **Drift check** — logged below

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

**Shared design surface (read):**

- `Packages/.../CwdResolver.swift` — the **exact mirror**: `processCwds(forPIDs:lsofOutput:…)` = injectable `lsofOutput ?? runLSOF(pids)`, pure `parseCwds`, private `runLSOF` doing a **per-PID-scoped** `lsof -a -p <list> -d cwd -Fpn`. This task's `lsof -p <pid> -Fftn` extends the same shape but on-demand for one pid.
- `Packages/.../PortRegistry.swift` — second mirror: injectable `lsofOutput` + pure line parser + private `runLSOF`.
- `Packages/.../AncestryResolver.swift` — newest sibling ([[PID-52.2]]): `ProcessNode` struct + pure parser + `Shell.run` shell-out. `OpenFile` mirrors `ProcessNode`/`ProcessCwd`.
- `Packages/.../Shell.swift` — `Shell.run(path, args)` sole spawn primitive; open-files stays on `/usr/sbin/lsof` (pinned surface, [[PID-049]]).
- `Pidlyse/ScanEngine.swift` — owns the per-PID provenance maps the view reads (`listeningPorts`/`containerOwners`/`cwds`/`processTable`), each per-scan. Open-files diverges: **on-demand cache**, not per-scan (heavier, per-row). Adding `openFiles` cache + `loadOpenFiles(for:)` here keeps all per-PID provenance readable from the one `@ObservedObject` the view already holds.
- `Pidlyse/MenuBarView.swift` — `row(_:)` line 298 ⓘ `Button { expandedPIDs.toggle(item.pid) }` gates `reasoningBlock` (line 350). Trigger the on-demand fetch at that toggle. `reasoningBlock` already renders wrapped command-line + `child of … ← launchd` chain (PID-52.2); append the open-files list in the same idiom.

**lsof output shape (sampled live, `lsof -p <pid> -Fftn`):** per-file records are `f<fd>` / `t<type>` / `n<name>` triples. The **dylib/framework noise is exactly the `ftxt` records** (fd = `txt` = memory-mapped executable + every linked library — 146 of 154 on a sample Finder). Actually-opened files/sockets carry **numeric** fds. Clean filter: **keep numeric-fd records only** (drops `cwd`/`txt`/`rtd`/`mem`), then keep type ∈ {REG, IPv4, IPv6, unix} (drops CHR ttys, PIPE, KQUEUE, systm, NPOLICY). No path-substring dylib blocklist needed — the fd-type filter does it structurally.

**Archive skim** (load-bearing):

- [[PID-038]] — CwdResolver's per-PID-scoped `lsof` + injectable-parser split; this mirrors it but **on-demand** (per-row) rather than bulk-once-per-scan, deliberately (open-files is heavier, and only wanted when a row is inspected).
- [[PID-042]] / [[PID-35.2]] — all spawns consolidated into `Shell.run`; the new lsof routes through it, no hand-rolled `Process`.
- [[PID-049]] — pins the shell-out surface to ps/lsof/docker; a second `lsof` invocation stays inside that surface (no new binary).
- [[PID-036.3]] — established the per-row provenance-hint idiom (render only when resolvable) the open-files line follows.
- [[PID-52.2]] — just deepened `reasoningBlock` (command line + chain); this appends to the same block, same `.caption2`/`.secondary` vocabulary.

**Drift check:** all cited paths/types/line-refs match HEAD (`reasoningBlock` at MenuBarView.swift:350, ⓘ toggle at :298–302, CwdResolver split intact). No drift. One design nuance (not blocking): open-files is the **first on-demand** provenance fetch — every prior map is per-scan. This is an intentional divergence per PID-52.1's resolved scoping, so the app-side wiring (cache + trigger-on-expand) is genuinely new, not a copy of the per-scan pattern.

**Resolved scoping** (AskUserQuestion):

| Question | Resolution |
|----------|-----------|
| Fetch / cache | **Cache per session** — fetch `lsof` once on first expand, reuse on re-expand (guard `openFiles[pid] == nil`). Empty results cached too (no refetch for a fileless process). Bounded to expanded rows; snapshot may go slightly stale until restart — accepted. |
| List cap | **15 + "+N more"** — resolver caps at 15 and returns the total; the view renders a muted `+N more` overflow line. |
| Display | **Path only, sockets inline** — file paths home-abbreviated to `~`; sockets shown by their raw lsof name (`127.0.0.1:5432`). No per-kind labelling. `OpenFile.isSocket` retained internally (drives abbreviation-skip for sockets), not surfaced as a visible tag. |

**Design decisions (assumptions):**

- **New file `OpenFilesResolver.swift` in PidlyseCore** — `OpenFile` (name + isSocket) + `OpenFileList` (capped `files` + `total`) models; pure `parseOpenFiles(lsofOutput:)` (numeric-fd + REG/socket filter, dedup, order-preserving); public `openFiles(forPID:lsofOutput:home:cap:)` composer (parse → home-abbreviate file paths → total → cap). Mirrors `CwdResolver.processCwds` / `parseCwds`.
- **Filter (structural, no path blocklist):** keep records whose fd is **numeric** (drops `cwd`/`txt`/`rtd`/`mem` — `txt` IS the dylib/framework noise), then type ∈ {REG, IPv4, IPv6, unix}. `isSocket` = type ∈ {IPv4, IPv6, unix}. Drops CHR/PIPE/KQUEUE/systm/NPOLICY.
- **App-side on-demand wiring in `ScanEngine`** — `@Published openFiles: [Int32: OpenFileList]` cache + `loadOpenFiles(for:)` (guard-cached, background fetch, main-thread publish). Placed in ScanEngine (not a new object) so all per-PID provenance stays readable from the one `@ObservedObject` the view holds; the on-demand lifecycle is the deliberate divergence, per-scan maps stay untouched.
- **Trigger via `.onAppear` on the expanded `reasoningBlock`** — robust to any expansion entry point (not coupled to the ⓘ button action).

**Exit-gate judgment:** Discovery surfaced no significant deviation → skip 🛠️. The three clarifications were UX refinements (cache/cap/display) inside the already-scoped on-demand approach — no change of target files, root cause, or approach. The on-demand app-side wiring is new but was locked by PID-52.1 and is the task's whole premise, not a deviation.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — mirrored `CwdResolver`: public model struct(s) (`OpenFile`/`OpenFileList` like `ProcessCwd`) + pure injectable parser (`parseOpenFiles` like `parseCwds`) + a composer applying home-abbreviation (reusing `CwdResolver.abbreviateHome`) + private `runLSOF(pid)` via `Shell.run` (like `CwdResolver.runLSOF`). App-side on-demand cache mirrors the per-scan published maps' shape but with lazy population.

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- **`Packages/.../OpenFilesResolver.swift`** (new) — `OpenFile` (name + isSocket) + `OpenFileList` (capped `files` + `total`, `overflow` computed) + pure `parseOpenFiles(lsofOutput:)` (numeric-fd filter → REG/socket type filter → dedup, order-preserving) + `openFiles(forPID:lsofOutput:home:cap:)` composer (parse → home-abbreviate file paths only → cap 15) + private `runLSOF(pid)` shelling `lsof -p <pid> -Fftn` via `Shell.run`.
- **Structural noise filter** — keeping only **numeric-fd** records drops the dylib/framework noise wholesale: it lives on `ftxt`/`fmem` (non-numeric fds), so no path-substring blocklist is needed. Then type ∈ {REG, IPv4, IPv6, unix}; `isSocket` = the three socket types.
- **`Pidlyse/ScanEngine.swift`** — published `openFiles: [Int32: OpenFileList]` cache + `loadOpenFiles(for:)` (guard-cached per session, background `lsof`, main-thread publish). The first **on-demand** provenance fetch; per-scan maps untouched.
- **`Pidlyse/MenuBarView.swift`** — `reasoningBlock` appends an `open files` header + one wrapped, selectable line per entry + a muted `+N more` overflow line, rendered only once resolved and non-empty (graceful degrade). Fetch triggered by `.onAppear` on the expanded block (robust to any expansion entry point, decoupled from the ⓘ button).
- **10 unit tests** added in `PidlyseTests/ScanEngineTests.swift` (`OpenFilesResolverTests`): numeric-fd/txt/mem noise drop, socket keep + isSocket, non-file-type (CHR) drop, order, dedup, empty, missing-type-record skip, home-abbreviation (files not sockets), cap + overflow, empty-list.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `OpenFilesResolverTests` → **10 passed, 0 failures**

- [x] Ran lint/type-check on changed code — `xcodebuild build -scheme Pidlyse` → **BUILD SUCCEEDED** (SourceKit "No such module PidlyseCore" diagnostics were stale-index false positives, exactly as PID-52.2 noted; the test run + real compile are both clean)

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — see below

**Testing Notes:** Change is contained (new PidlyseCore resolver + one app-side cache method + view lines); targeted suite + full app type-check suffice. Menu-bar UI can't be asserted headlessly → visual confirmation requested from the operator.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (the `/usr/sbin/lsof` shell-out surface it documents already covers the new per-PID `lsof` call; its feature list doesn't enumerate the inspector's contents) · `AGENTS.md`: no change (doesn't enumerate core files) · `CLAUDE.md`: **updated** — added `OpenFilesResolver.swift` to the PidlyseCore core-file list (Conventions §, line 18) · `.flowtron/PLAN.md`: the `.3` stub flip itself

- [x] Closed — PLAN.md `.3` line flipped to stub form `Completed 2026-06-30.` (kept nested under PID-EPIC-52 in `## High`; parent + cohort move to `## Completed` only when `.4` audit closes) and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate)

**Final Summary:**

Added the on-demand open-files list to the inline ⓘ inspector for **PID-EPIC-52** — the last feature child. Expanding a row now fetches its real open files + sockets via a single `lsof -p <pid>` (on-demand, never per-scan), shown as a wrapped, capped (15 + `+N more`) list. Backed by a new pure `OpenFilesResolver` in PidlyseCore — `OpenFile`/`OpenFileList` models + `parseOpenFiles(lsofOutput:)` + `openFiles(forPID:lsofOutput:home:cap:)` composer + a private `lsof -p <pid> -Fftn` shell-out via `Shell.run`. The dylib/framework noise is dropped **structurally** by keeping only numeric-fd records (the noise is all `txt`/`mem` fds), then filtering to type REG + sockets. `ScanEngine` gained an `openFiles` cache + `loadOpenFiles(for:)` (guard-cached per session, background fetch, main-thread publish) — the codebase's first on-demand provenance fetch; `reasoningBlock` renders the list, triggered by `.onAppear` on the expanded block. Files: `OpenFilesResolver.swift` (new, ~130 LOC), `ScanEngine.swift`, `MenuBarView.swift`, `CLAUDE.md`; 10 new unit tests. Build clean; 10 targeted tests pass.

**Archived:** 2026-06-30
