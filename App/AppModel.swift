import Foundation
import ServiceManagement
import UserNotifications
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var helperStatus: SMAppService.Status = .notRegistered
    @Published private(set) var sleepDisabled = false
    @Published private(set) var timerEnd: Date?
    @Published var lastError: String?

    private let client = HelperClient.shared
    private let daemon = SMAppService.daemon(plistName: WakeyIDs.helperPlist)
    private var refreshTimer: Timer?
    private var warnedLidClosedOnBattery = false

    var helperReady: Bool { helperStatus == .enabled }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = error.localizedDescription
            }
            objectWillChange.send()
        }
    }

    // MARK: - Lifecycle

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        Task { await refresh() }
        // State sync every 30 s.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in await AppModel.shared.refresh() }
        }
    }

    func refresh() async {
        helperStatus = daemon.status
        let wasDisabled = sleepDisabled

        if helperReady, let state = try? await client.state() {
            sleepDisabled = state.sleepDisabled
            timerEnd = state.timerEnd
            try? await client.registerApp()
        } else {
            // No helper yet: still show the real state (reading pmset needs no root).
            sleepDisabled = Pmset.isSleepDisabled()
            timerEnd = nil
        }

        if wasDisabled && !sleepDisabled {
            notify("Sleep is back on", "Your Mac can sleep again (timer ended, low battery, or turned off elsewhere).")
        }
        if wasDisabled != sleepDisabled { reloadWidget() }
        checkLidClosedOnBattery()
    }

    // MARK: - Actions

    /// Keep the Mac awake (optionally for some hours), or allow sleep again.
    func setAwake(_ awake: Bool, hours: Double? = nil) async {
        let until = hours.map { Date().addingTimeInterval($0 * 3600) }
        do {
            try await client.setSleepDisabled(awake, until: awake ? until : nil)
            sleepDisabled = awake
            timerEnd = awake ? until : nil
            lastError = nil
            reloadWidget()
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    /// First run: register the helper, then send the user to Login Items to approve it.
    func setUp() async {
        do {
            if daemon.status != .enabled { try daemon.register() }
            lastError = nil
        } catch {
            // register() throws while approval is pending; the status below covers that.
            if daemon.status != .requiresApproval { lastError = error.localizedDescription }
        }
        if daemon.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        await refresh()
    }

    /// Turn sleep back on first, then unregister the helper.
    func removeHelper() async {
        if helperReady { try? await client.setSleepDisabled(false) }
        do {
            try await daemon.unregister()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    func restoreSleepForQuit() async {
        guard helperReady, sleepDisabled else { return }
        try? await client.setSleepDisabled(false)
    }

    // MARK: - Helpers

    /// Battery warning: sleep disabled, on battery, lid closed.
    private func checkLidClosedOnBattery() {
        let risky = sleepDisabled && Battery.percentIfOnBattery() != nil && Battery.isLidClosed()
        if risky && !warnedLidClosedOnBattery {
            notify("Mac is awake with the lid closed", "Running on battery. Plug in, or it will drain and get warm.")
        }
        warnedLidClosedOnBattery = risky
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: WakeyIDs.widgetKind)
    }

    private func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
