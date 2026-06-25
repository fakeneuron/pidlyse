# Pidly — PLAN.md

## Vision

Pidly is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

- [x] **PID-004** [medium] | kill-hardening — Completed 2026-06-24.
- [x] **PID-005** [medium] | port-registry — Completed 2026-06-24.
- [x] **PID-006** [medium] | polish — Completed 2026-06-24.

## Medium

- [x] **PID-008** [light] | why-reasoning — Completed 2026-06-24.
- [x] **PID-011** [light] | row-labels — Completed 2026-06-24.
- [x] **PID-012** [light] | row-status-icons — Completed 2026-06-24.

## Low

- [x] **PID-010** [light] | auto-start — Completed 2026-06-24.
- [ ] **PID-EPIC-16** [light]🔧 | code-quality — Mechanical code-quality pass: extract shell-out helper (5 duplicate Process/Pipe/wait sites), fix makeItem double-allocation, simplify ScanEngine persistence coupling; survey for additional perf/UX opportunities. Filed via /ft-epic-discovery 2026-06-24.
  - [x] **PID-16.1** [light]🔧 | discovery — Completed 2026-06-24.
  - [x] **PID-16.2** [light]🔧 | shellout-helper — Completed 2026-06-24.
  - [ ] **PID-16.3** [light]🔧 | makeitem-alloc — Inline hasTTY/isOrphan computations in ScanEngine.makeItem (lines 190-200), removing the draft ProcessItem heap allocation. Keep riskTier logic unchanged.
  - [ ] **PID-16.4** [light]🔧 | scanengine-persistence — Simplify ScanEngine @Published+didSet UserDefaults coupling in init: avoid spurious startTimer calls by reading all persisted values before assignment; no behaviour change.
  - [ ] **PID-16.5** [light]🔧 | audit — Final-subtask audit per SPEC/epic.md (fixed doc-drift sweep acceptance line). Filed at filing time as highest .N child.

## Future Opportunities

- XPC service / `launchd` plist for background scanning (no app in foreground required)
- Docker / container management panel
- JSON override file for port registry (user-editable, loaded at startup)
- Animated icon states beyond simple badge

## Completed

- [x] **PID-EPIC-15** [light]🔧 | doc-sync — Completed 2026-06-24.
  - [x] **PID-15.2** [light]🔧 | spec-settings — Completed 2026-06-24.
  - [x] **PID-15.3** [light]🔧 | tasknote-readme-cmds — Completed 2026-06-24.
  - [x] **PID-15.N** [light]🔧 | audit — Completed 2026-06-24.
- [x] **PID-EPIC-14** [light]🔧 | correctness — Completed 2026-06-24.
  - [x] **PID-14.2** [light]🔧 | bun-guard — Completed 2026-06-24.
  - [x] **PID-14.3** [light]🔧 | docker-stop-note — Completed 2026-06-24.
  - [x] **PID-14.4** [light]🔧 | correctness audit — Completed 2026-06-24.
- [x] **PID-EPIC-13** [medium] | feature-expansion — Completed 2026-06-24.
  - [x] **PID-13.1** [medium] | discovery — Completed 2026-06-24.
  - [x] **PID-13.2** [medium] | cpu-ram-per-row — Completed 2026-06-24.
  - [x] **PID-13.3** [medium] | process-patterns — Completed 2026-06-24.
  - [x] **PID-13.4** [light] | app-description — Completed 2026-06-24.
  - [x] **PID-13.5** [medium] | notifications — Completed 2026-06-24.
  - [x] **PID-13.6** [medium] | audit — Completed 2026-06-24.
- [x] **PID-010** [light] | auto-start — Completed 2026-06-24.
- [x] **PID-011** [light] | row-labels — Completed 2026-06-24.
- [x] **PID-012** [light] | row-status-icons — Completed 2026-06-24.
- [x] **PID-008** [light] | why-reasoning — Completed 2026-06-24.
- [x] **PID-007** [light] | dismiss-snooze — Completed 2026-06-24.
- [x] **PID-006** [medium] | polish — Completed 2026-06-24.
- [x] **PID-005** [medium] | port-registry — Completed 2026-06-24.
- [x] **PID-004** [medium] | kill-hardening — Completed 2026-06-24.
- [x] **PID-003** [heavy] | popover-ui — Completed 2026-06-23.
- [x] **PID-009** [medium] | kill-all-safe — Completed 2026-06-23 (absorbed by PID-003 "Clean all safe").
- [x] **PID-002** [heavy] | scan-engine — Completed 2026-06-23.
- [x] **PID-001** [heavy] | scaffold — Completed 2026-06-23.

<!--
Task-line grammar (see .flowtron/core/SPEC.md §"Task-line format"):

  - [ ] **TASK-ID** [!critical] [model] | shortname — long description

All of `[!critical]`, `[model]`, and `| shortname` are optional.
-->
