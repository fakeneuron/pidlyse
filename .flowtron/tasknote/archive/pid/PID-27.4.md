---
title: launchd-registration
status: in-progress
tags: []
created: 2026-06-26
due:
related-tasks: [PID-EPIC-27, PID-27.3, PID-27.5]
---

# PID-27.4 | launchd-registration

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-27]] [[PID-27.3]] [[PID-27.5]]

## 🎯 Goal

Author the LaunchAgent `.plist` (`StartInterval`), embed it and `PidlyHelper` under the app bundle, and expose register/unregister/status via `SMAppService.agent(plistName:)` in a new `LaunchAgentService`.

## ✅ Acceptance

- [ ] `Pidly.app/Contents/Library/LaunchAgents/com.fakeneuron.pidly.helper.plist` is present in a release build (Label + BundleProgram + StartInterval correct).
- [ ] `Pidly.app/Contents/Helpers/PidlyHelper` is present in a release build (embedded + signed).
- [ ] `LaunchAgentService.register()`, `.unregister()`, `.status` compile without error against `SMAppService.agent(plistName:)`.
- [ ] `make test` stays green (65/65 prior tests; no new test surface here — `LaunchAgentService` is pure API glue).
- [ ] `make build-release` succeeds.

## 🧩 Subtasks

- [ ] Author `Pidly/com.fakeneuron.pidly.helper.plist` — `Label: com.fakeneuron.pidly.helper`, `BundleProgram: Contents/Helpers/PidlyHelper`, `StartInterval: 120`.
- [ ] Author `Pidly/LaunchAgentService.swift` — `enum LaunchAgentService` wrapping `SMAppService.agent(plistName:)` with `register() throws`, `unregister() async throws`, `status: SMAppService.Status`.
- [ ] Hand-edit `Pidly.xcodeproj/project.pbxproj` (B16X block): file refs (plist B15E, LaunchAgentService.swift B163), build files, two `PBXCopyFilesBuildPhase`s (LaunchAgents plist → `Contents/Library/LaunchAgents` + Helpers executable → `Contents/Helpers`), `PBXContainerItemProxy` (B165) + `PBXTargetDependency` (B166) for PidlyHelper in app target; wire LaunchAgentService.swift into app Sources (B164) and both copy phases + dependency into app target's buildPhases + dependencies.
- [ ] Verify: `make build-release`; confirm plist + helper binary at expected bundle paths; `make test` green.

## 🔗 Related

- [[PID-EPIC-27]] — parent epic (xpc-background-scan / launchd background scanning)
- [[PID-27.3]] — helper-target: produced the `PidlyHelper` executable this task embeds
- [[PID-27.5]] — notify-and-handoff: the next child; will call `LaunchAgentService.register()` conditionally

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Third implementation child of PID-EPIC-27. The helper executable (`PidlyHelper`) is built and verified; this task embeds it in the app bundle and wires up the `SMAppService.agent` API surface that `.5` and `.6` will call. Nothing has shifted since Discovery.

- [x] Read relevant source files — `PidlyHelper/main.swift` (helper entry point), `HelperConfig.swift` (shared config struct), `SettingsView.swift` (`SMAppService.mainApp` pattern), `ScanEngine.swift` (scan interval defaults), `Pidly/Info.plist` (bundle ID `com.fakeneuron.pidly`), `Pidly.xcodeproj/project.pbxproj` (target/phase structure, B15E is next available ID).

- [x] **Archive skim** — `PID-27.1` (mechanism: `SMAppService.agent(plistName:)`, `BundleProgram`, `Contents/Library/LaunchAgents` placement), `PID-27.2` (PidlyCore static-linked, zero-signing-surface), `PID-27.3` (helper target B150, product B151, bundle ID `com.fakeneuron.pidly.helper`, GENERATE_INFOPLIST_FILE = YES, pbxproj B15X block; **build-command gotcha: use `-scheme PidlyHelper`, not `-target PidlyHelper`**). No prior embed/copy-files work in this codebase — this is the first `PBXCopyFilesBuildPhase` addition.

