# Pidlyse — Raycast script commands

Sample [Raycast Script Commands](https://github.com/raycast/script-commands) that
drive Pidlyse from Raycast by wrapping the installed `pidlyse` CLI companion. No
running menu-bar app is required — each script shells out to the CLI, which scans
fresh on every invocation.

| Script | Wraps | Does |
|--------|-------|------|
| `clean-safe-strays.sh` | `pidlyse clean` | Kills the safe-to-clean set (safe bucket minus protected projects) — the same sweep as the popover's "Clean all". Returns exit status 1 if any swept item is not verified gone. |
| `list-strays.sh` | `pidlyse list --safe` | Lists the safe-to-clean candidates without killing anything. |

## Prerequisite

Install the CLI companion once:

```sh
make install-cli   # builds + copies `pidlyse` to /usr/local/bin
```

The scripts resolve the binary via `command -v pidlyse`, falling back to
`/usr/local/bin/pidlyse`, and print an install hint if it's missing.

## Install into Raycast

1. Copy this folder somewhere stable (or point Raycast straight at it).
2. Raycast → **Extensions → Script Commands → Add Script Directory** → pick this folder.
3. Run **Clean Safe Strays** / **List Safe Strays** from the Raycast root search.

## Also available via Shortcuts

Pidlyse also exposes **Clean Safe Strays** and **Scan Now** as native
[App Shortcuts](https://support.apple.com/guide/shortcuts-mac/welcome/mac) (AppIntents),
invocable from Shortcuts, Spotlight, and Raycast's Shortcuts listing — no CLI needed.
Those run in-app against the live scan; these Raycast scripts are the CLI-based
alternative for users who prefer the terminal companion.
