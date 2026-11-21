import AppKit
import ApplicationServices
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--version"] {
    print("0.1.1")
} else if arguments == ["--check-accessibility"] {
    // Internal, non-prompting probe: no AppKit session or input interception.
    // Bound its lifetime even if the lock helper itself is killed.
    alarm(3)
    exit(AXIsProcessTrusted() ? 0 : 2)
} else if arguments == ["--diagnose"] {
    emit(["name": "papermode-helper", "protocolVersion": 1, "version": "0.1.1",
          "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
          "inputLockImplemented": true, "accessibilityTrusted": AXIsProcessTrusted(),
          "keyboardSourceID": currentKeyboardSourceID() ?? "unknown",
          "unlockLayoutSupported": UnlockLayoutPolicy.supports(currentUnlockKeyLabel())])
} else if arguments == ["--request-permission"] {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    emit(["accessibilityTrusted": AXIsProcessTrustedWithOptions(options)])
} else if arguments == ["--ipc"] || arguments == ["--ipc-test"] || arguments == ["--ipc-preview"] {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let server = IPCServer(preview: arguments == ["--ipc-preview"], bounded: arguments == ["--ipc-test"])
    server.run()
    app.run()
    withExtendedLifetime(server) {}
} else if arguments == ["--lock"] || arguments == ["--test-lock"] || arguments == ["--preview"] {
    let preview = arguments == ["--preview"]
    let test = arguments == ["--test-lock"]
    if !preview && !AXIsProcessTrusted() {
        emit(["event": "error", "reason": "accessibility-required"])
        exit(2)
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let session = LockSession()
    let delay: TimeInterval = preview ? 0 : 5
    emit(["event": "starting", "delaySeconds": delay, "preview": preview])
    session.prepare(delay: delay, preview: preview, testDuration: preview ? 10 : (test ? 30 : nil))
    app.run()
    withExtendedLifetime(session) {}
} else {
    FileHandle.standardError.write(Data("Usage: papermode-helper --version | --diagnose | --request-permission | --preview | --test-lock | --lock\n".utf8))
    exit(64)
}
