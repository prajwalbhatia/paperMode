import Foundation

struct PlaybackPolicy {
    static func isPlayerLabel(_ label: String) -> Bool {
        // Limit first release to observed English player labels; reject Play/Pause toggles.
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["play", "pause", "play play", "pause pause", "play (k)", "pause (k)",
                "play keyboard shortcut k", "pause keyboard shortcut k"].contains(name)
    }
    private var spaceDown = false
    mutating func update(down: Bool, modifiers: Bool, repeated: Bool) -> Bool {
        if !down { spaceDown = false; return false }
        guard !spaceDown else { return false }
        spaceDown = true
        return modifiers && !repeated
    }
}
