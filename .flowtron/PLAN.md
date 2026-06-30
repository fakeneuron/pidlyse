# Pidlyse — PLAN.md

## Vision

Pidlyse is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

(none)

## Medium

## Low

## Future Opportunities

- **PID-030** [medium]🧠 | notarize-and-sign — Replace ad-hoc signing with Developer ID + Apple notarization + stapling (and the Hardened Runtime entitlement notarization requires). Removes the Gatekeeper "Apple could not verify…" warning on the public download. **Deferred 2026-06-28** — gated on $99/yr Apple Developer Program enrollment (operator opted to defer). Until then the public-trust story rests on the public source + SHA-256 checksum (shipped via `make dmg` + release.yml) + the honest right-click→Open install note in the README "Security" section. (Confirmed home for the no-sandbox / Hardened-Runtime posture by the [[PID-EPIC-35]] security sweep — F3/F4 folded here, no duplicate child filed.)
## Completed

- [x] **PID-041** [light]🔧 | onchange-deprecation — Completed 2026-06-29.
- [x] **PID-040** [medium]🧠 | popover-realign — Completed 2026-06-29.
- [x] **PID-039** [medium]🧠 | npm-surface-dedup — Completed 2026-06-29.
- [x] **PID-038** [medium]🧠 | cwd-provenance — Completed 2026-06-29.
- [x] **PID-EPIC-037** [medium]🧠 | docker-ownership-hint — Completed 2026-06-29.
  - [x] **PID-037.1** [medium]🧠 | discovery — Completed 2026-06-29.
  - [x] **PID-037.2** [medium]🧠 | owner-cache — Completed 2026-06-29.
  - [x] **PID-037.3** [medium]🧠 | ownership-ui — Completed 2026-06-29.
  - [x] **PID-037.4** [medium]🧠 | audit — Completed 2026-06-29.
- [x] **PID-EPIC-036** [medium]🧠 | process-provenance-hints — Completed 2026-06-29.
  - [x] **PID-036.1** [medium]🧠 | discovery — Completed 2026-06-28.
  - [x] **PID-036.2** [medium]🧠 | provenance-core — Completed 2026-06-28.
  - [x] **PID-036.3** [medium]🧠 | hints-ui — Completed 2026-06-28.
  - [x] **PID-036.4** [medium]🧠 | audit — Completed 2026-06-29.
- [x] **PID-EPIC-35** [heavy]🧠 | security-sweep — Completed 2026-06-28.
  - [x] **PID-35.1** [heavy]🧠 | discovery — Completed 2026-06-28.
  - [x] **PID-35.2** [medium]🔧 | stderr-drain — Completed 2026-06-28.
  - [x] **PID-35.3** [medium]🧠 | kill-path-hardening — Completed 2026-06-28.
  - [x] **PID-35.4** [light]🔧 | smells-cleanup — Completed 2026-06-28.
  - [x] **PID-35.5** [light]🔧 | ci-sha-pinning — Completed 2026-06-28.
  - [x] **PID-35.6** [heavy]🧠 | audit — Completed 2026-06-28.
- [x] **PID-EPIC-34** [light]🔧 | doc-hygiene — Completed 2026-06-28. Surfaced by audit-repo 2026-06-28 (Theme: Docs lag the last refactor wave).
  - [x] **PID-34.2** [light]🔧 | spec-structure-refresh — Completed 2026-06-28.
  - [x] **PID-34.3** [light]🔧 | settings-scene-comment — Completed 2026-06-28.
  - [x] **PID-34.4** [light]🔧 | worktree-hygiene — Completed 2026-06-28.
  - [x] **PID-34.N** [light]🔧 | audit — Completed 2026-06-28.
- [x] **PID-031** [light]🔧 | public-download-page — Completed 2026-06-28.
- [x] **PID-033** [light]🔧 | doc-footprint-accuracy — Completed 2026-06-28.
- [x] **PID-032** [medium]🔧 | settings-wont-open — Completed 2026-06-28.
- [x] **PID-EPIC-28** [heavy]🧠 | docker-panel — Completed 2026-06-26.
  - [x] **PID-28.1** [medium]🧠 | discovery — Completed 2026-06-26.
  - [x] **PID-28.2** [medium]🔧 | docker-service — Completed 2026-06-26.
  - [x] **PID-28.3** [light]🔧 | container-actions — Completed 2026-06-26.
  - [x] **PID-28.4** [medium]🧠 | container-panel-ui — Completed 2026-06-26.
  - [x] **PID-28.5** [medium]🔧 | audit — Completed 2026-06-26.
- [x] **PID-029** [medium]🔧 | drop-background-helper — Completed 2026-06-26.
- [x] **PID-EPIC-27** [heavy]🧠 | xpc-background-scan — Abandoned 2026-06-26 — background scanning dropped (a background component felt too intrusive; Pidlyse stays a simple foreground-only menu-bar scanner). `.2` PidlyseCore extraction kept as a benign refactor; `.3`/`.4` machinery removed in [[PID-029]].
  - [x] **PID-27.1** [heavy]🧠 | discovery — Completed 2026-06-26.
  - [x] **PID-27.2** [medium]🧠 | shared-scan-core — Completed 2026-06-26.
  - [x] **PID-27.3** [heavy]🧠 | helper-target — Completed 2026-06-26.
  - [x] **PID-27.4** [medium]🔧 | launchd-registration — Completed 2026-06-26.
  - [x] **PID-27.5** [heavy]🧠 | notify-and-handoff — De-scoped 2026-06-26 — background component dropped; teardown filed as [[PID-029]].
  - [x] **PID-27.6** [medium]🧠 | settings-and-signing — Won't do — EPIC-27 abandoned 2026-06-26.
  - [x] **PID-27.7** [medium]🧠 | audit — Won't do — EPIC-27 abandoned 2026-06-26.
- [x] **PID-025** [medium]🧠 | port-registry-json — Completed 2026-06-26.
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
