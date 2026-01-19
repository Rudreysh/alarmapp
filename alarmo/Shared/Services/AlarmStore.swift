import Foundation
import Combine

final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documents.appendingPathComponent("alarms.json")
        load()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        persist()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        persist()
    }

    func remove(id: UUID) {
        alarms.removeAll { $0.id == id }
        persist()
    }

    func toggleEnabled(id: UUID, enabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].enabled = enabled
        persist()
    }

    func alarm(by id: UUID) -> Alarm? {
        alarms.first { $0.id == id }
    }

    static func nextFireDate(for alarm: Alarm, from date: Date) -> Date? {
        let calendar = Calendar.current
        var base = DateComponents()
        base.hour = alarm.hour
        base.minute = alarm.minute
        base.second = 0 // Critical precision

        if alarm.isDaily {
            let next = calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
            print("[AlarmStore] Next Daily for \(alarm.hour):\(alarm.minute) -> \(String(describing: next))")
            return next
        }

        let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
        if weekdays.isEmpty {
            // One-shot: if time has passed today, schedule for tomorrow
            let next = calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
            print("[AlarmStore] Next OneShot for \(alarm.hour):\(alarm.minute) -> \(String(describing: next))")
            return next
        }

        // Specific days
        var candidates: [Date] = []
        for weekday in weekdays {
            var comps = base
            comps.weekday = weekday
            if let next = calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) {
                candidates.append(next)
            }
        }
        let chosen = candidates.sorted().first
        print("[AlarmStore] Next Repeating for \(alarm.hour):\(alarm.minute) -> \(String(describing: chosen))")
        return chosen
    }


    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Alarm].self, from: data)
            alarms = migrateDefaultWallpapers(in: decoded)
        } catch {
            alarms = []
        }
    }

    private func migrateDefaultWallpapers(in list: [Alarm]) -> [Alarm] {
        guard let firstCategory = WallpaperConfig.categories.first,
              let firstFilename = firstCategory.imageNames.first else {
            return list
        }
        let fallbackId = "\(firstCategory.id)-\(firstFilename)"
        var updated: [Alarm] = []
        var didChange = false
        for var alarm in list {
            if alarm.wallpaperId == "default" {
                alarm.wallpaperId = fallbackId
                didChange = true
            }
            updated.append(alarm)
        }
        if didChange {
            do {
                let data = try JSONEncoder().encode(updated)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                return updated
            }
        }
        return updated
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(alarms)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }
}
