import SwiftUI
import AppKit

/// App entry point: a menu bar popover plus a Settings window.
@main
struct BatteryHealthLensApp: App {
    @StateObject private var monitor = BatteryMonitor()
    @AppStorage(SettingsKey.showPercent) private var showPercent = true

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(monitor)
        } label: {
            MenuBarLabel(snapshot: monitor.snapshot, showPercent: showPercent)
        }
        .menuBarExtraStyle(.window)

        Window("BatteryHealthLens Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}

/// The menu bar title: charge percentage and a bolt while charging.
struct MenuBarLabel: View {
    let snapshot: BatterySnapshot?
    let showPercent: Bool

    var body: some View {
        if let s = snapshot {
            HStack(spacing: 2) {
                Image(systemName: s.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                if showPercent, let p = s.chargePercent { Text("\(p)%") }
            }
        } else {
            Image(systemName: "battery.0percent")
        }
    }
}

/// Opens the donation page.
enum Support {
    static func openDonate() {
        if let url = URL(string: "https://ko-fi.com/leodavidai") { NSWorkspace.shared.open(url) }
    }
}
