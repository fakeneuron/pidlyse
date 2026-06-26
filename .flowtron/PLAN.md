# Pidly — PLAN.md

## Vision

Pidly is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

(none)

## Medium

(none)

## Low

- [ ] **PID-025** [medium]🧠 | port-registry-json — Load a user-editable JSON file at startup to override/extend the built-in port registry, merged with compiled defaults — also resolves the manual CLAUDE.md↔PortRegistry.swift sync burden flagged in audit-repo 2026-06-24.
- [ ] **PID-EPIC-27** [heavy]🧠 | xpc-background-scan — Background scanning via an XPC service + `launchd` plist so scans run with no app in the foreground. Epic shell — run `/ft-epic-discovery` to break into children (entitlements research, XPC target, launchd plist, scan wiring, settings toggle).
- [ ] **PID-EPIC-28** [heavy]🧠 | docker-panel — Docker/container management panel: list running containers with stop/remove actions, building on `KillService`'s existing docker paths. Epic shell — run `/ft-epic-discovery` to break into children.

## Future Opportunities

(none)

## Completed

- [x] **PID-026** [light]🔧 | animated-icon — Completed 2026-06-26.
- [x] **PID-024** [light]🔧 | tty-sentinel-ssot — Completed 2026-06-26.
- [x] **PID-023** [medium]🧠 | right-click-menu — Completed 2026-06-25.
- [x] **PID-022** [light]🔧 | settings-open — Completed 2026-06-25.
- [x] **PID-021** [light]🔧 | collapsible-sections — Completed 2026-06-25.
- [x] **PID-EPIC-20** [medium]🧠 | dmg-release — Completed 2026-06-25.
  - [x] **PID-20.1** [medium]🧠 | discovery — Completed 2026-06-25.
  - [x] **PID-20.2** [light]🔧 | build-install — Completed 2026-06-25.
  - [x] **PID-20.3** [light]🔧 | dmg-package — Completed 2026-06-25.
  - [x] **PID-20.4** [light]🔧 | release-ci — Completed 2026-06-25.
  - [x] **PID-20.N** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-19** [light]🔧 | repo-hygiene — Completed 2026-06-25.
  - [x] **PID-19.2** [light]🔧 | gitignore — Completed 2026-06-25.
  - [x] **PID-19.3** [light]🔧 | spec-drift — Completed 2026-06-25.
  - [x] **PID-19.N** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-18** [medium]🧠 | correctness — Completed 2026-06-25.
  - [x] **PID-18.2** [light]🔧 | init-notifications — Completed 2026-06-25.
  - [x] **PID-18.3** [medium]🧠 | kill-pidreuse — Completed 2026-06-25.
  - [x] **PID-18.4** [light]🔧 | listeningpids-tests — Completed 2026-06-25.
  - [x] **PID-18.5** [light]🔧 | portregistry-tripwire — Completed 2026-06-25.
  - [x] **PID-18.N** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-17** [light]🔧 | ci-gates — Completed 2026-06-25.
  - [x] **PID-17.2** [light]🔧 | makefile-test — Completed 2026-06-25.
  - [x] **PID-17.3** [light]🔧 | ci-actions — Completed 2026-06-25.
  - [x] **PID-17.N** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-16** [light]🔧 | code-quality — Completed 2026-06-24.
  - [x] **PID-16.1** [light]🔧 | discovery — Completed 2026-06-24.
  - [x] **PID-16.2** [light]🔧 | shellout-helper — Completed 2026-06-24.
  - [x] **PID-16.3** [light]🔧 | makeitem-alloc — Completed 2026-06-24.
  - [x] **PID-16.4** [light]🔧 | scanengine-persistence — Completed 2026-06-24.
  - [x] **PID-16.5** [light]🔧 | audit — Completed 2026-06-24.
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
