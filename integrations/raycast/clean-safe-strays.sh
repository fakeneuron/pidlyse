#!/bin/bash

# Raycast Script Command — wraps the `pidlyse` CLI companion (PID-58.3).
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clean Safe Strays
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🧹
# @raycast.packageName Pidlyse
#
# Documentation:
# @raycast.description Kill every safe-to-clean stray process (safe bucket minus protected projects) — the same set as the Pidlyse popover's "Clean all".
# @raycast.author fakeneuron

# Resolve the installed CLI (see integrations/raycast/README.md → `make install-cli`).
PIDLYSE="$(command -v pidlyse || echo /usr/local/bin/pidlyse)"

if [ ! -x "$PIDLYSE" ]; then
  echo "pidlyse CLI not found. Install it with: make install-cli"
  exit 1
fi

"$PIDLYSE" clean
