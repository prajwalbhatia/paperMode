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

var progressChord = UnlockChord()
check(progressChord.progress(now: 0) == nil, "idle has no countdown")
progressChord.update(letterDown: true, modifiersHeld: true, now: 10)
check(progressChord.progress(now: 10) == 0, "countdown starts at zero progress")
check(progressChord.progress(now: 11) == 0.5, "halfway progress matches hold time")
progressChord.update(letterDown: true, modifiersHeld: true, now: 11)
check(progressChord.progress(now: 11.5) == 0.75, "repeat does not reset countdown")
check(progressChord.progress(now: 13) == 1, "completed progress is clamped")
progressChord.update(modifiersHeld: false, now: 11.5)
check(progressChord.progress(now: 12) == nil, "early release clears countdown")
progressChord.update(modifiersHeld: true, now: 14)
check(progressChord.progress(now: 14) == 0, "new hold restarts countdown")

// Real subprocess checks, without Accessibility changes or input interception.
func pump(until condition: () -> Bool, timeout: TimeInterval = 3) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
}
func probeResult(_ path: String, _ args: [String], timeout: TimeInterval = 1) -> PermissionProbe.Result? {
    let probe = PermissionProbe(executable: URL(fileURLWithPath: path), arguments: args, timeout: timeout)
    var result: PermissionProbe.Result?
    probe.start { result = $0 }
    pump(until: { result != nil })
    check(!probe.isRunning, "permission probe completes without pending state")
    return result
}
check(probeResult("/usr/bin/true", []) == .trusted, "fresh successful probe accepts trust")
check(probeResult("/bin/sh", ["-c", "exit 2"]) == .denied, "revoked permission is distinguished from probe failure")
check(probeResult("/usr/bin/false", []) == .failed, "unexpected probe exit fails closed")
check(probeResult("/nonexistent/papermode-test", []) == .failed, "probe launch error fails closed")
check(probeResult("/bin/sleep", ["5"], timeout: 0.1) == .failed, "hung probe fails closed before process exits")
let cancelledProbe = PermissionProbe(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.1)
var cancelledCallbacks = 0
cancelledProbe.start { _ in cancelledCallbacks += 1 }
cancelledProbe.cancel()
pump(until: { false }, timeout: 0.2)
check(!cancelledProbe.isRunning && cancelledCallbacks == 0, "session cleanup suppresses late probe and watchdog callbacks")
let repeatedProbe = PermissionProbe(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
var probeCallbacks = 0
repeatedProbe.start { _ in probeCallbacks += 1 }
repeatedProbe.start { _ in probeCallbacks += 100 }
pump(until: { probeCallbacks != 0 })
check(probeCallbacks == 1, "overlapping checks do not launch a second probe")
repeatedProbe.start { _ in probeCallbacks += 1 }
pump(until: { probeCallbacks == 2 })
check(probeCallbacks == 2, "subsequent permission checks can run after completion")
