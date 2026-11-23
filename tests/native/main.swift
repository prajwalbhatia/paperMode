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

var playbackKey = PlaybackPolicy()
for browser in ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox"] {
    check(PlaybackPolicy.isSupportedBrowser(browser), "allow compatible browser \(browser)")
}
check(!PlaybackPolicy.isSupportedBrowser("com.brave.Browser"), "unprobed browser remains unsupported")
check(playbackKey.update(down: true, modifiers: true, repeated: false), "playback chord fires once")
check(!playbackKey.update(down: true, modifiers: true, repeated: true), "playback autorepeat does not toggle again")
check(!playbackKey.update(down: true, modifiers: true, repeated: false), "duplicate down does not toggle again")
check(!playbackKey.update(down: false, modifiers: true, repeated: false), "release does not toggle")
check(!playbackKey.update(down: true, modifiers: false, repeated: false), "plain space does not control playback")
check(!playbackKey.update(down: true, modifiers: true, repeated: false), "adding modifiers to held space does not toggle")
_ = playbackKey.update(down: false, modifiers: false, repeated: false)
check(playbackKey.update(down: true, modifiers: true, repeated: false), "fresh playback chord can toggle again")
var seekChord = SeekChord()
check(seekChord.update(keycode: 123, down: true, modifiers: true, repeated: false) == -1, "left chord requests back once")
check(seekChord.update(keycode: 123, down: true, modifiers: true, repeated: true) == nil, "held left does not repeat")
check(seekChord.update(keycode: 123, down: false, modifiers: true, repeated: false) == nil, "left release does not seek")
check(seekChord.update(keycode: 124, down: true, modifiers: false, repeated: false) == nil, "plain right does not seek")
check(seekChord.update(keycode: 124, down: true, modifiers: true, repeated: false) == nil, "adding modifiers to held right does not seek")
_ = seekChord.update(keycode: 124, down: false, modifiers: false, repeated: false)
check(seekChord.update(keycode: 124, down: true, modifiers: true, repeated: false) == 1, "fresh right chord requests forward")
check(SeekPolicy.next(current: 330, minimum: 0, maximum: 1411, description: "5 Minutes 30 Seconds of 23 Minutes 31 Seconds",
    url: "https://www.youtube.com/watch?v=test", direction: 1) == 335, "YouTube seconds seek forward")
check(SeekPolicy.next(current: 2, minimum: 0, maximum: 1411, description: "", url: "https://www.youtube.com/watch?v=test",
    direction: -1) == 0, "YouTube seek clamps to start")
check(abs(SeekPolicy.next(current: 50, minimum: 0, maximum: 100, description: "5:00 of 10:00",
    url: "https://www.youtube.com/watch?v=test", direction: 1)! - (50 + 500 / 600)) < 0.000001,
    "percentage-scaled YouTube slider seeks by time")
check(abs(SeekPolicy.next(current: 76.95, minimum: 0, maximum: 100, description: "1:05:52 of 1:25:35",
    url: "https://app.tpstreams.com/embed/test", direction: -1)! - (76.95 - 500 / 5135)) < 0.000001, "course percentage seek uses duration")
check(SeekPolicy.next(current: 76.95, minimum: 0, maximum: 100, description: "unknown",
    url: "https://app.tpstreams.com/embed/test", direction: 1) == nil, "unknown duration fails closed")
let textOnlySeek = SeekPolicy.values(value: "0 Minutes 23 Seconds of 3 Minutes 43 Seconds",
    minimum: 0, maximum: 0, description: "0 Minutes 23 Seconds of 3 Minutes 43 Seconds",
    url: "https://www.youtube.com/watch?v=test")
check(textOnlySeek?.current == 23 && textOnlySeek?.maximum == 223,
      "YouTube time text works when AX slider maximum is zero")
check(SeekPolicy.next(current: textOnlySeek!.current, minimum: textOnlySeek!.minimum,
    maximum: textOnlySeek!.maximum, description: "0 Minutes 23 Seconds of 3 Minutes 43 Seconds",
    url: "https://www.youtube.com/watch?v=test", direction: 1) == 28,
    "time-text slider advances five seconds")
check(SeekPolicy.values(value: "unknown", minimum: 0, maximum: 0, description: "unknown",
    url: "https://www.youtube.com/watch?v=test") == nil, "unknown time text cannot drive a seek")
