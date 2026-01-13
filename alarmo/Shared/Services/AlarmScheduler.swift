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
        content.body = "Time to wake up!"
        content.categoryIdentifier = AlarmNotificationCategory.alarmRing
        content.userInfo = ["alarmId": alarm.id.uuidString]
        
        // Ensure critical alert sound or default
        if let sound = notificationSound(for: alarm) {
            content.sound = sound
        } else {
            content.sound = .default
        }
        content.interruptionLevel = .timeSensitive 

        // 1. Repeating Alarm (Daily or Specific Days)
        if alarm.repeatMask > 0 {
            if alarm.isDaily {
                var comps = DateComponents()
                comps.hour = alarm.hour
                comps.minute = alarm.minute
                comps.second = 0 // CRITICAL: Force 0 seconds
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                addRequest(id: alarm.id.uuidString, content: content, trigger: trigger, alarm: alarm)
            } else {
                let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
                for weekday in weekdays {
                    var comps = DateComponents()
                    comps.weekday = weekday
                    comps.hour = alarm.hour
                    comps.minute = alarm.minute
                    comps.second = 0
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    addRequest(id: "\(alarm.id.uuidString)-\(weekday)", content: content, trigger: trigger, alarm: alarm)
                }
            }
        } 
        // 2. One-shot Alarm
        else {
            // Find the next occurrence date
            guard let nextDate = AlarmStore.nextFireDate(for: alarm, from: Date()) else {
                print("[AlarmScheduler] ⚠️ Could not compute next fire date for one-shot alarm")
                return
            }
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nextDate)
            
            // We use calendar trigger for one-shot specific time to be precise with clock time
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            addRequest(id: alarm.id.uuidString, content: content, trigger: trigger, alarm: alarm)
        }
        
        AlarmDebug.dumpPendingNotifications()
    }
    
    private func addRequest(id: String, content: UNNotificationContent, trigger: UNNotificationTrigger, alarm: Alarm) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[AlarmScheduler] ❌ Error scheduling: \(error)")
            } else {
                AlarmDebug.logScheduleRequest(identifier: id, alarm: alarm, trigger: trigger)
            }
        }
    }

    private func notificationSound(for alarm: Alarm) -> UNNotificationSound? {
        // Try file extension variations
        let rawName = alarm.soundName
        
        // Look in main bundle root or flattened (Yellow folders)
        if Bundle.main.url(forResource: rawName, withExtension: nil) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(rawName))
        }
        
        // Look in specific ringtones folder (Blue folders)
        // Note: UNNotificationSound(named:) expects a path relative to bundle root or just filename if flattened.
        // It DOES NOT support full absolute paths.
        // If "BundledSounds/ringtones/foo.mp3" is the relative path, we use that.
        
        if let _ = Bundle.main.url(forResource: rawName, withExtension: nil, subdirectory: "BundledSounds/ringtones") {
             return UNNotificationSound(named: UNNotificationSoundName("BundledSounds/ringtones/\(rawName)"))
        }

        return .default
    }

    func scheduleSnooze(alarm: Alarm, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Snoozing"
        content.body = alarm.name.isEmpty ? "Alarm" : alarm.name
        content.categoryIdentifier = AlarmNotificationCategory.alarmRing
        content.userInfo = ["alarmId": alarm.id.uuidString]
        content.sound = notificationSound(for: alarm) ?? .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(alarm.id.uuidString)-snooze-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
        print("[AlarmScheduler] 💤 Snoozed for \(minutes)m")
    }
}
