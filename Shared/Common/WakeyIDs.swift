import Foundation

/// Identifiers shared by the app, the widget and the helper.
enum WakeyIDs {
    static let app = "com.isuser.wakey"
    static let widget = "com.isuser.wakey.widget"
    /// Helper bundle ID, launchd label and XPC Mach service name.
    static let helper = "com.isuser.wakey.helper"
    static let helperPlist = "com.isuser.wakey.helper.plist"
    static let widgetKind = "WakeyWidget"

    /// On battery below this percentage, sleep is turned back on.
    static let lowBatteryPercent = 20
}