let courseTextSeek = SeekPolicy.values(value: "1:11:24 of 1:25:35", minimum: 0, maximum: 0,
    description: "1:11:24 of 1:25:35", url: "https://app.tpstreams.com/embed/test")
check(courseTextSeek?.current == 4284 && courseTextSeek?.maximum == 5135,
      "course time text works when AX slider maximum is zero")
check(SeekPolicy.next(current: courseTextSeek!.current, minimum: courseTextSeek!.minimum,
    maximum: courseTextSeek!.maximum, description: "1:11:24 of 1:25:35",
    url: "https://app.tpstreams.com/embed/test", direction: -1) == 4279,
    "time-text course slider rewinds five seconds")
check(SeekPolicy.values(value: "1:11:24 of 1:25:35", minimum: 0, maximum: 0,
    description: "1:11:24 of 1:25:35", url: "https://example.com/embed/test")?.current == 4284,
    "generic time description supplies a verifiable seek position")
check(SeekPolicy.values(value: "1:11:24 of 1:25:35", minimum: 0, maximum: 0,
    description: "1:11:24 of 1:25:35", url: "http://example.com/embed/test") == nil,
    "generic time fallback rejects unsafe documents")
let playbackCenter = PlaybackClick.center(origin: CGPoint(x: 28, y: 843), size: CGSize(width: 40, height: 40))
check(playbackCenter?.x == 48 && playbackCenter?.y == 863,
      "observed course play button has a safe click center")
check(PlaybackClick.center(origin: CGPoint(x: 28, y: 843), size: CGSize(width: 500, height: 40))
    .map { _ in false } ?? true,
    "large page controls cannot use the playback click fallback")
check(PlaybackClick.center(origin: CGPoint(x: -1, y: 843), size: CGSize(width: 40, height: 40))
    .map { _ in false } ?? true,
    "offscreen playback controls cannot be clicked")
check(SeekClick.x(current: 79.62, next: 79.72, minimum: 0, maximum: 100, left: 59, width: 821)! > 712,
      "small course seek moves at least one screen pixel")
check(SeekClick.x(current: 79.62, next: 79.52, minimum: 0, maximum: 100, left: 59, width: 821)! < 713,
      "backward seek targets the earlier side of the timeline")
check(SeekClick.x(current: 50, next: 55, minimum: 0, maximum: 100, left: 0, width: 0) == nil,
      "missing slider geometry prevents a synthetic click")
let originalPointer = SeekClick.restorePoint(previous: CGPoint(x: 400, y: 200),
    barOrigin: CGPoint(x: 100, y: 800), barSize: CGSize(width: 800, height: 0))
check(originalPointer.x == 400 && originalPointer.y == 200, "pointer away from bar is restored")
check(SeekClick.restorePoint(previous: CGPoint(x: 400, y: 800), barOrigin: CGPoint(x: 100, y: 800),
    barSize: CGSize(width: 800, height: 0)).y == 736, "pointer on bar moves clear of preview")
check(PlaybackPolicy.isPlayerLabel("Pause keyboard shortcut k"), "observed YouTube label accepted")
check(PlaybackPolicy.isPlayerLabel("Play Play"), "observed course label accepted")
check(PlaybackPolicy.isPlayerLabel("Play video"), "generic video label accepted")
check(PlaybackPolicy.isPlayerContainer("YouTube Video Player in Full screen"),
      "Safari full-screen YouTube container is recognized")
for label in ["Play/Pause", "Play next", "Replay", "Autoplay", "Play all", "Play playlist"] {
    check(!PlaybackPolicy.isPlayerLabel(label), "ambiguous/non-player label rejected: \(label)")
}

check(PlaybackReadiness.decide(cancelled: false, sameTarget: true, actionable: false, now: 1, deadline: 3) == .wait, "transient missing action waits without toggling")
check(PlaybackReadiness.decide(cancelled: false, sameTarget: true, actionable: true, now: 2, deadline: 3) == .ready, "same player becomes ready during countdown")
check(PlaybackReadiness.decide(cancelled: false, sameTarget: false, actionable: true, now: 2, deadline: 3) == .stop, "readiness cannot retarget a changed player")
check(PlaybackReadiness.decide(cancelled: true, sameTarget: true, actionable: true, now: 2, deadline: 3) == .stop, "cancellation wins over readiness")
check(PlaybackReadiness.decide(cancelled: false, sameTarget: true, actionable: false, now: 3, deadline: 3) == .stop, "permanent missing action ends readiness wait")

