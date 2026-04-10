import Foundation
import UserNotifications

enum NotificationTemplateBuilder {
    static func content(
        for scenario: AppNotificationScenario,
        context: AppNotificationContext
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()

        switch scenario {
        case .alarmRing:
            let name = normalizedAlarmName(context.alarmName)
            content.title = "Alarmo"
            content.subtitle = name
            content.body = "Time to wake up! Use Snooze or Stop from the lock screen."

        case .alarmSnooze:
            content.title = "Alarmo"
            content.subtitle = normalizedAlarmName(context.alarmName)
            content.body = "Snoozing. We'll ring again soon."

        case .alarmTomorrowCheck:
            content.title = "No alarm for tomorrow"
            content.body = "Set an alarm now so you don't miss your morning."

        case .bedtimeReminder:
            content.title = "Time to wind down"
            if let fireTimeText = context.fireTimeText, !fireTimeText.isEmpty {
                content.body = "Your next alarm is at \(fireTimeText). Start preparing for sleep."
            } else {
                content.body = "Start preparing for sleep."
            }

        case .missedAlarmFollowUp:
            content.title = "Alarmo"
            content.subtitle = "You may have missed your alarm"
            content.body = "Open Alarmo to check and reschedule if needed."
        case .taskReminder:
            let name = normalizedItemName(context.itemName, fallback: "Task")
            content.title = "Task Reminder"
            content.body = "\(name) is scheduled now."
        case .taskOverdue:
            let name = normalizedItemName(context.itemName, fallback: "Task")
            content.title = "Task still pending"
            content.body = "\(name) is overdue."
        case .habitReminder:
            let name = normalizedItemName(context.itemName, fallback: "Habit")
            content.title = "Habit Check-in"
            content.body = "Time to log \(name)."
        case .pomodoroFocusStart:
            content.title = "Focus session started"
            content.body = "Stay in flow. You got this."
        case .pomodoroFocusComplete:
            content.title = "Focus complete"
            content.body = "Great work. Take a short break."
        case .pomodoroBreakStart:
            content.title = "Break started"
            content.body = "Recharge for your next focus session."
        case .pomodoroBreakComplete:
            content.title = "Break complete"
            content.body = "Ready to get back to focus?"
        case .stopwatchTargetReached:
            content.title = "Stopwatch target reached"
            content.body = "You've hit your target time."
        case .countdownFinished:
            content.title = "Countdown finished"
            content.body = "Time is up."
        case .countdownCycleRepeat:
            content.title = "Countdown cycle complete"
            content.body = "Starting next repeat cycle."
        }

        if let detail = context.detailText, !detail.isEmpty {
            content.subtitle = detail
        }

        return content
    }

    private static func normalizedAlarmName(_ name: String?) -> String {
        normalizedItemName(name, fallback: "Alarm")
    }

    private static func normalizedItemName(_ name: String?, fallback: String) -> String {
        guard let name else { return fallback }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
