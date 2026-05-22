import Foundation
import UserNotifications

struct AlarmDebug {
    
    static func logScheduleRequest(identifier: String, alarm: Alarm, trigger: UNNotificationTrigger?) {
        print("\n[AlarmSchedule] 🚀 Scheduling Notification")
        print("   ID: \(identifier)")
        print("   Alarm Time: \(alarm.timeString)")
        print("   Repeats: \(alarm.repeatMask > 0 ? "Yes" : "No")")
        print("   Sound: \(alarm.soundName)")
        
        if let calTrigger = trigger as? UNCalendarNotificationTrigger {
            print("   Trigger Components: \(calTrigger.dateComponents)")
            if let nextDate = calTrigger.nextTriggerDate() {
                print("   Next Fire Date: \(nextDate)")
            } else {
                print("   ⚠️ WARNING: Trigger has no next fire date!")
            }
        } else if let timeTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            print("   Trigger Interval: \(timeTrigger.timeInterval)s")
            if let nextDate = timeTrigger.nextTriggerDate() {
                print("   Next Fire Date: \(nextDate)")
            }
        }
    }
    
    static func dumpPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n[AlarmPending] 📋 Pending Requests: \(requests.count)")
            for req in requests {
                print("   --------------------------------")
                print("   ID: \(req.identifier)")
                print("   Title: \(req.content.title)")
                if let trigger = req.trigger {
                    if let cal = trigger as? UNCalendarNotificationTrigger, let next = cal.nextTriggerDate() {
                        print("   Next Fire: \(next)")
                    } else if let interval = trigger as? UNTimeIntervalNotificationTrigger, let next = interval.nextTriggerDate() {
                        print("   Next Fire: \(next)")
                    } else {
                        print("   Trigger: \(trigger)")
                    }
                }
            }
            print("   --------------------------------\n")
        }
    }
    
    static func logFire(alarmId: String, source: String) {
        print("\n[AlarmFire] 🔥 Alarm Fired!")
        print("   ID: \(alarmId)")
        print("   Source: \(source)")
    }
}
