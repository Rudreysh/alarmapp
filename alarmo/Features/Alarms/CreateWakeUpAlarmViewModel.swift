import Foundation
import Combine

final class CreateWakeUpAlarmViewModel: ObservableObject {
    @Published var draft: AlarmDraft
    @Published var soundProgress: Double = 0.0

    init(defaultHour: Int, defaultMinute: Int, defaultRepeatMask: Int, defaultSoundName: String, defaultSoundVolume: Float) {
        self.draft = AlarmDraft(
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            defaultRepeatMask: defaultRepeatMask,
            defaultSoundName: defaultSoundName,
            defaultSoundVolume: defaultSoundVolume
        )
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
