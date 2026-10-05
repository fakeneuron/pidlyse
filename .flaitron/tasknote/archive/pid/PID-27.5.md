---
title: notify-and-handoff
status: completed
tags: []
created: 2026-06-26
due:
related-tasks: [PID-EPIC-27, PID-27.3, PID-27.4, PID-029]
---

# PID-27.5 | notify-and-handoff

[← PLAN.md](../PLAN.md) · ✅ Completed (De-scoped) · 🔗 [[PID-EPIC-27]] [[PID-27.3]] [[PID-27.4]] [[PID-029]]

## 🎯 Goal

~~Wire the app↔helper handoff so the background helper surfaces new-stray notifications without double-alerting the app.~~ **De-scoped** — user dropped the background-helper component entirely (too intrusive; keep the app simple). EPIC-27 retired.

## ✅ Acceptance

- [ ] App writes `HelperConfig` (elapsedThreshold / ignoredNames / notificationsEnabled) to the shared `config.json` whenever settings change, so the helper reads current app settings.
- [ ] A pure, injectable shared dedupe baseline (persisted to Application Support) records seen stray PIDs; both app and helper read+write it so neither re-alerts on a stray the other already announced.
- [ ] App's notification path uses the shared persisted baseline (replacing the in-memory `previousPIDs`), preserving current app-foreground notification behavior.
- [ ] Helper loads config, enumerates, diffs against the shared baseline, posts a new-stray notification when `notificationsEnabled`, and updates the baseline. *(mechanism pending Discovery decision — see Discovery Notes)*
- [ ] New PidlyCore unit tests cover the baseline diff + persistence round-trip and the config write side; `make test` stays green.
- [ ] `make build-release` succeeds.

## 🧩 Subtasks

- [ ] *(populated after the Discovery clarifying decision)*

## 🔗 Related

