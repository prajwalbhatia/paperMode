// Standalone QA utility; never linked into PaperMode.
import AppKit
import ApplicationServices

func emit(_ value: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!); fflush(stdout)
}
func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func string(_ element: AXUIElement, _ name: String) -> String {
    attribute(element, name) as? String ?? ""
}
func actions(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
    return names as? [String] ?? []
}
func label(_ element: AXUIElement) -> String {
    let fields = ["AXTitle", "AXDescription", "AXHelp"].map { string(element, $0) }.filter { !$0.isEmpty }
    return Array(NSOrderedSet(array: fields)).compactMap { $0 as? String }.joined(separator: " | ")
}
func state(_ label: String) -> String? {
    let value = label.lowercased()
    // English-label heuristic only; not a general player identity guarantee.
    if value.range(of: "^pause(?:\\b)", options: .regularExpression) != nil { return "playing" }
    if value.range(of: "^play(?:\\b)", options: .regularExpression) != nil { return "paused" }
    return nil
}
struct Candidate {
    let element: AXUIElement
    let document: AXUIElement
    let documentURL: String
    let path: String
    let name: String
}
let args = CommandLine.arguments
guard args.count == 3, ["--inspect", "--cycle", "--locked-cycle"].contains(args[1]), ["chrome", "safari"].contains(args[2]) else {
    fputs("Usage: accessibility-probe --inspect|--cycle|--locked-cycle chrome|safari\nCycle requires exactly one Play/Pause AXPress control inside a web area of the focused/main window. Locked cycle exits after two actions, with a ten-second process watchdog.\n", stderr); exit(64)
}
guard AXIsProcessTrusted() else { emit(["event": "error", "reason": "accessibility-required"]); exit(2) }
let bundle = args[2] == "chrome" ? "com.google.Chrome" : "com.apple.Safari"
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
    emit(["event": "error", "reason": "browser-not-running"]); exit(2)
}
let root = AXUIElementCreateApplication(app.processIdentifier)
AXUIElementSetMessagingTimeout(root, 0.5)
guard let rawWindow = attribute(root, "AXFocusedWindow") ?? attribute(root, "AXMainWindow"), CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else {
    emit(["event": "error", "reason": "no-browser-window"]); exit(2)
}
let window = unsafeBitCast(rawWindow, to: AXUIElement.self)
var visited = 0
var candidates: [Candidate] = []
func inspect(_ element: AXUIElement, _ path: String, _ document: AXUIElement?, _ depth: Int) {
    guard visited < 6000, depth < 50 else { return }
    visited += 1
    let role = string(element, "AXRole")
    let web = role == "AXWebArea" ? element : document
    if role == "AXButton" {
        let name = label(element)
        if state(name) != nil { emit(["event": "control-found", "label": name, "hasWebAncestor": web != nil, "actions": actions(element)]) }
    }
    if role == "AXButton", let web {
        let name = label(element)
        if state(name) != nil, actions(element).contains("AXPress") {
            // Retain URL only in memory for document-change detection; never log it.
            let url = attribute(web, "AXURL").map { String(describing: $0) } ?? ""
            candidates.append(Candidate(element: element, document: web, documentURL: url, path: path, name: name))
        }
    }
    let children = attribute(element, "AXChildren") as? [AXUIElement] ?? []
    for (index, child) in children.enumerated() { inspect(child, path + ".\(index)", web, depth + 1) }
}
inspect(window, "window", nil, 0)
emit(["event": "inspection", "browser": args[2], "visited": visited,
      "candidates": candidates.map { ["label": $0.name, "path": $0.path, "state": state($0.name) ?? "unknown"] }])
