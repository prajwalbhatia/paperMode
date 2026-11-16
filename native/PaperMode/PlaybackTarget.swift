import AppKit
import ApplicationServices

/// Browser AX work never runs on the event-tap/main thread. No media-key fallback.
final class PlaybackTarget {
    private let queue = DispatchQueue(label: "PaperMode.playback")
    private let cancellation = NSLock()
    private var cancelled = false
    private var target: Target?
    // Accessed only on the serial AX queue. All AX objects share this operation budget.
    private var deadline: TimeInterval = 0
    private var queryFailed = false
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private func prepareQuery(_ element: AXUIElement) -> Bool {
        guard !isCancelled, let timeout = PlaybackBudget.timeout(now: now, deadline: deadline) else {
            queryFailed = true; return false
        }
        guard AXUIElementSetMessagingTimeout(element, timeout) == .success else {
            queryFailed = true; return false
        }
        return true
    }
    private func accept(_ result: AXError) -> Bool {
        guard now < deadline, !isCancelled else { queryFailed = true; return false }
        if result == .success { return true }
        if result != .attributeUnsupported && result != .noValue { queryFailed = true }
        return false
    }
    private func diagnostic(_ fields: [String: Any]) {
        guard ProcessInfo.processInfo.environment["PAPERMODE_PLAYBACK_DIAGNOSTICS"] == "1",
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return }
        FileHandle.standardError.write(data + Data([10]))
    }
    private struct Target {
        let pid: pid_t
        let window: AXUIElement
        let button: AXUIElement
        let document: AXUIElement
        let player: AXUIElement
        let url: String
    }

    private func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        guard prepareQuery(element) else { return nil }
        var result: CFTypeRef?
        return accept(AXUIElementCopyAttributeValue(element, name as CFString, &result)) ? result : nil
    }
    private func string(_ element: AXUIElement, _ name: String) -> String {
        value(element, name) as? String ?? ""
    }
    private func canPress(_ element: AXUIElement) -> Bool {
        guard prepareQuery(element) else { return false }
        var result: CFArray?
        return accept(AXUIElementCopyActionNames(element, &result)) &&
            (result as? [String] ?? []).contains("AXPress")
    }
    private func documentURL(_ element: AXUIElement) -> String {
        value(element, "AXURL").map { String(describing: $0) } ?? ""
    }
    private final class PlayerContext {
        let element: AXUIElement
        var hasTimeline = false
        init(_ element: AXUIElement) { self.element = element }
    }
    private func scan(pid: pid_t, requirePress: Bool = true) -> Target? {
        let operationDeadline = deadline
        deadline = min(deadline, now + 2)
        defer { deadline = operationDeadline }
        queryFailed = false
        let root = AXUIElementCreateApplication(pid)
        guard let raw = value(root, "AXFocusedWindow"), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeBitCast(raw, to: AXUIElement.self)
        var found: [(AXUIElement, AXUIElement, PlayerContext?)] = []
        var visited = 0
        var incomplete = false
        func walk(_ element: AXUIElement, _ document: AXUIElement?, _ context: PlayerContext?, _ depth: Int) {
            guard !queryFailed, visited < 3000, depth < 50, now < deadline, !isCancelled else { incomplete = true; return }
            visited += 1
            let role = string(element, "AXRole")
            let web = role == "AXWebArea" ? element : document
            var player = role == "AXWebArea" ? nil : context
            if role == "AXGroup" {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                if names.contains(where: PlaybackPolicy.isPlayerContainer) { player = PlayerContext(element) }
            }
            if role == "AXSlider", let player {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                if names.contains(where: PlaybackPolicy.isTimelineLabel) { player.hasTimeline = true }
            }
            if role == "AXButton", let web {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                // Count every player-like control before URL, container, enabled or action filtering.
                if names.contains(where: PlaybackPolicy.isPlayerLabel) { found.append((element, web, player)) }
            }
            for child in value(element, "AXChildren") as? [AXUIElement] ?? [] {
                walk(child, web, player, depth + 1)
                if incomplete || queryFailed { break }
            }
        }
        walk(window, nil, nil, 0)
        diagnostic(["playback": "scan", "visited": visited, "incomplete": incomplete || queryFailed, "candidates": found.count])
        guard !incomplete, !queryFailed, found.count == 1, let candidate = found.first,
              let player = candidate.2, player.hasTimeline else { return nil }
        let url = documentURL(candidate.1)
        guard PlaybackPolicy.isUniqueMediaControl(count: found.count, supportedDocument: PlaybackPolicy.isSupportedPlayerDocument(url),
            hasContainer: candidate.2 != nil, hasTimeline: player.hasTimeline),
              (value(candidate.0, "AXEnabled") as? Bool) == true,
              (!requirePress || canPress(candidate.0)), !queryFailed, now < deadline else { return nil }
        return Target(pid: pid, window: window, button: candidate.0, document: candidate.1, player: player.element, url: url)
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
        diagnostic(["playback": "bind", "browser": app?.bundleIdentifier ?? "none", "supported": supported])
        let pid = supported ? app?.processIdentifier : nil
        let expiresAt = now + 3
        queue.async { [self] in
            deadline = expiresAt
            guard let pid, !isCancelled, let anchor = scan(pid: pid, requirePress: false) else {
                DispatchQueue.main.async { completion(false) }; return
            }
            awaitReadiness(anchor, deadline: expiresAt, completion: completion)
        }
    }
    private func sameTarget(_ left: Target, _ right: Target) -> Bool {
        CFEqual(left.window, right.window) && CFEqual(left.button, right.button) &&
            CFEqual(left.document, right.document) && CFEqual(left.player, right.player) && left.url == right.url
    }
    private func awaitReadiness(_ anchor: Target, deadline: TimeInterval, completion: @escaping (Bool) -> Void) {
        self.deadline = deadline
        guard now < deadline, !isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == anchor.pid,
              let current = scan(pid: anchor.pid, requirePress: false), sameTarget(anchor, current) else {
            diagnostic(["playback": "binding-ended", "reason": "target-changed-or-unavailable"])
            DispatchQueue.main.async { completion(false) }; return
        }
        let decision = PlaybackReadiness.decide(cancelled: isCancelled,
            sameTarget: !queryFailed, actionable: canPress(current.button),
            now: ProcessInfo.processInfo.systemUptime, deadline: deadline)
        switch decision {
        case .ready:
            target = current
            diagnostic(["playback": "binding-ready"])
            DispatchQueue.main.async { completion(true) }
        case .stop:
            diagnostic(["playback": "binding-ended", "reason": "player-not-ready"])
            DispatchQueue.main.async { completion(false) }
        case .wait:
            queue.asyncAfter(deadline: .now() + 0.25) { [self] in
                awaitReadiness(anchor, deadline: deadline, completion: completion)
            }
        }
    }

    func request(completion: @escaping (String) -> Void) {
        let expiresAt = now + 3
        queue.async { [self] in
            deadline = expiresAt
            queryFailed = false
            var message = "Player unavailable · unlock to control video"
            if let saved = target, now < expiresAt, !isCancelled,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid,
               let current = scan(pid: saved.pid),
               sameTarget(saved, current),
               documentURL(saved.document) == saved.url,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid,
               !queryFailed, prepareQuery(saved.button), now < expiresAt, !isCancelled {
                // Never retry a toggle: AX success does not confirm video state.
                let result = AXUIElementPerformAction(saved.button, "AXPress" as CFString)
                message = result == .success ? "Playback requested · check the video" : "Request failed · unlock to control video"
            }
            DispatchQueue.main.async { completion(message) }
        }
    }
}
