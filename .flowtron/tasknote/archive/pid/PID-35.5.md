---
title: ci-sha-pinning
status: in-progress
tags: []
created: 2026-06-28
due:
related-tasks: [PID-EPIC-35, PID-35.1]
---

# PID-35.5 | ci-sha-pinning

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-35]] [[PID-35.1]]

## 🎯 Goal

Pin `actions/checkout` to an immutable commit SHA (instead of the mutable `@v4` major tag) in both GitHub Actions workflows, closing supply-chain finding F5 from the PID-EPIC-35 security sweep.

## ✅ Acceptance

- [x] `.github/workflows/release.yml` pins `actions/checkout` to a full 40-char commit SHA with a `# vX.Y.Z` version comment
- [x] `.github/workflows/test.yml` pins `actions/checkout` to the same SHA + version comment
- [x] Pinned SHA is the commit `@v4` currently resolves to (behavior unchanged, only the tag-mutability risk removed)
- [x] No other `@vN` tag references remain in either workflow

## 🧩 Subtasks

- [x] Replace `actions/checkout@v4` → `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1` in `release.yml`
- [x] Same replacement in `test.yml`
- [x] Sanity-check: grep both files for any remaining `@v` mutable refs

## 🔗 Related

- [[PID-EPIC-35]] — parent security-sweep epic
- [[PID-35.1]] — discovery; F5 is the supply-chain finding this child closes

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** F5 from the security sweep is still open and accurate — both workflows pin `actions/checkout@v4`, a mutable major tag. Pinning to a commit SHA is the documented fix and standard supply-chain hardening.

- [x] Read relevant source files — `release.yml` (1 checkout ref, L15), `test.yml` (1 checkout ref, L11)

- [x] **Archive skim** — `archive/pid/` skim of CI-touching tasknotes: PID-20.4 (release-ci) introduced `release.yml`, PID-17.3 (ci-actions) introduced `test.yml`. PID-35.1 Discovery inventoried F5. No prior tasknote pinned action SHAs — this is the first pinning pass. No design decisions conflict.

- [x] **Drift check** — F5 cited `release.yml`, `test.yml`, `actions/checkout@v4`. Verified against current code: both files still carry exactly one `- uses: actions/checkout@v4` line. No drift. (Note: `@v4` now floats to v4.3.1, not v4.2.2 — captured below.)

- [x] No clarifications needed.

  **Explicit assumptions:**
  - Pin to the commit `@v4` currently resolves to (**v4.3.1** = `34e114876b0b11c390a56381ad16ebd13914f8d5`, verified via GitHub API), not an older v4.x — this preserves current runtime behavior while removing the mutable-tag risk.
  - Annotate with a `# v4.3.1` trailing comment (Dependabot-compatible convention) so the human-readable version survives the SHA pin and Dependabot can bump it.
  - `checkout` is the only third-party action used; `gh release create` in `release.yml` is a CLI call, not a pinnable action.

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

- F5 (PID-35.1 inventory): "`actions/checkout@v4` pinned to mutable major tag, not a commit SHA → Pin to SHA." Low severity, supply-chain class.
- SHA resolution (GitHub API, `repos/actions/checkout`): `@v4` → v4.3.1 → `34e114876b0b11c390a56381ad16ebd13914f8d5`. (v4.2.2 = `11bd7190…` is the prior release; pinning to the current float keeps behavior identical.)
- Only one action to pin per file. No matrix, no reusable workflows, no other `uses:` lines.

Discovery surfaced no significant deviation → skip 🛠️.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — both workflows used the identical `- uses: actions/checkout@v4` shape; extended that single shape with the SHA pin in both files (no new pattern introduced)

- [x] Implemented the minimal solution — one-line edit per file

- [x] Updated/added tests for non-trivial behavior — N/A (declarative CI YAML; no test surface, change is behavior-preserving)

**Implementation Notes:**

- `release.yml:15` and `test.yml:11`: `actions/checkout@v4` → `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`.
- Pinned to the commit `@v4` resolved to at execution time (v4.3.1), so CI runtime behavior is identical; only the mutable-tag substitution risk is removed.

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — N/A (no test covers workflow YAML; change is non-functional)

- [x] Ran lint/type-check on changed code — `grep` verified both pins present, indentation intact, and zero remaining `@vN` mutable refs in `.github/workflows/`

- [x] (frontend) Asked the user for visual confirmation — N/A (no frontend)

**Testing Notes:**

- `grep -rnE "uses:.*@v[0-9]" .github/workflows/` → no matches (clean).
- Both `actions/checkout` lines now carry the full 40-char SHA + `# v4.3.1` comment.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `README.md` no change (Security section covers signing/checksum, not CI internals) · `AGENTS.md` no change (no CI-pinning policy documented) · `CLAUDE.md` no change (build/conventions unaffected) · `.flowtron/PLAN.md` updated (line flipped to Completed stub)

- [x] Closed — PLAN.md line flipped to stub form `Completed 2026-06-28.` and tasknote moved to `.flowtron/tasknote/archive/pid/`

- [x] Recap drafted (surfaced inline on conditional skip)

**Final Summary:**

Closed F5 from the PID-EPIC-35 security sweep: pinned `actions/checkout` to immutable commit SHA `34e114876b0b11c390a56381ad16ebd13914f8d5` (= v4.3.1, what `@v4` currently floats to) with a `# v4.3.1` annotation in both `.github/workflows/release.yml` and `test.yml`. Removes the mutable-major-tag supply-chain substitution risk while preserving CI behavior. SHA verified against the GitHub API before pinning. Two one-line edits; no other third-party actions to pin (`gh release create` is a CLI call, not an action). PID-35.6 (audit) is the only remaining EPIC-35 child.

**Archived:** 2026-06-28
