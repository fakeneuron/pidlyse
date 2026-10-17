#!/bin/bash

# Raycast Script Command — wraps the `pidlyse` CLI companion (PID-58.3).
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title List Strays
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🔍
# @raycast.packageName Pidlyse
#
# Documentation:
# @raycast.description List the likely stray processes Pidlyse found, with the reason each reads as one, without killing anything.
# @raycast.author fakeneuron

# Resolve the installed CLI (see integrations/raycast/README.md → `make install-cli`).
PIDLYSE="$(command -v pidlyse || echo /usr/local/bin/pidlyse)"

if [ ! -x "$PIDLYSE" ]; then
  echo "pidlyse CLI not found. Install it with: make install-cli"
  exit 1
fi

"$PIDLYSE" list
