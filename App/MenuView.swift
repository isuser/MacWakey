import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if !model.helperReady {
            Text(setupMessage)
            Button("Set up Wakey…") { Task { await model.setUp() } }
            Divider()
        }

        Toggle("Keep Mac awake", isOn: Binding(
            get: { model.sleepDisabled },
            set: { awake in Task { await model.setAwake(awake) } }
        ))
        .disabled(!model.helperReady)

        Menu("Keep awake for") {
            ForEach([1, 2, 4, 8], id: \.self) { hours in
                Button("\(hours) hour\(hours == 1 ? "" : "s")") {
                    Task { await model.setAwake(true, hours: Double(hours)) }
                }
            }
            Button("Until turned off") { Task { await model.setAwake(true) } }
        }
        .disabled(!model.helperReady)

        if let end = model.timerEnd {
            Text("Sleep returns in \(remaining(until: end))")
        }
        if let error = model.lastError {
            Text(error)
        }

        Divider()

        Toggle("Launch at login", isOn: Binding(
            get: { model.launchAtLogin },
            set: { model.launchAtLogin = $0 }
        ))
        if model.helperStatus != .notRegistered {
            Button("Remove helper") { Task { await model.removeHelper() } }
        }

        Divider()

        Button("Quit Wakey") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var setupMessage: String {
        switch model.helperStatus {
        case .requiresApproval: return "Approve Wakey in Login Items"
        default: return "Wakey needs a one-time setup"
        }
    }

    private func remaining(until end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSinceNow / 60))
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
}