check(!PlaybackPolicy.isUniqueMediaControl(count: 1, supportedDocument: false, hasContainer: false, hasTimeline: false), "unrelated Play button is not a media player")
check(!PlaybackPolicy.isUniqueMediaControl(count: 1, supportedDocument: true, hasContainer: false, hasTimeline: true), "page-level timeline cannot qualify an unrelated button")
check(!PlaybackPolicy.isUniqueMediaControl(count: 2, supportedDocument: true, hasContainer: true, hasTimeline: true), "second player-like control remains ambiguous even if non-actionable or URL-less")
check(PlaybackPolicy.isUniqueMediaControl(count: 1, supportedDocument: true, hasContainer: true, hasTimeline: true), "unique supported media control has required structural evidence")
check(PlaybackPolicy.isGeneralVideoDocument("https://courses.example.org/lesson/one"), "HTTPS course page eligible for structural player detection")
for url in ["http://courses.example.org/lesson", "https://localhost/lesson", "https://127.0.0.1/lesson", "https://user@courses.example.org/lesson", "https://courses.example.org:8443/lesson", "https://www.youtube.com/", "https://www.udemy.com/"] {
    check(!PlaybackPolicy.isGeneralVideoDocument(url), "reject unsafe generic document: \(url)")
}
check(PlaybackPolicy.isGeneralTimelineLabel("Progress"), "generic progress slider label accepted")
check(PlaybackPolicy.isGeneralTimelineLabel("Position"), "generic position slider label accepted within player structure")
check(PlaybackPolicy.isMediaEvidenceLabel("Mute"), "media control supplies structural evidence")
check(!PlaybackPolicy.isMediaEvidenceLabel("Your progress"), "course progress is not media evidence")
check(PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true, sharedGroupDepth: 3), "unique grouped player accepted")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: false, sharedGroupDepth: 3), "unrelated Play and slider rejected")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 2, timelineCount: 1, hasMediaEvidence: true, sharedGroupDepth: 3), "multiple players rejected")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 2, hasMediaEvidence: true, sharedGroupDepth: 3), "multiple timelines rejected")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true, sharedGroupDepth: 2), "page-level grouping rejected")
check(PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true,
    sharedGroupDepth: 1, compactFullscreen: true), "compact full-screen player accepted with corroborating evidence")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 2, timelineCount: 1, hasMediaEvidence: true,
    sharedGroupDepth: 1, compactFullscreen: true), "ambiguous full-screen players rejected")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true,
    sharedGroupDepth: 0, compactFullscreen: true), "root-level full-screen controls rejected")
check(PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true,
    sharedGroupDepth: 0, compactFullscreen: true, namedPlayerGroup: true),
    "compact full-screen player accepted in a named control group")
check(!PlaybackPolicy.isGeneralPlayerStructure(playCount: 1, timelineCount: 1, hasMediaEvidence: true,
    sharedGroupDepth: 0, namedPlayerGroup: true),
    "named root group alone cannot qualify a normal page")
let sharedPlayer = PlaybackPolicy.sharedPlayerGroup(play: [0, 1, 2, 3, 4],
    timeline: [0, 1, 2, 3, 5], evidence: [[0, 1, 2, 3, 6]], same: ==)
check(sharedPlayer?.group == 3 && sharedPlayer?.depth == 3, "deepest common player group selected")
check(PlaybackPolicy.sharedPlayerGroup(play: [0, 1, 2, 3], timeline: [0, 1, 4, 5],
    evidence: [[0, 1, 2, 6]], same: ==)?.depth == 1,
    "unrelated media control cannot create a deep player group")
check(PlaybackPolicy.sharedPlayerGroup(play: [0, 1, 2, 3], timeline: [0, 1, 2, 4],
    evidence: [[7, 8, 9]], same: ==) == nil, "media control in another subtree does not qualify")
check(PlaybackPolicy.isExplicitFiveSecondSkip("Rewind 5 seconds", direction: -1), "explicit generic rewind accepted")
check(!PlaybackPolicy.isExplicitFiveSecondSkip("Rewind 10 seconds", direction: -1), "unknown skip interval rejected")
check(abs(SeekPolicy.next(current: 50, minimum: 0, maximum: 100, description: "5:00 of 10:00",
    url: "https://courses.example.org/lesson", direction: 1)! - (50 + 500 / 600)) < 0.000001,
    "generic percentage timeline uses verified duration")
