---
title: dmg-release discovery
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-20]
---

# PID-20.1 | dmg-release discovery

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-20]]

## 🎯 Goal

Scope the `PID-EPIC-20` epic (`dmg-release`) before any implementation child fires; deliverable = filed concrete child scopes for `PID-20.2..PID-20.4` in `.flowtron/PLAN.md`.

## ✅ Acceptance

- [ ] Shared design surface inventoried for the epic (Xcode project structure, signing config, process-inspection entitlements, build toolchain) — captured in Discovery Notes
- [ ] Open scoping questions resolved with the user via AskUserQuestion — captured in a "Resolved scoping" table in Discovery Notes
- [ ] Concrete child scopes for `PID-20.2` .. `PID-20.4` filed in `.flowtron/PLAN.md` (each line under the 50w target / 70w hard cap per SPEC/tasknote-selection.md §"PLAN.md filing-discipline thresholds")
- [ ] Audit line `PID-20.N` reviewed and confirmed as-filed (or rewritten if the Discovery surfaces a scope shift)
- [ ] Phase 4 doc-drift sweep at closure: typically no AI-referenced doc updates land in pure Discovery filing (contract edits land inside the implementation children)

## 🧩 Subtasks

- [ ] Inventory shared design surface (Xcode project, Info.plist, existing entitlements, build scripts, CI config) — log in Discovery Notes
- [ ] Skim `.flowtron/tasknote/archive/PID/` for relevant precedents — log load-bearing findings in Discovery Notes
- [ ] Drift check on cited paths and concepts — flag any drift before re-interpreting the epic
- [ ] Surface open scoping questions via AskUserQuestion (signing identity availability, sandbox vs. hardened-runtime, DMG vs. zip, Homebrew Cask, CI vs. manual release) — record answers in a "Resolved scoping" table
- [ ] Draft refined long descriptions for `PID-20.2` .. `PID-20.4`; word-count each (≤50w target / 70w hard cap)
- [ ] Phase 2: write the drafted child lines into `.flowtron/PLAN.md` under `PID-EPIC-20` with 2-space indent
- [ ] Phase 3: markdown mental-pass on the PLAN.md edits (grammar / indent / cross-refs)
- [ ] Phase 4: doc-drift sweep + flip `.1` PLAN line to stub form + archive tasknote

## 🔗 Related

