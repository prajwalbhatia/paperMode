import Foundation

/// Tracks only the unlock chord, never the user's typed text.
struct UnlockChord {
    private var letterDown = false
    private var startedAt: TimeInterval?
    let holdDuration: TimeInterval = 2

    mutating func update(letterDown: Bool? = nil, modifiersHeld: Bool, now: TimeInterval) {
        if let letterDown { self.letterDown = letterDown }
        if self.letterDown && modifiersHeld {
            if startedAt == nil { startedAt = now }
        } else {
            startedAt = nil
        }
    }

    func isComplete(now: TimeInterval) -> Bool {
        guard let startedAt else { return false }
        return now - startedAt >= holdDuration
    }
}
