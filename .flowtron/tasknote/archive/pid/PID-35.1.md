---
title: security-sweep discovery
status: in-progress
tags: [security, audit, discovery]
created: 2026-06-28
due:
related-tasks: [PID-EPIC-35]
---

# PID-35.1 | security-sweep discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-35]]

## 🎯 Goal

Run the deep security + code-smell sweep across the whole Pidlyse source surface and scope the `PID-EPIC-35` epic (`security-sweep`) before any remediation child fires; deliverable = a findings inventory plus filed concrete child scopes for `PID-35.2..(N-1)` in `.flowtron/PLAN.md` (N provisional = 6).

## ✅ Acceptance

- [x] Shared design surface inventoried for the epic (shell-out callsites, untrusted-input parsing, kill/privilege path, port-registry JSON, distribution/trust + signing, SPEC contract impact) — captured in Discovery Notes
- [x] Security + smell findings inventory captured in Discovery Notes (each finding: location, severity, exploitability/impact, fix sketch)
- [x] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [x] Concrete remediation child scopes for PID-35.2 .. PID-35.5 filed in .flowtron/PLAN.md, one per finding cluster (all under the 50w target per SPEC/tasknote-selection.md §"PLAN.md filing-discipline thresholds")
- [x] Audit line PID-35.N reviewed — count landed on N=6 as filed; provisional PID-35.6 confirmed, no renumber
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the remediation children)

## 🧩 Subtasks

