import Foundation
import Darwin

/// A fresh process avoids relying solely on the lock process's cached AX verdict.
/// Call start/cancel on the main thread; launching and waiting happen off-thread.
final class PermissionProbe {
    enum Result { case trusted, denied, failed }
    private let executable: URL
    private let arguments: [String]
    private let timeout: TimeInterval
    private var pending: Launch?
    private var watchdog: DispatchWorkItem?
    var isRunning: Bool { pending != nil }

    init(executable: URL = Bundle.main.executableURL!,
         arguments: [String] = ["--check-accessibility"], timeout: TimeInterval = 3) {
        self.executable = executable
        self.arguments = arguments
        self.timeout = timeout
    }

    func start(completion: @escaping (Result) -> Void) {
        guard pending == nil else { return }
        let launch = Launch(executable: executable, arguments: arguments)
        pending = launch
        let expiry = DispatchWorkItem { [weak self] in
            guard let self, self.pending === launch else { return }
            self.cancel()
            completion(.failed)
        }
        watchdog = expiry
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: expiry)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = launch.run()
            DispatchQueue.main.async {
                guard let self, self.pending === launch else { return }
                self.watchdog?.cancel()
                self.watchdog = nil
                self.pending = nil
                completion(result)
            }
        }
    }

    func cancel() {
        watchdog?.cancel()
        watchdog = nil
        let launch = pending
        pending = nil
        // Never wait for process launch/exit on the event-tap thread.
        if let launch { DispatchQueue.global(qos: .utility).async { launch.cancel() } }
    }

    private final class Launch {
        private let lock = NSLock()
        private let process = Process()
        private var cancelled = false

        init(executable: URL, arguments: [String]) {
            process.executableURL = executable
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        func run() -> Result {
            lock.lock()
            guard !cancelled else { lock.unlock(); return .failed }
            do { try process.run() }
            catch { lock.unlock(); return .failed }
            lock.unlock()
            process.waitUntilExit()
            guard process.terminationReason == .exit else { return .failed }
            switch process.terminationStatus {
            case 0: return .trusted
            case 2: return .denied
            default: return .failed
            }
        }

        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            cancelled = true
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