- [[PID-EPIC-20]] — parent epic: dmg-release

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-epic-discovery` to scope a distribution workflow for Pidly. No existing distribution config in the project — exactly the gap this epic addresses.

- [x] Read relevant source files — read `Info.plist`, `Makefile`, `Pidly.xcscheme`, `project.pbxproj` (signing settings). Key state captured in Discovery Notes.

- [x] **Archive skim** — no prior PID tasknote touched signing, DMG creation, or distribution. `grep -l` across `archive/PID/*.md` for "sign", "dmg", "notari", "release" returned no hits. No load-bearing prior context.

- [x] **Drift check** — all referenced paths confirmed at HEAD (`Pidly/Info.plist`, `Makefile`, `Pidly.xcodeproj/xcshareddata/xcschemes/Pidly.xcscheme`). No drift.

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  **Resolved scoping:**

  | Question | Answer |
  |---|---|
  | Apple Developer ID? | No — ad-hoc signed. No notarization. Other-Mac users bypass GateKeeper via right-click → Open or `xattr -dr com.apple.quarantine Pidly.app`. |
  | Primary use case | Personal/local install on own Mac (immediate goal). GitHub Releases + fakeneuron.com secondary. |
  | Distribution channels | GitHub Releases + fakeneuron.com. No Homebrew Cask for now. |
  | CI automation | Yes — GitHub Actions workflow on `v*` tag push. |
  | App Sandbox? | No sandbox. Ad-hoc signing with no sandbox. `sysctl`/process-enum require unrestricted process access; sandbox would break core functionality. |

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **Current signing state:** `CODE_SIGN_STYLE = Automatic` but no `DEVELOPMENT_TEAM` set in `project.pbxproj`. The project cannot produce a distributable build without additional config. Ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) will work for personal use and GitHub Releases.
- **Info.plist:** `LSUIElement = true` (menu bar only, correct). `PRODUCT_BUNDLE_IDENTIFIER = com.fakeneuron.pidly`. `MARKETING_VERSION = 1.0` / `CURRENT_PROJECT_VERSION = 1` — v1.0 ready.
- **Scheme:** `ArchiveAction buildConfiguration = "Release"` already wired. Xcode can Archive today; we just need a scripted export + DMG creation step.
- **No entitlements file:** Not needed for ad-hoc signing or personal use. If a Developer ID is added later, a minimal entitlements file would be required for hardened runtime.
- **Makefile:** Single `test` target only. Needs `build-release`, `install`, and `dmg` targets.
- **CI:** `test.yml` exists from PID-17 epic. A `release.yml` on `v*` tags is the natural extension.
- **DMG approach:** Use `hdiutil` (built-in macOS) for a simple DMG. No `create-dmg` dependency needed for a personal/GitHub Releases distribution. Can add a background image later.
- **Child scope (N=5 confirmed):**
  - `.2 build-install` — `make build-release` + `make install` Makefile targets (ad-hoc sign, copy to `/Applications`)
  - `.3 dmg-package` — `make dmg` using `hdiutil` to produce an ad-hoc-signed DMG artifact
  - `.4 release-ci` — GitHub Actions `release.yml` on `v*` tags: build Release → package DMG → attach to GitHub Release via `gh release upload`

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — existing `test.yml` CI workflow (PID-17 epic) is the closest precedent for the release CI child. Makefile `test` target is the pattern for new Makefile targets. `hdiutil create` is the built-in macOS DMG approach (no external dependency).

- [x] Implemented the minimal solution — filed `.2..4` child lines in PLAN.md under `PID-EPIC-20`. Word counts: .2 = 22w, .3 = 25w, .4 = 25w (all within 50w target). `.1` stub-flipped to `[x] Completed 2026-06-25.` in the same edit.

- [x] Updated/added tests — N/A (pure PLAN.md filing; no executable code surface).

**Implementation Notes:**

- Lines filed: 3 implementation children (`PID-20.2..4`) nested under `PID-EPIC-20` with 2-space indent, `[light]🔧` model tag, em-dash separator, descriptions within target word count.
- N=5 confirmed (Discovery + 3 impl + Audit). No audit-number bump needed.
- Downstream-impact scan: Future Opportunities entries (XPC, Docker panel, JSON port registry, animated icons, TTY sentinel) share no surface with the distribution tooling children — no downstream impact, no reconcile edits needed.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (PLAN.md filing only)

- [x] Ran lint/type-check on changed code — N/A (no compilable changes)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

Markdown mental-pass on PLAN.md edits:
- 2-space child indent preserved on all three new lines ✓
- `**PID-20.2**`, `**PID-20.3**`, `**PID-20.4**` bold IDs intact ✓
- `[light]🔧` model tag on every new line ✓
- `| <shortname>` segments present and under 30 chars ✓
- Em-dash separator (` — `) consistent ✓
- Long descriptions all within 50w target ✓
- No trailing whitespace ✓

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the update
  - `README.md` — no change (Discovery filing adds no user-facing feature)
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change
  - `.flowtron/PLAN.md` — updated (epic filed + .1 stub-flipped + .2..4 children written)

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/PID/`

- [x] Recap drafted (inline on conditional skip)

**Final Summary:**

Filed `PID-EPIC-20` (`dmg-release`) with three implementation children scoped from Discovery: `.2 build-install` (Makefile targets for Release build + `/Applications` copy), `.3 dmg-package` (hdiutil DMG creation), `.4 release-ci` (GitHub Actions on `v*` tags). Ad-hoc signing, no Developer ID required; primary use case is personal local install with GitHub Releases as secondary. No downstream plan impact surfaced.

**Archived:** 2026-06-25
