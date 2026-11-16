import Foundation

struct PlaybackPolicy {
    static func isPlayerLabel(_ label: String) -> Bool {
        // Limit first release to observed English player labels; reject Play/Pause toggles.
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["play", "pause", "play play", "pause pause", "play (k)", "pause (k)",
                "play keyboard shortcut k", "pause keyboard shortcut k"].contains(name)
    }
    static func isUniqueMediaControl(count: Int, supportedDocument: Bool, hasContainer: Bool, hasTimeline: Bool) -> Bool {
        count == 1 && supportedDocument && hasContainer && hasTimeline
    }
    static func isPlayerContainer(_ name: String) -> Bool {
        ["YouTube Video Player", "YouTube Video Player in Fullscreen", "Video Player"].contains(name)
    }
    static func isTimelineLabel(_ name: String) -> Bool {
        ["Seek slider", "Progress Bar"].contains(name)
    }
    static func isSupportedPlayerDocument(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        switch url.host?.lowercased() {
        case "youtube.com", "www.youtube.com":
            return url.path.hasPrefix("/embed/") || (url.path == "/watch" && (url.queryItems ?? []).contains { $0.name == "v" && !($0.value ?? "").isEmpty })
        case "www.youtube-nocookie.com": return url.path.hasPrefix("/embed/")
        case "app.tpstreams.com": return url.path.hasPrefix("/embed/")
        default: return false
        }
    }
    private var spaceDown = false
    mutating func update(down: Bool, modifiers: Bool, repeated: Bool) -> Bool {
        if !down { spaceDown = false; return false }
        guard !spaceDown else { return false }
        spaceDown = true
        return modifiers && !repeated
    }
}

/// Only discovery is retried. A playback toggle is never retried.
enum PlaybackReadiness {
    enum Decision { case ready, wait, stop }
    static func decide(cancelled: Bool, sameTarget: Bool, actionable: Bool,
                       now: TimeInterval, deadline: TimeInterval) -> Decision {
        guard !cancelled, sameTarget, now < deadline else { return .stop }
        if actionable { return .ready }
        return now < deadline ? .wait : .stop
    }
}

/// A per-object timeout never exceeds the remaining operation budget.
enum PlaybackBudget {
    static func timeout(now: TimeInterval, deadline: TimeInterval) -> Float? {
        let remaining = deadline - now
        guard remaining > 0 else { return nil }
        return Float(min(0.15, remaining))
    }
}
