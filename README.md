# minimal-notifications

Two lightweight macOS clipboard-change indicators, built as an exploration of notification design that stays out of the way entirely — no banners, no Notification Center clutter, no click required to dismiss.

---

## Overview

Most clipboard managers and copy confirmations interrupt you with a visible banner. These two tools take the opposite approach: **audio-whisper** gives you a quiet sound and nothing else, **transient-bezel** gives you a flash of the native macOS HUD style — showing what you copied and the icon of the app you copied it from — and nothing else. Pick one, or run both.

Both can be paused and resumed together with a single command (`./toggle.sh`) — useful before a screen recording or presentation.

---

## Behavior

| Scenario | Behavior |
|---|---|
| Text copied to clipboard | Sound plays / bezel flashes within ~0.4s, bezel shows a text preview |
| File(s) copied in Finder | Bezel shows the file name (or "3 files copied") |
| Image copied (e.g. screenshot to clipboard) | Bezel shows "Image copied" |
| Any copy (bezel) | Icon and name of the source app shown alongside the preview |
| Paused via `./toggle.sh` | Both tools stay running but go silent until toggled back |
| Nothing copied yet (script just started) | No sound/bezel on startup — only fires on the *next* change |
| Clipboard unchanged | Silent — no repeated triggers on every poll |
| Fullscreen app active (bezel only) | Still renders above it — uses `.screenSaver` window level |
| Menu bar auto-hide enabled (bezel only) | Bezel position is fixed relative to actual menu bar thickness, not `visibleFrame`, so it doesn't jump when the menu bar auto-hides |

---

## Requirements

- macOS
- **audio-whisper**: no dependencies — pure Bash + `afplay` (built into macOS)
- **transient-bezel**: Xcode Command Line Tools (`xcode-select --install` if not already present) — no full Xcode required

---

## Installation

One command builds both tools, installs them, and registers `launchd` agents so they survive reboots:

```bash
git clone https://github.com/chakri192/minimal-notifications.git
cd minimal-notifications
./install.sh           # or: ./install.sh audio | ./install.sh bezel
```

To remove everything the installer created:

```bash
./uninstall.sh          # or: ./uninstall.sh audio | ./uninstall.sh bezel
```

### Trying without installing

```bash
# Audio whisper
./audio-whisper/clipboard-audio-whisper.sh &

# Transient bezel
swiftc transient-bezel/main.swift -o transient-bezel/clipboard-bezel -O
./transient-bezel/clipboard-bezel &
```

---

## Configuration

### Audio Whisper

Configured via environment variables — no editing required:

```bash
SOUND=/System/Library/Sounds/Tink.aiff VOLUME=0.3 ./clipboard-audio-whisper.sh &
```

| Variable | Default | Description |
|---|---|---|
| `SOUND` | `Morse.aiff` | Any file under `/System/Library/Sounds/` — `Pop`, `Ping`, `Purr`, `Tink` also work well |
| `VOLUME` | `0.15` | `0.0` (silent) to `1.0` (full) |
| `POLL_INTERVAL` | `0.4` | Seconds between clipboard checks |

### Transient Bezel

Configured via launch arguments — no recompiling required:

```bash
./clipboard-bezel -duration 1.5 -position bottom-right -preview 60 &
```

(To make flags permanent, add them to the `ProgramArguments` array in the plist.)

| Flag | Default | Description |
|---|---|---|
| `-position` | `top-right` | Screen corner: `top-right`, `top-left`, `bottom-right`, `bottom-left` |
| `-width` / `-height` | `300` / `56` | Size of the HUD |
| `-margin` | `16` | Distance from the chosen corner |
| `-radius` | `14` | Corner rounding |
| `-duration` | `1.0` | Seconds fully visible before fading |
| `-fade` | `0.18` | Fade in/out speed |
| `-poll` | `0.35` | Seconds between pasteboard checks |
| `-preview` | `40` | Max characters of copied text shown |

### Pausing both tools

```bash
./toggle.sh    # pause — e.g. before a screen recording
./toggle.sh    # run again to resume
```

This creates/removes `~/.config/minimal-notifications/paused`, which both tools check on every poll — nothing is stopped or restarted, so launchd agents keep running and pick right back up.

---

## How it works

**Audio Whisper**
1. Polls `pbpaste` on a loop and hashes the output with `md5`
2. When the hash changes, plays the configured sound via `afplay -v` asynchronously so the loop never blocks

**Transient Bezel**
1. Polls `NSPasteboard.general.changeCount` on a timer (there's no push-based clipboard-change API on macOS, so both tools poll)
2. On change, positions an `NSPanel` in the configured corner — top positions are offset below the menu bar using `NSStatusBar.system.thickness` rather than `visibleFrame` (which collapses to the full screen height when menu bar auto-hide is on); bottom positions use `visibleFrame` so the bezel clears the Dock
3. Inspects the pasteboard to pick a label: file URL(s) → file name or count, text → truncated one-line preview, image data → "Image copied"
4. Grabs `NSWorkspace.shared.frontmostApplication` for the source app's icon and name — the bezel itself runs as an `.accessory` app that never activates, so the frontmost app at copy time is the one the copy came from
5. Renders an `NSVisualEffectView` with `.hudWindow` material — the same blur material macOS uses for its own volume/brightness HUD — then fades in, holds, and fades out

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Neither tool fires at all | You may have left them paused — run `./toggle.sh`, or check for `~/.config/minimal-notifications/paused` |
| No sound plays | Check `VOLUME` isn't `0`, and confirm the file exists: `ls /System/Library/Sounds/` |
| Bezel doesn't appear at all | Confirm the build succeeded: `swiftc main.swift -o clipboard-bezel -O && echo OK`. A stale binary from an earlier build is the most common cause |
| Bezel overlaps the menu bar | Increase the `+ 10` offset added to `menuBarHeight` in `main.swift` |
| launchd agent won't load | `launchctl bootstrap` fails silently if the same label is already loaded — run `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<plist>` first, then bootstrap again |
| Multiple instances running | `pgrep -fl clipboard-bezel` / `pgrep -fl clipboard-audio-whisper` to check, `pkill -f <name>` to stop |

---

## Stopping

If installed via `./install.sh`, remove everything with:

```bash
./uninstall.sh
```

If running ad-hoc in the background:

```bash
pkill -f clipboard-audio-whisper
pkill -f clipboard-bezel
```
---

## License

MIT

## Contributors

| Contributor | Role |
|-------------|------|
| [chakri192](https://github.com/chakri192) | Author |
| [aider](https://github.com/Aider-AI/aider) | AI pair programmer |

### AI tooling

README and code contributions assisted by [aider](https://github.com/Aider-AI/aider) using local LLMs via [Ollama](https://ollama.com):

| Model | Used for |
|-------|----------|
| `qwen2.5-coder:7b` | Code suggestions, refactoring |
| `llama3.1:8b` | Prose, documentation, commit messages |
