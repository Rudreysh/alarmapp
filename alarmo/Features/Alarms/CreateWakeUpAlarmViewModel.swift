import Foundation
import Combine

final class CreateWakeUpAlarmViewModel: ObservableObject {
    @Published var draft: AlarmDraft
    @Published var soundProgress: Double = 0.0

    init(defaultHour: Int, defaultMinute: Int, defaultRepeatMask: Int, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.draft = AlarmDraft(
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            defaultRepeatMask: defaultRepeatMask,
            defaultSoundName: defaultSoundName,
            defaultSoundVolume: defaultSoundVolume,
            defaultWallpaperId: defaultWallpaperId
        )
    }

    init(alarm: Alarm) {
        var draft = AlarmDraft(
            defaultHour: alarm.hour,
            defaultMinute: alarm.minute,
            defaultRepeatMask: alarm.repeatMask,
            defaultSoundName: alarm.soundName,
            defaultSoundVolume: alarm.soundVolume,
            defaultWallpaperId: alarm.wallpaperId
        )
        draft.name = alarm.name
        draft.emoji = alarm.emoji
        draft.enabled = alarm.enabled
        draft.isDaily = alarm.isDaily
        draft.selectedWeekdays = Set(RepeatMask.weekdays(from: alarm.repeatMask))
        draft.wakeUpCheckEnabled = alarm.wakeUpCheckEnabled
        draft.vibrateEnabled = alarm.vibrateEnabled
        draft.gentleWakeUpSeconds = alarm.gentleWakeUpSeconds
        draft.timeReminderEnabled = alarm.timeReminderEnabled
        draft.weatherReminderEnabled = alarm.weatherReminderEnabled
        draft.labelReminderEnabled = alarm.labelReminderEnabled
        draft.extraLoudEnabled = alarm.extraLoudEnabled
        draft.snoozeMinutes = alarm.snoozeMinutes
        draft.snoozeCount = alarm.snoozeCount
        draft.missions = alarm.missions
        self.draft = draft
    }
    
    func addMission(_ mission: AlarmMission) {
        if draft.missions.count < 5 {
            draft.missions.append(mission)
        }
    }
    
    func removeMission(at index: Int) {
        draft.missions.remove(at: index)
    }

    var ringInText: String {
        let now = Date()
        guard let next = nextFireDate(from: now) else {
            return "Ring in less than a minute"
        }
        let diff = Int(next.timeIntervalSince(now))
        if diff < 60 {
            return "Ring in less than a minute"
        }
        let hours = diff / 3600
        let minutes = (diff % 3600) / 60
        return "Ring in \(hours)hrs \(minutes)min"
    }

    func toggleDaily() {
        draft.isDaily.toggle()
        if draft.isDaily {
            draft.selectedWeekdays = Set(1...7)
        }
    }

    func toggleWeekday(_ weekday: Int) {
        if draft.selectedWeekdays.contains(weekday) {
            draft.selectedWeekdays.remove(weekday)
        } else {
            draft.selectedWeekdays.insert(weekday)
        }
    }

    func nextFireDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        let baseComponents = DateComponents(hour: draft.hour, minute: draft.minute)
        if draft.isDaily || draft.selectedWeekdays.isEmpty {
            if let today = calendar.nextDate(after: date, matching: baseComponents, matchingPolicy: .nextTime) {
                return today
            }
            return calendar.date(byAdding: .day, value: 1, to: date)
        }

        let sorted = draft.selectedWeekdays.sorted()
        for weekday in sorted {
            var comps = baseComponents
            comps.weekday = weekday
            if let next = calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) {
                return next
            }
        }
        return nil
    }

    func repeatMask() -> Int {
        RepeatMask.mask(from: Array(draft.selectedWeekdays))
    }
}
