import SwiftUI
import Charts
import AppKit

/// The menu bar popover: health ring, stat tiles, history chart and footer actions.
struct ContentView: View {
    @EnvironmentObject private var monitor: BatteryMonitor
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.useFahrenheit) private var fahrenheit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = monitor.snapshot {
                header(s)
                tiles(s)
                HistoryChart(entries: monitor.history)
            } else {
                ContentUnavailableView("No Battery Found",
                                       systemImage: "powerplug",
                                       description: Text("This Mac doesn't have a battery to inspect."))
                    .frame(height: 180)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
        .onAppear { monitor.refresh() }
    }

    private func header(_ s: BatterySnapshot) -> some View {
        HStack(spacing: 16) {
            HealthRing(percent: s.healthPercent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Battery Health").font(.headline)
                Text(s.isCharging ? "Charging" : (s.externalConnected ? "On power adapter" : "On battery"))
                    .foregroundStyle(.secondary)
                Text("Charge \(Formatters.int(s.chargePercent))%").font(.callout)
            }
            Spacer()
        }
    }

    private func tiles(_ s: BatterySnapshot) -> some View {
        let f = Formatters.self
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, spacing: 8) {
            StatTile(title: "Cycles", value: f.int(s.cycleCount), icon: "arrow.triangle.2.circlepath")
            StatTile(title: "Design", value: f.mAh(s.designCapacity), icon: "ruler")
            StatTile(title: "Full Charge", value: f.mAh(s.maxCapacity), icon: "battery.100percent")
            StatTile(title: "Current", value: f.mAh(s.currentCharge), icon: "bolt.batteryblock")
            StatTile(title: "Temperature", value: f.temperature(s.temperatureCelsius, fahrenheit: fahrenheit), icon: "thermometer.medium")
            StatTile(title: "Voltage", value: f.volts(s.voltageMV), icon: "waveform.path.ecg")
            StatTile(title: "Amperage", value: f.amps(s.amperageMA), icon: "arrow.left.arrow.right")
            StatTile(title: "Adapter", value: s.externalConnected ? "Connected" : "None", icon: "powerplug")
            StatTile(title: "Watts", value: s.adapterWatts.map { "\($0) W" } ?? f.dash, icon: "bolt")
        }
    }

    private var footer: some View {
        HStack {
            Button("Copy Report") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(monitor.report(fahrenheit: fahrenheit), forType: .string)
            }
            Button("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Support / Donate ❤️") { Support.openDonate() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }
}

/// Circular gauge showing the health percentage.
struct HealthRing: View {
    let percent: Double?

    private var color: Color {
        guard let p = percent else { return .gray }
        return p >= 80 ? .green : (p >= 60 ? .orange : .red)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max((percent ?? 0) / 100, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(percent.map { String(format: "%.0f%%", $0) } ?? Formatters.dash)
                .font(.system(.title3, design: .rounded).bold())
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel("Health \(Formatters.percent(percent))")
    }
}

/// A small labelled value tile.
struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.callout.monospacedDigit().weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Line chart of daily health snapshots with selectable time ranges.
struct HistoryChart: View {
    enum Range: String, CaseIterable, Identifiable {
        case month = "1M", sixMonths = "6M", all = "All"
        var id: String { rawValue }
    }

    let entries: [HealthEntry]
    @State private var range: Range = .month

    private var filtered: [HealthEntry] {
        let cal = Calendar.current
        let start: Date?
        switch range {
        case .month: start = cal.date(byAdding: .month, value: -1, to: Date())
        case .sixMonths: start = cal.date(byAdding: .month, value: -6, to: Date())
        case .all: start = nil
        }
        guard let start else { return entries }
        return entries.filter { $0.date >= start }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Health History").font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
            }
            if entries.count < 2 {
                Text("Collecting data, check back tomorrow.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                let points = filtered
                let low = (points.map(\.health).min() ?? 80) - 2
                let high = (points.map(\.health).max() ?? 100) + 2
                Chart(points) { entry in
                    LineMark(x: .value("Date", entry.date), y: .value("Health", entry.health))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", entry.date), y: .value("Health", entry.health))
                        .symbolSize(points.count > 40 ? 0 : 18)
                }
                .chartYScale(domain: low...max(high, low + 1))
                .chartYAxis { AxisMarks { AxisGridLine(); AxisValueLabel() } }
                .frame(height: 120)
            }
        }
    }
}
