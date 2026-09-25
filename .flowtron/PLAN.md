# Pidlyse — PLAN.md

## Vision

Pidlyse is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

(none)

## Medium

(none)

## Low

- [ ] **PID-073** [light] | inspector-ppid-grouping — Expanded-row `Text("tty · ppid \(item.ppid) · age…")` interpolates ppid inside a Text literal, same locale-grouping bug PID-070 fixed for the visible PID. Fix with `Text(verbatim:)`.
## Future Opportunities

- **PID-030** [medium]🧠 | notarize-and-sign — Replace ad-hoc signing with Developer ID + Apple notarization + stapling (and the Hardened Runtime entitlement notarization requires). Removes the Gatekeeper "Apple could not verify…" warning on the public download. **Deferred 2026-06-28** — gated on $99/yr Apple Developer Program enrollment (operator opted to defer). Until then the public-trust story rests on the public source + SHA-256 checksum (shipped via `make dmg` + release.yml) + the honest right-click→Open install note in the README "Security" section. (Confirmed home for the no-sandbox / Hardened-Runtime posture by the [[PID-EPIC-35]] security sweep — F3/F4 folded here, no duplicate child filed.)
- [ ] **PID-063** [medium]🧠 | docker-scope-trim — Explore trimming docker/container surfaces to metrics-only (or dropping them): operator kills containers via Docker Desktop, not Pidlyse; weigh value for other users. Parked from [[PID-62.1]].

## Completed

- [x] **PID-069** [medium]🧠 | respawn-per-identity-watches — Completed 2026-09-25.
- [x] **PID-070** [light]🔧 | row-layout-legibility — Completed 2026-09-25.
- [x] **PID-064** [light]🔧 | gitleaks-ci-step — Completed 2026-09-24.
- [x] **PID-66** [light]🔧 | ci-spine-shape — Completed 2026-09-24.
- [x] **PID-072** [light]🔧 | shell-snapshot-misclassify — Completed 2026-09-24.
- [x] **PID-071** [medium]🧠 | isolated-chrome-helper-detection — Completed 2026-09-24.
- [x] **PID-EPIC-62** [heavy]🧠 | killability-truth — Completed 2026-09-24.
  - [x] **PID-62.1** [heavy]🧠 | killability-truth discovery — Completed 2026-08-08.
  - [x] **PID-62.2** [heavy]🧠 | respawn-detection-core — Completed 2026-08-08.
  - [x] **PID-62.3** [medium]🧠 | honest-unkillable-ux — Completed 2026-09-23.
  - [x] **PID-62.4** [medium]🧠 | tree-redundancy-collapse — Completed 2026-09-23.
  - [x] **PID-62.5** [medium]🧠 | kill-feedback-stability — Completed 2026-09-24.
  - [x] **PID-62.N** [heavy]🧠 | killability-truth audit — Completed 2026-09-24.
- [x] **PID-65** [light]🔧 | quality-stack-gaps — Completed 2026-09-23.
- [x] **PID-67** [light]🔧 | typecheck-verb-missing — Completed 2026-09-23.
- [x] **PID-068** [light] | brand-kit-back-port — Completed 2026-09-23.
- [x] **PID-060** [light]🔧 | readme-visuals — Completed 2026-07-03.
- [x] **PID-EPIC-58** [medium]🧠 | integrations — Completed 2026-07-02.
  - [x] **PID-58.1** [medium]🧠 | discovery — Completed 2026-07-02.
  - [x] **PID-58.2** [medium]🧠 | url-scheme — Completed 2026-07-02.
  - [x] **PID-58.3** [medium]🧠 | bridges — Completed 2026-07-02.
  - [x] **PID-58.4** [medium]🧠 | audit — Completed 2026-07-02.
- [x] **PID-EPIC-57** [heavy]🧠 | cli-companion — Completed 2026-07-02.
  - [x] **PID-57.1** [heavy]🧠 | cli-companion discovery — Completed 2026-07-02.
  - [x] **PID-57.2** [medium]🧠 | kill-core-extraction — Completed 2026-07-02.
  - [x] **PID-57.3** [medium]🧠 | cli-target — Completed 2026-07-02.
  - [x] **PID-57.4** [heavy]🧠 | audit — Completed 2026-07-02.
- [x] **PID-EPIC-56** [medium]🧠 | docker-enhance — Completed 2026-07-02.
  - [x] **PID-56.1** [medium]🧠 | discovery — Completed 2026-07-02.
  - [x] **PID-56.2** [medium]🧠 | container-stats — Completed 2026-07-02.
  - [x] **PID-56.3** [medium]🧠 | compose-grouping — Completed 2026-07-02.
  - [x] **PID-56.4** [light]🔧 | restart-action — Completed 2026-07-02.
  - [x] **PID-56.5** [medium]🧠 | audit — Completed 2026-07-02.
- [x] **PID-061** [light]🔧 | spec-doc-refresh — Completed 2026-07-02.
- [x] **PID-059** [light]🔧 | app-icon-wiring — Completed 2026-07-02.
- [x] **PID-EPIC-55** [medium]🧠 | idle-stray-signals — Completed 2026-07-02.
  - [x] **PID-55.1** [medium]🧠 | discovery — Completed 2026-07-02.
  - [x] **PID-55.2** [medium]🧠 | scan-history-cache — Completed 2026-07-02.
  - [x] **PID-55.3** [medium]🧠 | idle-dev-signal — Completed 2026-07-02.
  - [x] **PID-55.4** [medium]🧠 | audit — Completed 2026-07-02.
