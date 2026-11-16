import AppKit

final class Reminder {
    private var panels: [NSPanel] = []
    var isVisible: Bool { !panels.isEmpty && panels.allSatisfy(\.isVisible) }

    func show(preview: Bool = false, preparingSeconds: Int? = nil) {
        close()
        for screen in NSScreen.screens {
            let area = screen.visibleFrame
            let width = min(CGFloat(360), area.width - 24)
            let height = ReminderCard.height(preparing: preparingSeconds != nil)
            let panel = NSPanel(
                contentRect: NSRect(x: area.maxX - width - 12, y: area.maxY - height - 16, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            let view = ReminderCard(width: width, preview: preview, preparingSeconds: preparingSeconds)
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func updatePreparation(seconds: Int) {
        for panel in panels {
            (panel.contentView as? ReminderCard)?.updatePreparation(seconds: seconds)
        }
    }

    func updateHoldProgress(_ progress: Double?) {
        for panel in panels {
            (panel.contentView as? ReminderCard)?.updateHoldProgress(progress)
        }
    }

    func updatePlayback(_ text: String) {
        for panel in panels { (panel.contentView as? ReminderCard)?.updatePlayback(text) }
    }

    func close() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}


/// A compact reminder card; only this rectangle is painted over the course.
final class ReminderCard: NSView {
    static func height(preparing: Bool) -> CGFloat { preparing ? 136 : 222 }
    private static let brandIcon: NSImage? = {
        // The build and packager place this beside the standalone helper, so
        // artwork lookup does not depend on the launcher's working directory.
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        return NSImage(contentsOf: executable.deletingLastPathComponent().appendingPathComponent("PaperMode.png"))
            ?? NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
    }()

    private let playback = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")
    private let preparation = NSTextField(labelWithString: "")
    private let progressTrack = NSView()
    private let progressFill = NSView()
    private let preview: Bool
    private var lastProgress: Double?

    init(width: CGFloat, preview: Bool, preparingSeconds: Int? = nil) {
        self.preview = preview
        let height = Self.height(preparing: preparingSeconds != nil)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 0.98).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        let accent = NSColor(srgbRed: 0.96, green: 0.78, blue: 0.43, alpha: 1)
        let icon = NSImageView(frame: NSRect(x: 14, y: height - 40, width: 28, height: 28))
        icon.image = Self.brandIcon
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)
        label("PaperMode", frame: NSRect(x: 50, y: height - 36, width: 110, height: 20), size: 14, weight: .semibold, color: .white)
        let status = preparingSeconds != nil ? "STARTING" : (preview ? "PREVIEW" : "LOCKED")
        label(status, frame: NSRect(x: width - 94, y: height - 33, width: 78, height: 16), size: 10, weight: .semibold, color: accent, alignment: .right)

        // Persistent shortcut rows are separate from changing status feedback.
        if preparingSeconds == nil {
            label("UNLOCK", frame: NSRect(x: 16, y: 161, width: 90, height: 15), size: 10, weight: .semibold, color: accent)
            keyRow(last: "L", y: 127, width: width, accent: accent)
            label("PLAY / PAUSE", frame: NSRect(x: 16, y: 73, width: 120, height: 15), size: 10, weight: .semibold, color: accent)
            label("Press once", frame: NSRect(x: width - 110, y: 73, width: 94, height: 15), size: 10, weight: .medium, color: .white.withAlphaComponent(0.7), alignment: .right)
            keyRow(last: "Space", y: 39, width: width, accent: accent)
            let divider = NSView(frame: NSRect(x: 16, y: 94, width: width - 32, height: 1))
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            addSubview(divider)
        }
        hint.stringValue = preview ? "Input stays active during this preview" : "Hold all four keys for 2 seconds to unlock"
        hint.frame = NSRect(x: 16, y: preparingSeconds != nil ? 20 : 106, width: width - 32, height: 17)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = NSColor.white.withAlphaComponent(0.72)
        addSubview(hint)
        progressTrack.frame = NSRect(x: 16, y: 101, width: width - 32, height: 3)
        progressTrack.wantsLayer = true
        progressTrack.layer?.cornerRadius = 1.5
        progressTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        progressFill.wantsLayer = true
        progressFill.layer?.cornerRadius = 1.5
        progressFill.layer?.backgroundColor = accent.cgColor
        progressTrack.addSubview(progressFill)
        progressTrack.isHidden = true
        addSubview(progressTrack)
        preparation.frame = NSRect(x: 16, y: 46, width: width - 32, height: 29)
        preparation.font = .systemFont(ofSize: 20, weight: .semibold)
        preparation.textColor = .white
        preparation.isHidden = preparingSeconds == nil
        addSubview(preparation)
        playback.frame = NSRect(x: 16, y: 13, width: width - 32, height: 17)
        playback.font = .systemFont(ofSize: 11)
        playback.textColor = NSColor.white.withAlphaComponent(0.72)
        playback.stringValue = preview ? "Request playback without unlocking" : "Checking player availability…"
        playback.isHidden = preparingSeconds != nil
        addSubview(playback)
        if let preparingSeconds { updatePreparation(seconds: preparingSeconds) }
    }

    private func keyRow(last: String, y: CGFloat, width: CGFloat, accent: NSColor) {
        let keys: [(String, CGFloat)] = [("⌃ Control", 77), ("⌥ Option", 77), ("⌘ Cmd", 70), (last, 64)]
        let scale = min(1, (width - 32) / 306)
        var x: CGFloat = 16
        for (key, keyWidth) in keys {
            let capWidth = keyWidth * scale
            let cap = NSView(frame: NSRect(x: x, y: y, width: capWidth, height: 29))
            cap.wantsLayer = true
            cap.layer?.cornerRadius = 6
            cap.layer?.backgroundColor = (key == last ? accent : NSColor.white.withAlphaComponent(0.08)).cgColor
            cap.layer?.borderWidth = 1
            cap.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            let text = NSTextField(labelWithString: key)
            text.font = .systemFont(ofSize: 12, weight: .medium)
            text.textColor = key == last ? .black : .white
            text.alignment = .center
            text.frame = NSRect(x: 0, y: 6, width: capWidth, height: 17)
            cap.addSubview(text)
            addSubview(cap)
            x += capWidth + 6 * scale
        }
    }

    func updatePreparation(seconds: Int) {
        preparation.stringValue = "Locking in \(seconds)…"
        hint.stringValue = "Release the keys and get your notebook ready"
    }

    func updateHoldProgress(_ progress: Double?) {
        guard !preview, progress != lastProgress else { return }
        lastProgress = progress
        progressTrack.isHidden = progress == nil
        if let progress {
            let fraction = min(1, max(0, progress))
            // Round up so the display never says 0.0 seconds before completion.
            let remaining = ceil((1 - fraction) * 2 * 10) / 10
            hint.stringValue = String(format: "Keep holding · %.1f seconds to unlock", remaining)
            progressFill.frame = NSRect(x: 0, y: 0, width: progressTrack.bounds.width * fraction, height: 3)
        } else {
            hint.stringValue = "Hold all four keys for 2 seconds to unlock"
            progressFill.frame = .zero
        }
    }

    func updatePlayback(_ text: String) { playback.stringValue = text }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight,
                       color: NSColor, alignment: NSTextAlignment = .left) {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = alignment
        addSubview(label)
    }
}
