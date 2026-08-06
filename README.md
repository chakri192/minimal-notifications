<div align="center">

# minimal-notifications

**Two macOS clipboard indicators that require no dismissal.**

A quiet sound, or a brief display of the native system HUD. No banner, no Notification Center entry, no interaction required.

<p>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-12%2B-1c1c1e?style=flat-square&logo=apple&logoColor=white" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-AppKit-1c1c1e?style=flat-square&logo=swift&logoColor=F05138" />
  <img alt="Bash" src="https://img.shields.io/badge/Bash-zero%20deps-1c1c1e?style=flat-square&logo=gnubash&logoColor=4EAA25" />
  <img alt="Size" src="https://img.shields.io/badge/~400-lines-1c1c1e?style=flat-square" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-1c1c1e?style=flat-square" />
</p>

</div>

---

## Overview

A copy confirmation is the smallest useful notification, yet macOS presents it as a full event: a banner that animates in, persists, and accumulates in Notification Center until cleared. These two tools take the opposite approach — acknowledge the action, then leave no trace.

**audio-whisper** plays a quiet sound and does nothing else. 46 lines of Bash, no dependencies, no visual output.

**transient-bezel** displays the same floating HUD macOS uses for volume and brightness — the same `NSVisualEffectView` material and blur — showing a preview of the copied content and the icon of the originating application, then fades. It is never clickable and never focusable.

Either can be used independently. A single command silences both.

## Requirements

macOS 12 or later.

audio-whisper requires nothing further; `afplay` is part of the system. transient-bezel requires the Xcode Command Line Tools to compile (`xcode-select --install`), though not full Xcode. Once built, the binary depends only on system frameworks.

## Installation

```sh
git clone https://github.com/chakri192/minimal-notifications.git
cd minimal-notifications && ./install.sh
```

This compiles the Swift binary, installs both tools, and registers `launchd` agents so they persist across reboots. Pass `audio` or `bezel` to install only one.

Installed paths are `~/scripts/clipboard-audio-whisper.sh` and `~/apps/clipboard-bezel/clipboard-bezel`. `install.sh` substitutes the current username into the property lists before copying them to `~/Library/LaunchAgents/`, so the files in the repository remain generic. It also unloads any existing agent before loading the new one, making repeated execution safe.

## Comparison

|  | audio-whisper | transient-bezel |
|---|---|---|
| Feedback | Audible only | Visual only |
| Implementation | Bash, 46 lines | Swift and AppKit, 245 lines |
| Dependencies | None | Command Line Tools to build; none to run |
| Change detection | `pbpaste \| md5` | `NSPasteboard.changeCount` |
| Text | Yes | Yes, with a 40-character preview |
| Files copied in Finder | Yes | Yes — filename, or a count |
| Images and screenshots | **No** — `pbpaste` produces no output, so the hash is unchanged | Yes |
| Repeated identical text | **No** — the hash is unchanged | Yes — `changeCount` still increments |
| Source application | — | Yes, icon and name |

The two negative cases are inherent rather than incidental. Hashing `pbpaste` output is what allows audio-whisper to have no dependencies, and the consequence is that it observes only what `pbpaste` can produce. Running both tools covers the gap.

## Implementation

Both tools are polling loops. macOS publishes no change notification for the pasteboard, so polling is the only available approach; at 0.35–0.4 second intervals the cost is not measurable.

**The first poll never fires.** Both watchers establish a baseline at startup and compare against it, so launching an agent does not announce clipboard content that was already present.

**The pause mechanism is a file rather than a signal.** `./toggle.sh` creates or removes `~/.config/minimal-notifications/paused`, which both loops check on every iteration. Pausing is therefore immediate and symmetric, and requires no process to be stopped or restarted.

**The source application is the frontmost application.** transient-bezel sets its activation policy to `.accessory`, giving it no Dock icon, no menu bar presence, and no ability to become frontmost. This makes "the frontmost application when the pasteboard changed" a reliable proxy for the originating application.

### Two implementation details

