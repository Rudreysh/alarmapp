import Foundation
import UserNotifications

enum AppNotificationDomain: String, Codable, CaseIterable {
    case alarm
    case habit
    case task
    case pomodoro
    case stopwatch
    case accountability
    case system
    case marketing
}

enum AppNotificationScenario: String, Codable, CaseIterable {
    case alarmRing
    case alarmSnooze
    case alarmTomorrowCheck
    case bedtimeReminder
    case missedAlarmFollowUp
    case taskReminder
    case taskOverdue
    case habitReminder
    case pomodoroFocusStart
    case pomodoroFocusComplete
    case pomodoroBreakStart
    case pomodoroBreakComplete
    case stopwatchTargetReached
    case countdownFinished
    case countdownCycleRepeat
}

enum AppNotificationUrgency: String, Codable, CaseIterable {
    case timeSensitive
    case active
    case passive

    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .timeSensitive: return .timeSensitive
        case .active: return .active
        case .passive: return .passive
        }
    }
}

enum AppNotificationCadence: String, Codable, CaseIterable {
    case off
    case smart
    case frequent
}

enum NotificationQuietHoursPolicy: String, Codable {
    case allow
    case suppress
    case allowTimeSensitive
}

struct AppNotificationRule {
    let domain: AppNotificationDomain
    let urgency: AppNotificationUrgency
    let maxPerDay: Int
    let cooldownSeconds: TimeInterval
    let quietHoursPolicy: NotificationQuietHoursPolicy
    let isCritical: Bool
}

enum AppNotificationRulebook {
    static func rule(for scenario: AppNotificationScenario) -> AppNotificationRule {
        switch scenario {
        case .alarmRing:
            return AppNotificationRule(
                domain: .alarm,
                urgency: .timeSensitive,
                maxPerDay: 40,
                cooldownSeconds: 1,
                quietHoursPolicy: .allowTimeSensitive,
                isCritical: true
            )
        case .alarmSnooze:
            return AppNotificationRule(
                domain: .alarm,
                urgency: .timeSensitive,
                maxPerDay: 40,
                cooldownSeconds: 1,
                quietHoursPolicy: .allowTimeSensitive,
                isCritical: true
            )
        case .alarmTomorrowCheck:
            return AppNotificationRule(
                domain: .alarm,
                urgency: .active,
                maxPerDay: 1,
                cooldownSeconds: 60 * 60 * 4,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .bedtimeReminder:
            return AppNotificationRule(
                domain: .alarm,
                urgency: .passive,
                maxPerDay: 1,
                cooldownSeconds: 60 * 60 * 8,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .missedAlarmFollowUp:
            return AppNotificationRule(
                domain: .alarm,
                urgency: .active,
                maxPerDay: 2,
                cooldownSeconds: 60 * 60,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .taskReminder:
            return AppNotificationRule(
                domain: .task,
                urgency: .active,
                maxPerDay: 8,
                cooldownSeconds: 60 * 5,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .taskOverdue:
            return AppNotificationRule(
                domain: .task,
                urgency: .active,
                maxPerDay: 4,
                cooldownSeconds: 60 * 30,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .habitReminder:
            return AppNotificationRule(
                domain: .habit,
                urgency: .active,
                maxPerDay: 6,
                cooldownSeconds: 60 * 10,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .pomodoroFocusStart:
            return AppNotificationRule(
                domain: .pomodoro,
                urgency: .passive,
                maxPerDay: 12,
                cooldownSeconds: 60 * 5,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .pomodoroFocusComplete, .pomodoroBreakComplete:
            return AppNotificationRule(
                domain: .pomodoro,
                urgency: .active,
                maxPerDay: 20,
                cooldownSeconds: 10,
                quietHoursPolicy: .allowTimeSensitive,
                isCritical: false
            )
        case .pomodoroBreakStart:
            return AppNotificationRule(
                domain: .pomodoro,
                urgency: .active,
                maxPerDay: 20,
                cooldownSeconds: 10,
                quietHoursPolicy: .suppress,
                isCritical: false
            )
        case .stopwatchTargetReached:
            return AppNotificationRule(
                domain: .stopwatch,
                urgency: .active,
                maxPerDay: 8,
                cooldownSeconds: 30,
                quietHoursPolicy: .allow,
                isCritical: false
            )
        case .countdownFinished, .countdownCycleRepeat:
            return AppNotificationRule(
                domain: .stopwatch,
                urgency: .active,
                maxPerDay: 12,
                cooldownSeconds: 10,
                quietHoursPolicy: .allow,
                isCritical: false
            )
        }
    }
}

enum AppNotificationIdentifier {
    static let alarmTomorrowCheck = "alarmo.alarm.tomorrow-check"
    static let bedtimeReminder = "alarmo.alarm.bedtime-reminder"
    static let pomodoroSegmentEnd = "alarmo.pomodoro.segment-end"
    static let stopwatchTarget = "alarmo.stopwatch.target"
    static let countdownFinish = "alarmo.countdown.finish"
}

struct AppNotificationContext {
    var alarmName: String?
    var itemName: String?
    var fireTimeText: String?
    var detailText: String?
}
