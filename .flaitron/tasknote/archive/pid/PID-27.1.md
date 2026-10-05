---
title: xpc-background-scan discovery
status: completed
tags: []
created: 2026-06-26
related-tasks: [PID-EPIC-27]
---

# PID-27.1 | xpc-background-scan discovery

[← PLAN.md](../PLAN.md) · ✅ Completed · 🔗 [[PID-EPIC-27]]

## 🎯 Goal

Scope the `PID-EPIC-27` epic (`xpc-background-scan`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-27.2..6` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (current scan/timer architecture, lifecycle ownership, entitlements/sandbox impact, SPEC contract impact, Settings wiring) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for `PID-27.2` .. `PID-27.6` filed in `.flowtron/PLAN.md` (each line under the 50w target / 70w hard cap)
- [ ] Audit line `PID-27.7` reviewed and confirmed as-filed (or renumbered if Discovery shifts N)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (ScanEngine timer/lifecycle, AppDelegate/PidlyApp ownership, current entitlements, SPEC Non-Goals + Milestones, SettingsView) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/pid/` for relevant precedents (scan engine, settings, launch-at-login/SMAppService) — log load-bearing findings
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (architecture: XPC service vs `launchd` agent; entitlements/sandbox posture; per-child shortname + scope) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for `PID-27.2` .. `PID-27.6`; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under `PID-EPIC-27` with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip `.1` PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-27]] — parent epic (xpc-background-scan)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User invoked `/ft-epic-discovery` to decompose the filed PID-EPIC-27 shell. Background scanning is a real post-v1 capability; epic scope warrants the Discovery + Audit bracket given XPC/launchd/entitlements integration risk.

- [x] Read relevant source files

- [x] **Archive skim** — skim `.flowtron/tasknote/archive/<area>/` for prior tasknotes that touched the source paths in scope; log relevant findings in Discovery Notes before re-interpreting the task

- [x] **Drift check** — file paths, line numbers, function names, and root-cause hypotheses cited in the task description still match current code; flag any drift before re-interpreting the task

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Shared design surface

