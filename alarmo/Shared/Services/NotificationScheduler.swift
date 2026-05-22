import Foundation
import UserNotifications

class PlanNotificationScheduler {
    static let shared = PlanNotificationScheduler()
    private let orchestrator = NotificationOrchestrator.shared
    
    private init() {}
    
    func schedule(_ item: PlanItem) {
        // First cancel existing to avoid duplicates
        cancel(item)
        
        guard item.reminderEnabled else { return }
        
        let sound = notificationSound(for: item)
        let scenario = reminderScenario(for: item)
        guard let reminderTime = item.scheduledTime else { return }
        let calendar = Calendar.current
        let baseTimeComponents = adjustedTimeComponents(
            from: reminderTime,
            offset: item.reminderOffset,
            calendar: calendar
        )
        let now = Date()

        switch item.repeatRule.frequency {
        case .none:
            guard let date = item.scheduledDate,
                  let fireDate = combinedDate(
                    date: date,
                    timeComponents: baseTimeComponents,
                    calendar: calendar
                  ),
                  fireDate > now else { return }

            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            addRequest(
                item: item,
                trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false),
                scenario: scenario,
                sound: sound
            )

            // One-time overdue follow-up nudges after 30 minutes.
            let overdueDate = fireDate.addingTimeInterval(30 * 60)
            if overdueDate > now {
                let overdueComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: overdueDate)
                addRequest(
                    item: item,
                    trigger: UNCalendarNotificationTrigger(dateMatching: overdueComponents, repeats: false),
                    scenario: .taskOverdue,
                    sound: sound,
                    suffix: "_ovd"
                )
            }

        case .daily:
            let trigger = UNCalendarNotificationTrigger(dateMatching: baseTimeComponents, repeats: true)
            addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound)

        case .weekly:
            let weekdays = item.repeatRule.weekdays ?? []
            if weekdays.isEmpty {
                var fallback = baseTimeComponents
                fallback.weekday = calendar.component(.weekday, from: now)
                let trigger = UNCalendarNotificationTrigger(dateMatching: fallback, repeats: true)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_wd")
                return
            }
            for day in weekdays {
                var weekdayComponents = baseTimeComponents
                weekdayComponents.weekday = day // 1=Sun, 7=Sat
                let trigger = UNCalendarNotificationTrigger(dateMatching: weekdayComponents, repeats: true)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_wd\(day)")
            }

        case .monthly:
            let day = item.repeatRule.dayOfMonth
                ?? calendar.component(.day, from: item.scheduledDate ?? item.createdAt)
            if item.repeatRule.interval <= 1 {
                var monthlyComponents = baseTimeComponents
                monthlyComponents.day = min(max(day, 1), 31)
                let trigger = UNCalendarNotificationTrigger(dateMatching: monthlyComponents, repeats: true)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_mo")
            } else if let next = nextRepeatingOccurrence(for: item, now: now, timeComponents: baseTimeComponents, calendar: calendar) {
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_mo_next")
            }

        case .custom:
            if item.repeatRule.interval <= 1 {
                let trigger = UNCalendarNotificationTrigger(dateMatching: baseTimeComponents, repeats: true)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_c")
            } else if let next = nextRepeatingOccurrence(for: item, now: now, timeComponents: baseTimeComponents, calendar: calendar) {
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                addRequest(item: item, trigger: trigger, scenario: scenario, sound: sound, suffix: "_c_next")
            }
        }
    }
    
    func cancel(_ item: PlanItem) {
        var ids = [item.id.uuidString]
        for i in 1...7 { ids.append("\(item.id.uuidString)_wd\(i)") }
        ids.append("\(item.id.uuidString)_ovd")
        ids.append("\(item.id.uuidString)_wd")
        ids.append("\(item.id.uuidString)_mo")
        ids.append("\(item.id.uuidString)_mo_next")
        ids.append("\(item.id.uuidString)_c")
        ids.append("\(item.id.uuidString)_c_next")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    private func addRequest(
        item: PlanItem,
        trigger: UNNotificationTrigger,
        scenario: AppNotificationScenario,
        sound: UNNotificationSound,
        suffix: String = ""
    ) {
        let id = item.id.uuidString + suffix
        orchestrator.schedule(
            identifier: id,
            scenario: scenario,
            trigger: trigger,
            context: AppNotificationContext(itemName: item.title, detailText: item.subtitle),
            categoryIdentifier: AppNotificationCategory.planReminder,
            userInfo: [
                "planItemId": item.id.uuidString,
                "scenario": scenario.rawValue,
                "itemName": item.title
            ],
            sound: sound
        ) { success in
            if !success {
                print("Error scheduling notification for \(item.title): request not accepted")
            }
        }
    }

    private func reminderScenario(for item: PlanItem) -> AppNotificationScenario {
        item.type == .habit ? .habitReminder : .taskReminder
    }

    private func notificationSound(for item: PlanItem) -> UNNotificationSound {
        if let fileName = item.ringtone?.fileName {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        }
        return .default
    }

    private func adjustedTimeComponents(
        from time: Date,
        offset: TimeInterval?,
        calendar: Calendar
    ) -> DateComponents {
        let base = calendar.dateComponents([.hour, .minute], from: time)
        guard let offset, offset > 0,
              let hour = base.hour,
              let minute = base.minute else {
            return base
        }
        let today = calendar.startOfDay(for: Date())
        guard let sameDayTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) else {
            return base
        }
        let adjusted = sameDayTime.addingTimeInterval(-offset)
        return calendar.dateComponents([.hour, .minute], from: adjusted)
    }

    private func combinedDate(
        date: Date,
        timeComponents: DateComponents,
        calendar: Calendar
    ) -> Date? {
        guard let hour = timeComponents.hour, let minute = timeComponents.minute else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }

    private func nextRepeatingOccurrence(
        for item: PlanItem,
        now: Date,
        timeComponents: DateComponents,
        calendar: Calendar
    ) -> Date? {
        let startDay = calendar.startOfDay(for: item.scheduledDate ?? item.createdAt)
        var day = max(startDay, calendar.startOfDay(for: now))

        // Scan up to two years ahead for the next matching date.
        for _ in 0..<730 {
            if item.repeatRule.occurs(on: day, createdAt: item.createdAt),
               let fireDate = combinedDate(date: day, timeComponents: timeComponents, calendar: calendar),
               fireDate > now {
                return fireDate
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return nil
    }
}
