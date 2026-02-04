import Foundation
import UserNotifications

protocol AlarmSchedulerProtocol {
    func schedule(alarm: Alarm)
    func cancel(alarmId: UUID)
    func scheduleSnooze(alarm: Alarm, minutes: Int)
}

final class AlarmScheduler: AlarmSchedulerProtocol {
    func schedule(alarm: Alarm) {
        // ALWAYS cancel first to clean up any previous state/variation of this alarm
        cancel(alarmId: alarm.id)
        
        // If disabled, we stop here (notification is already cancelled)
        guard alarm.enabled else {
            print("[AlarmScheduler] 🔕 Alarm \(alarm.id) is disabled, skipping schedule.")
            return
        }

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

        // Determine Time Zone
        var targetTimeZone: TimeZone? = nil
        if alarm.timeZoneMode == .custom, let id = alarm.timeZoneIdentifier {
            targetTimeZone = TimeZone(identifier: id)
        }
        
        // 1. Repeating Alarm (Daily or Specific Days)
        if alarm.repeatMask > 0 {
            if alarm.isDaily {
                var comps = DateComponents()
                comps.hour = alarm.hour
                comps.minute = alarm.minute
                comps.second = alarm.second
                comps.timeZone = targetTimeZone // If nil, uses current (Floating)
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                addRequest(id: alarm.id.uuidString, content: content, trigger: trigger, alarm: alarm)
            } else {
                let weekdays = RepeatMask.weekdays(from: alarm.repeatMask)
                for weekday in weekdays {
                    var comps = DateComponents()
                    comps.weekday = weekday
                    comps.hour = alarm.hour
                    comps.minute = alarm.minute
                    comps.second = alarm.second
                    comps.timeZone = targetTimeZone // If nil, uses current (Floating)
                    
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    // Use a standardized format for repeating day identifiers
                    addRequest(id: "\(alarm.id.uuidString)-day-\(weekday)", content: content, trigger: trigger, alarm: alarm)
                }
            }
        } 
        // 2. One-shot Alarm
        else {
             // Calculate next fire date in the target time zone
            var calendar = Calendar.current
            if let tz = targetTimeZone {
                calendar.timeZone = tz
            }
            
            // Logic to find next occurrence of (hour, minute) in target calendar
            let now = Date()
            var nextDateComp = DateComponents()
            nextDateComp.hour = alarm.hour
            nextDateComp.minute = alarm.minute
            nextDateComp.second = alarm.second // High-precision support
            
            // Use built-in nextDate
            guard let nextDate = calendar.nextDate(after: now, matching: nextDateComp, matchingPolicy: .nextTime) else {
                 print("[AlarmScheduler] ⚠️ Could not compute next fire date")
                 return
            }
            
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: nextDate)
            
            // We use calendar trigger for one-shot specific time to be precise with clock time
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            addRequest(id: alarm.id.uuidString, content: content, trigger: trigger, alarm: alarm)
        }
        
        AlarmDebug.dumpPendingNotifications()
    }

    func cancel(alarmId: UUID) {
        let prefix = alarmId.uuidString
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let toCancel = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !toCancel.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
                print("[AlarmScheduler] 🗑️ Cancelled \(toCancel.count) notifications for alarm \(prefix)")
            }
        }
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
        let rawName = alarm.soundName
        
        // Use recursive search or known subfolder
        // 1. Try directly (if it has extension)
        if Bundle.main.url(forResource: rawName, withExtension: nil) != nil {
            return UNNotificationSound(named: UNNotificationSoundName(rawName))
        }
        
        // 2. Try cleaned name (e.g. "Forest" -> "forest.mp3") similar to SoundPlayer
        let cleaned = rawName.replacingOccurrences(of: " ", with: "_").lowercased()
        let filename = "\(cleaned).mp3"
        
        // Check in BundledSounds/ringtones (Common location)
        if Bundle.main.url(forResource: cleaned, withExtension: "mp3", subdirectory: "BundledSounds/ringtones") != nil {
            return UNNotificationSound(named: UNNotificationSoundName("BundledSounds/ringtones/\(filename)"))
        }
        
        // Check in root
        if Bundle.main.url(forResource: cleaned, withExtension: "mp3") != nil {
            return UNNotificationSound(named: UNNotificationSoundName(filename))
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
