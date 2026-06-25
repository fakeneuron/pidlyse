---
title: dmg-release audit
status: in-progress
tags: []
created: 2026-06-25
due:
related-tasks: [PID-EPIC-20, PID-20.1, PID-20.2, PID-20.3, PID-20.4]
---

# PID-20.N | dmg-release audit

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-20]]

## 🎯 Goal

Verify the completed `PID-EPIC-20` (`dmg-release`) cohort sits coherently in the codebase: cumulative doc-drift sweep across `.flowtron/tasknote/README.md` §"AI-referenced docs", naming/style consistency across the cohort's deliverables, and follow-up filings for any miss.

## ✅ Acceptance

- [ ] **Doc-drift sweep (fixed line, per SPEC/epic.md §"Audit acceptance — fixed doc-drift line")** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs", state "no change" or the specific update. Always present; surfaces cumulative slice-local staleness that per-task Phase 4 closures can miss.
- [ ] Cohort coherence inventory: each implementation child's deliverables read against the others (naming consistency, style parity, no contradictory cross-refs)
- [ ] No regressions surfaced in earlier-shipped cohort children's surfaces
- [ ] Audit findings recorded in Implementation Notes; misses cited as candidates for `/ft-file-followup <NEW-ID>` filing (filed AFTER audit closure to preserve `/ft-file-followup`'s filing-discipline gate)
- [ ] Single `feat: PID-20.N — audit PID-EPIC-20` (or `chore: ...` if no code edits land) commit lands
- [ ] PLAN.md line for `PID-20.N` flipped to stub form `Completed YYYY-MM-DD.`
- [ ] Tasknote moved to `.flowtron/tasknote/archive/pid/PID-20.N.md`
- [ ] Parent-flip prompt surfaced after audit closure (skill Step 8) — user confirms or declines flipping `PID-EPIC-20` to `Completed` and moving the cohort to `## Completed`

## 🧩 Subtasks

- [ ] Inventory cohort children's archived tasknotes — read each implementation child's Final Summary + Implementation Notes; capture deliverables in Discovery Notes
- [ ] Walk `.flowtron/tasknote/README.md` §"AI-referenced docs" entries — fixed doc-drift sweep
- [ ] Cohort coherence pass — naming consistency, style parity, no contradictory cross-refs across the cohort's deliverables
- [ ] Surface audit findings in Implementation Notes; cite each miss as a `/ft-file-followup <NEW-ID>` candidate
- [ ] Phase 4: flip `PID-20.N` PLAN line to stub form + archive tasknote
- [ ] Parent-flip: skill Step 8 prompts user; on confirm, atomic flip parent line + move cohort to `## Completed`

## 🔗 Related

- [[PID-EPIC-20]] — parent epic: dmg-release
- [[PID-20.1]] — discovery
- [[PID-20.2]] — build-install
- [[PID-20.3]] — dmg-package
- [[PID-20.4]] — release-ci

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** User explicitly invoked `/ft-close-epic PID-20.N`. All four implementation children (`PID-20.1`–`PID-20.4`) are `[x]` closed. Audit cohort state at closure: `.1` discovery (2026-06-25), `.2` build-install (2026-06-25), `.3` dmg-package (2026-06-25), `.4` release-ci (2026-06-25). No early-audit concern — all siblings closed.

- [x] Read relevant source files — read all four cohort archived tasknotes (`PID-20.1`–`PID-20.4`). Also confirmed deliverables at HEAD: `Makefile`, `.github/workflows/release.yml`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `.flowtron/tasknote/README.md`.

- [x] **Archive skim** — cohort children are the archive entries (`.1`–`.4` all under `archive/pid/`). Grepped non-cohort `archive/pid/` entries for "Makefile", "dmg", "release", "hdiutil" — no non-cohort hits. PID-17.3 (`ci-actions`, test.yml pattern) and PID-19.N (prior audit) provide surrounding context; no conflicts.

- [x] **Drift check** — all paths confirmed at HEAD:
  - `Makefile`: `.PHONY: test build-release install dmg`; all four targets present and matching tasknote descriptions ✅
  - `.github/workflows/release.yml`: exists, 23 lines, `on: push: tags: ['v*']`, `permissions: contents: write`, `make build-release` + `make dmg` + `gh release create` ✅
  - `README.md` line 29: mentions `make build-release`, `make install`, `make dmg`, and `v*` tag release workflow ✅
  - `CLAUDE.md` Build section: `make build-release`, `make install`, `make dmg` all present ✅
  - `.flowtron/tasknote/README.md` Project quick commands: `make build-release` and `make dmg` lines present ✅

- [x] Asked clarifying questions OR logged "No clarifications needed" with explicit assumptions

  No clarifications needed. Zero structured asks fired.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- **PID-20.1 (discovery):** Filed 3 implementation children. Scoping decisions: ad-hoc signing (no Developer ID), no notarization, `hdiutil` for DMG (no external deps), GitHub Actions on `v*` tags using `gh release create`. No downstream-plan impact.
- **PID-20.2 (build-install):** Added `make build-release` (`xcodebuild` Release, `CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual SYMROOT=$(CURDIR)/build` → `build/Release/Pidly.app`) and `make install` (`ditto` to `/Applications/Pidly.app`). Verified: 51 tests passing. Updated README.md, CLAUDE.md, tasknote README.
- **PID-20.3 (dmg-package):** Added `make dmg`: staging dir → copy app → `/Applications` symlink → `hdiutil create -format UDZO` → cleanup. Output: `build/Pidly.dmg` (281 KB). Verified: mounts correctly, 51 tests passing. Updated README.md, CLAUDE.md, tasknote README.
- **PID-20.4 (release-ci):** Added `.github/workflows/release.yml` (23 lines): `on: push: tags: ['v*']`, `permissions: contents: write`, `macos-latest`, `actions/checkout@v4`, `make build-release` → `make dmg` → `gh release create "${{ github.ref_name }}" build/Pidly.dmg`. Updated README.md.

✅ Phase 1 Discovery complete; entering Phase 2 Execution.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — N/A; audit is a verification pass, no new code surface.

- [x] Implemented the minimal solution — cohort coherence verified (see Implementation Notes). No inline fixes required.

- [x] Updated/added tests — N/A (no code edits landed).

**Implementation Notes:**

- **Cohort children inventoried:** `.1` filed children + resolved scoping decisions; `.2` added `build-release`/`install` Makefile targets; `.3` added `dmg` Makefile target; `.4` added `.github/workflows/release.yml`.
- **Coherence findings:**
  - Naming consistency: `build/Release/Pidly.app` (`.2` output) consumed correctly by `.3`'s `cp -R` and `.4`'s `make build-release` step ✅
  - `build/Pidly.dmg` (`.3` output) consumed correctly by `.4`'s `gh release create` ✅
  - Makefile style parity: all targets follow `.PHONY`-extension + comment + command pattern established in PID-17.2 ✅
  - `release.yml` mirrors `test.yml` pattern (PID-17.3): `macos-latest`, `actions/checkout@v4`, native `make` invocations, no third-party actions ✅
  - No contradictory cross-refs across cohort ✅
- **Regressions:** None surfaced — `.2` verified 51 tests passing; `.3` re-verified same; `.4` is YAML-only with no Swift changes.
- **Misses / follow-up candidates:** None identified. Distribution scope (ad-hoc signed, personal use + GitHub Releases) is fully delivered. Future Opportunities entries (XPC, Docker panel, JSON port registry, animated icons, TTY sentinel) are unchanged and orthogonal to this cohort.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (audit with no code edits)

- [x] Ran lint/type-check on changed code — N/A (no compilable changes)

- [x] (frontend) Asked the user for visual confirmation — N/A (no UI change)

**Testing Notes:**

Markdown verification pass only — no executable surface changed by the audit.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — for each entry in `.flowtron/tasknote/README.md` §"AI-referenced docs":
  - `README.md` — no change (updated during cohort: `make build-release`, `make install`, `make dmg`, `v*` tag release workflow all documented on line 29)
  - `AGENTS.md` — no change
  - `CLAUDE.md` — no change (updated during cohort: Build section has `make build-release`, `make install`, `make dmg`)
  - `.flowtron/PLAN.md` — will update (PID-20.N flipped to stub form; parent cohort moved to `## Completed` on user confirmation)

- [ ] Closed — PLAN.md line flipped to stub form `Completed 2026-06-25.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [ ] Recap drafted (surfaces at the 📦 ready-to-commit gate, or inline on conditional skip)

**Final Summary:**

Audit ran against the full PID-EPIC-20 (`dmg-release`) cohort (`.1`–`.4`). All deliverables confirmed at HEAD: `make build-release`, `make install`, `make dmg` in Makefile; `.github/workflows/release.yml` on `v*` tags. Cohort is coherent — naming, style parity, and cross-refs all consistent. No regressions, no misses; no follow-up filings required.

**Archived:** 2026-06-25
