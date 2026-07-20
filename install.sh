#!/bin/bash
#
# install.sh — builds, installs, and starts the clipboard indicators.
#
# Usage:
#   ./install.sh          # install both tools
#   ./install.sh audio    # audio-whisper only
#   ./install.sh bezel    # transient-bezel only
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
AGENTS="$HOME/Library/LaunchAgents"
UID_NUM="$(id -u)"

mkdir -p "$AGENTS"

# Installs a plist (with YOUR_USERNAME filled in) and (re)starts its agent.
load_agent() {
    local src="$1"
    local name; name="$(basename "$src")"
    local label="${name%.plist}"
    sed "s|YOUR_USERNAME|$USER|g" "$src" > "$AGENTS/$name"
    # bootstrap fails if the label is already loaded, so unload it first.
    launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$name"
}

install_audio() {
    echo "==> Installing audio-whisper"
    mkdir -p "$HOME/scripts"
    install -m 755 "$REPO/audio-whisper/clipboard-audio-whisper.sh" "$HOME/scripts/"
    load_agent "$REPO/audio-whisper/com.user.clipboard-audio-whisper.plist"
    echo "    audio-whisper is running. Copy something to hear it."
}

install_bezel() {
    echo "==> Installing transient-bezel"
    if ! command -v swiftc >/dev/null 2>&1; then
        echo "error: swiftc not found — install the Xcode Command Line Tools first:" >&2
        echo "       xcode-select --install" >&2
        exit 1
    fi
    swiftc "$REPO/transient-bezel/main.swift" -o "$REPO/transient-bezel/clipboard-bezel" -O
    mkdir -p "$HOME/apps/clipboard-bezel"
    install -m 755 "$REPO/transient-bezel/clipboard-bezel" "$HOME/apps/clipboard-bezel/"
    load_agent "$REPO/transient-bezel/com.user.clipboard-bezel.plist"
    echo "    transient-bezel is running. Copy something to see it."
}

case "${1:-all}" in
    audio) install_audio ;;
    bezel) install_bezel ;;
    all)   install_audio; install_bezel ;;
    *)     echo "usage: $0 [audio|bezel|all]" >&2; exit 1 ;;
esac