- [x] **PID-EPIC-54** [medium]🧠 | detection-rules — Completed 2026-07-01.
  - [x] **PID-54.1** [medium]🧠 | discovery — Completed 2026-07-01.
  - [x] **PID-54.2** [medium]🧠 | expand-builtin-kinds — Completed 2026-07-01.
  - [x] **PID-54.3** [medium]🧠 | custom-rules — Completed 2026-07-01.
  - [x] **PID-54.4** [medium]🧠 | protect-and-scope — Completed 2026-07-01.
  - [x] **PID-54.5** [medium]🧠 | audit — Completed 2026-07-01.
- [x] **PID-EPIC-53** [medium]🧠 | clean-history-stats — Completed 2026-07-01.
  - [x] **PID-53.1** [medium]🧠 | discovery — Completed 2026-06-30.
  - [x] **PID-53.2** [medium]🧠 | clean-log-store — Completed 2026-07-01.
  - [x] **PID-53.3** [medium]🧠 | cleaned-tab-stats — Completed 2026-07-01.
  - [x] **PID-53.4** [medium]🧠 | audit — Completed 2026-07-01.
- [x] **PID-EPIC-52** [medium]🧠 | process-inspector — Completed 2026-06-30.
  - [x] **PID-52.1** [medium]🧠 | discovery — Completed 2026-06-30.
  - [x] **PID-52.2** [medium]🧠 | inspector-shell — Completed 2026-06-30.
  - [x] **PID-52.3** [medium]🧠 | inspector-open-files — Completed 2026-06-30.
  - [x] **PID-52.4** [medium]🧠 | audit — Completed 2026-06-30.
- [x] **PID-051** [medium]🧠 | kill-rescan-flicker — Completed 2026-06-30. No-bug: `engine.scan()` replaces `items` atomically (no mid-scan clear); the momentary clear is real Chrome teardown/respawn churn across two scans, not a render flicker.
- [x] **PID-EPIC-50** [medium]🧠 | popover-power-ux — Completed 2026-06-30.
  - [x] **PID-50.1** [medium]🧠 | discovery — Completed 2026-06-30.
  - [x] **PID-50.2** [light]🔧 | row-context-menu — Completed 2026-06-30.
  - [x] **PID-50.3** [light]🔧 | provenance-sort — Completed 2026-06-30.
  - [x] **PID-50.4** [light]🔧 | reclaimable-footprint — Completed 2026-06-30.
  - [x] **PID-50.5** [medium]🧠 | quick-filter — Completed 2026-06-30.
  - [x] **PID-50.6** [medium]🧠 | per-kind-toggles — Completed 2026-06-30.
  - [x] **PID-50.7** [medium]🧠 | popover-keys-dismiss — Completed 2026-06-30.
  - [x] **PID-50.8** [medium]🧠 | audit — Completed 2026-06-30.
- [x] **PID-049** [medium]🧠 | ux-feature-survey — Completed 2026-06-30.
- [x] **PID-048** [light]🔧 | doc-currency-sweep — Completed 2026-06-30.
- [x] **PID-047** [light]🔧 | logo-provenance — Completed 2026-06-30.
- [x] **PID-046** [light]🔧 | node-bun-tokenboundary — Completed 2026-06-29.
- [x] **PID-045** [light]🔧 | set-toggle-ext — Completed 2026-06-29.
- [x] **PID-043** [light]🔧 | port-table-drift — Completed 2026-06-29.
- [x] **PID-044** [light]🔧 | listeningpids-collapse — Completed 2026-06-29.
- [x] **PID-042** [light]🔧 | shellout-dedup — Completed 2026-06-29.
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
  - [x] **PID-34.5** [light]🔧 | audit — Completed 2026-06-28.
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
  - [x] **PID-20.5** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-19** [light]🔧 | repo-hygiene — Completed 2026-06-25.
  - [x] **PID-19.2** [light]🔧 | gitignore — Completed 2026-06-25.
  - [x] **PID-19.3** [light]🔧 | spec-drift — Completed 2026-06-25.
  - [x] **PID-19.4** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-18** [medium]🧠 | correctness — Completed 2026-06-25.
  - [x] **PID-18.2** [light]🔧 | init-notifications — Completed 2026-06-25.
  - [x] **PID-18.3** [medium]🧠 | kill-pidreuse — Completed 2026-06-25.
  - [x] **PID-18.4** [light]🔧 | listeningpids-tests — Completed 2026-06-25.
  - [x] **PID-18.5** [light]🔧 | portregistry-tripwire — Completed 2026-06-25.
  - [x] **PID-18.6** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-17** [light]🔧 | ci-gates — Completed 2026-06-25.
  - [x] **PID-17.2** [light]🔧 | makefile-test — Completed 2026-06-25.
  - [x] **PID-17.3** [light]🔧 | ci-actions — Completed 2026-06-25.
  - [x] **PID-17.4** [light]🔧 | audit — Completed 2026-06-25.
- [x] **PID-EPIC-16** [light]🔧 | code-quality — Completed 2026-06-24.
  - [x] **PID-16.1** [light]🔧 | discovery — Completed 2026-06-24.
  - [x] **PID-16.2** [light]🔧 | shellout-helper — Completed 2026-06-24.
  - [x] **PID-16.3** [light]🔧 | makeitem-alloc — Completed 2026-06-24.
  - [x] **PID-16.4** [light]🔧 | scanengine-persistence — Completed 2026-06-24.
  - [x] **PID-16.5** [light]🔧 | audit — Completed 2026-06-24.
- [x] **PID-EPIC-15** [light]🔧 | doc-sync — Completed 2026-06-24.
  - [x] **PID-15.2** [light]🔧 | spec-settings — Completed 2026-06-24.
  - [x] **PID-15.3** [light]🔧 | tasknote-readme-cmds — Completed 2026-06-24.
  - [x] **PID-15.4** [light]🔧 | audit — Completed 2026-06-24.
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
