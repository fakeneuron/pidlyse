#!/bin/bash

# Raycast Script Command — wraps the `pidlyse` CLI companion (PID-58.3).
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Clean Likely Strays
# @raycast.mode fullOutput
#
# Optional parameters:
# @raycast.icon 🧹
# @raycast.packageName Pidlyse
#
# Documentation:
# @raycast.description Kill every likely stray in the "Clean all" sweep set (not high-risk, minus protected projects, registered-port listeners, and other users' processes). Exit status 1 means one or more swept items were not verified gone.
# @raycast.author fakeneuron

# Resolve the installed CLI (see integrations/raycast/README.md → `make install-cli`).
PIDLYSE="$(command -v pidlyse || echo /usr/local/bin/pidlyse)"

if [ ! -x "$PIDLYSE" ]; then
  echo "pidlyse CLI not found. Install it with: make install-cli"
  exit 1
fi

"$PIDLYSE" clean
