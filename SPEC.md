# BatteryHealthLens — specification

**Tagline:** See your battery's cycle count, true capacity and wear in a menu bar popover, with a daily health history.

**Category:** Battery & Power

**Inspired by (paid):** Battery Health 3 ($9.99 one-time)

**Frameworks:** SwiftUI, AppKit, IOKit, Charts, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: Battery Health 3 reads the low-level battery data of a MacBook and presents cycle count, design versus current capacity, temperature and charging details in a menu bar app, at a price of around ten dollars. Mac utility lists and forum posts about checking battery wear regularly recommend this kind of tool, and long-lived apps such as coconutBattery show consistent demand for the information.

Our clean-room feature set: a popover showing health percentage, cycle count, design capacity, full-charge capacity, current charge in milliamp hours, temperature in Celsius, voltage, amperage, whether the adapter is connected, and the adapter wattage. A daily snapshot of health percentage and cycle count is stored so a Swift Charts line shows wear over weeks and months. An optional alert fires when health drops under a chosen threshold or when the cycle count passes a chosen number. Aim for about three hundred lines.

UI spec: MenuBarExtra in window style whose title shows the charge percentage with a small bolt when charging. The popover has a header ring with health percent, a grid of stat tiles, a Health History chart with one-month, six-month and all-time ranges, and a footer with Copy Report, Settings and Quit. Settings has the alert thresholds, a toggle for showing percent in the menu bar, temperature unit, and launch at login. Empty state: on a Mac without a battery, the popover says no battery was found and hides the chart. The history chart says collecting data, check back tomorrow, until two snapshots exist.

Technical approach: open the IOKit service named AppleSmartBattery by IOServiceGetMatchingService with IOServiceMatching, then read its properties dictionary using IORegistryEntryCreateCFProperties. Relevant keys include CycleCount, DesignCapacity, AppleRawMaxCapacity or MaxCapacity, NominalChargeCapacity, Temperature in hundredths of a Kelvin-based Celsius value, Voltage, Amperage, IsCharging, ExternalConnected and AdapterDetails. Compute health as the maximum capacity divided by design capacity. Refresh every thirty seconds and on power source change notifications from IOPSNotificationCreateRunLoopSource. Snapshots are appended once per day to a JSON file in Application Support. Alerts use UserNotifications. No special privacy permission is needed since the registry data is readable by normal users.

Edge cases: key names differ between Intel and Apple silicon, so read optional values safely and display a dash when missing. On Apple silicon the raw max capacity key may be a percentage-like value, so detect when it is below one hundred and fall back to the nominal charge capacity. Guard against divide by zero and implausible readings by discarding snapshots above one hundred twenty percent. Handle sleep and wake by refreshing immediately. Desktop Macs show the empty state. Limit stored history to five years and keep the file small.
