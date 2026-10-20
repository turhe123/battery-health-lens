import Foundation
import UserNotifications

/// Posts local notifications when health or cycle count crosses the user's thresholds (once per crossing).
enum AlertManager {
    private static let defaults = UserDefaults.standard

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func evaluate(_ snapshot: BatterySnapshot) {
        guard defaults.bool(forKey: SettingsKey.alertsEnabled) else { return }
        let healthLimit = defaults.object(forKey: SettingsKey.healthThreshold) as? Double ?? 80
        let cycleLimit = defaults.object(forKey: SettingsKey.cycleThreshold) as? Int ?? 1000

        if let health = snapshot.healthPercent {
            check(health < healthLimit, flag: "alert.health.sent",
                  title: "Battery health is low",
                  body: String(format: "Health is %.0f%%, below your %.0f%% threshold.", health, healthLimit))
        }
        if let cycles = snapshot.cycleCount {
            check(cycles >= cycleLimit, flag: "alert.cycles.sent",
                  title: "Battery cycle count reached",
                  body: "Your battery has \(cycles) cycles (threshold \(cycleLimit)).")
        }
    }

    private static func check(_ triggered: Bool, flag: String, title: String, body: String) {
        guard triggered else { defaults.set(false, forKey: flag); return }
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: flag, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
