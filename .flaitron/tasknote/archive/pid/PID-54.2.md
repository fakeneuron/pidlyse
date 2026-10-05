---
title: expand-builtin-kinds
status: in-progress
tags: []
created: 2026-07-01
related-tasks: [PID-EPIC-54, PID-54.1]
---

# PID-54.2 | expand-builtin-kinds

[← PLAN.md](../PLAN.md) · 🟢 In progress · 🔗 [[PID-EPIC-54]] · [[PID-54.1]]

## 🎯 Goal

Add new `ProcessKind` cases + `ScanCore.detectKind` matchers for additional dev-tool / dev-server / local-infra process families, each slotted before the generic `node`/`npm` fallbacks, assigned a risk tier + label, and reflected in the SPEC Scan-Engine + Classification tables.

## ✅ Acceptance

- [ ] New `ProcessKind` cases added with `label` entries (one per confirmed family)
- [ ] `detectKind` matchers slotted **before** the generic `npm`/`bun`/`node` fallbacks, using `hasTokenBoundary` (no raw `contains` false positives)
- [ ] `riskTier` switch extended for every new case (exhaustive-switch compile gate satisfied) with a justified tier per kind
- [ ] Detection is dev-scoped — no flood of unrelated processes (esp. Electron: no VS Code / Slack / Discord false positives)
- [ ] Unit tests added: positive match per new kind + key negative (false-positive guard) + risk-tier assertion for at least the infra-tier kinds
- [ ] `make test` green
- [ ] SPEC.md §"Scan Engine" pattern table + §"Classification" updated with the new kinds
- [ ] Phase 4 doc-drift sweep across README §"AI-referenced docs"

## 🧩 Subtasks

- [ ] Resolve scoping questions (Electron scope · SvelteKit-folds-into-vite · MCP/Playwright-variant breadth · risk-tier posture) via AskUserQuestion
- [ ] Add confirmed `ProcessKind` cases + `label`s in `ProcessItem.swift`
- [ ] Add `detectKind` matchers in `ScanCore.swift`, ordered before generic fallbacks
- [ ] Extend the `riskTier` switch for every new case
- [ ] Add unit tests (positive + negative + tier) in `ScanEngineTests.swift`
- [ ] Run `make test`
- [ ] Sync SPEC.md §"Scan Engine" + §"Classification" tables
- [ ] Phase 4 closure — doc-drift sweep, PLAN flip, archive

## 🔗 Related

- [[PID-EPIC-54]] — parent epic (detection-rules)
- [[PID-54.1]] — discovery; scoped this child. Precedents: PID-13.3 (add kinds), PID-046 (`hasTokenBoundary`), PID-045 (Set toggle wiring)
- [[PID-EPIC-55]] — idle-stray-signals; builds on this child's expanded kinds (complementary)

---

## 📝 Phase 1: Discovery

- [x] Reviewed the task entry in PLAN.md

- [x] **Relevance Assessment**

  **Verdict:** Proceed
  **Rationale:** Implementation child `.2` of PID-EPIC-54, scoped by the `.1` Discovery (resolved 2026-07-01). Clear deliverable: new detection kinds. No prerequisite blocks; `.3`/`.4` are independent siblings.

- [x] Read relevant source files — `ProcessItem.swift` (`ProcessKind`), `ScanCore.swift` (`detectKind`/`riskTier`/`hasTokenBoundary`), `ScanEngineTests.swift`, SPEC.md §"Scan Engine"/§"Classification".

- [x] **Archive skim** — done in `.1`; load-bearing precedents: **PID-13.3** (the template for adding kind + matcher + tier), **PID-046** (`hasTokenBoundary` — new kinds MUST use it, not raw `contains`), **PID-045** (`disabledKinds` Set toggle — `CaseIterable` drives the Settings list, so new cases auto-appear in the "Scanned kinds" toggles + `disabledKinds` persistence for free).

- [x] **Drift check** — all cited symbols match HEAD. `vite` already ships (`ProcessItem.swift:12`, `ScanCore.swift:201`) — confirmed in `.1`; expansion is about *new* kinds only. `hasTokenBoundary` is `private` (fine — `detectKind` is the public entry).

- [x] Asked clarifying questions — resolved via AskUserQuestion (table below)

- [x] Subtasks above populated with concrete, ordered steps

**Discovery Notes:**

