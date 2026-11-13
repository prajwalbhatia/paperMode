import AppKit
import ApplicationServices

final class LockSession {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var observers: [NSObjectProtocol] = []
    private var signals: [DispatchSourceSignal] = []
    private var chord = UnlockChord()
    private let reminder = Reminder()
    private let parentPID = getppid()
    private var active = false
    private var deadline: TimeInterval?
    private var preview = false
    private var permissionCheckAt: TimeInterval = 0

    func begin(preview: Bool, testDuration: TimeInterval?) {
        self.preview = preview
        guard getppid() == parentPID else { finish("parent-exited"); return }
        if !preview && !AXIsProcessTrusted() {
            emit(["event": "error", "reason": "accessibility-required"])
            NSApp.stop(nil)
            exit(2)
        }
        if !preview {
            guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .defaultTap, eventsOfInterest: CGEventMask.max,
                callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    return Unmanaged<LockSession>.fromOpaque(context).takeUnretainedValue().handle(type, event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
                emit(["event": "error", "reason": "event-tap-unavailable"])
                exit(3)
            }
            tap = newTap
            CGEvent.tapEnable(tap: newTap, enable: false)
            guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
                CFMachPortInvalidate(newTap)
                emit(["event": "error", "reason": "event-source-unavailable"])
                exit(3)
            }
            source = newSource
            CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        }
        reminder.show(preview: preview)
        guard reminder.isVisible else { finish("reminder-unavailable"); return }
        active = true
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "PaperMode course viewing")
        let now = ProcessInfo.processInfo.systemUptime
        deadline = testDuration.map { now + $0 }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.reminder.show(preview: self.preview)
            if !self.reminder.isVisible { self.finish("reminder-unavailable") }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.finish("system-sleep") })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.finish("session-inactive") })
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
        emit(["event": preview ? "preview" : "locked", "testSession": testDuration != nil])
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
            DispatchQueue.main.async { self.finish("event-tap-disabled") }
            return Unmanaged.passUnretained(event)
        }
        guard active else { return Unmanaged.passUnretained(event) }
        let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
        let modifiers = event.flags.contains(flags)
        if type == .keyDown || type == .keyUp {
            let isL = event.getIntegerValueField(.keyboardEventKeycode) == 37
            chord.update(letterDown: isL ? type == .keyDown : nil, modifiersHeld: modifiers, now: ProcessInfo.processInfo.systemUptime)
        } else if type == .flagsChanged {
            chord.update(modifiersHeld: modifiers, now: ProcessInfo.processInfo.systemUptime)
        }
        // System-defined events may include hardware power actions. Only swallow
        // recognized consumer/media keys; never promise power/Touch ID blocking.
        if type.rawValue == 14 {
            guard let native = NSEvent(cgEvent: event), native.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }
            let key = (native.data1 >> 16) & 0xffff
            let mediaKeys: Set<Int> = [0, 1, 2, 3, 7, 8, 9, 10, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
            return mediaKeys.contains(key) ? nil : Unmanaged.passUnretained(event)
        }
        return nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if getppid() != parentPID { finish("parent-exited"); return }
        if !reminder.isVisible { finish("reminder-unavailable"); return }
        if let deadline, now >= deadline { finish("development-test-ended"); return }
        if !preview && chord.isComplete(now: now) { finish("shortcut"); return }
        if let tap, !CGEvent.tapIsEnabled(tap: tap) { finish("event-tap-disabled"); return }
        if !preview && now >= permissionCheckAt {
            permissionCheckAt = now + 1
            if !AXIsProcessTrusted() { finish("permission-revoked") }
        }
    }

    func finish(_ reason: String) {
        active = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
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
        emit(["event": "unlocked", "reason": reason])
        NSApp.terminate(nil)
    }
}

func emit(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        FileHandle.standardOutput.write(data + Data([10]))
    }
}
