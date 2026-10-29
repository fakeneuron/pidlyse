---
name: audit
description: Pidlyse audit — thin overlay over flaitron's bundled `ft-audit` (runs its passes by reference, applies the project deltas below). Swift/SwiftUI macOS menu bar app; domains general, security, structure, context, docs, performance. Forked from flaitron's audit-overlay template; see `docs/MIGRATION.md` §1.2.1.
flaitron-reconciled: v7.5.0
flaitron-tracks: ft-audit
---

# audit — thin overlay over `ft-audit`

> **Overlay skill.** This file does NOT restate the audit procedure. It points
> at flaitron's bundled scaffold and supplies only what diverges for this
> project. First action on every run: read the referenced scaffold below and
> run **its** procedure, finding format, closing sections, and hard rules —
> substituting the `## Deltas` values for the scaffold's `<placeholder>` slots.

**Referenced scaffold (read first, always):**
`.flaitron/core/claude/skills/ft-audit/SKILL.md`

**Pass files:** the scaffold loads its per-domain pass definitions from a
`passes/<domain>.md` sibling. This overlay has no `passes/` directory of its
own — resolve those reads **relative to the referenced scaffold's directory**,
i.e. `.flaitron/core/claude/skills/ft-audit/passes/<domain>.md`.

## Domains

`general` (default) · `security` · `structure` · `context` · `docs` · `performance`.
No `backend` or `frontend`: Pidlyse is a native app with no server and no web UI —
a domain token outside this list → stop and ask.

Invoked as `/audit <domain> [scope]`; a bare invocation resolves to `general`.

## Deltas

Where a value differs per domain it is keyed by domain; an unkeyed value applies
to every domain above.

- **Scope glob** (default-`all` target):
  - general / security / structure / performance: `Pidlyse/**/*.swift`, `PidlyseTests/**/*.swift`, `Packages/PidlyseCore/Sources/**/*.swift`, `Packages/PidlyseCore/Tests/**/*.swift`, `integrations/**`, `Makefile`, `Pidlyse/Info.plist`, `.github/workflows/*.yml`
  - structure: whole repo (findings live between files; the app/core split is the main seam)
  - docs: `README.md`, `SPEC.md`, `AGENTS.md`, `integrations/raycast/README.md`, `docs/screenshots/*` (alt text vs. what the image shows)
  - context: `AGENTS.md`, `CLAUDE.md`, `.claude/**`
- **Rubric files** (audit-against contracts): `AGENTS.md` (§"Conventions" is the declared architecture: what lives in `PidlyseCore`, what stays app-side, the single-owner seams), `SPEC.md` (product contract), `Pidlyse/Info.plist` (declared URL scheme and `LSUIElement`), `README.md` (§"Security" — the public-trust story), `integrations/raycast/README.md`.
- **Verification gates** (run before passes): security: `gitleaks detect --no-banner` (the same scan CI's `test.yml` runs) — no dependency scanner is configured, so for pass 5 read `Packages/PidlyseCore/Package.swift` / any `Package.resolved` directly. structure / docs / performance: none configured — passes run on read-the-code evidence. `make test` is allowed when a pass needs a green baseline; never run `make install`, `make install-cli`, `make dmg` or anything that writes outside the repo or `build/`.
- **Sacred invariants → Critical** (severity guide):
  - A path that kills, signals or `docker stop`s a process without an explicit user action (row ✕, ⌘⌫, Clean all, `pidlyse kill`/`clean`, or a launcher verb that is itself the action). Includes anything that could let a web page, file or other app trigger `pidlyse://clean` beyond its bounded sweep set.
  - SIGKILL sent without the SIGTERM grace period (2 s), or a kill reported as done when the process table was not re-read (outcomes must say what happened, not what was attempted).
  - Killing past an identity guard (PID recycled / start-time mismatch) or past EPERM (`.unkillable` — never escalate against a foreign owner).
  - The sweep set widening: "Clean all" must stay stray ∧ not high-risk ∧ not protected ∧ not port-bound ∧ killable, and must fail closed when the port scan returned no data.
  - Process command lines persisted anywhere (clean log is privacy-first: no command line on disk).
  - Operator email or any identifying personal string in an outbound request.
- **Per-pass examples** (concrete stack anti-patterns to add under each pass):
  - Secrets: tokens or paths with user names in `Info.plist`, logs (`print`/`NSLog`/`os_log` of full command lines, which can carry credentials passed as CLI args), UserDefaults values, the clean log, notification bodies.
  - Input handling: `pidlyse://` URL host/path parsing (`URLScheme.parse`), App Intents parameters, CLI arg parsing in `CLICore`/`main.swift`, `ps`/`lsof`/`docker` output parsing (spaces in paths, malformed lines, huge output), user-supplied custom/ignore rules (regex/glob compile failure or catastrophic patterns), any string interpolated into a `Shell.run` argument list — arguments must stay an array, never a shell string.
  - Auth & authz: the app has no accounts; read this as authorization of destructive action — who or what may trigger a kill, and the EPERM / foreign-uid boundary.
  - Network & boundaries: app does no network I/O of its own — flag any new egress; Docker CLI invocation and PATH resolution (`DockerService` binary lookup), Raycast scripts calling the installed CLI, the `/usr/local/bin` install target, `flock` lock-file location and permissions, `Application Support` file modes.
  - Dependencies: SwiftPM manifests and `Package.resolved`, GitHub Actions pins (`actions/checkout` floor, third-party actions), `release.yml` signing/upload steps, ad-hoc signing and no-sandbox/Hardened-Runtime posture (PID-030 is the deferred home — do not re-file).
  - Structure: logic re-derived in a consumer instead of read from its core owner (verdict, sweep predicate, group membership, settings keys, display order, port registry); `Process()` spawned outside `Shell.run`; `docker` invoked outside `DockerService`; `KillService.kill` called from a view; live system access inline in `ScanEngine.scan()`/`kill()` instead of behind the injectable seams. Typical file size here is 100–450 lines; `MenuBarView.swift` (~760) and `ScanEngine.swift` (~740) are the known large files.
  - Docs: `AGENTS.md` / `SPEC.md` / README claims vs. code (PID numbers cited as authority, file lists in §Conventions that omit or invent files, make targets, port-registry sync note); screenshots and GIF vs. the stray-first popover.
  - Performance: an always-running menu bar app — scan interval cost, `ps`/`lsof`/`docker` budgets (10 s / 20 s / 20 s), work done on the main thread, SwiftUI body recompute on every `@Published` tick, `ScanHistory`/`RespawnHistory` growth over a long session. Findings need a measurement (Instruments, `time` on the CLI) or are Low.
- **Extra hard rules** (appended project-specific rules):
  - "Never kill without explicit user action" outranks convenience: any finding touching it is Critical however small it looks.
  - Do not run the app, the CLI's `clean`/`kill`, or `pidlyse://` verbs during an audit — read-only `pidlyse list` is fine. An audit must never terminate a user process.
  - Don't re-file what is already settled or tracked: PID-030 (notarize/sign), PID-092 (screenshots), and prior PID-EPIC-35 security-sweep decisions.

Settled findings — by-design calls, accepted won't-fix tradeoffs — do **not**
belong in this block. They live in `.flaitron/audit-decisions/`, one file per
domain, which the scaffold reads before its passes and appends to at its write
step (scaffold §1 step 5, §5 step 3).
