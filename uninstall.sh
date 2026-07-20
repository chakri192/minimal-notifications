#!/bin/bash
#
# uninstall.sh — stops the agents and removes everything install.sh created.
#
# Usage:
#   ./uninstall.sh          # remove both tools
#   ./uninstall.sh audio    # audio-whisper only
#   ./uninstall.sh bezel    # transient-bezel only
#
set -euo pipefail

AGENTS="$HOME/Library/LaunchAgents"
UID_NUM="$(id -u)"

remove_agent() {
    local label="$1"
    launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
    rm -f "$AGENTS/$label.plist"
}

uninstall_audio() {
    echo "==> Removing audio-whisper"
    remove_agent "com.user.clipboard-audio-whisper"
    rm -f "$HOME/scripts/clipboard-audio-whisper.sh"
}

uninstall_bezel() {
    echo "==> Removing transient-bezel"
    remove_agent "com.user.clipboard-bezel"
    rm -f "$HOME/apps/clipboard-bezel/clipboard-bezel"
    rmdir "$HOME/apps/clipboard-bezel" 2>/dev/null || true
}

case "${1:-all}" in
    audio) uninstall_audio ;;
    bezel) uninstall_bezel ;;
    all)   uninstall_audio; uninstall_bezel ;;
    *)     echo "usage: $0 [audio|bezel|all]" >&2; exit 1 ;;
esac

echo "Done."
