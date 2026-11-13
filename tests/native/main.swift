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

for changedMask in [0, 1, 4, 8, 16, 255] {
    check(InputPolicy.suppressSystemEvent(subtype: 7, data1: changedMask), "suppress auxiliary mouse mask \(changedMask)")
}
for key in [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25] {
    for state in [0x0a00, 0x0b00, 0x0a01] {
        check(InputPolicy.suppressSystemEvent(subtype: 8, data1: (key << 16) | state), "suppress control \(key), state \(state)")
    }
}
check(InputPolicy.suppressSystemEvent(subtype: 10, data1: 0), "suppress separate eject subtype")
check(InputPolicy.suppressSystemEvent(subtype: 16, data1: 0), "suppress menu subtype")
for key in [6, 24, 65535] {
    check(!InputPolicy.suppressSystemEvent(subtype: 8, data1: key << 16), "preserve power or unknown key \(key)")
}
for subtype in [1, 11, 12, 13, 17, 999] {
    check(!InputPolicy.suppressSystemEvent(subtype: subtype, data1: 0), "preserve system lifecycle or unknown subtype \(subtype)")
}
check(UnlockLayoutPolicy.supports("l"), "allow lowercase L mapping")
check(UnlockLayoutPolicy.supports("L"), "allow uppercase L mapping")
for source in [nil, "n", "ł", ""] as [String?] {
    check(!UnlockLayoutPolicy.supports(source), "reject unsupported or missing layout")
}
