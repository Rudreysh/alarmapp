import Foundation
import UserNotifications

protocol AlarmSchedulerProtocol {
    func schedule(alarm: Alarm)
    func scheduleSnooze(alarm: Alarm, minutes: Int)
}

final class AlarmScheduler: AlarmSchedulerProtocol {
    func schedule(alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name.isEmpty ? "Alarm" : alarm.name
        content.body = "Alarm"
        content.categoryIdentifier = AlarmNotificationCategory.alarmRing
        content.userInfo = ["alarmId": alarm.id.uuidString]
        if let sound = notificationSound(for: alarm) {
            content.sound = sound
        } else {
            content.sound = .default
        }

        let calendar = Calendar.current
        if alarm.isDaily {
            var comps = DateComponents()
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            return
        }

        let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
        if weekdays.isEmpty {
            var comps = DateComponents()
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            return
        }

        for weekday in weekdays {
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "\(alarm.id.uuidString)-\(weekday)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    private func notificationSound(for alarm: Alarm) -> UNNotificationSound? {
        let name = alarm.soundName.replacingOccurrences(of: " ", with: "_").lowercased()
        if let _ = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "BundledSounds/ringtones") {
            return UNNotificationSound(named: UNNotificationSoundName("BundledSounds/ringtones/\(name).mp3"))
        }
        if let _ = Bundle.main.url(forResource: name, withExtension: "mp3") {
            return UNNotificationSound(named: UNNotificationSoundName("\(name).mp3"))
        }
        return nil
    }

    func scheduleSnooze(alarm: Alarm, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name.isEmpty ? "Alarm" : alarm.name
        content.body = "Snoozed alarm"
        content.categoryIdentifier = AlarmNotificationCategory.alarmRing
        content.userInfo = ["alarmId": alarm.id.uuidString]
        content.sound = notificationSound(for: alarm) ?? .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(alarm.id.uuidString)-snooze-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
