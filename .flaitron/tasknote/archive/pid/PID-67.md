---
title: typecheck-verb-missing
status: completed
tags: [justfile, fleet-verbs]
created: 2026-09-23
due:
related-tasks: []
touches:
  - justfile
---

# PID-67 | typecheck-verb-missing

[← PLAN.md](../PLAN.md) · ✅ Completed 2026-09-23

## 🎯 Goal

Expose the fleet `just typecheck` verb in pidlyse's justfile so it succeeds instead of erroring with `justfile does not contain recipe`.

## ⚡ Notes

**Relevance:** Proceed — `justfile` had `lint:` (`xcodebuild build -scheme Pidlyse`) but no `typecheck:`; gap still present at HEAD `2019cd4`.
**Best Practices Review:** Single responsibility preserved — `typecheck` depends on `lint` rather than duplicating the `xcodebuild build` body, so the type-check command has one definition. No refactor.
**Drift check:** no drift — `lint:` recipe body matches the PLAN.md citation (`xcodebuild build`).
**Archive skim:** no prior tasknotes touch `justfile` (`grep -l justfile archive/pid/*.md` → no hits; justfile landed in `d966271` without a tasknote).
**Declared scope:** `touches: [justfile]`.
**Pattern survey:** Extends the existing recipe shape (comment line + recipe); `just`'s recipe-dependency form (`typecheck: lint`) is the idiomatic alias.
**Implementation:** Added `typecheck: lint` after `lint:` in `justfile`. Receipt: `just --list` → shows `typecheck`; `just typecheck` → exit 0 (`** BUILD SUCCEEDED **`). Structural quality assertions N/A — justfile recipe, no Swift code changed.
**Docs touched:** `README.md` no change (no `just` verbs documented) · `AGENTS.md` no change · `CLAUDE.md` no change · `SPEC.md` no change · `.flowtron/PLAN.md` PID-67 line flipped to Completed.

## ✅ Recap

Added a 3-line `typecheck:` recipe to `justfile` that depends on `lint` (same `xcodebuild build -scheme Pidlyse`); `just typecheck` now exits 0. Scope reconciliation: `git diff --name-only` = `justfile` + workflow files (PLAN.md, this note) — matches declared `touches:`. No refactors, nothing deferred.

**Archived:** 2026-09-23
