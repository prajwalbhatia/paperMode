import AppKit
import ApplicationServices

/// One session per process. Newline-delimited JSON; raw input never crosses IPC.
final class IPCServer {
    private struct Request: Decodable {
        let protocolVersion: Int
        let requestID: String
        let command: String
    }
    private var buffer = Data()
    private var seen = Set<String>()
    private var sessionID: String?
    private var closed = false
    private let preview: Bool
    private let bounded: Bool
    private lazy var session = LockSession { [weak self] value in
        self?.send(value, id: self?.sessionID)
    }

    init(preview: Bool, bounded: Bool) {
        self.preview = preview
        self.bounded = bounded
    }

    func run() {
        signal(SIGPIPE, SIG_IGN)
        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async { self?.receive(data) }
        }
        send(["event": "ready", "preview": preview, "testSession": bounded], id: nil)
    }

    private func send(_ value: [String: Any], id: String?) {
        guard !closed else { return }
        var response = value
        response["protocolVersion"] = 1
        response["requestID"] = id.map { $0 as Any } ?? NSNull()
        response["preview"] = preview
        guard let data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]) else { return }
        do { try FileHandle.standardOutput.write(contentsOf: data + Data([10])) }
        catch {
            closed = true
            session.finish("connection-lost")
        }
    }

    private func receive(_ data: Data) {
        guard !closed else { return }
        if data.isEmpty {
            FileHandle.standardInput.readabilityHandler = nil
            session.finish("connection-lost")
            closed = true
            return
        }
        buffer.append(data)
        guard buffer.count <= 16384 else { reject(); return }
        while let newline = buffer.firstIndex(of: 10) {
            let line = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            guard let request = try? JSONDecoder().decode(Request.self, from: Data(line)),
                  request.protocolVersion == 1, !request.requestID.isEmpty, request.requestID.utf8.count <= 128,
                  seen.count < 64, seen.insert(request.requestID).inserted else { reject(); return }
            let id = request.requestID
            switch request.command {
            case "status":
                send(["event": "status", "accessibilityTrusted": AXIsProcessTrusted(),
                      "unlockLayoutSupported": UnlockLayoutPolicy.supports(currentUnlockKeyLabel()),
                      "keyboardSourceID": currentKeyboardSourceID() ?? "unknown"], id: id)
            case "request-permission":
                guard sessionID == nil else { reject(); return }
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                send(["event": "status", "accessibilityTrusted": AXIsProcessTrustedWithOptions(options)], id: id)
            case "start":
                guard sessionID == nil else { reject(); return }
                sessionID = id
                if !preview && !AXIsProcessTrusted() {
                    send(["event": "error", "reason": "accessibility-required"], id: id)
                    session.finish("accessibility-required")
                    return
                }
                send(["event": "starting", "delaySeconds": 5], id: id)
                session.prepare(delay: 5, preview: preview, testDuration: preview ? 10 : (bounded ? 30 : nil))
            case "shutdown":
                session.finish("app-quit")
                closed = true
                return
            default:
                reject()
                return
            }
        }
    }

    private func reject() {
        send(["event": "error", "reason": "protocol-error"], id: sessionID)
        session.finish("protocol-error")
        closed = true
    }
}