**Rendering above fullscreen applications.** An ordinary window is hidden when a fullscreen application is active. The bezel uses window level `.screenSaver` with a collection behaviour of `[.canJoinAllSpaces, .stationary, .ignoresCycle]`, so it renders above fullscreen content and Mission Control without entering the window cycle.

**Stable positioning with menu bar auto-hide.** The conventional anchor for a top-corner window is `screen.visibleFrame`, which excludes the menu bar. With auto-hide enabled that frame changes size, causing the bezel to shift position depending on cursor location. It instead anchors to `screen.frame` offset by `NSStatusBar.system.thickness`, which is constant. Bottom positions continue to use `visibleFrame`, since the relevant obstruction there is the Dock.

## Configuration

### transient-bezel

Options are read through `UserDefaults` and supplied as `-key value` arguments, requiring no recompilation.

```sh
~/apps/clipboard-bezel/clipboard-bezel -position bottom-right -duration 1.5 -width 320
```

| Option | Default | Description |
|---|---|---|
| `-position` | `top-right` | `top-right`, `top-left`, `bottom-right`, `bottom-left` |
| `-duration` | `1.0` | Seconds held at full opacity |
| `-fade` | `0.18` | Fade in and out duration |
| `-poll` | `0.35` | Seconds between pasteboard checks |
| `-width` · `-height` | `300` · `56` | Bezel dimensions in points |
| `-radius` · `-margin` | `14` · `16` | Corner radius and distance from the screen edge |
| `-preview` | `40` | Maximum characters of text preview |

To persist an option, add it to `ProgramArguments` in `~/Library/LaunchAgents/com.user.clipboard-bezel.plist` and reload the agent.

### audio-whisper

Options are environment variables.

| Variable | Default | Description |
|---|---|---|
| `SOUND` | `/System/Library/Sounds/Morse.aiff` | Any file playable by `afplay` |
| `VOLUME` | `0.15` | `0.0` to `1.0` |
| `POLL_INTERVAL` | `0.4` | Seconds between checks |
| `PAUSE_FILE` | `~/.config/minimal-notifications/paused` | Shared pause flag |

## Operation

```sh
./toggle.sh              # pause both; run again to resume
./install.sh bezel       # rebuild and reinstall after modifying main.swift
./uninstall.sh           # stop the agents and remove all installed files
```

```sh
launchctl list | grep clipboard
tail -f /tmp/clipboard-bezel.err /tmp/clipboard-audio-whisper.err
```

To evaluate without installing:

```sh
./audio-whisper/clipboard-audio-whisper.sh &
swiftc transient-bezel/main.swift -o /tmp/clipboard-bezel -O && /tmp/clipboard-bezel &
```

## Troubleshooting

| Symptom | Cause |
|---|---|
| Neither tool responds | Paused. Run `./toggle.sh`, or check for the flag file |
| No sound, bezel functional | `VOLUME` is `0`, or `SOUND` refers to a missing file — the script reports this and exits |
| Bezel never appears | A stale binary from an earlier build. Re-run `./install.sh bezel`, which recompiles before installing |
| Bezel overlaps the menu bar | Increase the `topInset` offset in `main.swift` |
| Agent fails to load | `launchctl bootstrap` fails if the label is already loaded; unload it first |

## Project structure

```
minimal-notifications/
├── install.sh                 Build, install, and register agents  [audio|bezel|all]
├── uninstall.sh               Unload agents and remove installed files
├── toggle.sh                  Create or remove the shared pause flag
├── transient-bezel/
│   ├── main.swift             Bezel window, pasteboard watcher, configuration
│   └── com.user.clipboard-bezel.plist
└── audio-whisper/
    ├── clipboard-audio-whisper.sh
    └── com.user.clipboard-audio-whisper.plist
```

## License

MIT — see [LICENSE](LICENSE).

## Contributors

| | |
|---|---|
| [chakri192](https://github.com/chakri192) | Author |
| [aider](https://github.com/Aider-AI/aider) | AI pair programmer |
