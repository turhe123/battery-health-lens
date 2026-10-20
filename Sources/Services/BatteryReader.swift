import Foundation
import IOKit
import IOKit.ps

/// An immutable reading of the battery's registry values at one moment.
struct BatterySnapshot: Equatable {
    var cycleCount: Int?
    var designCapacity: Int?
    var maxCapacity: Int?
    var currentCharge: Int?
    var chargePercent: Int?
    var temperatureCelsius: Double?
    var voltageMV: Int?
    var amperageMA: Int?
    var isCharging: Bool
    var externalConnected: Bool
    var adapterWatts: Int?

    /// Health as full-charge capacity over design capacity, in percent; nil when not computable.
    var healthPercent: Double? {
        guard let max = maxCapacity, let design = designCapacity, design > 0, max > 0 else { return nil }
        return Double(max) / Double(design) * 100
    }
}

/// Reads the `AppleSmartBattery` IOKit service and normalises Intel / Apple silicon differences.
enum BatteryReader {
    /// Returns nil when the Mac has no battery (e.g. desktops).
    static func read() -> BatterySnapshot? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any] else { return nil }
        if let installed = props["BatteryInstalled"] as? Bool, !installed { return nil }

        func int(_ key: String) -> Int? {
            guard let n = props[key] as? NSNumber else { return nil }
            // Some firmware reports signed values as large unsigned numbers.
            let v = n.int64Value
            return v > Int64(Int32.max) && v <= Int64(UInt32.max) ? Int(Int32(truncatingIfNeeded: v)) : Int(v)
        }

        // Apple silicon may expose MaxCapacity as a percentage; fall back to the nominal mAh value.
        var maxCap = int("AppleRawMaxCapacity") ?? int("MaxCapacity")
        if let m = maxCap, m <= 100 { maxCap = int("NominalChargeCapacity") }

        var current = int("AppleRawCurrentCapacity") ?? int("CurrentCapacity")
        if int("AppleRawCurrentCapacity") == nil, int("MaxCapacity") ?? 0 <= 100 { current = nil }

        let temperature = int("Temperature").map { Double($0) / 100 }
        let adapter = props["AdapterDetails"] as? [String: Any]
        let watts = (adapter?["Watts"] as? NSNumber)?.intValue

        return BatterySnapshot(
            cycleCount: int("CycleCount"),
            designCapacity: int("DesignCapacity"),
            maxCapacity: maxCap,
            currentCharge: current,
            chargePercent: systemChargePercent(),
            temperatureCelsius: temperature.flatMap { (-40...150).contains($0) ? $0 : nil },
            voltageMV: int("Voltage"),
            amperageMA: int("Amperage") ?? int("InstantAmperage"),
            isCharging: props["IsCharging"] as? Bool ?? false,
            externalConnected: props["ExternalConnected"] as? Bool ?? false,
            adapterWatts: (watts ?? 0) > 0 ? watts : nil
        )
    }

    /// Charge percentage as shown by macOS, from the power-sources API.
    private static func systemChargePercent() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return Int((Double(cur) / Double(max) * 100).rounded())
        }
        return nil
    }
}
