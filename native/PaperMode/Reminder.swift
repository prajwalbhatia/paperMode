import AppKit
import QuartzCore

final class Reminder {
    private var panels: [NSPanel] = []
    var isVisible: Bool { !panels.isEmpty && panels.allSatisfy(\.isVisible) }

    func show(preview: Bool = false, preparingSeconds: Int? = nil) {
        close()
        for screen in NSScreen.screens {
            let area = screen.visibleFrame
            let width = min(CGFloat(340), area.width - 24)
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
    static func height(preparing: Bool) -> CGFloat { preparing ? 112 : 154 }
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
    private let progressTrack = CAShapeLayer()
    private let progressFill = CAShapeLayer()
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
        let icon = NSImageView(frame: NSRect(x: 14, y: height - 33, width: 22, height: 22))
        icon.image = Self.brandIcon
        icon.imageScaling = .scaleProportionallyUpOrDown
        addSubview(icon)
        label("PaperMode", frame: NSRect(x: 42, y: height - 30, width: 110, height: 18), size: 13, weight: .semibold, color: .white)
        let status = preparingSeconds != nil ? "STARTING" : (preview ? "PREVIEW" : "LOCKED")
        label(status, frame: NSRect(x: width - 94, y: height - 29, width: 78, height: 16), size: 10, weight: .semibold, color: accent, alignment: .right)

        // Persistent shortcut rows are separate from changing status feedback.
        if preparingSeconds == nil {
            label("Unlock", frame: NSRect(x: 16, y: 102, width: 130, height: 15), size: 12, weight: .semibold, color: .white)
            keyRow(last: "L", y: 95, width: width, accent: accent)
            label("Play / pause", frame: NSRect(x: 16, y: 67, width: 130, height: 16), size: 12, weight: .medium, color: .white)
            keyRow(last: "Space", y: 63, width: width, accent: accent)
            label("Skip ±5 sec", frame: NSRect(x: 16, y: 36, width: 130, height: 16), size: 12, weight: .medium, color: .white)
            keyRow(last: "← / →", y: 32, width: width, accent: accent)
        }
        hint.stringValue = preview ? "Input stays active during this preview" : "Hold 2 seconds"
        hint.frame = NSRect(x: 16, y: preparingSeconds != nil ? 18 : 88,
                            width: preparingSeconds != nil ? width - 32 : 136, height: 13)
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = NSColor.white.withAlphaComponent(0.72)
        addSubview(hint)
        preparation.frame = NSRect(x: 16, y: 42, width: width - 32, height: 26)
        preparation.font = .systemFont(ofSize: 18, weight: .semibold)
        preparation.textColor = .white
        preparation.isHidden = preparingSeconds == nil
        addSubview(preparation)
        playback.frame = NSRect(x: 16, y: 10, width: width - 32, height: 16)
        playback.font = .systemFont(ofSize: 10)
        playback.textColor = NSColor.white.withAlphaComponent(0.72)
        playback.stringValue = preview ? "Request playback without unlocking" : "Checking player availability…"
        playback.isHidden = preparingSeconds != nil
        addSubview(playback)
        // Trace the rounded perimeter from the top centre as the unlock hold
        // completes. Keep it inside the card so it never covers the lesson.
        let outline = Self.progressOutline(width: width, height: height)
        progressTrack.path = outline
        progressTrack.fillColor = NSColor.clear.cgColor
        progressTrack.strokeColor = NSColor.white.withAlphaComponent(0.12).cgColor
        progressTrack.lineWidth = 3
        progressTrack.isHidden = true
        progressFill.path = outline
        progressFill.fillColor = NSColor.clear.cgColor
        progressFill.strokeColor = accent.cgColor
        progressFill.lineWidth = 3
        progressFill.lineCap = .round
        progressFill.strokeEnd = 0
        progressFill.isHidden = true
        layer?.addSublayer(progressTrack)
        layer?.addSublayer(progressFill)
        if let preparingSeconds { updatePreparation(seconds: preparingSeconds) }
    }

    private static func progressOutline(width: CGFloat, height: CGFloat) -> CGPath {
        let inset: CGFloat = 2
        let radius: CGFloat = 14
        let left = inset, right = width - inset
        let bottom = inset, top = height - inset
        let path = CGMutablePath()
        path.move(to: CGPoint(x: width / 2, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addArc(center: CGPoint(x: right - radius, y: top - radius), radius: radius,
                    startAngle: .pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: right, y: bottom + radius))
        path.addArc(center: CGPoint(x: right - radius, y: bottom + radius), radius: radius,
                    startAngle: 0, endAngle: -.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addArc(center: CGPoint(x: left + radius, y: bottom + radius), radius: radius,
                    startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
        path.addLine(to: CGPoint(x: left, y: top - radius))
        path.addArc(center: CGPoint(x: left + radius, y: top - radius), radius: radius,
                    startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: width / 2, y: top))
        return path
    }

    private func keyRow(last: String, y: CGFloat, width: CGFloat, accent: NSColor) {
        let keys: [(String, CGFloat)] = [("⌃⌥⌘", 78), (last, 78)]
        let scale = min(1, (width - 32) / 308)
        var x = width - (162 * scale) - 16
        for (key, keyWidth) in keys {
            let capWidth = keyWidth * scale
            let cap = NSView(frame: NSRect(x: x, y: y, width: capWidth, height: 24))
            cap.wantsLayer = true
            cap.layer?.cornerRadius = 5
            cap.layer?.backgroundColor = (key == last ? accent : NSColor.white.withAlphaComponent(0.08)).cgColor
            cap.layer?.borderWidth = 1
            cap.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            let text = NSTextField(labelWithString: key)
            text.font = .systemFont(ofSize: 11, weight: .medium)
            text.textColor = key == last ? .black : .white
            text.alignment = .center
            text.frame = NSRect(x: 0, y: 4, width: capWidth, height: 16)
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
        progressFill.isHidden = progress == nil
        if let progress {
            let fraction = min(1, max(0, progress))
            // Round up so the display never says 0.0 seconds before completion.
            let remaining = ceil((1 - fraction) * 2 * 10) / 10
            hint.stringValue = String(format: "%.1f sec left", remaining)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressFill.strokeEnd = CGFloat(fraction)
            CATransaction.commit()
        } else {
            hint.stringValue = "Hold 2 seconds"
            progressFill.strokeEnd = 0
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
