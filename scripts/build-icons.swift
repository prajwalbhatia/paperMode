import AppKit
import Foundation

// Vector artwork rendered locally with AppKit. No downloaded assets or fonts.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("assets")
let iconset = root.appendingPathComponent(".build/PaperMode.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
let ink = color(0.09, 0.15, 0.19)
func rounded(_ rect: NSRect, _ radius: CGFloat, _ fill: NSColor) {
    fill.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func artwork() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    NSGradient(starting: color(0.16, 0.25, 0.29), ending: ink)!.draw(in: tile, angle: -90)
    // Warm paper with a folded corner and a deliberately uncluttered silhouette.
    let paper = NSBezierPath()
    paper.move(to: NSPoint(x: 300, y: 226))
    paper.line(to: NSPoint(x: 682, y: 226))
    paper.curve(to: NSPoint(x: 726, y: 270), controlPoint1: NSPoint(x: 710, y: 226), controlPoint2: NSPoint(x: 726, y: 242))
    paper.line(to: NSPoint(x: 726, y: 700))
    paper.line(to: NSPoint(x: 610, y: 816))
    paper.line(to: NSPoint(x: 300, y: 816))
    paper.curve(to: NSPoint(x: 256, y: 772), controlPoint1: NSPoint(x: 272, y: 816), controlPoint2: NSPoint(x: 256, y: 800))
    paper.line(to: NSPoint(x: 256, y: 270))
    paper.curve(to: NSPoint(x: 300, y: 226), controlPoint1: NSPoint(x: 256, y: 242), controlPoint2: NSPoint(x: 272, y: 226))
    paper.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -16); shadow.set()
    color(0.98, 0.96, 0.89).setFill(); paper.fill()
    NSGraphicsContext.restoreGraphicsState()
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 610, y: 816)); fold.line(to: NSPoint(x: 610, y: 724))
    fold.curve(to: NSPoint(x: 634, y: 700), controlPoint1: NSPoint(x: 610, y: 708), controlPoint2: NSPoint(x: 618, y: 700))
    fold.line(to: NSPoint(x: 726, y: 700)); fold.close()
    color(0.80, 0.83, 0.78).setFill(); fold.fill()
    rounded(NSRect(x: 328, y: 630, width: 222, height: 24), 12, ink.withAlphaComponent(0.32))
    rounded(NSRect(x: 328, y: 550, width: 298, height: 24), 12, ink.withAlphaComponent(0.20))
    rounded(NSRect(x: 328, y: 470, width: 190, height: 24), 12, ink.withAlphaComponent(0.20))
    let badge = NSBezierPath(ovalIn: NSRect(x: 530, y: 150, width: 320, height: 320))
    color(0.96, 0.76, 0.38).setFill(); badge.fill()
    let shackle = NSBezierPath(roundedRect: NSRect(x: 638, y: 298, width: 104, height: 102), xRadius: 51, yRadius: 51)
    ink.setStroke(); shackle.lineWidth = 23; shackle.stroke()
    rounded(NSRect(x: 610, y: 230, width: 160, height: 114), 25, ink)
    color(0.96, 0.76, 0.38).setFill()
    NSBezierPath(ovalIn: NSRect(x: 680, y: 277, width: 20, height: 20)).fill()
    rounded(NSRect(x: 685, y: 262, width: 10, height: 22), 5, color(0.96, 0.76, 0.38))
}
func trayArtwork() {
    NSColor.black.setStroke()
    let sheet = NSBezierPath()
    sheet.move(to: NSPoint(x: 11, y: 2)); sheet.line(to: NSPoint(x: 3, y: 2))
    sheet.line(to: NSPoint(x: 3, y: 16)); sheet.line(to: NSPoint(x: 10, y: 16))
    sheet.line(to: NSPoint(x: 14, y: 12)); sheet.line(to: NSPoint(x: 14, y: 10))
    sheet.lineWidth = 1.4; sheet.lineJoinStyle = .round; sheet.stroke()
    let fold = NSBezierPath(); fold.move(to: NSPoint(x: 10, y: 16)); fold.line(to: NSPoint(x: 10, y: 12)); fold.line(to: NSPoint(x: 14, y: 12)); fold.lineWidth = 1.2; fold.stroke()
    rounded(NSRect(x: 5, y: 9, width: 4, height: 1.2), 0.6, .black)
    let shackle = NSBezierPath(roundedRect: NSRect(x: 11, y: 5, width: 4, height: 4.5), xRadius: 2, yRadius: 2)
    shackle.lineWidth = 1.3; shackle.stroke()
    rounded(NSRect(x: 9.5, y: 1.5, width: 7, height: 5), 1.2, .black)
}
func render(_ pixels: Int, to url: URL, tray: Bool = false) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / (tray ? 18 : 1024)); transform.concat()
    if tray { trayArtwork() } else { artwork() }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
try render(1024, to: assets.appendingPathComponent("PaperMode.png"))
try render(18, to: assets.appendingPathComponent("paperTemplate.png"), tray: true)
try render(36, to: assets.appendingPathComponent("paperTemplate@2x.png"), tray: true)
for size in [16, 32, 128, 256, 512] {
    try render(size, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
print("Rendered PaperMode app and menu bar icons")
