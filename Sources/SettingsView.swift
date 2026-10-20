import SwiftUI
import ServiceManagement

/// Settings window: alert thresholds, menu bar display, temperature unit and launch at login.
struct SettingsView: View {
    @AppStorage(SettingsKey.alertsEnabled) private var alertsEnabled = false
    @AppStorage(SettingsKey.healthThreshold) private var healthThreshold = 80.0
    @AppStorage(SettingsKey.cycleThreshold) private var cycleThreshold = 1000
    @AppStorage(SettingsKey.showPercent) private var showPercent = true
    @AppStorage(SettingsKey.useFahrenheit) private var useFahrenheit = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Notify me when thresholds are crossed", isOn: $alertsEnabled)
                    .onChange(of: alertsEnabled) { _, on in if on { AlertManager.requestAuthorization() } }
                HStack {
                    Text("Health below")
                    Slider(value: $healthThreshold, in: 50...100, step: 1)
                    Text("\(Int(healthThreshold))%").monospacedDigit().frame(width: 40)
                }
                .disabled(!alertsEnabled)
                Stepper("Cycle count reaches \(cycleThreshold)", value: $cycleThreshold, in: 100...3000, step: 50)
                    .disabled(!alertsEnabled)
                if alertsEnabled {
                    Text("If no alerts appear, allow notifications for BatteryHealthLens in System Settings › Notifications.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Display") {
                Toggle("Show charge percentage in menu bar", isOn: $showPercent)
                Picker("Temperature unit", selection: $useFahrenheit) {
                    Text("Celsius").tag(false)
                    Text("Fahrenheit").tag(true)
                }
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                HStack {
                    Button("Support / Donate ❤️") { Support.openDonate() }
                    Spacer()
                    Text("Free & open source").foregroundStyle(.secondary).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