if args[1] == "--inspect" { exit(0) }
guard visited < 6000, candidates.count == 1, let target = candidates.first, let before = state(target.name) else {
    emit(["event": "refused", "reason": "no-unique-confirmed-player"]); exit(3)
}
func unchanged() -> Bool {
    let current = attribute(target.document, "AXURL").map { String(describing: $0) } ?? ""
    return !target.documentURL.isEmpty && current == target.documentURL &&
        string(target.element, "AXRole") == "AXButton" && actions(target.element).contains("AXPress")
}
guard unchanged() else { emit(["event": "refused", "reason": "target-unverifiable"]); exit(3) }
var inputTap: CFMachPort?
var reminder: NSPanel?
var suppressed = 0
var eventTypes: [String: Int] = [:]
func releaseInput() {
    if let tap = inputTap {
        emit(["event": "tap-check-before-release", "enabled": CGEvent.tapIsEnabled(tap: tap), "suppressedEvents": suppressed, "eventTypes": eventTypes])
        CGEvent.tapEnable(tap: tap, enable: false)
        CFMachPortInvalidate(tap)
        reminder?.orderOut(nil)
        emit(["event": "input-filter-released"])
    }
}
if args[1] == "--locked-cycle" {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let panel = NSPanel(contentRect: NSRect(x: 60, y: 80, width: 520, height: 90),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.ignoresMouseEvents = true
    let text = NSTextField(labelWithString: "Accessibility playback test — input locked briefly\nEmergency exit: Control + Option + Command + L")
    text.frame = NSRect(x: 20, y: 15, width: 480, height: 60)
    panel.contentView?.addSubview(text)
    reminder = panel
    inputTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
        options: .defaultTap, eventsOfInterest: CGEventMask.max, callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                emit(["event": "aborted", "reason": "tap-disabled"]); exit(5)
            }
            if type == .keyDown && event.getIntegerValueField(.keyboardEventKeycode) == 37 &&
                event.flags.contains([.maskControl, .maskAlternate, .maskCommand]) {
                emit(["event": "aborted", "reason": "emergency-shortcut"]); exit(5)
            }
            if type.rawValue == 14, let native = NSEvent(cgEvent: event),
                !InputPolicy.suppressSystemEvent(subtype: Int(native.subtype.rawValue), data1: native.data1) {
                return Unmanaged.passUnretained(event)
            }
            eventTypes[String(type.rawValue), default: 0] += 1
            suppressed += 1
            return nil
        }, userInfo: nil)
    guard let tap = inputTap, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
        emit(["event": "error", "reason": "tap-unavailable"]); exit(5)
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    panel.orderFrontRegardless()
    alarm(10)
    emit(["event": "input-filter-enabled", "enabled": CGEvent.tapIsEnabled(tap: tap)])
}
// Poll without reissuing AXPress: distinguish delayed UI updates from a missed action.
func awaitState(_ expected: String) -> String? {
    let start = Date()
    var last: String?
    repeat {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        let current = state(label(target.element))
        if current != last {
            emit(["event": "state-observed", "state": current ?? "unknown",
                  "elapsedMilliseconds": Int(Date().timeIntervalSince(start) * 1000)])
            last = current
        }
        if current == expected { return current }
    } while Date().timeIntervalSince(start) < 3
    return last
}
emit(["event": "action-context", "browserActive": app.isActive,
      "frontmostBundle": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"])
let first = AXUIElementPerformAction(target.element, "AXPress" as CFString)
let observedAfter = awaitState(before == "playing" ? "paused" : "playing")
let afterLabel = label(target.element)
let after = observedAfter
emit(["event": "first-action", "axResult": first.rawValue, "before": before, "after": after ?? "unknown", "label": afterLabel])
if let tap = inputTap { emit(["event": "tap-check-after-first", "enabled": CGEvent.tapIsEnabled(tap: tap)]) }
guard first == .success, unchanged(), let after, after != before else {
    emit(["event": "unconfirmed", "reason": "no-state-transition-on-retained-element", "restoreAttempted": false]); releaseInput(); exit(4)
}
let second = AXUIElementPerformAction(target.element, "AXPress" as CFString)
let restored = awaitState(before)
emit(["event": "second-action", "axResult": second.rawValue, "state": restored ?? "unknown",
      "restoredByLabel": second == .success && restored == before])
releaseInput()
exit(second == .success && restored == before ? 0 : 4)