- **`ScanEngine.swift`** (`ObservableObject`) owns the whole scan lifecycle: `Timer` (`startTimer`, line 142), `scan()` shelling to `ps`/`lsof` via the pure static `enumerate` (line 155), `UNUserNotificationCenter` firing (`fireNotificationIfNeeded`, line 121), `UserDefaults` config persistence, and `previousPIDs`/`dismissedPIDs` baselines. **All alive only while the app process runs** — this is the code that must become reusable in a background context.
- **Pure core already isolated & injectable:** `ScanEngine.enumerate(...)`, `ProcessItem`, `PortRegistry` (incl. PID-025's `effectivePorts`), and classification are side-effect-free and unit-tested → cleanly extractable into a shared target the helper can link.
- **`SMAppService` precedent:** `SettingsView.swift` already uses `SMAppService.mainApp` for Launch-at-login. The sibling `SMAppService.agent(plistName:)` is the modern, SMJobBless-free path to register a LaunchAgent — extend the same import/pattern.
- **Sandbox posture:** no `.entitlements` file exists (only `Info.plist`); the app is **unsandboxed**, which is *required* for `ps`/`lsof`/`kill` over arbitrary processes. The helper must stay unsandboxed too → Developer-ID/ad-hoc signed, no Mac App Store (already true). Logged assumption, not asked.
- **`LSUIElement = YES`:** Pidly is already a menu-bar agent (no Dock). "No app in the foreground" therefore means *scans continue after the user fully quits Pidly* — the launchd-agent story, not a foreground/background distinction.

### Architecture finding (load-bearing)

The epic title says "XPC service + launchd plist", but **XPC services are spawned on-demand by the running app and die with it** — they cannot scan once Pidly is quit. The persistence mechanism is a **launchd LaunchAgent**; XPC would only be an optional live-IPC channel. User confirmed: LaunchAgent, XPC dropped. The parent epic description is refined accordingly at `.1` closure.

### Archive skim

Port/scan/settings lineage: PID-005 (port registry), PID-024/025 (TTY SSOT, port JSON), PID-026 (icon pulse on new stray), PID-13.x/16.x/18.x (scan engine + notifications + kill guards). No prior background/daemon/launchd work — this epic is the first helper-process effort. SMAppService launch-at-login landed in the PID-20.x DMG-release cohort. No drift in cited paths.

### Resolved scoping

| Question | Decision |
|---|---|
| Background mechanism | **launchd LaunchAgent** via `SMAppService.agent(plistName:)`; XPC dropped as persistence engine |
| Helper scope | **Scan + notify only** — read-only watcher; all kills stay in the app UI (honors never-auto-kill) |
| Notification owner (app quit) | **Helper posts notifications directly** — own bundle + UN authorization + dedupe baseline |
| Sandbox/signing posture | Stay **unsandboxed**, Developer-ID/ad-hoc signed (assumption — required for enumerate/kill) |
| Priority / N | Stays **Low** (SPEC post-v1 Non-Goal); **N=7** (.1 Discovery + .2–.6 impl + .7 audit) |

### Planned children (Phase 2 deliverable)

- **.2 shared-scan-core** — extract pure `enumerate`/`ProcessItem`/`PortRegistry`/classification into a shared target both app + helper link.
- **.3 helper-target** — new unsandboxed LaunchAgent helper bundle that runs the shared core once per invocation, reading config from a shared store.
- **.4 launchd-registration** — `.plist` (StartInterval) + register/unregister/status via `SMAppService.agent`; install under the app bundle.
- **.5 notify-and-handoff** — helper posts new-stray notifications (UN auth, persisted dedupe baseline) + app/helper share config & last-results so they don't double-alert.
- **.6 settings-and-signing** — "Background scanning" toggle in SettingsView gates registration; helper signing/notarization config; SPEC Non-Goals/Tech-Stack update.

**Phase 1→2 exit:** Clarifications surfaced (3 architecture forks resolved) → **fire 🛠️** per the `default-fire-on-clarifications` flavor.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — looked at neighboring code for an existing pattern to extend; justified the new shape if none fits

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior

**Implementation Notes:**

- Filed **5 child lines** `PID-27.2`..`.6` under `PID-EPIC-27` with 2-space indent, before the `.7` audit line. Matched the PID-20.x epic-cohort shape (indent, `[model]` per line, em-dash, ≤50w). N unchanged at 7 → audit stays `.7` (no renumber).
- Models: `.2` `[medium]🧠` (extraction refactor), `.3` `[heavy]🧠` (new helper process), `.4` `[medium]🔧` (plist + SMAppService wiring), `.5` `[heavy]🧠` (notify dedupe + shared-state), `.6` `[medium]🧠` (settings + signing).
- Word-counts: all child long descriptions ~25–38w, under the 50w target. Parent description refined (~42w) to drop XPC-as-mechanism framing → launchd-agent.
- **Downstream-impact reconciliation:** scanned remaining active PLAN entries (only `PID-EPIC-28` docker-panel in Low; Future = none; High/Medium empty). EPIC-28 builds on `KillService` docker paths — no shared surface with the scan-core/launchd-helper children. **No downstream impact; no reconcile edits.**
- Tests N/A — pure PLAN.md filing, no executable code surface.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code

- [x] Ran lint/type-check on changed code

- [x] (frontend) Asked the user for visual confirmation (👁️ prefix on the prose ask)

**Testing Notes:**

Markdown-only edit — no test/lint/frontend surface (all N/A). Markdown mental-pass on the PLAN.md block passed: 2-space child indent on all 7 lines, bold IDs intact, `[model]` tag + `| shortname` (≤30c) present per line, em-dash separators consistent, descriptions ≤50w, no trailing whitespace. `PID-EPIC-28` (unedited) still parses.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — README.md (background scanning not yet shipped → no change); AGENTS.md (no scan/launchd refs → no change); CLAUDE.md (helper conventions land with impl children → no change); PLAN.md (children filed + `.1` flipped). Contract edits land inside `.2`–`.6`.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-26.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Filed PID-EPIC-27 (`xpc-background-scan`) and drove its `.1` Discovery to close. The load-bearing finding: app-quit persistence needs a **launchd LaunchAgent** (`SMAppService.agent`), not an XPC service (XPC dies with the app); the helper is read-only (scan + notify, kills stay in-app) and posts its own notifications; the helper stays unsandboxed like the app. Scoped 5 implementation children (`.2` shared-scan-core → `.3` helper-target → `.4` launchd-registration → `.5` notify-and-handoff → `.6` settings-and-signing) + `.7` audit; refined the parent description off the XPC framing. No code changed — pure PLAN.md filing.

**Archived:** 2026-06-26
