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
        let timeline: AXUIElement
        let url: String
        let rewind: AXUIElement?
        let forward: AXUIElement?
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
    private func sliderPoint(_ element: AXUIElement) -> CGPoint? {
        guard let raw = value(element, "AXPosition"), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let ax = unsafeBitCast(raw, to: AXValue.self)
        guard AXValueGetType(ax) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(ax, .cgPoint, &point) ? point : nil
    }
    private func sliderSize(_ element: AXUIElement) -> CGSize? {
        guard let raw = value(element, "AXSize"), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let ax = unsafeBitCast(raw, to: AXValue.self)
        guard AXValueGetType(ax) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(ax, .cgSize, &size) ? size : nil
    }
    private func canClickButton(_ element: AXUIElement) -> Bool {
        guard let origin = sliderPoint(element), let size = sliderSize(element) else { return false }
        return PlaybackClick.center(origin: origin, size: size) != nil
    }
    private func canActivate(_ element: AXUIElement) -> Bool {
        canPress(element) || canClickButton(element)
    }
    private func stillOnTarget(_ target: Target) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid else { return false }
        let root = AXUIElementCreateApplication(target.pid)
        guard let raw = value(root, "AXFocusedWindow"), CFGetTypeID(raw) == AXUIElementGetTypeID(),
              CFEqual(raw, target.window), documentURL(target.document) == target.url else { return false }
        var element = target.document
        for _ in 0..<PlaybackPolicy.maxAccessibilityDepth {
            if CFEqual(element, target.window) { return !queryFailed && now < deadline && !isCancelled }
            guard let parent = value(element, "AXParent"), CFGetTypeID(parent) == AXUIElementGetTypeID() else { return false }
            element = unsafeBitCast(parent, to: AXUIElement.self)
        }
        return false
    }
    private func clickButton(_ element: AXUIElement, target: Target) -> Bool {
        guard let origin = sliderPoint(element), let size = sliderSize(element),
              let location = PlaybackClick.center(origin: origin, size: size),
              !queryFailed, now < deadline, !isCancelled,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
              let previous = CGEvent(source: nil)?.location,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                 mouseCursorPosition: location, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                               mouseCursorPosition: location, mouseButton: .left),
              let restore = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                    mouseCursorPosition: SeekClick.restorePoint(previous: previous,
                                        barOrigin: origin, barSize: size), mouseButton: .left) else { return false }
        for event in [down, up, restore] {
            event.setIntegerValueField(.eventSourceUserData, value: SeekClick.marker)
        }
        guard stillOnTarget(target) else { return false }
        for event in [down, up, restore] { event.post(tap: .cghidEventTap) }
        return true
    }
    private func seekValues(_ timeline: AXUIElement, url: String)
        -> (values: (current: Double, minimum: Double, maximum: Double), description: String)? {
        let rawValue = value(timeline, "AXValue")
        let reportedDescription = string(timeline, "AXValueDescription")
        let description = reportedDescription.isEmpty ? (rawValue as? String ?? "") : reportedDescription
        guard let values = SeekPolicy.values(value: rawValue, minimum: value(timeline, "AXMinValue"),
            maximum: value(timeline, "AXMaxValue"), description: description, url: url) else { return nil }
        return (values, description)
    }
    private func clickTimeline(_ element: AXUIElement, target: Target, current: Double, next: Double,
                               minimum: Double, maximum: Double) -> Bool {
        guard let origin = sliderPoint(element), let size = sliderSize(element),
              origin.x.isFinite, origin.y.isFinite, size.height.isFinite,
              size.height >= 0, size.height <= 50,
              let x = SeekClick.x(current: current, next: next, minimum: minimum, maximum: maximum,
                                  left: origin.x, width: size.width),
              !queryFailed, now < deadline, !isCancelled,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid,
              let source = CGEventSource(stateID: .privateState) else { return false }
        let location = CGPoint(x: x, y: origin.y + size.height / 2)
        guard let previous = CGEvent(source: nil)?.location,
              previous.x.isFinite, previous.y.isFinite,
              let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                 mouseCursorPosition: location, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                               mouseCursorPosition: location, mouseButton: .left),
              let restore = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                    mouseCursorPosition: SeekClick.restorePoint(previous: previous,
                                        barOrigin: origin, barSize: size), mouseButton: .left) else { return false }
        down.setIntegerValueField(.eventSourceUserData, value: SeekClick.marker)
        up.setIntegerValueField(.eventSourceUserData, value: SeekClick.marker)
        restore.setIntegerValueField(.eventSourceUserData, value: SeekClick.marker)
        guard stillOnTarget(target) else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        restore.post(tap: .cghidEventTap)
        return true
    }
    private func safeSeekFocus(_ target: Target) -> Bool {
        let root = AXUIElementCreateApplication(target.pid)
        guard let raw = value(root, "AXFocusedUIElement"), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
        let focused = unsafeBitCast(raw, to: AXUIElement.self)
        // An arrow on a volume slider or other child changes that control.
        // Only the bound timeline or the selected player surface is safe.
        return CFEqual(focused, target.timeline) || CFEqual(focused, target.player)
    }
    private func focusBoundPlayer(_ target: Target) -> Bool {
        if safeSeekFocus(target) { return true }
        guard stillOnTarget(target),
              prepareQuery(target.timeline),
              AXUIElementSetAttributeValue(target.timeline, "AXFocused" as CFString, kCFBooleanTrue) == .success,
              !queryFailed, now < deadline, !isCancelled else { return false }
        return safeSeekFocus(target)
    }
    private func sendFirefoxArrow(_ target: Target, direction: Int) -> Bool {
        let eligible = PlaybackPolicy.isYouTubePlayerDocument(target.url) ||
            PlaybackPolicy.isGeneralVideoDocument(target.url)
        let focused = eligible && focusBoundPlayer(target)
        let timely = !queryFailed && now < deadline && !isCancelled
        let foreground = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.pid
        diagnostic(["playback": "firefox-arrow-check", "eligible": eligible,
                    "focused": focused, "timely": timely, "foreground": foreground])
        guard eligible, focused, timely, foreground,
              let source = CGEventSource(stateID: .privateState) else { return false }
        let keycode = CGKeyCode(direction < 0 ? 123 : 124)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: false) else { return false }
        guard stillOnTarget(target) else { return false }
        for event in [down, up] {
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: SeekClick.marker)
            event.post(tap: .cghidEventTap)
        }
        return true
    }
    private final class PlayerContext {
        let element: AXUIElement
        var timelines: [AXUIElement] = []
        init(_ element: AXUIElement) { self.element = element }
    }
    private struct ScanPart {
        let element: AXUIElement
        let document: AXUIElement
        let groups: [AXUIElement]
    }
    private func scan(pid: pid_t, requirePress: Bool = true) -> Target? {
        let operationDeadline = deadline
        deadline = min(deadline, now + 2)
        defer { deadline = operationDeadline }
        queryFailed = false
        let root = AXUIElementCreateApplication(pid)
        // Firefox initializes its web-content Accessibility tree when a client
        // reads AXRole on the application element. Without this, its window may
        // expose only browser chrome and no player controls.
        _ = string(root, "AXRole")
        guard let raw = value(root, "AXFocusedWindow"), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeBitCast(raw, to: AXUIElement.self)
        var found: [(AXUIElement, AXUIElement, PlayerContext?, [AXUIElement])] = []
        var udemyRewind: [ScanPart] = []
        var udemyForward: [ScanPart] = []
        var udemyTimeline: [ScanPart] = []
        var generalTimelines: [ScanPart] = []
        var mediaEvidence: [ScanPart] = []
        var exitFullscreen: [ScanPart] = []
        var fiveSecondBack: [ScanPart] = []
        var fiveSecondForward: [ScanPart] = []
        var visited = 0
        var incomplete = false
        func walk(_ element: AXUIElement, _ document: AXUIElement?, _ context: PlayerContext?,
                  _ groups: [AXUIElement], _ depth: Int) {
            guard !queryFailed, visited < 3000, depth < PlaybackPolicy.maxAccessibilityDepth,
                  now < deadline, !isCancelled else { incomplete = true; return }
            visited += 1
            let role = string(element, "AXRole")
            let web = role == "AXWebArea" ? element : document
            var player = role == "AXWebArea" ? nil : context
            var groupPath = role == "AXWebArea" ? [] : groups
            if role == "AXGroup" {
                groupPath.append(element)
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                if names.contains(where: PlaybackPolicy.isPlayerContainer) { player = PlayerContext(element) }
            }
            if role == "AXSlider", let player {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                if names.contains(where: PlaybackPolicy.isTimelineLabel) { player.timelines.append(element) }
            }
            if role == "AXSlider", let web {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                let part = ScanPart(element: element, document: web, groups: groupPath)
                if names.contains("Progress bar") { udemyTimeline.append(part) }
                if names.contains(where: PlaybackPolicy.isGeneralTimelineLabel) { generalTimelines.append(part) }
                if names.contains(where: PlaybackPolicy.isMediaEvidenceLabel) { mediaEvidence.append(part) }
            }
            if role == "AXButton", let web {
                let names = [string(element, "AXTitle"), string(element, "AXDescription")]
                let part = ScanPart(element: element, document: web, groups: groupPath)
                // Count every player-like control before URL, container, enabled or action filtering.
                if names.contains(where: PlaybackPolicy.isPlayerLabel) { found.append((element, web, player, groupPath)) }
                if names.contains("Rewind") { udemyRewind.append(part) }
                if names.contains("Forward") { udemyForward.append(part) }
                if names.contains(where: PlaybackPolicy.isMediaEvidenceLabel) { mediaEvidence.append(part) }
                if names.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "exit full screen" }) {
                    exitFullscreen.append(part)
                }
                if names.contains(where: { PlaybackPolicy.isExplicitFiveSecondSkip($0, direction: -1) }) { fiveSecondBack.append(part) }
                if names.contains(where: { PlaybackPolicy.isExplicitFiveSecondSkip($0, direction: 1) }) { fiveSecondForward.append(part) }
            }
            for child in value(element, "AXChildren") as? [AXUIElement] ?? [] {
                walk(child, web, player, groupPath, depth + 1)
                if incomplete || queryFailed { break }
            }
        }
        walk(window, nil, nil, [], 0)
        diagnostic(["playback": "scan", "visited": visited, "incomplete": incomplete || queryFailed, "candidates": found.count])
        if !incomplete, !queryFailed, found.count == 1, let candidate = found.first,
           candidate.2 == nil, PlaybackPolicy.isUdemyLectureDocument(documentURL(candidate.1)) {
            guard udemyRewind.count == 1, udemyForward.count == 1, udemyTimeline.count == 1,
                  let back = udemyRewind.first, let ahead = udemyForward.first,
                  let timeline = udemyTimeline.first,
                  CFEqual(back.document, candidate.1), CFEqual(ahead.document, candidate.1),
                  CFEqual(timeline.document, candidate.1),
                  let shared = candidate.3.reversed().first(where: { group in
                      back.groups.contains(where: { CFEqual($0, group) }) &&
                      ahead.groups.contains(where: { CFEqual($0, group) }) &&
                      timeline.groups.contains(where: { CFEqual($0, group) })
                  }), candidate.3.firstIndex(where: { CFEqual($0, shared) }).map({ $0 >= 3 }) == true,
                  (value(candidate.0, "AXEnabled") as? Bool) == true,
                  (!requirePress || canActivate(candidate.0)), canPress(back.element), canPress(ahead.element),
                  !queryFailed, now < deadline else { return nil }
            return Target(pid: pid, window: window, button: candidate.0, document: candidate.1,
                          player: shared, timeline: timeline.element, url: documentURL(candidate.1),
                          rewind: back.element, forward: ahead.element)
        }
        if !incomplete, !queryFailed, found.count == 1, let candidate = found.first,
           !PlaybackPolicy.isSupportedPlayerDocument(documentURL(candidate.1)),
           PlaybackPolicy.isGeneralVideoDocument(documentURL(candidate.1)),
           generalTimelines.count == 1, let timeline = generalTimelines.first,
           CFEqual(timeline.document, candidate.1) {
            let evidenceGroups = mediaEvidence.filter { CFEqual($0.document, candidate.1) }.map(\.groups)
            let common = PlaybackPolicy.sharedPlayerGroup(play: candidate.3,
                timeline: timeline.groups, evidence: evidenceGroups, same: { CFEqual($0, $1) })
            if let common,
               PlaybackPolicy.isGeneralPlayerStructure(playCount: found.count,
                   timelineCount: generalTimelines.count, hasMediaEvidence: !evidenceGroups.isEmpty,
                   sharedGroupDepth: common.depth,
                   compactFullscreen: visited < 150 && exitFullscreen.count == 1 &&
                       exitFullscreen.contains(where: { CFEqual($0.document, candidate.1) &&
                           $0.groups.contains(where: { CFEqual($0, common.group) }) }),
                   namedPlayerGroup: ![string(common.group, "AXTitle"),
                       string(common.group, "AXDescription")].allSatisfy { $0.isEmpty }),
               (value(candidate.0, "AXEnabled") as? Bool) == true,
               (!requirePress || canActivate(candidate.0)), !queryFailed, now < deadline {
                func skip(_ parts: [ScanPart]) -> AXUIElement? {
                    guard parts.count == 1, let part = parts.first,
                          CFEqual(part.document, candidate.1),
                          part.groups.contains(where: { CFEqual($0, common.group) }),
                          canPress(part.element) else { return nil }
                    return part.element
                }
                let back = skip(fiveSecondBack)
                let ahead = skip(fiveSecondForward)
                guard !queryFailed, now < deadline else { return nil }
                return Target(pid: pid, window: window, button: candidate.0, document: candidate.1,
                              player: common.group, timeline: timeline.element, url: documentURL(candidate.1),
                              rewind: back, forward: ahead)
            }
        }
        var selectedControl: Int? = found.count == 1 ? 0 : nil
        if !incomplete, !queryFailed, found.count == 2,
           let first = found.first, let player = first.2,
           player.timelines.count == 1, let timeline = player.timelines.first,
           PlaybackPolicy.isSupportedPlayerDocument(documentURL(first.1)),
           found.allSatisfy({ item in
               CFEqual(item.1, first.1) && item.2.map { CFEqual($0.element, player.element) } == true
           }) {
            let timelineParts = generalTimelines.filter {
                CFEqual($0.document, first.1) && CFEqual($0.element, timeline)
            }
            if timelineParts.count == 1, let part = timelineParts.first {
                selectedControl = PlaybackPolicy.nestedPlayerControlIndex(
                    candidateGroups: found.map { $0.3 }, timelineGroups: part.groups,
                    same: { CFEqual($0, $1) })
            }
        }
        guard !incomplete, !queryFailed, let selectedControl, found.indices.contains(selectedControl),
              let player = found[selectedControl].2, player.timelines.count == 1,
              let timeline = player.timelines.first else {
            diagnostic(["playback": "scan-rejected", "reason": "structure-or-timeout",
                        "playerContainer": found.first?.2 != nil,
                        "timelines": found.first?.2?.timelines.count ?? 0])
            return nil
        }
        let candidate = found[selectedControl]
        let url = documentURL(candidate.1)
        let supportedDocument = PlaybackPolicy.isSupportedPlayerDocument(url)
        let enabled = (value(candidate.0, "AXEnabled") as? Bool) == true
        let pressable = !requirePress || canActivate(candidate.0)
        // The nested selector above resolves a transient outer overlay only
        // when one inner button uniquely shares the timeline's group path.
        guard PlaybackPolicy.isUniqueMediaControl(count: 1, supportedDocument: supportedDocument,
            hasContainer: candidate.2 != nil, hasTimeline: true),
              enabled, pressable, !queryFailed, now < deadline else {
            diagnostic(["playback": "scan-rejected", "reason": "player-attributes",
                        "supportedDocument": supportedDocument, "enabled": enabled,
                        "pressable": pressable, "queryFailed": queryFailed])
            return nil
        }
        return Target(pid: pid, window: window, button: candidate.0, document: candidate.1,
                      player: player.element, timeline: timeline, url: url, rewind: nil, forward: nil)
    }
    private var isCancelled: Bool {
        cancellation.lock(); defer { cancellation.unlock() }; return cancelled
    }
    func cancel() {
        cancellation.lock(); cancelled = true; cancellation.unlock()
    }
    func bind(completion: @escaping (Bool, String?) -> Void) {
        let app = NSWorkspace.shared.frontmostApplication
        let supported = PlaybackPolicy.isSupportedBrowser(app?.bundleIdentifier)
        diagnostic(["playback": "bind", "browser": app?.bundleIdentifier ?? "none", "supported": supported])
        guard supported else {
            let hint = "Chrome, Safari or Firefox video not in front"
            DispatchQueue.main.async { completion(false, hint) }
            return
        }
        let pid = supported ? app?.processIdentifier : nil
        let expiresAt = now + 3
        queue.async { [self] in
            deadline = expiresAt
            guard let pid, !isCancelled else {
                DispatchQueue.main.async { completion(false, nil) }; return
            }
            awaitInitialScan(pid: pid, deadline: expiresAt, completion: completion)
        }
    }
    private func awaitInitialScan(pid: pid_t, deadline: TimeInterval, completion: @escaping (Bool, String?) -> Void) {
        self.deadline = deadline
        guard now < deadline, !isCancelled,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            diagnostic(["playback": "binding-ended", "reason": "no-player-before-deadline"])
            DispatchQueue.main.async { completion(false, nil) }; return
        }
        if let anchor = scan(pid: pid, requirePress: false) {
            awaitReadiness(anchor, deadline: deadline, completion: completion)
        } else {
            queue.asyncAfter(deadline: .now() + 0.25) { [self] in
                awaitInitialScan(pid: pid, deadline: deadline, completion: completion)
            }
        }
    }
    private func sameTarget(_ left: Target, _ right: Target) -> Bool {
        // Browsers replace AX controls as the player redraws. The unique player
        // structure is checked by each scan; keep the session bound to its
        // original window and video URL rather than transient AX object IDs.
        guard left.pid == right.pid && CFEqual(left.window, right.window) && left.url == right.url else { return false }
        // A generic course page can replace its video without changing URL.
        // Keep the exact AX player group and document in that case.
        if PlaybackPolicy.isGeneralVideoDocument(left.url) {
            return CFEqual(left.document, right.document) && CFEqual(left.player, right.player)
        }
        return true
    }
    private func awaitReadiness(_ anchor: Target, deadline: TimeInterval, completion: @escaping (Bool, String?) -> Void) {
        self.deadline = deadline
        guard now < deadline, !isCancelled, NSWorkspace.shared.frontmostApplication?.processIdentifier == anchor.pid else {
            diagnostic(["playback": "binding-ended", "reason": "target-changed-or-unavailable"])
            DispatchQueue.main.async { completion(false, nil) }; return
        }
        guard let current = scan(pid: anchor.pid, requirePress: false) else {
            queue.asyncAfter(deadline: .now() + 0.25) { [self] in
                awaitReadiness(anchor, deadline: deadline, completion: completion)
            }
            return
        }
        guard sameTarget(anchor, current) else {
            diagnostic(["playback": "binding-ended", "reason": "target-changed"])
            DispatchQueue.main.async { completion(false, nil) }; return
        }
        let decision = PlaybackReadiness.decide(cancelled: isCancelled,
            sameTarget: !queryFailed, actionable: canActivate(current.button),
            now: ProcessInfo.processInfo.systemUptime, deadline: deadline)
        switch decision {
        case .ready:
            target = current
            diagnostic(["playback": "binding-ready"])
            DispatchQueue.main.async { completion(true, nil) }
        case .stop:
            diagnostic(["playback": "binding-ended", "reason": "player-not-ready"])
            DispatchQueue.main.async { completion(false, nil) }
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
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid,
               !queryFailed, now < expiresAt, !isCancelled {
                // Never retry a toggle: AX success does not confirm video state.
                // Some course players expose a visible button without AXPress.
                if canPress(current.button) && prepareQuery(current.button) && stillOnTarget(current) {
                    let result = AXUIElementPerformAction(current.button, "AXPress" as CFString)
                    message = result == .success ? "Playback requested · check the video" : "Request failed · unlock to control video"
                    diagnostic(["playback": "request", "method": "AXPress", "result": result == .success ? "sent" : "action-failed"])
                } else if !queryFailed, clickButton(current.button, target: current) {
                    message = "Playback requested · check the video"
                    diagnostic(["playback": "request", "method": "button-click", "result": "sent"])
                } else {
                    diagnostic(["playback": "request", "result": "activation-unavailable"])
                }
            } else {
                diagnostic(["playback": "request", "result": "target-unavailable"])
            }
            DispatchQueue.main.async { completion(message) }
        }
    }

    func seek(direction: Int, completion: @escaping (String) -> Void) {
        let expiresAt = now + 3
        queue.async { [self] in
            deadline = expiresAt
            queryFailed = false
            var message = "Seek unavailable · unlock to control video"
            if let saved = target, now < expiresAt, !isCancelled,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == saved.pid,
               let current = scan(pid: saved.pid, requirePress: false), sameTarget(saved, current),
               !queryFailed, now < expiresAt, !isCancelled {
                if current.rewind != nil && current.forward != nil &&
                   (PlaybackPolicy.isUdemyLectureDocument(saved.url) ||
                    !PlaybackPolicy.isSupportedPlayerDocument(saved.url)) {
                    // Use the player's own buttons when the site-specific
                    // probe or explicit labels establish five-second skips.
                    let button = direction < 0 ? current.rewind : current.forward
                    if let button, canPress(button), prepareQuery(button), stillOnTarget(current),
                       !queryFailed, now < expiresAt, !isCancelled {
                        let result = AXUIElementPerformAction(button, "AXPress" as CFString)
                        if result == .success { message = "Seek requested · check the video" }
                        diagnostic(["playback": "seek", "method": "player-button",
                                    "result": result == .success ? "sent" : "action-failed"])
                    }
                } else if let resolved = seekValues(current.timeline, url: current.url),
                          let next = SeekPolicy.next(current: resolved.values.current,
                              minimum: resolved.values.minimum, maximum: resolved.values.maximum,
                              description: resolved.description, url: saved.url, direction: direction),
                          now < expiresAt, !isCancelled {
                    let firefox = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "org.mozilla.firefox"
                    // Firefox seeks with a plain arrow only when the selected
                    // player has focus. Other browsers use the slider.
                    let sent = firefox
                        ? sendFirefoxArrow(current, direction: direction)
                        : clickTimeline(current.timeline, target: current, current: resolved.values.current, next: next,
                            minimum: resolved.values.minimum, maximum: resolved.values.maximum)
                    message = sent ? "Seek requested · check the video" : "Seek unavailable · unlock to control video"
                    diagnostic(["playback": "seek", "method": firefox ? "focused-arrow" : "timeline-click",
                                "result": sent ? "sent" : "failed"])
                }
            }
            DispatchQueue.main.async { completion(message) }
        }
    }
}
