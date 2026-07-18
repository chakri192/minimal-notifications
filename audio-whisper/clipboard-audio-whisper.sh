#!/bin/bash
#
# clipboard-audio-whisper.sh
# Monitors the macOS clipboard in a loop. On every change, plays a quiet
# system sound as the only feedback — no visual notification at all.
#
# Usage:
#   chmod +x clipboard-audio-whisper.sh
#   ./clipboard-audio-whisper.sh &         # run in background
#
# To stop it later:
#   pkill -f clipboard-audio-whisper.sh

# --- Config -----------------------------------------------------------
SOUND="/System/Library/Sounds/Morse.aiff"  # try Pop.aiff, Tink.aiff, etc.
VOLUME=0.15                                 # 0.0 (silent) -> 1.0 (full)
POLL_INTERVAL=0.4                           # seconds between checks
# ------------------------------------------------------------------------

last_hash=""

while true; do
    # Hash the clipboard contents so we can detect a change cheaply.
    # md5 handles text; for binary/image copies this still changes hash.
    current_hash=$(pbpaste 2>/dev/null | md5)

    if [[ "$current_hash" != "$last_hash" && -n "$last_hash" ]]; then
        # Play async (&) so the loop doesn't stall waiting on afplay.
        afplay -v "$VOLUME" "$SOUND" &
    fi

    last_hash="$current_hash"
    sleep "$POLL_INTERVAL"
done
