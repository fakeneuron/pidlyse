# Pidly — PLAN.md

## Vision

Pidly is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

- [x] **PID-004** [medium] | kill-hardening — Completed 2026-06-24.
- [x] **PID-005** [medium] | port-registry — Completed 2026-06-24.
- [ ] **PID-006** [medium] | polish — Icon states (outline / filled / spinner), badge colours (red safe-count / yellow review-only), scan timer, Settings panel (interval, elapsed threshold, ignored PIDs).

## Medium

- [ ] **PID-007** [light] | dismiss-snooze — "Ignore for session" per PID (snoozes until app restart, no kill). Dismiss button in popover row.
- [ ] **PID-008** [light] | why-reasoning — "Why is this here?" expander per row — inline classification reasoning (which criteria fired, elapsed time, TTY status, parent PID).

## Low

- [ ] **PID-010** [light] | auto-start — `SMAppService` login-item registration. Off by default, toggleable in Settings.

## Future Opportunities

- XPC service / `launchd` plist for background scanning (no app in foreground required)
- Docker / container management panel
- JSON override file for port registry (user-editable, loaded at startup)
- Animated icon states beyond simple badge

## Completed

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