check(SeekPolicy.next(current: 50, minimum: 0, maximum: 100, description: "unknown",
    url: "https://courses.example.org/lesson", direction: 1) == nil,
    "generic percentage timeline without duration cannot seek")
check(SeekPolicy.next(current: 50, minimum: 0, maximum: 100, description: "1:00 of 10:00",
    url: "https://courses.example.org/lesson", direction: 1) == nil,
    "generic percentage timeline rejects inconsistent displayed time")
check(SeekPolicy.next(current: 50, minimum: 0, maximum: 100, description: "4:57 of 10:00",
    url: "https://courses.example.org/lesson", direction: 1) != nil,
    "generic percentage timeline allows display rounding")
check(SeekPolicy.next(current: 300, minimum: 0, maximum: 600, description: "1:00 of 10:00",
    url: "https://courses.example.org/lesson", direction: 1) == nil,
    "generic seconds timeline rejects inconsistent displayed time")
check(SeekPolicy.next(current: 17058, minimum: 0, maximum: 75136,
    description: "0:17 / 1:15", url: "https://courses.example.org/lesson", direction: 1) == 22058,
    "generic millisecond timeline uses displayed elapsed and duration")
check(SeekPolicy.next(current: 31058, minimum: 0, maximum: 75136,
    description: "0:17 / 1:15", url: "https://courses.example.org/lesson", direction: 1) == nil,
    "generic millisecond timeline rejects inconsistent displayed time")
for url in ["https://example.com/watch?v=abc", "https://www.youtube.com.evil.test/watch?v=abc", "https://www.youtube.com/", "https://www.youtube.com/playlist?list=abc", "http://www.youtube.com/watch?v=abc", "https://www.youtube.com@evil.test/watch?v=abc"] {
    check(!PlaybackPolicy.isSupportedPlayerDocument(url), "reject unsupported/spoofed player document: \(url)")
}
check(PlaybackPolicy.isSupportedPlayerDocument("https://www.youtube.com/watch?v=abc"), "YouTube video document supported")
check(PlaybackPolicy.isSupportedPlayerDocument("https://app.tpstreams.com/embed/account/video/?token=test"), "TPStreams embed document supported")
check(PlaybackPolicy.isUdemyLectureDocument("https://www.udemy.com/course/nodejs-express-mongodb-bootcamp/learn/lecture/15064262#overview"), "Udemy lecture document supported")
check(PlaybackPolicy.isSupportedPlayerDocument("https://www.udemy.com/course/example/learn/lecture/12345"), "Udemy lecture accepted as player document")
for url in ["https://www.udemy.com/", "https://www.udemy.com/course/example/learn/", "https://www.udemy.com/course/example/learn/quiz/12345", "https://www.udemy.com.evil.test/course/example/learn/lecture/12345", "http://www.udemy.com/course/example/learn/lecture/12345"] {
    check(!PlaybackPolicy.isUdemyLectureDocument(url), "reject non-lecture or spoofed Udemy document: \(url)")
}
check(PlaybackPolicy.isYouTubePlayerDocument("https://www.youtube.com/watch?v=abc"), "Firefox arrow fallback accepts a YouTube watch page")
check(PlaybackPolicy.isYouTubePlayerDocument("https://www.youtube-nocookie.com/embed/abc"), "Firefox arrow fallback accepts a YouTube embed")
check(!PlaybackPolicy.isYouTubePlayerDocument("https://app.tpstreams.com/embed/test"), "Firefox arrow fallback rejects an untested course player")
check(!PlaybackPolicy.isYouTubePlayerDocument("https://www.youtube.com.evil.test/watch?v=abc"), "Firefox arrow fallback rejects a spoofed host")
check(PlaybackBudget.timeout(now: 10, deadline: 9) == nil, "expired queued request has no AX budget")
check(PlaybackBudget.timeout(now: 10, deadline: 10) == nil, "deadline boundary disallows an AX call")
check(abs(Double(PlaybackBudget.timeout(now: 10, deadline: 10.02)!) - 0.02) < 0.000001, "child-object timeout shrinks to remaining budget")
check(PlaybackBudget.timeout(now: 10, deadline: 20) == Float(0.15), "all queried objects use the per-call cap")
check(PlaybackReadiness.decide(cancelled: false, sameTarget: true, actionable: true, now: 4, deadline: 3) == .stop, "late readiness cannot authorize expired work")
