import Foundation
import UserNotifications

class PlanNotificationScheduler {
    static let shared = PlanNotificationScheduler()
    
    private init() {}
    
    func schedule(_ item: PlanItem) {
        // First cancel existing to avoid duplicates
        cancel(item)
        
        guard item.reminderEnabled else { return }
        
        // Determine Sound
        let sound: UNNotificationSound
        if let fileName = item.ringtone?.fileName {
            sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        } else {
            sound = .default
        }
        
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.habitIntent == .quit ? "Don't forget your limit!" : "Time to focus on your goal!"
        if let subtitle = item.subtitle, !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        content.sound = sound
        
        // If specific reminder time is set (scheduledTime), use it.
        // If reminderOffset is set, adjust.
        // For simple tasks/habits, we usually adhere to 'scheduledTime' or 'scheduledDate' time component.
        
        guard let reminderTime = item.scheduledTime else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        // Adjust for offset if needed (simplified: subtract offset)
        if let offset = item.reminderOffset, offset > 0 {
            // This is tricky for repeating notifications because we have HH:MM components.
            // Converting to Date -> Subtract -> Back to Components is safest.
            if let date = calendar.date(from: components) {
                 let adjustedDate = date.addingTimeInterval(-offset)
                 components = calendar.dateComponents([.hour, .minute], from: adjustedDate)
            }
        }
        
        // Schedule based on repeat rule
        if item.repeatRule.frequency == .none {
            // One-time
            // If date + time is in future
            if let date = item.scheduledDate {
                // Combine date and time (from components)
                let fullDate = calendar.date(bySettingHour: components.hour!, minute: components.minute!, second: 0, of: date)
                if let fullDate = fullDate, fullDate > Date() {
                    let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fullDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                    let newContent = content.mutableCopy() as! UNMutableNotificationContent
                    addRequest(item: item, content: newContent, trigger: trigger)
                }
            }
        } else if item.repeatRule.frequency == .daily {
            // Repeat Daily at Time
            // trigger needs date components from item.scheduledTime
            let triggerDate = calendar.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            
            let newContent = content.mutableCopy() as! UNMutableNotificationContent
            addRequest(item: item, content: newContent, trigger: trigger)
            
        } else if item.repeatRule.frequency == .weekly {
            // Repeat on specific weekdays
            let weekdays = item.repeatRule.weekdays ?? []
            for day in weekdays {
                var weekdayComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
                weekdayComponents.weekday = day // 1=Sun, 7=Sat
                let trigger = UNCalendarNotificationTrigger(dateMatching: weekdayComponents, repeats: true)
                let newContent = content.mutableCopy() as! UNMutableNotificationContent
                addRequest(item: item, content: newContent, trigger: trigger, suffix: "_wd\(day)")
            }
        }
    }
    
    func cancel(_ item: PlanItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
        // Also remove any suffixed IDs (for weekly repeats)
        // Since we can't wildcard remove, we should ideally store IDs.
        // Simplify: Try removing standard suffixes for weekdays 1-7
        var ids = [item.id.uuidString]
        for i in 1...7 { ids.append("\(item.id.uuidString)_wd\(i)") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    private func addRequest(item: PlanItem, content: UNMutableNotificationContent, trigger: UNNotificationTrigger, suffix: String = "") {
        let id = item.id.uuidString + suffix
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification for \(item.title): \(error)")
            }
        }
    }
}