- [x] Inventory shared design surface — read every Swift source (PidlyseCore: ScanCore, DockerCore, PortRegistry, ProcessItem, Container; app: AppDelegate, ScanEngine, KillService, DockerService, the views, PidlyseApp) — log in Discovery Notes
- [x] Threat-model the trust boundaries: shell-out arg construction + PATH/binary resolution (docker/ps/sysctl), untrusted process-metadata parsing, kill→PID-reuse race, port-registry JSON ingestion, signing/notarization/entitlements/LSUIElement
- [x] Skim .flowtron/tasknote/archive/pid/ for relevant precedents (PID-16 code-quality, PID-18 correctness, PID-16.2 shellout-helper, PID-18.3 kill-pidreuse, PID-030 notarize) — log load-bearing findings
- [x] Drift check on cited paths/concepts — flag any drift before re-interpreting the epic
- [x] Build the findings inventory; cluster findings into remediation tracks
- [x] Surface open scoping questions via AskUserQuestion (per-child shortname + scope + severity triage; whether any finding is High/urgent enough to re-prioritize) — record answers in a "Resolved scoping" table
- [x] Draft refined long descriptions for PID-35.2 .. PID-35.5; word-counted each (≤50w); audit confirmed PID-35.6
- [x] Phase 2: write the drafted child lines into .flowtron/PLAN.md under PID-EPIC-35 with 2-space indent
- [x] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [x] Phase 4: doc-drift sweep + flip .1 PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-35]] — parent epic (security-sweep)
- [[PID-EPIC-16]] — prior code-quality sweep (shellout-helper, makeitem-alloc) — closest precedent for a findings-driven cleanup epic
- [[PID-EPIC-18]] — prior correctness sweep (kill-pidreuse, listeningpids-tests) — kill-path + parsing precedents
- [[PID-030]] — deferred notarize-and-sign (distribution/trust surface; gated on Apple Developer enrollment)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-epic-discovery` to open a deep security + smell sweep. Surface is a ~2.1k-LOC local macOS menu-bar tool with real OS-trust-boundary code (shell-out, process kill, untrusted metadata parsing) — warrants the Discovery + Audit bracket.

- [x] Read relevant source files — all 15 Swift sources + Info.plist, Makefile, both CI workflows, README §Security

- [x] **Archive skim** — see Discovery Notes; PID-16.2/PID-002 established the stdout drain-before-wait invariant (load-bearing for F1)

- [x] **Drift check** — all cited paths match HEAD; no drift (files read directly at HEAD)

- [x] Asked clarifying questions — resolved via AskUserQuestion, see "Resolved scoping" table below

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Shared design surface inventoried

| Surface | Files | Trust note |
|---|---|---|
| Shell-out primitive (×3) | `ScanCore.runShell`, `PortRegistry.runShell`, `DockerService.run` | `Process` + `executableURL` + `arguments` array — NO `sh -c`, no string interpolation → classic injection structurally absent |
| Untrusted-input parsing | `ScanCore.parsePSLine/parseElapsed/detectKind`, `DockerCore.parseLine`, `PortRegistry.parsePIDAndPort` | All return `nil` on malformed; `Int32()`/`Int()` guards drop overflow |
| Kill / privilege | `KillService` (SIGTERM→2s→SIGKILL, sysctl start-time PID-reuse guard, EPERM handling) | Never auto-kills; explicit click only |
| Port-registry ingestion | `PortRegistry` (`ports.json` read-only, `JSONDecoder`, malformed→builtins) | App never writes the file; advisory, never fatal |
| Distribution / trust | `Info.plist` (LSUIElement, no sandbox/hardened-runtime/entitlements), `Makefile` (ad-hoc `CODE_SIGN_IDENTITY="-"`), `release.yml`/`test.yml` | Unsandboxed by necessity (shell-out + signals) |

### Findings inventory

| ID | Severity | Location | Finding | Fix sketch |
|---|---|---|---|---|
| F1 | Medium | all 3 `runShell`/`run` helpers | `standardError = Pipe()` set but never drained → >64 KB stderr fills buffer → child blocks → `waitUntilExit()` hangs background thread. Same class PID-16.2 fixed for stdout. | Drain stderr concurrently, or route stderr to `FileHandle.nullDevice`/`/dev/null` |
| F2 | Low | `DockerService.cliPath()` | docker resolved from `/usr/local/bin` (admin-writable on Intel brew) by `isExecutableFile` → local trojan-`docker` runs with user privs on a docker-kill | Optional root-ownership / non-writable check before exec; document residual risk |
| F8 | Low-Med | `KillService.killPosix` | start-time guard protects only SIGKILL escalation; initial SIGTERM can hit a PID recycled between scan and click | Re-verify identity (or re-resolve) immediately before the first SIGTERM |
| F6 | Low (smell) | `PortRegistry.effectivePorts` | `static let` computed once at startup → `ports.json` edits need app restart | Recompute per-scan or expose a reload |
| F7 | Low (smell) | `ScanCore.detectKind` | substring matching (`s.contains("docker")`) can misclassify paths; classification-only, never auto-kills | Tighten match (token/word boundary) where cheap |
| F9 | Low (smell) | `KillService.findContainerID` | inspects EVERY running container per docker-kill (perf) | Map PID→container once / short-circuit |
| F3 | Info / by-design | `Info.plist`, project | no App Sandbox / Hardened Runtime / entitlements file | Folds into PID-030 (hardened-runtime is a notarization prerequisite) |
| F4 | Known/deferred | `Makefile`, `release.yml` | ad-hoc signed, not notarized | **Already tracked as PID-030** (deferred, gated on Apple enrollment) |
| F5 | Low (supply-chain) | `release.yml`, `test.yml` | `actions/checkout@v4` pinned to mutable major tag, not a commit SHA | Pin to SHA |

**Clean (no finding):** no `sh -c`/string-interpolated shell anywhere, no network/`URL(string:)`/HTTP, no `NSAppleScript`, no temp files, no credential/secret handling, UserDefaults holds only config, app never writes `ports.json`. Baseline is solid.

### Archive skim (load-bearing)

- **PID-16.2 (shellout-helper) + PID-002** — established the critical invariant `readDataToEndOfFile()` BEFORE `waitUntilExit()` to prevent pipe-buffer deadlock. Applied to **stdout only**; stderr pipe left undrained → directly motivates F1 and confirms it's a real miss, not a misread.
- **PID-18.3 (kill-pidreuse)** — added the sysctl start-time PID-reuse guard (basis for F8's "escalation-only" scope observation).
- **PID-16.1 (discovery)** — inventoried the 5 shell-out sites; local-per-file helper placement.
- **PID-030** — deferred notarize-and-sign; the home for F3/F4 (operator decision this Discovery).

### Resolved scoping

| Question | Answer |
|---|---|
| Sweep breadth | Security + general code smells (shortname `security-sweep`) |
| Child shape | Findings-driven — children scoped from the real inventory above |
| Flow depth | Default (no `--deep`) |
| Priority / model | Medium · `[heavy]🧠` coordination |
| Which clusters → children | **All four:** F1 stderr-drain, F2+F8 kill-path-hardening, F6/F7/F9 smells-cleanup, F5 CI-SHA-pinning |
| Distribution/trust (F3/F4) | Fold into existing **PID-030** (note F3 hardened-runtime prerequisite there at closure; no duplicate child) |

### Child plan (N stays 6 — provisional audit number holds)

- **PID-35.2** `[medium]🔧` | stderr-drain — F1
- **PID-35.3** `[medium]🧠` | kill-path-hardening — F2 + F8
- **PID-35.4** `[light]🔧` | smells-cleanup — F6 + F7 + F9
- **PID-35.5** `[light]🔧` | ci-sha-pinning — F5
- **PID-35.6** `[heavy]🧠` | audit — unchanged

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed the PID-EPIC-16 cohort-children filing pattern (2-space indent, `[model]` tag per line, em-dash separator, ≤50w descriptions)

- [x] Implemented the minimal solution — 4 child lines (PID-35.2..35.5) written under PID-EPIC-35; PID-35.6 audit kept; PID-030 cross-ref edit applied

- [x] Updated/added tests for non-trivial behavior — N/A (pure PLAN.md filing; no executable code surface)

**Implementation Notes:**

- 4 child lines written. Word-counts: .2≈37w, .3≈38w, .4≈37w, .5≈23w — all under the 50w target.
- No audit-number bump: the four-cluster triage landed exactly on the provisional N=6, so PID-35.6 audit holds as filed.
- Downstream-impact reconciliation (new-task-filing trigger): scanned the rest of the active PLAN (High/Medium/Low/Future). Only PID-030 shares a surface (distribution/trust). PID-030 already names the Hardened-Runtime-for-notarization scope, so F3/F4 fold there cleanly — classified **absorbing**, action **edit** (added a one-clause `[[PID-EPIC-35]]` cross-ref). No other entries impacted.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (no code changed; markdown-only)

- [x] Ran lint/type-check on changed code — markdown mental-pass: 2-space child indent ✓, bold IDs ✓, `[model]` tag on every line ✓, `| shortname` ≤30 chars ✓, em-dash separators ✓, ≤50w ✓, no trailing whitespace ✓, PID-030 cross-ref parses ✓

- [ ] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask) — N/A (no UI surface)

**Testing Notes:** Pure PLAN.md filing — no test suite or compiler surface touched.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` no change · `AGENTS.md` no change · `CLAUDE.md` no change · `.flowtron/PLAN.md` updated (this filing). Contract edits land inside the implementation children, not this Discovery.

- [x] Closed — PLAN.md `.1` line flipped to stub form `Completed 2026-06-28.`; tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

PID-EPIC-35 (`security-sweep`) filed and its `.1` Discovery driven to closure. The deep sweep read all ~2.1k LOC plus Info.plist / Makefile / CI / README §Security and confirmed a solid baseline: no `sh -c`/string-interpolated shell (all `Process` + arg arrays), no network, no AppleScript, no temp files, no secret handling. Nine findings inventoried; the operator triaged four into remediation children — **PID-35.2** stderr-drain (F1, the one real latent bug — undrained stderr pipe, same deadlock class PID-16.2 fixed for stdout), **PID-35.3** kill-path-hardening (F2 docker-binary trust + F8 SIGTERM TOCTOU), **PID-35.4** smells-cleanup (F6/F7/F9), **PID-35.5** ci-sha-pinning (F5). Distribution/trust (F3/F4) folded into existing PID-030. Audit landed on N=6 as provisionally filed. Refined epic scope: a findings-driven hardening pass over the shell-out, kill, and supply-chain surfaces of an otherwise injection-safe local tool.

**Archived:** 2026-06-28
