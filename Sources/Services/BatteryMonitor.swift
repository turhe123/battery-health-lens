import AppKit
import IOKit.ps

/// Keys for settings stored in UserDefaults / @AppStorage.
enum SettingsKey {
    static let alertsEnabled = "alertsEnabled"
    static let healthThreshold = "healthThreshold"
    static let cycleThreshold = "cycleThreshold"
    static let showPercent = "showPercentInMenuBar"
    static let useFahrenheit = "useFahrenheit"
}

/// Observable model that refreshes battery data on a timer, power-source changes and wake.
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot?
    @Published private(set) var history: [HealthEntry] = []
    @Published private(set) var lastUpdated = Date()

    private let store = HistoryStore()
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?

    init() {
        history = store.entries
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        installPowerSourceObserver()
    }

    func refresh() {
        snapshot = BatteryReader.read()
        lastUpdated = Date()
        if let snapshot {
            store.recordIfNeeded(snapshot)
            history = store.entries
            AlertManager.evaluate(snapshot)
        }
    }

    private func installPowerSourceObserver() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { monitor.refresh() } }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    /// Plain-text report for the clipboard.
    func report(fahrenheit: Bool) -> String {
        guard let s = snapshot else { return "BatteryHealthLens: no battery found." }
        let f = Formatters.self
        return """
        BatteryHealthLens report — \(lastUpdated.formatted(date: .abbreviated, time: .shortened))
        Health: \(f.percent(s.healthPercent))
        Cycle count: \(f.int(s.cycleCount))
        Design capacity: \(f.mAh(s.designCapacity))
        Full-charge capacity: \(f.mAh(s.maxCapacity))
        Current charge: \(f.mAh(s.currentCharge)) (\(f.int(s.chargePercent))%)
        Temperature: \(f.temperature(s.temperatureCelsius, fahrenheit: fahrenheit))
        Voltage: \(f.volts(s.voltageMV))
        Amperage: \(f.amps(s.amperageMA))
        Adapter: \(s.externalConnected ? "Connected" : "Not connected")\(s.adapterWatts.map { " (\($0) W)" } ?? "")
        Charging: \(s.isCharging ? "Yes" : "No")
        """
    }
}

/// Formatting helpers that render missing values as a dash.
enum Formatters {
    static let dash = "—"
    static func int(_ v: Int?) -> String { v.map(String.init) ?? dash }
    static func mAh(_ v: Int?) -> String { v.map { "\($0) mAh" } ?? dash }
    static func percent(_ v: Double?) -> String { v.map { String(format: "%.1f%%", $0) } ?? dash }
    static func volts(_ mv: Int?) -> String { mv.map { String(format: "%.2f V", Double($0) / 1000) } ?? dash }
    static func amps(_ ma: Int?) -> String { ma.map { "\($0) mA" } ?? dash }
    static func temperature(_ c: Double?, fahrenheit: Bool) -> String {
        guard let c else { return dash }
        return fahrenheit ? String(format: "%.1f °F", c * 9 / 5 + 32) : String(format: "%.1f °C", c)
    }
}
