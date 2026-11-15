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

    /// nil means idle; 0...1 represents the same hold used to unlock.
    func progress(now: TimeInterval) -> Double? {
        guard let startedAt else { return nil }
        return min(1, max(0, (now - startedAt) / holdDuration))
    }

    func isComplete(now: TimeInterval) -> Bool {
        progress(now: now) == 1
    }
}
