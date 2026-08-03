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
            content.body = condensed(DailyInsightsStore.shared.motivationLine(for: .alarmRing), maxCharacters: 150)

        case .alarmSnooze:
            content.title = "Alarmo"
            content.subtitle = normalizedAlarmName(context.alarmName)
            content.body = condensed(DailyInsightsStore.shared.motivationLine(for: .alarmSnooze), maxCharacters: 150)

        case .alarmTomorrowCheck:
            content.title = "No alarm set for tomorrow"
            content.body = "Add one now and start tomorrow right on time."

        case .bedtimeReminder:
            content.title = "Time to wind down"
            if let fireTimeText = context.fireTimeText, !fireTimeText.isEmpty {
                let line = "Your next alarm is at \(fireTimeText). " + DailyInsightsStore.shared.motivationLine(for: .bedtimeReminder)
                content.body = condensed(line, maxCharacters: 170)
            } else {
                content.body = condensed(DailyInsightsStore.shared.motivationLine(for: .bedtimeReminder), maxCharacters: 150)
            }

        case .missedAlarmFollowUp:
            content.title = "Alarmo"
            content.subtitle = "You may have missed your alarm"
            content.body = condensed(DailyInsightsStore.shared.motivationLine(for: .missedAlarmFollowUp), maxCharacters: 150)
        case .taskReminder:
            let name = normalizedItemName(context.itemName, fallback: "Task")
            content.title = "Task Reminder"
            let line = "\(name) is scheduled now. " + DailyInsightsStore.shared.motivationLine(for: .taskReminder)
            content.body = condensed(line, maxCharacters: 170)
        case .taskOverdue:
            let name = normalizedItemName(context.itemName, fallback: "Task")
            content.title = "Task still pending"
            let line = "\(name) is overdue. " + DailyInsightsStore.shared.motivationLine(for: .taskOverdue)
            content.body = condensed(line, maxCharacters: 170)
        case .habitReminder:
            let name = normalizedItemName(context.itemName, fallback: "your habit")
            let detail = normalizedItemName(context.detailText, fallback: "")
            let message = habitReminderMessage(habitName: name, detailText: detail)
            content.title = message.title
            let line = message.body + " " + DailyInsightsStore.shared.motivationLine(for: .habitReminder)
            content.body = condensed(line, maxCharacters: 180)
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

    private static func habitReminderMessage(habitName: String, detailText: String) -> (title: String, body: String) {
        let source = "\(habitName) \(detailText)".lowercased()

        if source.contains("water") || source.contains("hydrate") {
            let variants = [
                ("Almost there! 💧", "Keep your streak alive. Log your water intake now."),
                ("Hydration check 💧", "A quick sip now helps you finish \(habitName) on target."),
                ("Stay hydrated 💙", "You're close — add your water progress and complete today's goal.")
            ]
            return pickStableVariant(from: variants, key: source)
        }

        if source.contains("walk") || source.contains("step") {
            let variants = [
                ("Walk boost 🚶", "A short walk now moves \(habitName) forward."),
                ("Step streak time 👟", "Keep momentum going — log your walk progress."),
                ("Move break 🚶‍♂️", "Finish strong. Add a few more steps to complete today's habit.")
            ]
            return pickStableVariant(from: variants, key: source)
        }

        if source.contains("run") || source.contains("jog") {
            let variants = [
                ("Run day 🏃", "You're one session away from closing \(habitName) today."),
                ("Pace reminder 🏃‍♀️", "Even a short run keeps your streak intact."),
                ("Finish your run ✅", "Log your run progress and lock in today's win.")
            ]
            return pickStableVariant(from: variants, key: source)
        }

        if source.contains("sleep") || source.contains("bed") {
            let variants = [
                ("Wind-down check 🌙", "Keep your sleep routine consistent tonight."),
                ("Sleep habit reminder 😴", "Start your bedtime routine and log progress."),
                ("Night routine 🛌", "A steady sleep schedule helps you hit tomorrow's goals.")
            ]
            return pickStableVariant(from: variants, key: source)
        }

        if source.contains("meditat") || source.contains("mindful") || source.contains("breathe") {
            let variants = [
                ("Reset in 2 minutes 🧘", "Take a short breathing break and log \(habitName)."),
                ("Mindful pause 🧠", "A quick session now keeps your habit streak strong."),
                ("Calm check-in ✨", "Complete today's \(habitName) with one focused session.")
            ]
            return pickStableVariant(from: variants, key: source)
        }

        let variants = [
            ("Habit check-in", "Small steps win. Log \(habitName) now."),
            ("Keep the streak alive 🔥", "You're close — finish \(habitName) today."),
            ("Progress reminder ✅", "Take one action now to complete \(habitName).")
        ]
        return pickStableVariant(from: variants, key: source)
    }

    private static func pickStableVariant(
        from variants: [(title: String, body: String)],
        key: String
    ) -> (title: String, body: String) {
        guard !variants.isEmpty else { return ("Reminder", "It's time to check in.") }
        let hash = key.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % variants.count
        return variants[index]
    }

    private static func condensed(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        let cut = text.index(text.startIndex, offsetBy: maxCharacters)
        let prefix = String(text[..<cut])
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return prefix + "…"
    }
}
