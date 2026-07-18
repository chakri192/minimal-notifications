//
//  main.swift
//  clipboard-bezel
//
//  Watches the macOS pasteboard and shows a floating bezel — using the
//  SAME blur material (NSVisualEffectView, .hudWindow) that the real
//  system volume/brightness HUD uses — in the top-right corner.
//
//  Build:
//    swiftc main.swift -o clipboard-bezel -O
//
//  Run:
//    ./clipboard-bezel &
//
import AppKit

// MARK: - Config

let bezelWidth: CGFloat        = 260
let bezelHeight: CGFloat       = 56
let marginFromCorner: CGFloat  = 16
let cornerRadius: CGFloat      = 14
let displayDuration: TimeInterval = 1.0
let fadeDuration: TimeInterval    = 0.18
let pollInterval: TimeInterval    = 0.35
let previewMaxLength = 40

// MARK: - Bezel window

final class BezelWindow: NSPanel {
    let effectView = NSVisualEffectView()
    let label = NSTextField(labelWithString: "")
    var hideWorkItem: DispatchWorkItem?

    init() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let menuBarHeight = NSStatusBar.system.thickness
        let topInset = menuBarHeight + 10
        let x = screenFrame.maxX - bezelWidth - marginFromCorner
        let y = screenFrame.maxY - bezelHeight - topInset
        let frame = NSRect(x: x, y: y, width: bezelWidth, height: bezelHeight)

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

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 8, y: (bezelHeight - 20) / 2, width: bezelWidth - 16, height: 20)
        label.autoresizingMask = [.width]
        label.lineBreakMode = .byTruncatingTail

        effectView.addSubview(label)
        contentView = effectView

        alphaValue = 0
    }

    func present(text: String) {
        hideWorkItem?.cancel()
        label.stringValue = text

        // Re-anchor to the top-right corner every time, in case the
        // display configuration changed since last shown.
        let screenFrame = NSScreen.main?.frame ?? .zero
        let menuBarHeight = NSStatusBar.system.thickness
        let topInset = menuBarHeight + 10
        let x = screenFrame.maxX - bezelWidth - marginFromCorner
        let y = screenFrame.maxY - bezelHeight - topInset
        setFrameOrigin(NSPoint(x: x, y: y))

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

        var text = pb.string(forType: .string) ?? "Copied"
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if text.isEmpty { text = "Copied" }
        if text.count > previewMaxLength {
            text = String(text.prefix(previewMaxLength)) + "…"
        }

        bezel.present(text: text)
    }
}

// MARK: - App bootstrap

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar item

let watcher = ClipboardWatcher()
watcher.start()

app.run()
