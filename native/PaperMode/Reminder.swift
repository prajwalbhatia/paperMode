import AppKit

final class Reminder {
    private var panels: [NSPanel] = []
    var isVisible: Bool { !panels.isEmpty && panels.allSatisfy(\.isVisible) }

    func show(preview: Bool = false) {
        close()
        for screen in NSScreen.screens {
            let area = screen.visibleFrame
            let width = min(CGFloat(350), area.width - 24)
            let panel = NSPanel(
                contentRect: NSRect(x: area.maxX - width - 12, y: area.maxY - 86, width: width, height: 74),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 74))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
            view.layer?.cornerRadius = 12
            let title = NSTextField(labelWithString: preview ? "PaperMode · preview (input is active)" : "PaperMode · input locked")
            title.font = .systemFont(ofSize: 12, weight: .semibold)
            title.textColor = .white
            title.frame = NSRect(x: 14, y: 48, width: width - 28, height: 18)
            let hint = NSTextField(wrappingLabelWithString: "Hold Control + Option + Command + L\nfor 2 seconds to unlock")
            hint.font = .systemFont(ofSize: 12)
            hint.textColor = .white
            hint.frame = NSRect(x: 14, y: 8, width: width - 28, height: 36)
            view.addSubview(title)
            view.addSubview(hint)
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
