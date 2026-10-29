# Audit decisions — security

> Settled `/audit security` outcomes. Read before the passes; a finding that
> matches an entry is not reported unless its "Revisit if" condition holds.

- **docker-binary-trust-residual** (`Packages/PidlyseCore/Sources/PidlyseCore/DockerService.swift:cliPath`) — won't-fix: `/usr/local/bin` is group-writable by `admin` on Intel by design, so a same-group attacker could replace `docker` there; rejecting group-writable paths would silently break Docker detection on those machines. Documented in README §Security. Source: audit-security (2026-10-29). Revisit if: the Docker binary lookup in `DockerService.cliPath` or its trust check changes.
