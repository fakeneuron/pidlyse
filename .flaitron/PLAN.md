# Pidlyse — PLAN.md

## Vision

Pidlyse is a native macOS menu bar app (Swift + SwiftUI, M-series) that scans for stray and zombie processes — orphaned test runners, playwright-mcp instances, zombie Chrome helpers — and surfaces them with a badge count. One click expands a tray UI that leads with the likely strays, grouped by why each reads as stray, with in-use processes folded away and a per-row kill plus a bounded "Clean all". The goal is to replace the manual `ps aux | grep` ritual with a permanent, low-friction process hygiene tool that lives beside the clock.

See [`SPEC.md`](../SPEC.md) for the canonical workflow contract.

## High

(none)

## Medium

(none)

## Low

- [ ] **PID-090** [medium] | port-scan-fail-open — The port-bound sweep exclusion fails open: when the registered-port `lsof` times out the listener map is empty, so port-bound strays are swept again. Surface a port-data-unavailable signal and decide whether it blocks the sweep. From [[PID-088]] review.
- [ ] **PID-091** [light] | spaced-display-path — `ProcessItem.displayPath` takes the first space-split token of `command`, so a path containing a space shows as a fragment in the inspector and provenance. Read the scan-time `ProcessItem.argv` (added by [[PID-087]]) instead. From [[PID-087]] Discovery.
- [ ] **PID-092** [light] | readme-screenshots — Re-record `docs/screenshots/popover.png` and `clean-all.gif`: both date from 2026-07-03 and show the pre-[[PID-EPIC-086]] popover (PID-titled rows, kind groups, a Needs review section). Operator-recorded; refresh the alt text if the framing changes. From [[PID-086.N]] audit.

## Future Opportunities

- **PID-030** [medium]🧠 | notarize-and-sign — Replace ad-hoc signing with Developer ID + Apple notarization + stapling (and the Hardened Runtime entitlement notarization requires). Removes the Gatekeeper "Apple could not verify…" warning on the public download. **Deferred 2026-06-28** — gated on $99/yr Apple Developer Program enrollment (operator opted to defer). Until then the public-trust story rests on the public source + SHA-256 checksum (shipped via `make dmg` + release.yml) + the honest right-click→Open install note in the README "Security" section. (Confirmed home for the no-sandbox / Hardened-Runtime posture by the [[PID-EPIC-35]] security sweep — F3/F4 folded here, no duplicate child filed.)

## Completed

- [x] **PID-EPIC-086** [heavy]🧠 | stray-utility-ux — Completed 2026-10-17.
  - [x] **PID-086.1** [frontier]💎 | stray-utility-ux discovery — Completed 2026-10-15.
  - [x] **PID-086.2** [heavy]🧠 | stray-verdict-core — Completed 2026-10-16.
  - [x] **PID-086.3** [medium]🧩 | row-identity — Completed 2026-10-17.
  - [x] **PID-086.4** [medium]🧩 | stray-first-popover — Completed 2026-10-17.
  - [x] **PID-086.5** [light]🔧 | cli-stray-parity — Completed 2026-10-17.
  - [x] **PID-086.N** [heavy]🧠 | stray-utility-ux audit — Completed 2026-10-17.
- [x] **PID-089** [light] [unattended] | stray-reason-order — Completed 2026-10-17.
- [x] **PID-087** [light] [unattended] | spaced-path-names — Completed 2026-10-17.
- [x] **PID-088** [light] [unattended] | port-bound-sweep — Completed 2026-10-17.
- [x] **PID-EPIC-079** [heavy]🧠 | consumer-seams — Completed 2026-10-15.
  - [x] **PID-079.2** [light]🔧 | clean-log-merge-on-write — Completed 2026-10-08.
  - [x] **PID-079.3** [medium]🧩 [unattended] | shell-run-timeout — Completed 2026-10-08.
  - [x] **PID-079.4** [light]🔧 [unattended] | scan-on-launch — Completed 2026-10-10.
  - [x] **PID-079.5** [light]🔧 [unattended] | cli-clean-exit-status — Completed 2026-10-10.
  - [x] **PID-079.6** [heavy]🧠 | shared-scan-pipeline — Completed 2026-10-15.
  - [x] **PID-079.7** [light]🔧 | settings-keys-in-core — Completed 2026-10-15.
  - [x] **PID-079.N** [heavy]🧠 | consumer-seams audit — Completed 2026-10-15.
- [x] **PID-EPIC-080** [light]🔧 | docs-plan-currency — Completed 2026-10-15.
  - [x] **PID-080.2** [light]🔧 [unattended] | readme-disk-footprint — Completed 2026-10-08.
  - [x] **PID-080.3** [light]🔧 [unattended] | plan-completed-rotation — Completed 2026-10-08.
  - [x] **PID-080.N** [light]🔧 | docs-plan-currency audit — Completed 2026-10-08.
- [x] **PID-EPIC-078** [heavy]🧠 | test-safety-net — Completed 2026-10-15.
  - [x] **PID-078.2** [medium]🧩 [unattended] | core-test-target — Completed 2026-10-08.
  - [x] **PID-078.3** [heavy]🧠 | engine-lifecycle-tests — Completed 2026-10-15.
  - [x] **PID-078.4** [light]🔧 | core-tests-per-type — Completed 2026-10-15.
  - [x] **PID-078.N** [medium]🧩 [unattended] | test-safety-net audit — Completed 2026-10-15.
- [x] **PID-085** [medium]🧩 [unattended] | clean-log-main-thread — Completed 2026-10-12.
- [x] **PID-084** [medium]🧩 [unattended] | clean-log-lock-hygiene — Completed 2026-10-12.
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

<!--
Task-line grammar (see .flaitron/core/SPEC.md §"Task-line format"):

  - [ ] **TASK-ID** [!critical] [model] | shortname — long description

All of `[!critical]`, `[model]`, and `| shortname` are optional.
-->