- [[PID-EPIC-27]] — parent epic (xpc-background-scan / launchd background scanning)
- [[PID-27.3]] — helper-target: produced the `PidlyHelper` `tool` executable this task teaches to notify
- [[PID-27.4]] — launchd-registration: embedded helper + plist; `BundleProgram: Contents/Helpers/PidlyHelper`
- [[PID-27.6]] — settings-and-signing: the toggle gating registration + Developer-ID signing/notarization

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** De-scope
  **Rationale:** Discovery surfaced a load-bearing deviation (helper is a bare `tool`, not a bundle → can't post UN notifications without bundle conversion). Two clarifying rounds resolved up the stack to the epic premise: the user finds a background component too intrusive and wants the app kept simple. The helper's only user-visible payload is notifications, so dropping them hollows out EPIC-27 → De-scope `.5` and retire the epic, rather than build handoff plumbing nothing consumes.

- [x] Read relevant source files — `PidlyHelper/main.swift` (helper entry, prints count only), `Packages/PidlyCore/Sources/PidlyCore/HelperConfig.swift` (read side: `load`/`decode`/`fileURL`, no write side yet), `ScanEngine.swift` (app notification path: in-memory `previousPIDs`, `fireNotificationIfNeeded`), `PortRegistry.swift` (PID-025 Application-Support JSON read pattern), `PidlyTests/HelperConfigTests.swift` (pure decode test conventions), `Pidly.xcodeproj/project.pbxproj` (helper product type).

- [x] **Archive skim** — `PID-27.1` (Discovery: "helper posts notifications directly — own bundle + UN authorization + dedupe baseline"; helper read-only, kills stay in-app), `PID-27.2` (PidlyCore extraction + `HelperConfig` shape, `config.json` location mirroring PID-025 `ports.json`), `PID-27.3` (helper built as **`com.apple.product-type.tool`**, `-scheme PidlyHelper`), `PID-27.4` (plist `BundleProgram: Contents/Helpers/PidlyHelper`, `StartInterval: 120`; `LaunchAgentService` API surface). PID-025 (`ports.json`) is the precedent for a pure inject-testable Application-Support JSON read.

- [x] **Drift check** — **Drift found (load-bearing).** `PID-27.1` Discovery assumed the helper would post notifications via "its own bundle + UN authorization." But `PID-27.3` built `PidlyHelper` as a **bare `tool` target** (`com.apple.product-type.tool`, confirmed in pbxproj line 235), embedded at `Contents/Helpers/PidlyHelper`. `UNUserNotificationCenter.current()` requires a process with a bundle proxy and raises `bundleProxyForCurrentProcess is nil` for a bare command-line tool — so the helper **cannot** post UN notifications as currently built. This changes the approach and which files are edited → surfaced as a clarifying question before execution.

- [x] Asked clarifying questions — Two AskUserQuestion rounds (helper-notify mechanism → epic direction → cleanup scope). Resolutions in the "Clarifying resolution" block below.

- [x] Subtasks — N/A (De-scope: no execution; closure only).

**Clarifying resolution:**

1. *How should the bare-`tool` helper post notifications?* → User: "if the notification adds too much complexity, we can just avoid it. it's probably unnecessary noise for user anyway."
2. *Helper exists only to notify; dropping it hollows the epic — how to proceed?* → User: "i find a background component too intrusive. let's keep this app simple." → **Retire EPIC-27.**
3. *Cleanup scope for the dormant `.3`/`.4` machinery?* → User: **Stop + tear out** — remove the helper machinery (filed as [[PID-029]]); keep `PidlyCore` (`.2`).

**Discovery Notes:**

### Scope boundary (recap from `.4`)

| Child | Owns |
|---|---|
| .3 | `PidlyHelper` `tool` executable (built) |
| .4 | LaunchAgent plist + embed helper + `SMAppService.agent` API surface (done) |
| **.5 (this)** | App writes config; shared persisted dedupe baseline; app uses it; helper posts new-stray notifications |
| .6 | Settings toggle gating registration + Developer-ID signing/notarization + SPEC updates |

### Three clean, unambiguous pieces (no decision needed)

1. **Config write side (app→helper).** Add `HelperConfig.save(_:)` (write `config.json`, `createDirectory` for the `Pidly/` dir like PID-025) + app calls it from `ScanEngine`'s `didSet` knobs (elapsedThreshold / ignoredNames / notificationsEnabled) and at init. Pure write + round-trip testable.
2. **Shared persisted dedupe baseline.** New pure PidlyCore type (e.g. `StrayBaseline`) persisting seen PIDs to `~/Library/Application Support/Pidly/baseline.json`, with an injectable `newStrays(current:previous:)`-style diff + decode/encode round-trip. Mirrors PID-025's pure-decode-with-fallback shape. Both processes read+write it → single source of truth → no double-alert.
3. **App rewire.** Replace `ScanEngine.previousPIDs` (in-memory) with the shared persisted baseline so the app and helper share one baseline.

### The one real decision (clarifying question)

Helper-side **posting** mechanism, given the helper is a bare `tool`:
- **A — Convert `PidlyHelper` to a faceless `.app` bundle** (LSUIElement, own Info.plist + bundle ID `com.fakeneuron.pidly.helper`). The correct macOS path for a LaunchAgent that posts UN notifications. Cost: pbxproj product-type change + plist `BundleProgram` path change (`PidlyHelper.app/Contents/MacOS/PidlyHelper`) + Copy phase change — ripples into PID-27.4 artifacts. Signing stays in `.6`.
- **B — `osascript -e 'display notification …'` from the bare tool.** Works with no bundle; pragmatic. Cost: notifications attribute to "Script Editor", limited styling, separate auth surface.
- **C — Defer helper posting to `.6`.** Land handoff infra + shared baseline + app rewire now; helper records new strays into the baseline but posting (bundle conversion) moves to `.6` with signing. Cleanest `.5`, but re-scopes the headline "helper posts notifications" deliverable into `.6`.

## 🛠️ Phase 2: Execution

- N/A — **De-scoped** at Phase 1. No code written in this tasknote. The teardown of the dormant `.3`/`.4` machinery is filed as its own task, [[PID-029]].

## 🧪 Phase 3: Testing & Linting

- N/A — no code changed.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (background scanning never became user-visible). `AGENTS.md`: no change. `CLAUDE.md`: **stale** — the `LaunchAgentService` / helper conventions bullet describes machinery being removed; that edit belongs to the [[PID-029]] teardown (where the code actually goes), not this de-scope closure. `.flowtron/tasknote/README.md` §"AI-referenced docs": no change. `.flowtron/PLAN.md`: EPIC-27 retired (see below).

- [x] Closed — EPIC-27 block moved to `## Completed` (parent abandoned; `.5` de-scoped; `.6`/`.7` won't-do; `.2`/`.3`/`.4` keep completed history). PID-029 teardown filed under `## Low`. Tasknote moved to `.flowtron/tasknote/archive/pid/`.

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

PID-27.5 (`notify-and-handoff`) **de-scoped** without writing code. Discovery surfaced that `PidlyHelper` was built as a bare `com.apple.product-type.tool` in PID-27.3, which cannot use `UNUserNotificationCenter` (needs a bundle proxy) — so helper-posted notifications required a bundle conversion. Surfacing that tradeoff to the user resolved up to the epic premise: the user finds a background component too intrusive and wants Pidly kept simple (foreground-only menu-bar scanner). Decision: **retire EPIC-27**. The `.3`/`.4` helper machinery is currently dormant (nothing registers it with `launchd` — registration was gated behind the unbuilt `.6` toggle), so nothing intrusive runs today. Closure actions: moved the EPIC-27 block to `## Completed` with abandonment annotations (`.2` PidlyCore extraction kept as a benign useful refactor); filed `PID-029` to tear out the helper target / plist / `LaunchAgentService.swift` / Copy Files phases. No source files changed in this task.

**Archived:** 2026-06-26
