#!/bin/bash
#
# toggle.sh — pause/resume both clipboard indicators at once.
#
# Handy before a screen recording, presentation, or screen share.
# Works by creating/removing a flag file that both tools check on
# every poll, so no processes are stopped or restarted.
#
set -euo pipefail

PAUSE_FILE="$HOME/.config/minimal-notifications/paused"

if [[ -f "$PAUSE_FILE" ]]; then
    rm "$PAUSE_FILE"
    echo "Clipboard notifications resumed."
else
    mkdir -p "$(dirname "$PAUSE_FILE")"
    touch "$PAUSE_FILE"
    echo "Clipboard notifications paused. Run again to resume."
fi
