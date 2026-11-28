import Foundation

struct PlaybackPolicy {
    static let maxAccessibilityDepth = 50
    static func isSupportedBrowser(_ bundleID: String?) -> Bool {
        ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox"].contains(bundleID ?? "")
    }
    static func isPlayerLabel(_ label: String) -> Bool {
        // Limit first release to observed English player labels; reject Play/Pause toggles.
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["play", "pause", "play play", "pause pause", "play (k)", "pause (k)",
                "play keyboard shortcut k", "pause keyboard shortcut k", "play video", "pause video"].contains(name)
    }
    static func isUniqueMediaControl(count: Int, supportedDocument: Bool, hasContainer: Bool, hasTimeline: Bool) -> Bool {
        count == 1 && supportedDocument && hasContainer && hasTimeline
    }
    /// A video can expose an outer "Play Video" overlay as well as its inner
    /// Play/Pause control. Select the inner control only when both buttons
    /// belong to the same player and one sits strictly closer to its timeline.
    static func nestedPlayerControlIndex<Group>(candidateGroups: [[Group]], timelineGroups: [Group],
                                                same: (Group, Group) -> Bool) -> Int? {
        guard candidateGroups.count == 2, !timelineGroups.isEmpty else { return nil }
        func isPrefix(_ prefix: [Group], of path: [Group]) -> Bool {
            prefix.count <= path.count && zip(prefix, path).allSatisfy { same($0, $1) }
        }
        guard candidateGroups.allSatisfy({ !$0.isEmpty && isPrefix($0, of: timelineGroups) }) else { return nil }
        let inner = candidateGroups[0].count > candidateGroups[1].count ? 0 : 1
        let outer = 1 - inner
        guard candidateGroups[inner].count >= 2,
              candidateGroups[outer].count < candidateGroups[inner].count,
              isPrefix(candidateGroups[outer], of: candidateGroups[inner]) else { return nil }
        return inner
    }
    static func isPlayerContainer(_ name: String) -> Bool {
        ["YouTube Video Player", "YouTube Video Player in Fullscreen",
         "YouTube Video Player in Full screen", "Video Player"].contains(name)
    }
    static func isTimelineLabel(_ name: String) -> Bool {
        ["Seek slider", "Progress Bar"].contains(name)
    }
    static func isGeneralVideoDocument(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.user == nil,
              url.password == nil, url.port == nil || url.port == 443,
              let host = url.host?.lowercased(), host.contains("."), !host.hasSuffix(".local"),
              !host.allSatisfy({ $0.isNumber || $0 == "." }) else { return false }
        return !["youtube.com", "www.youtube.com", "www.youtube-nocookie.com",
                  "app.tpstreams.com", "www.udemy.com"].contains(host)
    }
    static func isGeneralTimelineLabel(_ name: String) -> Bool {
        ["seek slider", "progress bar", "progress", "position", "seek", "scrubber", "timeline", "video progress"]
            .contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
    static func isMediaEvidenceLabel(_ name: String) -> Bool {
        ["mute", "unmute", "volume", "volume slider", "fullscreen", "full screen",
         "enter full screen", "exit full screen", "picture in picture", "captions",
         "closed captions", "subtitles", "playback speed", "playback rate"]
            .contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
    static func isExplicitFiveSecondSkip(_ name: String, direction: Int) -> Bool {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return direction < 0
            ? ["rewind 5 seconds", "skip back 5 seconds", "back 5 seconds"].contains(label)
            : ["forward 5 seconds", "skip forward 5 seconds", "ahead 5 seconds"].contains(label)
    }
    static func isGeneralPlayerStructure(playCount: Int, timelineCount: Int,
                                         hasMediaEvidence: Bool, sharedGroupDepth: Int,
                                         compactFullscreen: Bool = false,
                                         namedPlayerGroup: Bool = false) -> Bool {
        playCount == 1 && timelineCount == 1 && hasMediaEvidence &&
            (sharedGroupDepth >= 3 ||
             (compactFullscreen && (sharedGroupDepth >= 1 ||
                 (sharedGroupDepth == 0 && namedPlayerGroup))))
    }
    static func sharedPlayerGroup<Group>(play: [Group], timeline: [Group], evidence: [[Group]],
                                         same: (Group, Group) -> Bool) -> (group: Group, depth: Int)? {
        for depth in play.indices.reversed() {
            let group = play[depth]
            if timeline.contains(where: { same($0, group) }) &&
               evidence.contains(where: { $0.contains(where: { same($0, group) }) }) {
                return (group, depth)
            }
        }
        return nil
    }
    static func isUdemyLectureDocument(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.user == nil,
              url.password == nil, url.port == nil || url.port == 443,
              url.host?.lowercased() == "www.udemy.com" else { return false }
        return url.path.range(of: "^/course/[^/]+/learn/lecture/[0-9]+/?$", options: .regularExpression) != nil
    }
    static func isSupportedPlayerDocument(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        switch url.host?.lowercased() {
        case "youtube.com", "www.youtube.com":
            return url.path.hasPrefix("/embed/") || (url.path == "/watch" && (url.queryItems ?? []).contains { $0.name == "v" && !($0.value ?? "").isEmpty })
        case "www.youtube-nocookie.com": return url.path.hasPrefix("/embed/")
        case "app.tpstreams.com": return url.path.hasPrefix("/embed/")
        case "www.udemy.com": return isUdemyLectureDocument(value)
        default: return false
        }
    }
    static func isYouTubePlayerDocument(_ value: String) -> Bool {
        guard isSupportedPlayerDocument(value), let host = URLComponents(string: value)?.host?.lowercased() else { return false }
        return ["youtube.com", "www.youtube.com", "www.youtube-nocookie.com"].contains(host)
    }
    static func isTPStreamsEmbedDocument(_ value: String) -> Bool {
        isSupportedPlayerDocument(value) && URLComponents(string: value)?.host?.lowercased() == "app.tpstreams.com"
    }
    static func isCourseVideoFocus(role: String, title: String, description: String, directPlayerChild: Bool) -> Bool {
        role == "AXGroup" && title.isEmpty && description.isEmpty && directPlayerChild
    }
    private var spaceDown = false
    mutating func update(down: Bool, modifiers: Bool, repeated: Bool) -> Bool {
        if !down { spaceDown = false; return false }
        guard !spaceDown else { return false }
        spaceDown = true
        return modifiers && !repeated
    }
}

/// Convert a five-second skip to the value scale exposed by each supported player.
enum SeekPolicy {
    static let seconds = 5.0

    private static func time(_ text: String) -> Double? {
        if text.contains(":") {
            let rawParts = text.split(separator: ":")
            let parts = rawParts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == rawParts.count, (2...3).contains(parts.count),
                  parts.allSatisfy({ $0 >= 0 && $0.isFinite }) else { return nil }
            return parts.reduce(0) { $0 * 60 + $1 }
        }
        let words = text.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty, words.count.isMultiple(of: 2) else { return nil }
        var total = 0.0
        var used = Set<String>()
        for index in stride(from: 0, to: words.count, by: 2) {
            guard let amount = Double(words[index]), amount >= 0, amount.isFinite else { return nil }
            let unit = words[index + 1].trimmingCharacters(in: .punctuationCharacters)
            guard !used.contains(unit) else { return nil }
            used.insert(unit)
            switch unit {
            case "hour", "hours": total += amount * 3600
            case "minute", "minutes": total += amount * 60
            case "second", "seconds": total += amount
            default: return nil
            }
        }
        return total
    }

    private static func times(_ description: String) -> (Double, Double)? {
        let separator = description.contains(" of ") ? " of " : " / "
        let parts = description.components(separatedBy: separator)
        guard parts.count == 2, let elapsed = time(parts[0]), let total = time(parts[1]),
              total > 0, elapsed >= 0, elapsed <= total else { return nil }
        return (elapsed, total)
    }

    static func duration(_ description: String) -> Double? { times(description)?.1 }

    static func values(value: Any?, minimum: Any?, maximum: Any?, description: String,
                       url: String) -> (current: Double, minimum: Double, maximum: Double)? {
        guard PlaybackPolicy.isSupportedPlayerDocument(url) || PlaybackPolicy.isGeneralVideoDocument(url) else { return nil }
        if let current = value as? NSNumber, let lower = minimum as? NSNumber, let upper = maximum as? NSNumber,
           current.doubleValue.isFinite, lower.doubleValue.isFinite, upper.doubleValue.isFinite,
           upper.doubleValue > lower.doubleValue, current.doubleValue >= lower.doubleValue,
           current.doubleValue <= upper.doubleValue {
            return (current.doubleValue, lower.doubleValue, upper.doubleValue)
        }
        guard let (elapsed, total) = times(description) else { return nil }
        return (elapsed, 0, total)
    }

    static func next(current: Double, minimum: Double, maximum: Double, description: String,
                     url: String, direction: Int) -> Double? {
        guard direction == -1 || direction == 1, current.isFinite, minimum.isFinite, maximum.isFinite,
              maximum > minimum, current >= minimum, current <= maximum,
              let host = URLComponents(string: url)?.host?.lowercased() else { return nil }
        let range = maximum - minimum
        let total = duration(description)
        let delta: Double
        switch host {
        case "youtube.com", "www.youtube.com", "www.youtube-nocookie.com":
            if let total, total > 0, abs(range - total) <= max(1, total * 0.01) {
                delta = seconds
            } else if let total, total > 0, range >= 99, range <= 101 {
                delta = seconds * range / total
            } else if range > 100 {
                delta = seconds
            } else { return nil }
        case "app.tpstreams.com":
            guard let total, total > 0 else { return nil }
            if abs(range - total) <= max(1, total * 0.01) {
                delta = seconds
            } else if range >= 99, range <= 101 {
                delta = seconds * range / total
            } else { return nil }
        default:
            guard PlaybackPolicy.isGeneralVideoDocument(url),
                  let (elapsed, total) = times(description), total > 0 else { return nil }
            if abs(range - total) <= max(1, total * 0.01) {
                guard abs(current - minimum - elapsed) <= 2 else { return nil }
                delta = seconds
            } else if range >= 99, range <= 101 {
                let numericElapsed = (current - minimum) * total / range
                let roundingTolerance = max(2, min(10, total / range))
                guard abs(numericElapsed - elapsed) <= roundingTolerance else { return nil }
                delta = seconds * range / total
            } else if abs(range / 1000 - total) <= max(1, total * 0.01) {
                guard abs((current - minimum) / 1000 - elapsed) <= 2 else { return nil }
                delta = seconds * 1000
            } else { return nil }
        }
        let result = min(maximum, max(minimum, current + Double(direction) * delta))
        return result == current ? nil : result
    }
}

struct SeekChord {
    private var held: Set<Int64> = []
    mutating func update(keycode: Int64, down: Bool, modifiers: Bool, repeated: Bool) -> Int? {
        guard keycode == 123 || keycode == 124 else { return nil }
        if !down { held.remove(keycode); return nil }
        guard !held.contains(keycode) else { return nil }
        held.insert(keycode)
        return modifiers && !repeated ? (keycode == 123 ? -1 : 1) : nil
    }
}

enum PlaybackClick {
    static func center(origin: CGPoint, size: CGSize) -> CGPoint? {
        guard origin.x.isFinite, origin.y.isFinite, size.width.isFinite, size.height.isFinite,
              origin.x >= 0, origin.y >= 0,
              size.width >= 16, size.width <= 120,
              size.height >= 16, size.height <= 120 else { return nil }
        return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }
}

enum SeekClick {
    // Only our paired synthetic mouse events may pass the session tap.
    static let marker = Int64.random(in: Int64.min...Int64.max)

    static func x(current: Double, next: Double, minimum: Double, maximum: Double,
                  left: Double, width: Double) -> Double? {
        guard current.isFinite, next.isFinite, minimum.isFinite, maximum.isFinite,
              left.isFinite, width.isFinite, maximum > minimum, width >= 100,
              current >= minimum, current <= maximum, next >= minimum, next <= maximum,
              next != current else { return nil }
        let currentX = left + width * (current - minimum) / (maximum - minimum)
        let desiredX = left + width * (next - minimum) / (maximum - minimum)
        var targetX = desiredX.rounded()
        if targetX == currentX.rounded() {
            targetX += next > current ? 1 : -1
        }
        return min(left + width - 2, max(left + 2, targetX))
    }

    static func restorePoint(previous: CGPoint, barOrigin: CGPoint, barSize: CGSize) -> CGPoint {
        let barY = barOrigin.y + barSize.height / 2
        guard previous.x >= barOrigin.x - 12, previous.x <= barOrigin.x + barSize.width + 12,
              abs(previous.y - barY) <= 28 else { return previous }
        // If the pointer was already on the bar, leave it over the video
        // instead so a seek preview does not remain pinned during the lock.
        return CGPoint(x: previous.x, y: barY > 70 ? barY - 64 : barY + 64)
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
