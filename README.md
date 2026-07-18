# Minimal Notifications

Two lightweight macOS clipboard-change indicators, built as an exploration of
notification design that stays out of the way — no banners, no Notification
Center clutter, no clicks required to dismiss.

## 1. Audio Whisper

The most minimal visual notification is no visual notification at all.

A background shell script polls the clipboard and plays a quiet system sound
the moment it changes — instant physical confirmation without moving your
eyes from where you're typing.

**Stack:** Bash + `afplay`

```
audio-whisper/
├── clipboard-audio-whisper.sh          # the watcher loop
└── com.user.clipboard-audio-whisper.plist   # launchd config for auto-start at login
```

### Setup

```bash
chmod +x audio-whisper/clipboard-audio-whisper.sh
./audio-whisper/clipboard-audio-whisper.sh &
```

### Auto-start at login

```bash
mkdir -p ~/scripts
cp audio-whisper/clipboard-audio-whisper.sh ~/scripts/
# Edit the plist's ProgramArguments path to point at ~/scripts/clipboard-audio-whisper.sh
# if you copied the repo somewhere other than the path baked into the file.
cp audio-whisper/com.user.clipboard-audio-whisper.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.clipboard-audio-whisper.plist
```

### Customizing the sound

Edit `SOUND=` in the script. Any file under `/System/Library/Sounds/` works —
`Pop`, `Ping`, `Purr`, `Tink`, and `Morse` are all good low-key options.

---

## 2. Transient Bezel

A brief, unclickable overlay in the top-right corner of the screen, styled
with the exact same blur material Apple uses for its own volume/brightness
HUD. It flashes on clipboard change and disappears without a trace.

**Stack:** Swift + AppKit (`NSVisualEffectView`, material: `.hudWindow`)

An earlier version of this was prototyped in Hammerspoon/Lua using
`hs.canvas`, but that can only approximate the native blur with flat
colors — it doesn't have access to real `NSVisualEffectView` materials. This
version uses AppKit directly for a pixel-accurate match, and needs no
Accessibility permission grant.

```
transient-bezel/
└── main.swift
```

### Build & run

Requires Xcode Command Line Tools (`xcode-select --install` if you don't
have them — no full Xcode needed).

```bash
cd transient-bezel
swiftc main.swift -o clipboard-bezel -O
./clipboard-bezel &
```

### Auto-start at login

```bash
mkdir -p ~/apps/clipboard-bezel
cp transient-bezel/clipboard-bezel ~/apps/clipboard-bezel/
cat > ~/Library/LaunchAgents/com.user.clipboard-bezel.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.clipboard-bezel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/apps/clipboard-bezel/clipboard-bezel</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/clipboard-bezel.err</string>
</dict>
</plist>
EOF
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.clipboard-bezel.plist
```

### Config

Tunable constants live at the top of `main.swift`:

| Constant | Purpose |
|---|---|
| `bezelWidth` / `bezelHeight` | Size of the HUD |
| `marginFromCorner` | Distance from the screen's top-right corner |
| `cornerRadius` | Corner rounding |
| `displayDuration` | How long the bezel stays fully visible |
| `fadeDuration` | Fade in/out speed |
| `pollInterval` | How often the pasteboard is checked |
| `previewMaxLength` | Max characters of copied text shown |

---

## Stopping either one

```bash
pkill -f clipboard-audio-whisper
pkill -f clipboard-bezel
```

Or, if installed via launchd:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.clipboard-audio-whisper.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.clipboard-bezel.plist
```