### Surface to edit (3 code files + 1 doc)
1. `ProcessItem.swift` — add `case`s to `ProcessKind` enum + a `label` per case.
2. `ScanCore.swift` — add `detectKind` matchers (before the `npm`/`bun`/`node` fallbacks) + extend the exhaustive `riskTier` switch.
3. `ScanEngineTests.swift` — positive/negative/tier unit tests.
4. `SPEC.md` — §"Scan Engine" pattern table + §"Classification" tier rows.

Free wins from existing wiring: `CaseIterable` → new kinds auto-join the Settings "Scanned kinds" toggle list + `disabledKinds` UserDefaults persistence. No app-side changes needed.

### Design subtleties surfaced (drive the scoping questions)
- **SvelteKit runs *as Vite*.** Its dev server has no distinct process token — the command line is just `vite`, already caught by `.vite`. A separate `.sveltekit` kind is largely unactionable. → propose fold into existing `.vite` (drop as separate kind).
- **Electron helpers = false-positive minefield.** Bare `electron`/`Electron Helper` matches VS Code, Slack, Discord, and every Electron app on the machine — Pidlyse must NOT surface those. → propose dev-scoped match only: `node_modules/electron` / `node_modules/.bin/electron` (project-local `electron .` dev runs).
- **`go` is a dangerously short token.** `go run` compiles+execs a *temp binary* (the durable server isn't named `go`). → propose matching explicit `go run` / `go build` / `go test` command forms, never bare `go`.
- **"more MCP/Playwright variants" is vague.** Current detection catches `@playwright/mcp` / `playwright-mcp` / Chrome-under-mcp. Other MCP servers run as `node .../server-*` — generalizable via `@modelcontextprotocol` / `mcp-server-` tokens. → scope question.
- **Next/Astro** are the clean additions: `next dev` (worker renames to `next-server`), `astro dev` (`node .../.bin/astro`). Tokens `next` / `next-server` / `astro`.
- **Local LLM servers**: `ollama serve`/`ollama runner`, `llama-server`/`llama-cli` (llama.cpp), possibly `lms`/LM Studio, `vllm`. Real infra → high risk (never easy-kill someone's model server).

### Proposed risk-tier posture
None of the new kinds are ever `.easy` — they're servers/tools/infra, not throwaway test runners. Dev servers (next/astro) mirror `.vite` (strong-stray→moderate, else high). Build/run tools (cargo, go) mirror the npm/bun family. Local LLM servers + electron dev → treat like real infra (high / moderate-when-strong-stray). Only the existing test-runner kinds stay easy-kill-eligible.

### Resolved scoping (AskUserQuestion, 2026-07-01)

| Question | Resolution |
|----------|-----------|
| Electron scope | **Dev-scoped only** — match `node_modules/electron` / `node_modules/.bin/electron` (project-local `electron .` dev). No installed-app false positives (VS Code / Slack / Discord). |
| Next/Astro/SvelteKit | **Next + Astro get distinct kinds** (`.nextjs`, `.astro`); **SvelteKit folds into existing `.vite`** (its dev server *is* Vite — no distinct token). Note in SPEC. |
| Local LLM breadth | **ollama + llama.cpp** — one `.llmServer` kind matching `ollama` (serve/runner) + `llama-server`/`llama-cli`. High risk (never easy-kill). |
| MCP variants | **Add generic `.mcpServer`** matching `@modelcontextprotocol` / `mcp-server-`; existing `.playwrightMCP` cases unchanged. |

### Final kind set (7 new) + tier
| New kind | `label` | detectKind match | riskTier group |
|---|---|---|---|
| `.nextjs` | Next.js | `next` token OR `next-server` | dev-server (strongStray→moderate, else high) |
| `.astro` | Astro | `astro` token | dev-server |
| `.cargo` | cargo | `cargo` token | build/run (npm family) |
| `.goRun` | go run | `go run ` command form only (never bare `go`) | build/run |
| `.electron` | Electron (dev) | `node_modules/electron` / `node_modules/.bin/electron` | dev-server |
| `.llmServer` | LLM server | `ollama` token OR `llama-server`/`llama-cli` | real infra (always high) |
| `.mcpServer` | MCP server | `@modelcontextprotocol` / `mcp-server-` | test/mcp tooling (strongStray→easy) |

**Scope narrowing from the plan line:** SvelteKit dropped (unactionable — is Vite); `go` restricted to `go run` command form (bare token too short); Electron dev-scoped (avoid installed-app flood). All within epic intent.

**Exit gate judgment:** Discovery surfaced approach-shaping clarifications (SvelteKit fold, Electron scoping, go narrowing, generic MCP) → **fire 🛠️** — present the concrete plan and wait for go before Phase 2.

## 🛠️ Phase 2: Execution

- [x] **Pattern survey** — followed PID-13.3 (add kind + matcher + tier) and PID-046 (`hasTokenBoundary`, never raw `contains`); reused the existing enum/detectKind/riskTier three-point extension shape rather than inventing a new structure.

- [x] Implemented the minimal solution — 7 new kinds across `ProcessItem.swift`, `ScanCore.swift`, SPEC.md.

- [x] Updated/added tests for non-trivial behavior — 11 new tests (positive + false-positive guards + tier).

**Implementation Notes:**
- `ProcessItem.swift`: added `.nextjs .astro .cargo .goRun .electron .llmServer .mcpServer` + labels.
- `ScanCore.swift`: `detectKind` — generic `.mcpServer` after the playwright cases; the dev-server/build/infra block (`next`/`next-server`, `astro`, `cargo`, `go run` via new private `isGoRun`, `ollama`/`llama-server`/`llama-cli`, `node_modules/electron`) slotted before the generic `npm`/`bun`/`node` fallbacks. `riskTier` — `.llmServer` joins the always-high infra guard; `.mcpServer` joins the easy-eligible tooling group; the 5 dev-server/build kinds join the npm/vite/bun (strongStray→moderate, else high) group. Exhaustive switch satisfied.
- Free wiring: `CaseIterable` auto-adds the 7 kinds to the Settings "Scanned kinds" toggles + `disabledKinds` persistence — no app-side change.
- Scope narrowings held: SvelteKit → `.vite` (no separate kind); `go` → `go run` command form only; Electron → project-local `node_modules/electron` (no installed-app false positives).

## 🧪 Phase 3: Testing & Linting

- [x] Ran targeted test suite for changed code — `make test`: **160 tests, 0 failures** (73 in ScanEngineTests, +11 new). One initial failure was a bad test assertion (a node-launched `nextcloud` path correctly classifies `.node`, not `nil`) — fixed the expectation, not the code.

- [x] Ran lint/type-check on changed code — the Swift compile under `make test` type-checks the package; no separate linter in this project. SourceKit `XCTest`/`Shell` "not found" diagnostics are cross-file resolution false positives (build + tests succeed).

- [x] (frontend) Asked the user for visual confirmation — N/A (pure PidlyseCore classification logic; no UI change).

**Testing Notes:** All detection + tier behavior locked by unit tests, including the Electron installed-app negative guard and the generic-MCP-vs-playwright-MCP distinction.

## 🚀 Phase 4: Closure

- [x] **Doc-drift sweep** — `.flowtron/tasknote/README.md` §"AI-referenced docs": `README.md` — **updated** (kind count 12→19 + new kinds in the feature list, line 9) · `AGENTS.md` — no change · `CLAUDE.md` — no change · `.flowtron/PLAN.md` — updated (`.2` flipped to stub). Also synced the non-AI-referenced `SPEC.md` §"Scan Engine" + §"Classification" tables (the task's own contract deliverable).

- [x] Closed — PLAN.md line flipped to stub form and tasknote moved to archive

- [x] Recap drafted

**Final Summary:** Added 7 new built-in `ProcessKind` cases — `nextjs`, `astro`, `cargo`, `goRun`, `electron`, `llmServer`, `mcpServer` — with `detectKind` matchers slotted before the generic node/npm fallbacks (via `hasTokenBoundary` + a new `isGoRun` helper), each assigned a justified risk tier in the exhaustive `riskTier` switch. Dev servers (next/astro) and build tools (cargo/go run/electron) mirror the vite/npm tier (never easy-kill); local LLM servers are always high; generic MCP servers join the easy-eligible tooling group. SvelteKit intentionally folds into the shipped `.vite` kind; `go` is restricted to the `go run` command form; Electron is dev-scoped to `node_modules/electron` to avoid surfacing installed apps. 11 unit tests, `make test` green (160/0). SPEC + README synced.

**Archived:** 2026-07-01
