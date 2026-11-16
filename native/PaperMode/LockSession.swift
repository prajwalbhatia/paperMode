import AppKit
import ApplicationServices

final class LockSession {
    private let send: ([String: Any]) -> Void

    init(send: @escaping ([String: Any]) -> Void = emit) { self.send = send }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var preparationTimer: Timer?
    private var activity: NSObjectProtocol?
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private var chord = UnlockChord()
    private let playback = PlaybackTarget()
    private var playbackKey = PlaybackPolicy()
    private var playbackPending = false
    private var playbackHint = "Checking play/pause availability…"
    private var playbackBound = false
    private let reminder = Reminder()
    private let parentPID = getppid()
    private var active = false
    private var deadline: TimeInterval?
    private var preview = false
    private let permissionProbe = PermissionProbe()
    private var permissionCheckAt: TimeInterval = 0
    private var keyboardSourceID: String?
    private var lockedAt: TimeInterval?
    private var finishing = false
    private var layoutCheckAt: TimeInterval = 0

    private var cancellationObserversInstalled = false

    private func observeCancellation() {
        guard !cancellationObserversInstalled else { return }
        cancellationObserversInstalled = true
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.finish("system-sleep") })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.finish("session-inactive") })
    }

    func prepare(delay: TimeInterval, preview: Bool, testDuration: TimeInterval?) {
        guard !finishing else { return }
        observeCancellation()
        if !preview {
            playbackBound = true
            playback.bind { [weak self] available in
                guard let self, !self.finishing else { return }
                self.playbackHint = available ? "⌃⌥⌘ Space · request play/pause" : "Play/pause unavailable · unlock to control"
                if self.active { self.reminder.updatePlayback(self.playbackHint) }
            }
        }
        guard delay > 0 else { begin(preview: preview, testDuration: testDuration); return }
        let startsAt = ProcessInfo.processInfo.systemUptime + delay
        reminder.show(preview: preview, preparingSeconds: Int(ceil(delay)))
        guard reminder.isVisible else { finish("reminder-unavailable"); return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !self.finishing else { return }
            guard getppid() == self.parentPID else { self.finish("parent-exited"); return }
            let remaining = startsAt - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 {
                self.preparationTimer?.invalidate()
                self.preparationTimer = nil
                self.begin(preview: preview, testDuration: testDuration)
            } else {
                self.reminder.updatePreparation(seconds: Int(ceil(remaining)))
            }
        }
        preparationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func begin(preview: Bool, testDuration: TimeInterval?) {
        guard !finishing else { return }
        observeCancellation()
        self.preview = preview
        if !preview && !playbackBound {
            playbackBound = true
            playback.bind { [weak self] available in
                guard let self, !self.finishing else { return }
                self.playbackHint = available ? "⌃⌥⌘ Space · request play/pause" : "Play/pause unavailable · unlock to control"
                self.reminder.updatePlayback(self.playbackHint)
            }
        }
        guard getppid() == parentPID else { finish("parent-exited"); return }
        if !preview && !AXIsProcessTrusted() {
            send(["event": "error", "reason": "accessibility-required"])
            NSApp.stop(nil)
            exit(2)
        }
        if !preview {
            keyboardSourceID = currentKeyboardSourceID()
            guard UnlockLayoutPolicy.supports(currentUnlockKeyLabel()) else {
                send(["event": "error", "reason": "unsupported-keyboard-layout", "message": "Select a keyboard layout with L at the standard U.S. key position before locking."])
                exit(4)
            }

        }
        reminder.show(preview: preview)
        reminder.updatePlayback(playbackHint)
        guard reminder.isVisible else { finish("reminder-unavailable"); return }
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "PaperMode course viewing")
        let now = ProcessInfo.processInfo.systemUptime
        deadline = testDuration.map { now + $0 }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.reminder.show(preview: self.preview)
            self.reminder.updatePlayback(self.playbackHint)
            if !self.reminder.isVisible { self.finish("reminder-unavailable") }
        })
        for number in [SIGINT, SIGTERM, SIGHUP] {
            signal(number, SIG_IGN)
            let handler = DispatchSource.makeSignalSource(signal: number, queue: .main)
            handler.setEventHandler { [weak self] in self?.finish("process-signal") }
            handler.resume()
            signals.append(handler)
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        // Complete AppKit, power-assertion and observer setup before creating the
        // tap. A newly created tap is enabled immediately; expensive setup after
        // creation can starve its callbacks and trigger the WindowServer timeout.
        if !preview {
            guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .defaultTap, eventsOfInterest: CGEventMask.max,
                callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    return Unmanaged<LockSession>.fromOpaque(context).takeUnretainedValue().handle(type, event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
                send(["event": "error", "reason": "event-tap-unavailable"])
                exit(3)
            }
            tap = newTap
            guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
                CFMachPortInvalidate(newTap)
                send(["event": "error", "reason": "event-source-unavailable"])
                exit(3)
            }
            source = newSource
            CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        }
        active = true
        lockedAt = ProcessInfo.processInfo.systemUptime
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        send(["event": preview ? "preview" : "locked", "testSession": testDuration != nil])
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            active = false
            let reason = type == .tapDisabledByTimeout ? "event-tap-timeout" : "event-tap-disabled-by-user-input"
            DispatchQueue.main.async { self.finish(reason) }
            return Unmanaged.passUnretained(event)
        }
        guard active else { return Unmanaged.passUnretained(event) }
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let modifiers = event.flags.contains(flags)
        if type == .keyDown || type == .keyUp {
            if event.getIntegerValueField(.keyboardEventKeycode) == 49 {
                let request = playbackKey.update(down: type == .keyDown,
                    modifiers: modifiers && !event.flags.contains(.maskShift),
                    repeated: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
                if request && !playbackPending {
                    playbackPending = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.active, !self.finishing else { return }
                        self.reminder.updatePlayback("Requesting playback…")
                        self.playback.request { [weak self] message in
                            guard let self, self.active, !self.finishing else { return }
                            self.playbackPending = false
                            self.reminder.updatePlayback(message)
                        }
                    }
                }
            }
            let isL = event.getIntegerValueField(.keyboardEventKeycode) == 37
            chord.update(letterDown: isL ? type == .keyDown : nil, modifiersHeld: modifiers, now: ProcessInfo.processInfo.systemUptime)
        } else if type == .flagsChanged {
            chord.update(modifiersHeld: modifiers, now: ProcessInfo.processInfo.systemUptime)
        }
        if type.rawValue == 14 {
            guard let native = NSEvent(cgEvent: event) else {
                return Unmanaged.passUnretained(event)
            }
            return InputPolicy.suppressSystemEvent(subtype: Int(native.subtype.rawValue), data1: native.data1)
                ? nil : Unmanaged.passUnretained(event)
        }
        return nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if getppid() != parentPID { finish("parent-exited"); return }
        if !reminder.isVisible { finish("reminder-unavailable"); return }
        if let deadline, now >= deadline { finish("development-test-ended"); return }
        if !preview && now >= layoutCheckAt {
            layoutCheckAt = now + 0.5
            if currentKeyboardSourceID() != keyboardSourceID || !UnlockLayoutPolicy.supports(currentUnlockKeyLabel()) {
                finish("keyboard-layout-changed"); return
            }
        }
        if !preview { reminder.updateHoldProgress(chord.progress(now: now)) }
        if !preview && chord.isComplete(now: now) { finish("shortcut"); return }
        if let tap, !CGEvent.tapIsEnabled(tap: tap) { finish("event-tap-observed-disabled"); return }
        if !preview && now >= permissionCheckAt && !permissionProbe.isRunning {
            if !AXIsProcessTrusted() { finish("permission-revoked"); return }
            permissionProbe.start { [weak self] result in
                guard let self, !self.finishing else { return }
                self.permissionCheckAt = ProcessInfo.processInfo.systemUptime + 1
                switch result {
                case .trusted: break
                case .denied: self.finish("permission-revoked")
                case .failed: self.finish("permission-check-failed")
                }
            }
        }
    }

    func finish(_ reason: String) {
        guard !finishing else { return }
        finishing = true
        playback.cancel()
        active = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        permissionProbe.cancel()
        preparationTimer?.invalidate()
        preparationTimer = nil
        timer?.invalidate()
        timer = nil
        reminder.close()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        signals.forEach { $0.cancel() }
        signals.removeAll()
        send(["event": "unlocked", "reason": reason, "elapsedMilliseconds": lockedAt.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1000) } ?? 0])
        NSApp.terminate(nil)
    }
}

func emit(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        FileHandle.standardOutput.write(data + Data([10]))
    }
}
