import Foundation

/// One stored daily data point.
struct HealthEntry: Codable, Identifiable, Equatable {
    var date: Date
    var health: Double
    var cycles: Int?
    var id: Date { date }
}

/// Persists one health snapshot per day to a small JSON file in Application Support.
final class HistoryStore {
    private(set) var entries: [HealthEntry] = []
    private let url: URL?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("BatteryHealthLens", isDirectory: true)
        if let dir { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        url = dir?.appendingPathComponent("history.json")
        load()
    }

    private func load() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = ((try? decoder.decode([HealthEntry].self, from: data)) ?? []).sorted { $0.date < $1.date }
    }

    /// Records today's snapshot if none exists yet. Implausible readings are discarded.
    func recordIfNeeded(_ snapshot: BatterySnapshot, now: Date = Date()) {
        guard let health = snapshot.healthPercent, health > 0, health <= 120 else { return }
        let cal = Calendar.current
        if let last = entries.last, cal.isDate(last.date, inSameDayAs: now) { return }
        entries.append(HealthEntry(date: now, health: (health * 10).rounded() / 10, cycles: snapshot.cycleCount))
        if let cutoff = cal.date(byAdding: .year, value: -5, to: now) {
            entries.removeAll { $0.date < cutoff }
        }
        save()
    }

    private func save() {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) { try? data.write(to: url, options: .atomic) }
    }
}
