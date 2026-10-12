# Pidlyse — PLAN.md

## Vision

Pidlyse is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI with categorised candidates, kill buttons for safe ones, and a "needs review" section for anything tied to a registered port or recently started. The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

- [ ] **PID-EPIC-078** [heavy]🧠 | test-safety-net — Make app-side lifecycle change safe before PID-EPIC-079 touches it. Discovery supplied by audit-repo 2026-10-07. Surfaced by audit-repo 2026-10-07 (Theme: Lifecycle edges are untested)
  - [x] **PID-078.2** [medium]🧩 [unattended] | core-test-target — Completed 2026-10-08.
  - [ ] **PID-078.3** [heavy]🧠 | engine-lifecycle-tests — Make ScanEngine's scan inputs injectable (enumerate closure + defaults suite) and cover rescan queueing, dismissal re-application, kill-token linger/clear, and the isSweepable fold.
  - [ ] **PID-078.N** [medium]🧩 [unattended] | test-safety-net audit

## Medium

- [ ] **PID-EPIC-079** [heavy]🧠 | consumer-seams — Close the app↔CLI and app↔subprocess seams where state is lost or the scan loop can wedge. Discovery supplied by audit-repo 2026-10-07. Surfaced by audit-repo 2026-10-07 (Theme: Two consumers, one truth)
  - [x] **PID-079.2** [light]🔧 | clean-log-merge-on-write — Completed 2026-10-08.
  - [x] **PID-079.3** [medium]🧩 [unattended] | shell-run-timeout — Completed 2026-10-08.
  - [x] **PID-079.4** [light]🔧 [unattended] | scan-on-launch — Completed 2026-10-10.
  - [x] **PID-079.5** [light]🔧 [unattended] | cli-clean-exit-status — Completed 2026-10-10.
  - [ ] **PID-079.6** [heavy]🧠 | shared-scan-pipeline — Lift the scan pipeline, protected/sweep predicate, and CleanEvent(item:cwd:) into PidlyseCore so ScanEngine and PidlyseCLI each make one call; update the AGENTS.md convention lines that say "keep the two pipelines in step".
  - [ ] **PID-079.N** [heavy]🧠 | consumer-seams audit
- [ ] **PID-EPIC-080** [light]🔧 | docs-plan-currency — Bring README trust claims and PLAN.md bookkeeping back in line with the code. Discovery supplied by audit-repo 2026-10-07. Surfaced by audit-repo 2026-10-07 (Theme: Docs and plan currency)
  - [x] **PID-080.2** [light]🔧 [unattended] | readme-disk-footprint — Completed 2026-10-08.
  - [x] **PID-080.3** [light]🔧 [unattended] | plan-completed-rotation — Completed 2026-10-08.
  - [x] **PID-080.N** [light]🔧 | docs-plan-currency audit — Completed 2026-10-08.

## Low

- [ ] **PID-084** [medium]🧩 [unattended] | clean-log-lock-hygiene — CleanLogFile.append blocks the caller on flock, and the app calls it on the main thread from the kill callback, so a peer stuck in the lock stalls the UI. Open the lock fd with O_CLOEXEC so a Shell.run during the critical section cannot inherit it. Surfaced by the PID-082 review.

## Future Opportunities

- **PID-030** [medium]🧠 | notarize-and-sign — Replace ad-hoc signing with Developer ID + Apple notarization + stapling (and the Hardened Runtime entitlement notarization requires). Removes the Gatekeeper "Apple could not verify…" warning on the public download. **Deferred 2026-06-28** — gated on $99/yr Apple Developer Program enrollment (operator opted to defer). Until then the public-trust story rests on the public source + SHA-256 checksum (shipped via `make dmg` + release.yml) + the honest right-click→Open install note in the README "Security" section. (Confirmed home for the no-sandbox / Hardened-Runtime posture by the [[PID-EPIC-35]] security sweep — F3/F4 folded here, no duplicate child filed.)

## Completed

- [x] **PID-082** [medium]🧩 [unattended] | clean-log-append-lock — Completed 2026-10-12.
- [x] **PID-081** [light]🔧 [unattended] | coverage-follows-core-tests — Completed 2026-10-12.
- [x] **PID-063** [medium]🧠 | docker-scope-trim — Completed 2026-10-07.
- [x] **PID-076** [light] [unattended] | ci-build-cli — Completed 2026-10-07.
- [x] **PID-074** [medium] [unattended] | checkout-action-floor — Completed 2026-10-07.
- [x] **PID-075** [medium] | port-registry-sync — Completed 2026-10-07.
- [x] **PID-077** [light] | docs-layering — Completed 2026-10-07.
- [x] **PID-083** [medium] | flaitron rename review — Completed 2026-10-05.
- [x] **PID-073** [light] | inspector-ppid-grouping — Completed 2026-09-25.
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

<!--
Task-line grammar (see .flaitron/core/SPEC.md §"Task-line format"):

  - [ ] **TASK-ID** [!critical] [model] | shortname — long description

All of `[!critical]`, `[model]`, and `| shortname` are optional.
-->