- [x] **Drift check** — Helper bundle ID `com.fakeneuron.pidly.helper` confirmed in pbxproj (B159/B15A configs). App target B101 has no existing `dependencies` or `CopyFiles` phases. `SMAppService.mainApp` pattern in `SettingsView.swift:11` confirmed present; `ServiceManagement` already imported. Helper product ref B151. Next available pbxproj ID: `B15E`. No drift.

- [x] Asked clarifying questions — No clarifications needed. Explicit assumptions:
  - Helper executable lands at `Contents/Helpers/PidlyHelper` (Apple convention for `SMAppService.agent`; `BundleProgram` key is relative to bundle root).
  - Plist lives at `Pidly/com.fakeneuron.pidly.helper.plist` in source (same `Pidly/` group as `Info.plist`), copied to `Contents/Library/LaunchAgents/` via a Copy Files phase (`dstSubfolderSpec = 1`, `dstPath = "Contents/Library/LaunchAgents"`).
  - `StartInterval = 120` seconds (matches app's default `scanInterval`; static in plist, dynamic-interval design deferred to `.6`).
  - `LaunchAgentService` is a new `Pidly/LaunchAgentService.swift` — pure enum (no stored state) mirroring the `launchAtLogin` inline pattern in `SettingsView.swift` but extracted as a reusable service for `.5`/`.6`.
  - ID block: `B15E`–`B166` (plist ref, plist build file, two Copy Files phases, LaunchAgentService ref, LaunchAgentService build file, ContainerItemProxy, TargetDependency).
  - No new unit tests: `LaunchAgentService` is pure API delegation to the system framework — no logic to test; compile success + embedded binary presence are the verification gate.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Scope boundary

| Child | Owns |
|---|---|
| .3 | `PidlyHelper` executable target (built, verified) |
| **.4 (this)** | LaunchAgent plist + embed helper in app bundle + `SMAppService.agent` API surface |
| .5 | Helper posts UN notifications + dedupe baseline + app↔helper shared state |
| .6 | Settings toggle gating registration + signing/notarization config |

### pbxproj ID plan

| ID | Object |
|---|---|
| B15E | PBXFileReference — `com.fakeneuron.pidly.helper.plist` |
| B15F | PBXBuildFile — plist in Copy LaunchAgents phase |
| B160 | PBXCopyFilesBuildPhase — plist → `Contents/Library/LaunchAgents` (app target) |
| B161 | PBXBuildFile — PidlyHelper (B151) in Copy Helpers phase, `SignOnCopy` |
| B162 | PBXCopyFilesBuildPhase — PidlyHelper → `Contents/Helpers` (app target) |
| B163 | PBXFileReference — `LaunchAgentService.swift` |
| B164 | PBXBuildFile — LaunchAgentService.swift in app Sources |
| B165 | PBXContainerItemProxy — proxy for PidlyHelper target |
| B166 | PBXTargetDependency — PidlyHelper dep in app target |

**Phase 1→2 exit:** Discovery surfaced no significant deviation → **skip 🛠️**

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — `LaunchAgentService` mirrors `SettingsView.swift`'s inline `launchAtLogin` Binding (same `SMAppService` import, same try/catch shape) but extracted as a standalone service type — the same extraction pattern `KillService` uses relative to inline kill calls. Two Copy Files phases follow the canonical `dstSubfolderSpec = 1` + `dstPath` shape (no prior CopyFiles in this pbxproj, shape derived from Xcode schema). `PBXContainerItemProxy` + `PBXTargetDependency` for a helper dep mirror the existing PidlyTests → Pidly dependency (B122/B123 block).

- [x] Implemented the minimal solution

- [x] Updated/added tests for non-trivial behavior — `LaunchAgentService` is pure API delegation to the system framework (no logic to test); compile success + embedded binary presence are the verification gate. No new test file added.

**Implementation Notes:**

- **`Pidly/com.fakeneuron.pidly.helper.plist`** (new) — `Label: com.fakeneuron.pidly.helper`, `BundleProgram: Contents/Helpers/PidlyHelper`, `StartInterval: 120`. Copied to `Contents/Library/LaunchAgents/` in the app bundle via B160 Copy Files phase.
- **`Pidly/LaunchAgentService.swift`** (new) — `enum LaunchAgentService` with `plistName = "com.fakeneuron.pidly.helper.plist"`, `status: SMAppService.Status`, `register() throws`, `unregister() async throws`. The `.6` settings toggle calls these.
- **`Pidly.xcodeproj/project.pbxproj`** — B15E–B166 block: plist file ref (B15E) + build file (B15F), Copy LaunchAgents phase (B160), helper build file with `SignOnCopy` (B161), Copy Helpers phase (B162), LaunchAgentService.swift file ref (B163) + build file (B164) in app Sources, PBXContainerItemProxy (B165) + PBXTargetDependency (B166) for PidlyHelper dep in app target. App target (B101): two new buildPhases + one dependency.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **65 tests, 0 failures** (65/65 prior; no new test surface). `LaunchAgentService` compiles as part of the app target.

- [x] Ran lint/type-check on changed code — `make build-release`: **BUILD SUCCEEDED**. Swift compiler accepted `LaunchAgentService` (ServiceManagement already imported in `SettingsView.swift`; no new framework linkage needed). No warnings in new code.

- [x] (frontend) Visual confirmation — **N/A**: no UI surface (plist + service enum + pbxproj wiring only). No 👁️ ask warranted.

**Testing Notes:**

- Bundle structure verified post-build:
  - `Pidly.app/Contents/Helpers/PidlyHelper` — present (embedded, `SignOnCopy` re-signed with app identity)
  - `Pidly.app/Contents/Library/LaunchAgents/com.fakeneuron.pidly.helper.plist` — present
- `SMAppService.agent(plistName:)` compile-time: the `plistName` must match the filename in `Contents/Library/LaunchAgents/` exactly — confirmed by inspecting the bundle.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md`: no change (LaunchAgent not yet user-visible — UI toggle is `.6`). `AGENTS.md`: no change (conventions bullet accurate; `LaunchAgentService` is app-side infrastructure). `CLAUDE.md`: **updated** — added conventions bullet for `LaunchAgentService.swift` + plist location + Copy Helpers phase. `.flowtron/PLAN.md`: PID-27.4 line flipped to stub form.

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-26.` and tasknote moved to `.flowtron/tasknote/archive/PID/`

- [x] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Authored the LaunchAgent plist (`com.fakeneuron.pidly.helper.plist`: `Label`, `BundleProgram: Contents/Helpers/PidlyHelper`, `StartInterval: 120`) and embedded it + the `PidlyHelper` executable into the app bundle via two new `PBXCopyFilesBuildPhase`s in `Pidly.xcodeproj` (Copy LaunchAgents → `Contents/Library/LaunchAgents/`; Copy Helpers → `Contents/Helpers/`, `SignOnCopy`). Added `PBXContainerItemProxy` + `PBXTargetDependency` so the app target builds `PidlyHelper` first. Authored `Pidly/LaunchAgentService.swift` — a pure `enum` wrapping `SMAppService.agent(plistName:)` with `register() throws`, `unregister() async throws`, and `status: SMAppService.Status` — mirroring the existing `launchAtLogin` pattern in `SettingsView.swift` but extracted as a standalone service for `.5`/`.6` to call. Verified: `make build-release` succeeds; `Pidly.app/Contents/Helpers/PidlyHelper` and `Contents/Library/LaunchAgents/com.fakeneuron.pidly.helper.plist` both present post-build; `make test` 65/65 green. Files: `Pidly/com.fakeneuron.pidly.helper.plist`, `Pidly/LaunchAgentService.swift` (new); `Pidly.xcodeproj/project.pbxproj`, `CLAUDE.md` (edited).

**Archived:** 2026-06-26
