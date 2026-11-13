import AppKit
import Foundation

// Milestone 1 only: no event tap, permission request, or input interception.
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--version"] {
    print("0.1.0")
} else if arguments == ["--diagnose"] {
    let report: [String: Any] = [
        "name": "papermode-helper",
        "protocolVersion": 1,
        "version": "0.1.0",
        "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
        "inputLockImplemented": false
    ]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    FileHandle.standardError.write(Data("Usage: papermode-helper --version | --diagnose\n".utf8))
    exit(64)
}
