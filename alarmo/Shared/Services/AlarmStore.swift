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

        if alarm.isDaily {
            return calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
        }

        let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
        if weekdays.isEmpty {
            return calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
        }

        for weekday in weekdays.sorted() {
            var comps = base
            comps.weekday = weekday
            if let next = calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) {
                return next
            }
        }
        return nil
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            alarms = try JSONDecoder().decode([Alarm].self, from: data)
        } catch {
            alarms = []
        }
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
