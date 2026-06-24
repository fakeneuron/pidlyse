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
- [ ] **PID-EPIC-13** [medium] | feature-expansion — Multi-child epic to make Pidly more informative: adds per-process CPU/RAM display, expands process-pattern vocabulary (vite, bun, node), refines app descriptions and in-app copy, and adds proactive badge/notification support for newly detected strays. (filed via /ft-epic-discovery; refined at .1 closure)
  - [x] **PID-13.1** [medium] | discovery — Completed 2026-06-24.
  - [ ] **PID-13.2** [medium] | cpu-ram-per-row — Add `%cpu` and `rss` columns to the `ps` shell-out in `ScanEngine`, surface as new fields on `ProcessItem`, and render as a compact `0.1% · 48 MB` annotation on each popover row in `MenuBarView`.
  - [ ] **PID-13.3** [medium] | process-patterns — Expand `ScanEngine.detectKind` to recognise vite (dev server), bun (runtime), and bare node processes; assign risk tiers (vite/bun = npm-tier, node = high); add `ProcessKind` cases and labels.
  - [ ] **PID-13.4** [light] | app-description — Update `README.md` with a sharper tagline and feature summary reflecting the shipped feature set; review and improve stale or generic in-app copy.
  - [ ] **PID-13.5** [medium] | notifications — Add `UserNotifications` support: fire a macOS system notification when a scan surfaces new stray processes not in the previous result; add an opt-in toggle in `SettingsView`.
  - [ ] **PID-13.6** [medium] | audit — Final-subtask audit per SPEC/epic.md (fixed doc-drift sweep acceptance line). Filed at filing time as highest .N child.

## Low

- [x] **PID-010** [light] | auto-start — Completed 2026-06-24.

## Future Opportunities

- XPC service / `launchd` plist for background scanning (no app in foreground required)
- Docker / container management panel
- JSON override file for port registry (user-editable, loaded at startup)
- Animated icon states beyond simple badge

## Completed

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
