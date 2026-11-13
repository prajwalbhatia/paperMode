import AppKit

final class Reminder {
    private var panels: [NSPanel] = []
    var isVisible: Bool { !panels.isEmpty && panels.allSatisfy(\.isVisible) }

    func show(preview: Bool = false) {
        close()
        for screen in NSScreen.screens {
            let area = screen.visibleFrame
            let width = min(CGFloat(332), area.width - 24)
            let panel = NSPanel(
                contentRect: NSRect(x: area.maxX - width - 12, y: area.maxY - 132, width: width, height: 116),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            let view = ReminderCard(width: width, preview: preview)
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func close() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}


/// A compact reminder card; only this rectangle is painted over the course.
final class ReminderCard: NSView {
    init(width: CGFloat, preview: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 116))
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 0.98).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        let accent = NSColor(srgbRed: 0.96, green: 0.78, blue: 0.43, alpha: 1)
        let icon = NSImageView(frame: NSRect(x: 16, y: 80, width: 20, height: 20))
        icon.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil)
        icon.contentTintColor = accent
        addSubview(icon)
        label("PaperMode", frame: NSRect(x: 44, y: 80, width: 110, height: 20), size: 14, weight: .semibold, color: .white)
        let status = preview ? "PREVIEW" : "LOCKED"
        label(status, frame: NSRect(x: width - 94, y: 83, width: 78, height: 16), size: 10, weight: .semibold, color: accent, alignment: .right)

        let keys: [(String, CGFloat)] = [("⌃ Control", 77), ("⌥ Option", 77), ("⌘ Cmd", 70), ("L", 34)]
        var x: CGFloat = 16
        let scale = min(1, (width - 32) / 276)
        for (key, keyWidth) in keys {
            let capWidth = keyWidth * scale
            let cap = NSView(frame: NSRect(x: x, y: 39, width: capWidth, height: 29))
            cap.wantsLayer = true
            cap.layer?.cornerRadius = 6
            cap.layer?.backgroundColor = (key == "L" ? accent : NSColor.white.withAlphaComponent(0.08)).cgColor
            cap.layer?.borderWidth = 1
            cap.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
            let text = NSTextField(labelWithString: key)
            text.font = .systemFont(ofSize: 12, weight: .medium)
            text.textColor = key == "L" ? NSColor.black : .white
            text.alignment = .center
            text.frame = NSRect(x: 0, y: 6, width: capWidth, height: 17)
            cap.addSubview(text)
            addSubview(cap)
            x += capWidth + 6 * scale
        }
        label(preview ? "Input stays active during this preview" : "Hold all four keys for 2 seconds to unlock",
              frame: NSRect(x: 16, y: 13, width: width - 32, height: 17),
              size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))
    }

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
