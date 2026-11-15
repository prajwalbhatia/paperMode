import AppKit

// Local notifications exercise the real native preparation path without sleeping
// the machine or creating an input tap. Process termination is part of cleanup.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let session = LockSession()
let sleep = CommandLine.arguments.last == "sleep"
DispatchQueue.main.async {
    session.prepare(delay: 5, preview: true, testDuration: 10)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSWorkspace.shared.notificationCenter.post(
            name: sleep ? NSWorkspace.willSleepNotification : NSWorkspace.sessionDidResignActiveNotification,
            object: nil)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 6) { exit(1) }
app.run()
withExtendedLifetime(session) {}
