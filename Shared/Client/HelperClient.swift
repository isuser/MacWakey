import Foundation

struct HelperState {
    var sleepDisabled: Bool
    var timerEnd: Date?
}

enum HelperError: LocalizedError {
    case unreachable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unreachable(let why): return "Wakey helper not reachable (\(why))."
        case .failed(let why): return why
        }
    }
}

/// Talks to the root helper over XPC. Used by the app and the widget.
final class HelperClient: @unchecked Sendable {
    static let shared = HelperClient()

    private let lock = NSLock()
    private var connection: NSXPCConnection?

    func state() async throws -> HelperState {
        try await call { helper, done in
            helper.getState { disabled, end in
                done(.success(HelperState(
                    sleepDisabled: disabled,
                    timerEnd: end > 0 ? Date(timeIntervalSince1970: end) : nil
                )))
            }
        }
    }

    func setSleepDisabled(_ disabled: Bool, until: Date? = nil) async throws {
        try await call { helper, done in
            helper.setSleepDisabled(disabled, timerEnd: until?.timeIntervalSince1970 ?? 0) { error in
                done(error.map { .failure(HelperError.failed($0)) } ?? .success(()))
            }
        }
    }

    func registerApp() async throws {
        try await call { helper, done in
            helper.registerApp { done(.success(())) }
        }
    }

    // MARK: - Plumbing

    /// Runs one XPC call. Fails after 3 s so a missing helper never hangs the UI or widget.
    private func call<T>(
        _ body: @escaping (WakeyHelperProtocol, @escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            let finish: (Result<T, Error>) -> Void = { result in
                if once.claim() { continuation.resume(with: result) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                finish(.failure(HelperError.unreachable("timed out")))
            }
            let proxy = currentConnection().remoteObjectProxyWithErrorHandler { error in
                finish(.failure(HelperError.unreachable(error.localizedDescription)))
            }
            guard let helper = proxy as? WakeyHelperProtocol else {
                finish(.failure(HelperError.unreachable("bad proxy")))
                return
            }
            body(helper, finish)
        }
    }

    private func currentConnection() -> NSXPCConnection {
        lock.lock()
        defer { lock.unlock() }
        if let connection { return connection }

        let new = NSXPCConnection(machServiceName: WakeyIDs.helper, options: .privileged)
        new.remoteObjectInterface = NSXPCInterface(with: WakeyHelperProtocol.self)
        new.invalidationHandler = { [weak self, weak new] in
            guard let self else { return }
            self.lock.lock()
            if self.connection === new { self.connection = nil }
            self.lock.unlock()
        }
        new.resume()
        connection = new
        return new
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
