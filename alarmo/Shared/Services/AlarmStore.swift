import Foundation
import Combine

final class AlarmStore: ObservableObject {
    static let shared = AlarmStore() // Allow singleton access for non-view contexts
    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL
    private let persistenceQueue = DispatchQueue(label: "alarm.store.persistence", qos: .utility)
    private let persistenceQueueKey = DispatchSpecificKey<Void>()

    init(fileManager: FileManager = .default) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = documents.appendingPathComponent("alarms.json")
        self.persistenceQueue.setSpecific(key: persistenceQueueKey, value: ())
        load()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.persistenceQueue.setSpecific(key: persistenceQueueKey, value: ())
        load()
    }

    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        if alarm.type == .quick {
            persistSync()
        } else {
            persistAsync()
        }
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index] = alarm
        if alarm.type == .quick {
            persistSync()
        } else {
            persistAsync()
        }
    }

    func remove(id: UUID) {
        let removedWasQuick = alarms.first(where: { $0.id == id })?.type == .quick
        alarms.removeAll { $0.id == id }
        if removedWasQuick {
            persistSync()
        } else {
            persistAsync()
        }
    }

    func toggleEnabled(id: UUID, enabled: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].enabled = enabled
        if alarms[index].type == .quick {
            persistSync()
        } else {
            persistAsync()
        }
    }

    func moveAlarmUp(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }), index > 0 else { return }
        alarms.swapAt(index, index - 1)
        persistAsync()
    }

    func moveAlarmDown(id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }), index < alarms.count - 1 else { return }
        alarms.swapAt(index, index + 1)
        persistAsync()
    }

    func moveAlarm(from sourceIndex: Int, to destinationIndex: Int) {
        guard alarms.indices.contains(sourceIndex) else { return }
        guard destinationIndex >= 0 && destinationIndex <= alarms.count else { return }
        guard sourceIndex != destinationIndex else { return }

        var reordered = alarms
        let moved = reordered.remove(at: sourceIndex)
        let targetIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        reordered.insert(moved, at: max(0, min(targetIndex, reordered.count)))
        alarms = reordered
        persistAsync()
    }

    // MARK: - Bulk Global Operations

    /// Apply snooze duration to all alarms and reschedule
    func applyGlobalSnooze(minutes: Int) {
        let scheduler = AlarmManagerFacade.shared
        for index in alarms.indices {
            alarms[index].snoozeMinutes = minutes
        }
        persistAsync()
        // Reschedule all enabled alarms
        for alarm in alarms where alarm.enabled {
            scheduler.schedule(alarm: alarm)
        }
    }

    /// Apply volume to all alarms (no reschedule needed; soundVolume is read at ring time)
    func applyGlobalVolume(volume: Float) {
        for index in alarms.indices {
            alarms[index].soundVolume = volume
        }
        persistAsync()
    }

    /// Apply vibration setting to all alarms
    func applyGlobalVibration(enabled: Bool) {
        for index in alarms.indices {
            alarms[index].vibrateEnabled = enabled
        }
        persistAsync()
    }

    /// Skip weekends: strip Sat/Sun bits from repeatMask, or restore originals.
    /// Original masks are persisted so toggling off restores per-alarm settings.
    func applySkipWeekends(_ skip: Bool) {
        let key = "alarmo.qs.originalRepeatMasks"
        let scheduler = AlarmManagerFacade.shared

        if skip {
            // Save original masks before stripping weekend days
            var originals: [String: Int] = [:]
            for index in alarms.indices {
                let alarm = alarms[index]
                originals[alarm.id.uuidString] = alarm.repeatMask
                // Strip Sunday (bit 0) and Saturday (bit 6)
                let withoutWeekend = alarm.repeatMask & ~(RepeatMask.sunday | RepeatMask.saturday)
                alarms[index].repeatMask = withoutWeekend
            }
            if let data = try? JSONEncoder().encode(originals) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } else {
            // Restore original masks
            if let data = UserDefaults.standard.data(forKey: key),
               let originals = try? JSONDecoder().decode([String: Int].self, from: data) {
                for index in alarms.indices {
                    let idStr = alarms[index].id.uuidString
                    if let original = originals[idStr] {
                        alarms[index].repeatMask = original
                    }
                }
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        persistAsync()
        // Reschedule all enabled alarms
        for alarm in alarms where alarm.enabled {
            scheduler.schedule(alarm: alarm)
        }
    }

    /// Returns alarms sorted by the given sort order
    func sortedAlarms(by order: Int) -> [Alarm] {
        switch order {
        case 1: // Active first, then by time
            return alarms.sorted { a, b in
                if a.enabled != b.enabled { return a.enabled }
                return a.hour * 60 + a.minute < b.hour * 60 + b.minute
            }
        case 2: // Recently added
            return alarms.sorted { $0.createdAt > $1.createdAt }
        case 3: // Manual order
            return alarms
        default: // Sort by time
            return alarms.sorted { a, b in
                let aMin = a.hour * 60 + a.minute
                let bMin = b.hour * 60 + b.minute
                return aMin < bMin
            }
        }
    }

    /// Smart Wake: shift alarm times earlier by windowMinutes, or restore originals.
    func applySmartWake(enabled: Bool, windowMinutes: Int) {
        let key = "alarmo.qs.smartWakeOriginals"
        let scheduler = AlarmManagerFacade.shared

        if enabled {
            var originals: [String: [String: Int]] = [:]
            for index in alarms.indices {
                let alarm = alarms[index]
                originals[alarm.id.uuidString] = ["h": alarm.hour, "m": alarm.minute]
                let totalMinutes = alarm.hour * 60 + alarm.minute - windowMinutes
                let normalized = ((totalMinutes % 1440) + 1440) % 1440
                alarms[index].hour = normalized / 60
                alarms[index].minute = normalized % 60
            }
            if let data = try? JSONEncoder().encode(originals) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } else {
            if let data = UserDefaults.standard.data(forKey: key),
               let originals = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
                for index in alarms.indices {
                    let idStr = alarms[index].id.uuidString
                    if let orig = originals[idStr] {
                        alarms[index].hour = orig["h"] ?? alarms[index].hour
                        alarms[index].minute = orig["m"] ?? alarms[index].minute
                    }
                }
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        persistAsync()
        for alarm in alarms where alarm.enabled {
            scheduler.schedule(alarm: alarm)
        }
    }

    func alarm(by id: UUID) -> Alarm? {
        alarms.first { $0.id == id }
    }

    func hasAnyAlarmScheduled(referenceDate: Date = Date()) -> Bool {
        alarms.contains { alarm in
            alarm.enabled && Self.nextFireDate(for: alarm, from: referenceDate) != nil
        }
    }

    static func nextFireDate(for alarm: Alarm, from date: Date) -> Date? {
        var calendar = Calendar.current
        
        // Respect Custom Time Zone if enabled
        if alarm.timeZoneMode == .custom, let id = alarm.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
            calendar.timeZone = tz
        }
        
        var base = DateComponents()
        base.hour = alarm.hour
        base.minute = alarm.minute
        base.second = alarm.second // High-precision support

        if alarm.isDaily {
            let next = calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
            return next
        }

        let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
        if weekdays.isEmpty {
            // One-shot: if time has passed today, schedule for tomorrow
            let next = calendar.nextDate(after: date, matching: base, matchingPolicy: .nextTime)
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

    private func persistAsync() {
        let snapshot = alarms
        let destination = fileURL
        persistenceQueue.async {
            Self.writeSnapshot(snapshot, to: destination)
        }
    }

    private func persistSync() {
        let snapshot = alarms
        let destination = fileURL
        if DispatchQueue.getSpecific(key: persistenceQueueKey) != nil {
            Self.writeSnapshot(snapshot, to: destination)
        } else {
            persistenceQueue.sync {
                Self.writeSnapshot(snapshot, to: destination)
            }
        }
    }

    private static func writeSnapshot(_ snapshot: [Alarm], to destination: URL) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: destination, options: [.atomic])
        } catch {
            #if DEBUG
            print("[AlarmStore] Persist failed: \(error)")
            #endif
        }
    }
}
