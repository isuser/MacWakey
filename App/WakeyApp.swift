import SwiftUI

@main
struct WakeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            // Open eye = Mac kept awake; slashed eye = normal sleep.
            Image(systemName: model.sleepDisabled ? "eye" : "eye.slash")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in AppModel.shared.start() }
    }

    /// Restore on quit: turn sleep back on before exiting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await AppModel.shared.restoreSleepForQuit()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
