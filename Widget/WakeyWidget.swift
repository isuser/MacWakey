import AppIntents
import SwiftUI
import WidgetKit

struct WakeyEntry: TimelineEntry {
    let date: Date
    let sleepDisabled: Bool
    let timerEnd: Date?
    let helperReachable: Bool
}

struct WakeyProvider: TimelineProvider {
    func placeholder(in context: Context) -> WakeyEntry {
        WakeyEntry(date: .now, sleepDisabled: false, timerEnd: nil, helperReachable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (WakeyEntry) -> Void) {
        Task { completion(await Self.loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WakeyEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            var next = Date().addingTimeInterval(15 * 60)
            if let end = entry.timerEnd, end < next { next = end.addingTimeInterval(35) }
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func loadEntry() async -> WakeyEntry {
        do {
            let state = try await HelperClient.shared.state()
            return WakeyEntry(date: .now, sleepDisabled: state.sleepDisabled,
                              timerEnd: state.timerEnd, helperReachable: true)
        } catch {
            return WakeyEntry(date: .now, sleepDisabled: false, timerEnd: nil, helperReachable: false)
        }
    }
}

/// Widget button: flips the sleep setting through the helper.
struct ToggleSleepIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Wakey"

    func perform() async throws -> some IntentResult {
        let state = try await HelperClient.shared.state()
        try await HelperClient.shared.setSleepDisabled(!state.sleepDisabled)
        return .result()
    }
}

struct WakeyWidgetView: View {
    let entry: WakeyEntry

    var body: some View {
        VStack(spacing: 6) {
            if entry.helperReachable {
                Button(intent: ToggleSleepIntent()) {
                    Image(systemName: entry.sleepDisabled ? "eye" : "eye.slash")
                        .font(.system(size: 36))
                }
                .buttonStyle(.plain)
                Text(entry.sleepDisabled ? "Awake" : "Sleep on")
                    .font(.headline)
                if let end = entry.timerEnd {
                    Text("until \(end, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "eye.slash")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Open Wakey to set up")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct WakeyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WakeyIDs.widgetKind, provider: WakeyProvider()) { entry in
            WakeyWidgetView(entry: entry)
        }
        .configurationDisplayName("Wakey")
        .description("Keep your Mac awake with one tap.")
        .supportedFamilies([.systemSmall])
    }
}
