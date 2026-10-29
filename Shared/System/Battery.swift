import Foundation
import IOKit
import IOKit.ps

enum Battery {
    /// Battery percentage when running on battery; nil on power adapter or with no battery.
    static func percentIfOnBattery() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            guard description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue else {
                return nil // on power adapter
            }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Int ?? 100
            return max > 0 ? current * 100 / max : nil
        }
        return nil
    }

    static func isLow() -> Bool {
        guard let percent = percentIfOnBattery() else { return false }
        return percent < WakeyIDs.lowBatteryPercent
    }

    /// True when a MacBook lid is closed.
    static func isLidClosed() -> Bool {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != 0 else { return false }
        defer { IOObjectRelease(rootDomain) }
        let value = IORegistryEntryCreateCFProperty(
            rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue()
        return value as? Bool ?? false
    }
}
