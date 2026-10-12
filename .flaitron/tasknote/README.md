# Tasknote Directory

This directory holds active tasknotes and archived tasknotes for completed
work. Tasknote templates are resolved from the flaitron submodule at
`.flaitron/core/templates/`. The canonical workflow lives in
`.flaitron/core/SPEC.md`.

## Layout

- `<TASK-ID>.md` — active tasknote (one per task in flight)
- `archive/<area>/<TASK-ID>.md` — completed tasknotes, one folder per area

Tasknotes are scaffolded automatically by the slash commands from
`.flaitron/core/templates/`; inspect those files directly for the
canonical shapes. Three variants:

- **Standard 4-phase tasknote** — `/ft-task <ID>` scaffolds from `tasknote-template.md`; full schema at `.flaitron/core/SPEC.md` §"Tasknote frontmatter" + §"Tasknote body shape" (model assignment lives on the PLAN.md task line — see §"Task-line format").
- **Starter tasknote** — `/ft-file-task <ID> --starter` scaffolds from `tasknote-starter-template.md` for mid-flow context capture; lifecycle at `.flaitron/core/SPEC/starter.md`.
- **Micro-tasknote** — `/ft-task <ID> --micro` scaffolds from `tasknote-micro-template.md` for tasks above the skip-tasknote threshold but below full 4-phase ceremony; threshold at `.flaitron/core/SPEC/tasknote-selection.md` §"When to use a tasknote (and when not to)".
- **Epic lifecycle** — for code-sweep or major multi-child feature epics, bracket the implementation children with a **Discovery** subtask (`<AREA>-<N>.1`, plans the children) and an **Audit** subtask (final `.N`, verifies the completed work). See `.flaitron/core/SPEC/epic.md`. Simple implementations don't need it.

## Area prefixes

Canonical prefixes (defined by flaitron):

| Prefix | Area |
|--------|------|
| `CORE-` | cross-cutting, orchestration, project-wide |
| `BE-` | backend |
| `FE-` | frontend |
| `DB-` | database, migrations |
| `DEPLOY-` | deployment, CI/CD, infra |
| `TEST-` | testing infrastructure |

Project-specific prefixes:

| Prefix | Area | Notes |
|--------|------|-------|
| `PID-` | Pidlyse (process scanner) | macOS menu bar app tasks |

## Archive layout

| Prefix | Folder |
|--------|--------|
| `CORE-*` | `archive/core/` |
| `BE-*` | `archive/backend/` |
| `FE-*` | `archive/frontend/` |
| `DB-*` | `archive/database/` |
| `DEPLOY-*` | `archive/deployment/` |
| `TEST-*` | `archive/testing/` |

Project-specific prefixes archive under their own subfolder named for the area:
`PID-*` → `archive/pid/`.

## AI-referenced docs

Canonical docs that AI sessions consume as cold-start ground truth — the
project-declared doc set walked at every Phase 4 closure (per
`.flaitron/core/SPEC.md` §"🚀 Phase 4: Closure") and at every
epic-audit subtask (per `.flaitron/core/SPEC/epic.md`). Flat list,
one-line purpose each. Extend as the architecture matures (architecture
notes, API specs, DB schema docs, ADRs, inventories).

- `README.md` — project overview, current shipped feature surface
- `AGENTS.md` — assistant-facing project guide: tech stack, build, binding conventions, plus the flaitron paste-block (read by Claude Code, Codex, Cursor, Amp, Aider, Grok)
- `CLAUDE.md` — thin `@AGENTS.md` import + Claude-only notes
- `SPEC.md` — canonical technical specification: project structure, scan engine patterns, classification tiers, kill flow, settings, and shipped feature surface
- `.flaitron/PLAN.md` — roadmap and active task queue

## Project quick commands

- Build (Release, ad-hoc signed): `make build-release` → `build/Release/Pidlyse.app`; or `xcodebuild build -scheme Pidlyse` for a debug build
- Package DMG: `make dmg` → `build/Pidlyse.dmg` (drag-install with /Applications symlink)
- Build the `pidlyse` terminal companion: `make build-cli` → `Packages/PidlyseCore/.build/release/pidlyse`; install: `make install-cli` (→ /usr/local/bin)
- Tests: `make test` (app scheme via `make test-app`, then `swift test --package-path Packages/PidlyseCore`)
  (`CODE_SIGNING_ALLOWED=NO` on the app scheme is required for CLI test runs — pre-existing code-signing limitation in this environment)
- Type check: `xcodebuild build -scheme Pidlyse` (Swift compiler surfaces all type errors; no separate linter)
