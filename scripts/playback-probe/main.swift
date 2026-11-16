// Isolated feasibility tool. Never linked into or bundled with PaperMode.
import AppKit
import ApplicationServices

func report(_ values: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
    fflush(stdout)
}

guard CommandLine.arguments.count == 2, ["--toggle", "--lock-probe", "--lock-probe-forward"].contains(CommandLine.arguments[1]) else {
    fputs("Usage: playback-probe --toggle | --lock-probe | --lock-probe-forward\nIsolated QA only. Lock probes release after ten seconds; process watchdog: fifteen seconds.\n", stderr)
    exit(64)
}
guard AXIsProcessTrusted() else {
    report(["event": "error", "reason": "accessibility-required"])
    exit(2)
}
// NX_KEYTYPE_PLAY = 16, NX_SUBTYPE_AUX_CONTROL_BUTTONS = 8.
// Key-down/up occupy the second byte of data1; no key-repeat flag.
var events: [CGEvent] = []
for state in [0xA, 0xB] {
    guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
        context: nil, subtype: 8, data1: (16 << 16) | (state << 8), data2: -1)?.cgEvent else {
        report(["event": "error", "reason": "event-construction-failed"])
        exit(3)
    }
    events.append(event)
}
func dispatch(_ location: CGEventTapLocation) {
    for event in events { event.post(tap: location) }
    report(["event": "dispatched", "command": "toggle-play-pause", "location": location.rawValue,
            "frontmost": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown", "playbackConfirmed": false])
}
if CommandLine.arguments[1] == "--toggle" {
    dispatch(.cghidEventTap)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
    exit(0)
}

// Standalone bounded experiment, not the production LockSession.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let panel = NSPanel(contentRect: NSRect(x: 60, y: 80, width: 540, height: 90),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.level = .screenSaver
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
panel.ignoresMouseEvents = true
let label = NSTextField(labelWithString: "Playback feasibility test — automatic release in 10 seconds\nEmergency exit: Control + Option + Command + L")
label.frame = NSRect(x: 20, y: 15, width: 500, height: 60)
panel.contentView?.addSubview(label)
panel.orderFrontRegardless()
var blocked = 0
var forwarded = 0
var pending = 0
let marker = Int64.random(in: 1...Int64.max)
let forwardMode = CommandLine.arguments[1] == "--lock-probe-forward"
var tap: CFMachPort?
func finish(_ reason: String) -> Never {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
    panel.orderOut(nil)
    report(["event": "finished", "reason": reason, "suppressedEvents": blocked, "forwardedProbeEvents": forwarded])
    exit(0)
}
tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
    options: .defaultTap, eventsOfInterest: CGEventMask.max, callback: { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput { finish("tap-disabled") }
        if type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 37 &&
            event.flags.contains([.maskControl, .maskAlternate, .maskCommand]) { finish("emergency-shortcut") }
        if type.rawValue == 14, let native = NSEvent(cgEvent: event) {
            if forwardMode && pending > 0 && event.getIntegerValueField(.eventSourceUserData) == marker &&
                Int(native.subtype.rawValue) == 8 && (native.data1 >> 16) & 0xffff == 16 {
                pending -= 1; forwarded += 1
                return Unmanaged.passUnretained(event)
            }
            // Preserve unknown lifecycle events; drop media and auxiliary mouse input.
            if !InputPolicy.suppressSystemEvent(subtype: Int(native.subtype.rawValue), data1: native.data1) {
                return Unmanaged.passUnretained(event)
            }
        }
        blocked += 1
        return nil
    }, userInfo: nil)
guard let tap, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
    report(["event": "error", "reason": "tap-unavailable"]); exit(3)
}
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
report(["event": "probe-locked", "durationSeconds": 10])
for (seconds, location) in [(2.0, CGEventTapLocation.cghidEventTap), (4.0, .cgAnnotatedSessionEventTap), (6.0, .cgAnnotatedSessionEventTap)] {
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
        report(["event": "tap-check", "seconds": seconds, "enabled": CGEvent.tapIsEnabled(tap: tap), "suppressedEvents": blocked])
        if forwardMode && seconds > 2 {
            pending = 2
            for event in events { event.setIntegerValueField(.eventSourceUserData, value: marker) }
            dispatch(.cghidEventTap)
        } else { dispatch(location) }
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 10) { finish("test-ended") }
// Process termination also releases the tap; this alarm bounds a stalled run loop.
alarm(15)
app.run()
