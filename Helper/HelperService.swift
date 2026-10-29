import Foundation

/// Owns the sleep setting, the auto-off timer and the safety rules.
/// All state lives on `queue`; methods ending in `Locked` must run on it.
final class HelperService: NSObject, WakeyHelperProtocol {
    private let queue = DispatchQueue(label: "com.isuser.wakey.helper.state")
    private var timerEnd: Date?
    private var appConnectionID: ObjectIdentifier?
    private var ticker: DispatchSourceTimer?

    private static let stateURL = URL(fileURLWithPath: "/Library/Application Support/Wakey/state.json")
    private static let checkInterval: TimeInterval = 30

    private struct SavedState: Codable {
        var timerEnd: Date?
        var bootTime: Double
    }

    // MARK: - Startup

    func start() {
        queue.sync {
            let saved = loadLocked()
            let rebooted = saved.map { abs($0.bootTime - Self.bootTime()) > 1 } ?? true
            timerEnd = saved?.timerEnd
            if let end = timerEnd, end <= Date() { timerEnd = nil }

            if Pmset.isSleepDisabled() {
                // Restore at boot: sleep comes back on unless a saved timer is still running.
                if rebooted && timerEnd == nil {
                    NSLog("Wakey helper: restoring sleep after reboot")
                    _ = applyLocked(disabled: false)
                }
            } else {
                timerEnd = nil
            }
            saveLocked()
        }

        let ticker = DispatchSource.makeTimerSource(queue: queue)
        ticker.schedule(deadline: .now() + Self.checkInterval, repeating: Self.checkInterval)
        ticker.setEventHandler { [weak self] in self?.checkLocked() }
        ticker.resume()
        self.ticker = ticker
    }

    // MARK: - XPC

    func getState(reply: @escaping (Bool, Double) -> Void) {
        queue.async {
            reply(Pmset.isSleepDisabled(), self.timerEnd?.timeIntervalSince1970 ?? 0)
        }
    }

    func setSleepDisabled(_ disabled: Bool, timerEnd end: Double, reply: @escaping (String?) -> Void) {
        queue.async {
            if disabled && Battery.isLow() {
                reply("Battery is below \(WakeyIDs.lowBatteryPercent)%. Plug in to keep the Mac awake.")
                return
            }
            self.timerEnd = (disabled && end > 0) ? Date(timeIntervalSince1970: end) : nil
            reply(self.applyLocked(disabled: disabled))
        }
    }

    func registerApp(reply: @escaping () -> Void) {
        // Must be read on the XPC call's own thread.
        guard let connection = NSXPCConnection.current() else { reply(); return }
        let id = ObjectIdentifier(connection)
        queue.async {
            if self.appConnectionID != id {
                self.appConnectionID = id
                connection.invalidationHandler = { [weak self] in
                    self?.queue.async { self?.appDisconnectedLocked(id) }
                }
            }
            reply()
        }
    }

    // MARK: - Safety rules

    /// Restore on crash: the app went away with sleep disabled and no timer.
    /// (A normal quit already restores sleep from the app itself.)
    private func appDisconnectedLocked(_ id: ObjectIdentifier) {
        guard appConnectionID == id else { return }
        appConnectionID = nil
        if timerEnd == nil && Pmset.isSleepDisabled() {
            NSLog("Wakey helper: app disconnected, restoring sleep")
            _ = applyLocked(disabled: false)
        }
    }

    /// Runs every 30 s: timer end and low battery.
    private func checkLocked() {
        guard Pmset.isSleepDisabled() else {
            if timerEnd != nil { timerEnd = nil; saveLocked() }
            return
        }
        if let end = timerEnd, end <= Date() {
            NSLog("Wakey helper: timer ended, restoring sleep")
            _ = applyLocked(disabled: false)
        } else if Battery.isLow() {
            NSLog("Wakey helper: battery low, restoring sleep")
            _ = applyLocked(disabled: false)
        }
    }

    // MARK: - Helpers

    private func applyLocked(disabled: Bool) -> String? {
        let error = Pmset.setSleepDisabled(disabled)
        if !disabled { timerEnd = nil }
        saveLocked()
        return error
    }

    private func loadLocked() -> SavedState? {
        guard let data = try? Data(contentsOf: Self.stateURL) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    private func saveLocked() {
        let state = SavedState(timerEnd: timerEnd, bootTime: Self.bootTime())
        let folder = Self.stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: Self.stateURL, options: .atomic)
        }
    }

    /// Boot time in seconds since 1970, used to tell a reboot from a helper restart.
    private static func bootTime() -> Double {
        var time = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &time, &size, nil, 0) == 0 else { return 0 }
        return Double(time.tv_sec)
    }
}
