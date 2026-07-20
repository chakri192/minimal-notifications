//
//  main.swift
//  clipboard-bezel
//
//  Watches the macOS pasteboard and shows a floating bezel — using the
//  SAME blur material (NSVisualEffectView, .hudWindow) that the real
//  system volume/brightness HUD uses — showing what was copied and the
//  icon + name of the app it was copied from.
//
//  Build:
//    swiftc main.swift -o clipboard-bezel -O
//
//  Run:
//    ./clipboard-bezel &
//
import AppKit

// MARK: - Config
//
// Every value can be overridden at launch without recompiling, using the
// standard macOS `-key value` argument syntax that UserDefaults parses:
//
//   ./clipboard-bezel -duration 1.5 -width 320 -position bottom-right
//
private func config(_ key: String, _ fallback: Double) -> Double {
    UserDefaults.standard.object(forKey: key) != nil
        ? UserDefaults.standard.double(forKey: key)
        : fallback
}

let bezelWidth        = CGFloat(config("width", 300))
let bezelHeight       = CGFloat(config("height", 56))
let marginFromCorner  = CGFloat(config("margin", 16))
let cornerRadius      = CGFloat(config("radius", 14))
let displayDuration: TimeInterval = config("duration", 1.0)
let fadeDuration: TimeInterval    = config("fade", 0.18)
let pollInterval: TimeInterval    = config("poll", 0.35)
let previewMaxLength = Int(config("preview", 40))

/// One of: top-right (default), top-left, bottom-right, bottom-left.
let position = UserDefaults.standard.string(forKey: "position") ?? "top-right"

/// While this file exists, the bezel stays silent. Shared with
/// audio-whisper; flip it with toggle.sh at the repo root.
let pauseFilePath = NSString(string: "~/.config/minimal-notifications/paused")
    .expandingTildeInPath

// MARK: - Bezel window

final class BezelWindow: NSPanel {
    let effectView = NSVisualEffectView()
    let iconView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let sourceLabel = NSTextField(labelWithString: "")
    var hideWorkItem: DispatchWorkItem?

    init() {
        let frame = NSRect(origin: .zero,
                           size: NSSize(width: bezelWidth, height: bezelHeight))

        super.init(contentRect: frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .screenSaver                 // stays above fullscreen apps
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        // Same material Apple's own volume/brightness HUD uses.
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.frame = NSRect(x: 0, y: 0, width: bezelWidth, height: bezelHeight)
        effectView.autoresizingMask = [.width, .height]

        let iconSize: CGFloat = 28
        iconView.frame = NSRect(x: 14, y: (bezelHeight - iconSize) / 2,
                                width: iconSize, height: iconSize)
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let textX = iconView.frame.maxX + 10
        let textWidth = bezelWidth - textX - 12

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: textX, y: bezelHeight / 2 - 1,
                                  width: textWidth, height: 18)
        titleLabel.autoresizingMask = [.width]
        titleLabel.lineBreakMode = .byTruncatingTail

        sourceLabel.font = .systemFont(ofSize: 11)
        sourceLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        sourceLabel.frame = NSRect(x: textX, y: bezelHeight / 2 - 17,
                                   width: textWidth, height: 14)
        sourceLabel.autoresizingMask = [.width]
        sourceLabel.lineBreakMode = .byTruncatingTail

        effectView.addSubview(iconView)
        effectView.addSubview(titleLabel)
        effectView.addSubview(sourceLabel)
        contentView = effectView

        alphaValue = 0
    }

    /// Corner anchor. Top positions offset below the menu bar using its
    /// actual thickness rather than visibleFrame (which collapses when
    /// menu bar auto-hide is on); bottom positions use visibleFrame so
    /// the bezel clears the Dock.
    private func origin(on screen: NSScreen) -> NSPoint {
        let frame = screen.frame
        let topInset = NSStatusBar.system.thickness + 10
        let bottomY = screen.visibleFrame.minY + marginFromCorner
        switch position {
        case "top-left":
            return NSPoint(x: frame.minX + marginFromCorner,
                           y: frame.maxY - bezelHeight - topInset)
        case "bottom-left":
            return NSPoint(x: frame.minX + marginFromCorner, y: bottomY)
        case "bottom-right":
            return NSPoint(x: frame.maxX - bezelWidth - marginFromCorner, y: bottomY)
        default: // top-right
            return NSPoint(x: frame.maxX - bezelWidth - marginFromCorner,
                           y: frame.maxY - bezelHeight - topInset)
        }
    }

    func present(title: String, source: String?, icon: NSImage?) {
        hideWorkItem?.cancel()

        titleLabel.stringValue = title
        sourceLabel.stringValue = source ?? ""
        sourceLabel.isHidden = source == nil
        // Center the title vertically when there's no source line.
        titleLabel.frame.origin.y = source == nil
            ? (bezelHeight - 18) / 2
            : bezelHeight / 2 - 1

        iconView.image = icon
            ?? NSImage(systemSymbolName: "doc.on.clipboard",
                       accessibilityDescription: "Clipboard")

        // Re-anchor every time, in case the display configuration
        // changed since last shown.
        if let screen = NSScreen.main {
            setFrameOrigin(origin(on: screen))
        }

        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fadeDuration
            animator().alphaValue = 1
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = fadeDuration
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
            })
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
    }
}

// MARK: - Clipboard watcher

final class ClipboardWatcher {
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let bezel = BezelWindow()
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Paused: swallow the change silently.
        guard !FileManager.default.fileExists(atPath: pauseFilePath) else { return }

        // The copy almost certainly came from whichever app is frontmost
        // (this app never activates, so it's never frontmost itself).
        let sourceApp = NSWorkspace.shared.frontmostApplication

        bezel.present(title: message(for: pb),
                      source: sourceApp?.localizedName,
                      icon: sourceApp?.icon)
    }

    /// Describes the pasteboard contents: file name(s) for file copies,
    /// a truncated preview for text, "Image copied" for screenshots etc.
    private func message(for pb: NSPasteboard) -> String {
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.count == 1
                ? urls[0].lastPathComponent
                : "\(urls.count) files copied"
        }

        if let raw = pb.string(forType: .string) {
            // Collapse all runs of whitespace (newlines, tabs) to single spaces.
            let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            if !text.isEmpty {
                return text.count > previewMaxLength
                    ? String(text.prefix(previewMaxLength)) + "…"
                    : text
            }
        }

        if pb.canReadItem(withDataConformingToTypes: ["public.image"]) {
            return "Image copied"
        }

        return "Copied"
    }
}

// MARK: - App bootstrap

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar item

let watcher = ClipboardWatcher()
watcher.start()

app.run()
