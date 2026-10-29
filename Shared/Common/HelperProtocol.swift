import Foundation

/// XPC interface of the root helper. These are the only things it will do.
/// `timerEnd` is seconds since 1970; 0 means no timer.
@objc protocol WakeyHelperProtocol {
    func getState(reply: @escaping (_ sleepDisabled: Bool, _ timerEnd: Double) -> Void)

    /// Disable or enable sleep. Enabling sleep always clears the timer.
    /// Replies with an error message, or nil on success.
    func setSleepDisabled(_ disabled: Bool, timerEnd: Double, reply: @escaping (_ error: String?) -> Void)

    /// The menu bar app calls this so the helper restores sleep if the app dies.
    func registerApp(reply: @escaping () -> Void)
}
