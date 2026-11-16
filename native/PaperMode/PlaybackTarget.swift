import AppKit
import ApplicationServices

/// Browser AX work never runs on the event-tap/main thread. No media-key fallback.
final class PlaybackTarget {
    private let queue = DispatchQueue(label: "PaperMode.playback")
    private let cancellation = NSLock()
    private var cancelled = false
    private var target: Target?
    private struct Target {
        let pid: pid_t
        let window: AXUIElement
        let button: AXUIElement
        let document: AXUIElement
        let url: String
    }

    private func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    private func string(_ element: AXUIElement, _ name: String) -> String {
        value(element, name) as? String ?? ""
    }
    private func canPress(_ element: AXUIElement) -> Bool {
        var result: CFArray?
        return AXUIElementCopyActionNames(element, &result) == .success &&
            (result as? [String] ?? []).contains("AXPress")
    }
    private func documentURL(_ element: AXUIElement) -> String {
        value(element, "AXURL").map { String(describing: $0) } ?? ""
    }
    private func scan(pid: pid_t) -> Target? {
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.15)
        guard let raw = value(root, "AXFocusedWindow"), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeBitCast(raw, to: AXUIElement.self)
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var found: [Target] = []
        var visited = 0
        var incomplete = false
        func walk(_ element: AXUIElement, _ document: AXUIElement?, _ depth: Int) {
            guard visited < 3000, depth < 50, ProcessInfo.processInfo.systemUptime < deadline else { incomplete = true; return }
            guard !isCancelled else { incomplete = true; return }
            visited += 1
            let role = string(element, "AXRole")
            let web = role == "AXWebArea" ? element : document
            if role == "AXButton", let web {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                if names.contains(where: PlaybackPolicy.isPlayerLabel), canPress(element) {
                    let url = documentURL(web)
                    if !url.isEmpty { found.append(Target(pid: pid, window: window, button: element, document: web, url: url)) }
                }
            }
            // Failure to enumerate children is not proof that a target is unique.
            var children: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children)
            if result != .success && result != .attributeUnsupported && result != .noValue { incomplete = true }
            for child in children as? [AXUIElement] ?? [] { walk(child, web, depth + 1) }
        }
        walk(window, nil, 0)
        guard !incomplete, found.count == 1 else { return nil }
        return found[0]
    }
    private var isCancelled: Bool {
        cancellation.lock(); defer { cancellation.unlock() }; return cancelled
    }
    func cancel() {
        cancellation.lock(); cancelled = true; cancellation.unlock()
    }
    func bind(completion: @escaping (Bool) -> Void) {
        let app = NSWorkspace.shared.frontmostApplication
        let supported = ["com.google.Chrome", "com.apple.Safari"].contains(app?.bundleIdentifier ?? "")
        let pid = supported ? app?.processIdentifier : nil
        queue.async { [self] in
            if let pid, !isCancelled { target = scan(pid: pid) }
            let available = target != nil && !isCancelled
            DispatchQueue.main.async { completion(available) }
        }
    }
    func request(completion: @escaping (String) -> Void) {
        queue.async { [self] in
            var message = "Player unavailable · unlock to control video"
            if let saved = target, !isCancelled,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid,
               let current = scan(pid: saved.pid),
               CFEqual(saved.window, current.window), CFEqual(saved.button, current.button),
               CFEqual(saved.document, current.document), saved.url == current.url,
               documentURL(saved.document) == saved.url,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid, !isCancelled {
                // Never retry a toggle: AX success does not confirm video state.
                let result = AXUIElementPerformAction(saved.button, "AXPress" as CFString)
                message = result == .success ? "Playback requested · check the video" : "Request failed · unlock to control video"
            }
            DispatchQueue.main.async { completion(message) }
        }
    }
}
