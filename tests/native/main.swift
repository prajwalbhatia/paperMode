import Foundation

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAIL: \(name)") }
    print("PASS: \(name)")
}
var chord = UnlockChord()
chord.update(letterDown: true, modifiersHeld: true, now: 10)
check(!chord.isComplete(now: 11.99), "requires full two seconds")
check(chord.isComplete(now: 12), "completes at two seconds")
chord.update(letterDown: false, modifiersHeld: true, now: 12.1)
check(!chord.isComplete(now: 20), "letter release cancels hold")
chord.update(letterDown: true, modifiersHeld: true, now: 30)
chord.update(letterDown: true, modifiersHeld: true, now: 31)
check(!chord.isComplete(now: 31.99), "repeat cannot unlock early")
check(chord.isComplete(now: 32), "repeat does not restart timer")
chord.update(modifiersHeld: false, now: 32.1)
check(!chord.isComplete(now: 40), "modifier release cancels hold")
chord.update(modifiersHeld: true, now: 41)
check(!chord.isComplete(now: 42), "repress starts a fresh hold")
check(chord.isComplete(now: 43), "fresh hold completes")
var idle = UnlockChord()
idle.update(modifiersHeld: true, now: 1)
check(!idle.isComplete(now: 100), "modifiers alone never unlock")
idle.update(letterDown: true, modifiersHeld: false, now: 101)
check(!idle.isComplete(now: 200), "letter alone never unlocks")
