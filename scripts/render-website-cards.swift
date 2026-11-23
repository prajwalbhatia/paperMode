import AppKit

@main
struct RenderWebsiteCards {
    static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try render(preparingSeconds: 3, to: output.appendingPathComponent("app-countdown-0.1.2.png"))
        try render(preparingSeconds: nil, to: output.appendingPathComponent("app-reminder-0.1.2.png"))
    }

    private static func render(preparingSeconds: Int?, to url: URL) throws {
        let view = ReminderCard(width: 340, preview: false, preparingSeconds: preparingSeconds)
        if preparingSeconds == nil {
            view.updatePlayback("Ready · request playback without unlocking")
        }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fatalError("Unable to create reminder bitmap")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Unable to encode reminder PNG")
        }
        try png.write(to: url)
    }
}
