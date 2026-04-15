import Foundation
import UserNotifications

final class NotificationOrchestrator {
    static let shared = NotificationOrchestrator()

    private let center = UNUserNotificationCenter.current()
    private let settings = SettingsStore.shared
    private let lastSentAtKey = "alarmo.notifications.lastSentAtByScenario"
    private let dailyCountKeyPrefix = "alarmo.notifications.dailyCount."

    private init() {}

    func schedule(
        identifier: String,
        scenario: AppNotificationScenario,
        trigger: UNNotificationTrigger,
        context: AppNotificationContext,
        categoryIdentifier: String? = nil,
        userInfo: [AnyHashable: Any] = [:],
        sound: UNNotificationSound? = nil,
        attachments: [UNNotificationAttachment] = [],
        force: Bool = false,
        onCompletion: ((Bool) -> Void)? = nil
    ) {
        let rule = AppNotificationRulebook.rule(for: scenario)

        if !force {
            guard isScenarioEnabled(scenario) else {
                onCompletion?(false)
                return
            }
            guard !shouldSuppressByQuietHours(rule: rule) else {
                onCompletion?(false)
                return
            }
            guard canSend(rule: rule, scenario: scenario) else {
                onCompletion?(false)
                return
            }
        }

        let content = NotificationTemplateBuilder.content(for: scenario, context: context)
        // Group notifications by feature in Notification Center for cleaner stacked cards.
        content.threadIdentifier = "alarmo.\(rule.domain.rawValue)"
        content.summaryArgument = summaryArgument(for: scenario, context: context)
        content.summaryArgumentCount = 1
        content.interruptionLevel = rule.urgency.interruptionLevel
        if rule.isCritical && EntitlementInspector.hasCriticalAlertsAccess {
            content.interruptionLevel = .critical
        }
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        if let sound {
            content.sound = sound
        }
        if !attachments.isEmpty {
            content.attachments = attachments
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { [weak self] error in
            if let error {
                print("[NotificationOrchestrator] Failed to schedule \(scenario.rawValue): \(error)")
                onCompletion?(false)
                return
            }
            self?.markSent(scenario: scenario)
            onCompletion?(true)
        }
    }

    func cancel(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func reconcileAlarmLifecycleNotifications(alarms: [Alarm], now: Date = Date()) {
        let prefs = settings.notificationPrefs
        guard prefs.alarmReminderEnabled,
              prefs.alarm.enabled,
              prefs.alarmRules.tomorrowCheckEnabled else {
            cancel(identifiers: [AppNotificationIdentifier.alarmTomorrowCheck])
            return
        }

        let hasAlarmTomorrow = alarms.contains { alarm in
            guard alarm.enabled else { return false }
            guard let next = AlarmStore.nextFireDate(for: alarm, from: now) else { return false }
            return Calendar.current.isDate(next, equalTo: now.addingTimeInterval(24 * 60 * 60), toGranularity: .day)
        }

        if hasAlarmTomorrow {
            cancel(identifiers: [AppNotificationIdentifier.alarmTomorrowCheck])
            return
        }

        let targetDate = tomorrowCheckDate(from: now)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: targetDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        schedule(
            identifier: AppNotificationIdentifier.alarmTomorrowCheck,
            scenario: .alarmTomorrowCheck,
            trigger: trigger,
            context: AppNotificationContext(),
            sound: .default,
            force: true
        )
    }

    func scheduleBedtimeReminder(
        at date: Date,
        nextAlarmTimeText: String
    ) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        schedule(
            identifier: AppNotificationIdentifier.bedtimeReminder,
            scenario: .bedtimeReminder,
            trigger: trigger,
            context: AppNotificationContext(fireTimeText: nextAlarmTimeText),
            sound: .default,
            force: true
        )
    }

    private func isScenarioEnabled(_ scenario: AppNotificationScenario) -> Bool {
        let prefs = settings.notificationPrefs
        let feature = featurePrefs(for: scenario)
        if !feature.enabled || feature.cadence == .off {
            return false
        }
        switch scenario {
        case .alarmRing, .alarmSnooze:
            return true
        case .alarmTomorrowCheck:
            return prefs.alarmReminderEnabled && prefs.alarm.enabled && prefs.alarmRules.tomorrowCheckEnabled
        case .bedtimeReminder:
            return prefs.alarm.enabled && prefs.alarmRules.bedtimeReminderEnabled
        case .missedAlarmFollowUp:
            return prefs.alarm.enabled && prefs.alarmRules.missedAlarmFollowUpEnabled
        case .taskReminder, .taskOverdue:
            return prefs.tasks.enabled
        case .habitReminder:
            return prefs.habits.enabled
        case .pomodoroFocusStart, .pomodoroFocusComplete, .pomodoroBreakStart, .pomodoroBreakComplete:
            return prefs.pomodoro.enabled
        case .stopwatchTargetReached, .countdownFinished, .countdownCycleRepeat:
            return prefs.stopwatch.enabled
        }
    }

    private func shouldSuppressByQuietHours(rule: AppNotificationRule, now: Date = Date()) -> Bool {
        let quiet = settings.notificationPrefs.quietHours
        guard quiet.enabled else { return false }
        guard isQuietHours(now, quietHours: quiet) else { return false }

        switch rule.quietHoursPolicy {
        case .allow:
            return false
        case .suppress:
            return true
        case .allowTimeSensitive:
            return !(quiet.allowTimeSensitive && rule.urgency == .timeSensitive)
        }
    }

    private func isQuietHours(_ now: Date, quietHours: NotificationQuietHoursPrefs) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        let start = min(23, max(0, quietHours.startHour))
        let end = min(23, max(0, quietHours.endHour))

        if start == end {
            return true
        }
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    private func canSend(rule: AppNotificationRule, scenario: AppNotificationScenario, now: Date = Date()) -> Bool {
        let key = scenario.rawValue
        let last = loadLastSentAt()[key] ?? 0
        if last > 0, now.timeIntervalSince1970 - last < rule.cooldownSeconds {
            return false
        }

        let dayKey = dailyCountKey(for: now)
        let counts = loadDailyCount(dayKey: dayKey)
        let sentToday = counts[key] ?? 0
        let featureCap = max(1, featurePrefs(for: scenario).maxPerDay)
        return sentToday < min(rule.maxPerDay, featureCap)
    }

    private func markSent(scenario: AppNotificationScenario, now: Date = Date()) {
        let key = scenario.rawValue
        var last = loadLastSentAt()
        last[key] = now.timeIntervalSince1970
        UserDefaults.standard.set(last, forKey: lastSentAtKey)

        let dayKey = dailyCountKey(for: now)
        var counts = loadDailyCount(dayKey: dayKey)
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: dailyCountStorageKey(dayKey: dayKey))
    }

    private func loadLastSentAt() -> [String: TimeInterval] {
        (UserDefaults.standard.dictionary(forKey: lastSentAtKey) as? [String: TimeInterval]) ?? [:]
    }

    private func loadDailyCount(dayKey: String) -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: dailyCountStorageKey(dayKey: dayKey)) as? [String: Int]) ?? [:]
    }

    private func dailyCountKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dailyCountStorageKey(dayKey: String) -> String {
        dailyCountKeyPrefix + dayKey
    }

    private func tomorrowCheckDate(from now: Date) -> Date {
        let calendar = Calendar.current
        if let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), evening > now {
            return evening
        }
        return now.addingTimeInterval(5 * 60)
    }

    private func featurePrefs(for scenario: AppNotificationScenario) -> NotificationFeaturePrefs {
        let prefs = settings.notificationPrefs
        switch scenario {
        case .alarmRing, .alarmSnooze, .alarmTomorrowCheck, .bedtimeReminder, .missedAlarmFollowUp:
            return prefs.alarm
        case .taskReminder, .taskOverdue:
            return prefs.tasks
        case .habitReminder:
            return prefs.habits
        case .pomodoroFocusStart, .pomodoroFocusComplete, .pomodoroBreakStart, .pomodoroBreakComplete:
            return prefs.pomodoro
        case .stopwatchTargetReached, .countdownFinished, .countdownCycleRepeat:
            return prefs.stopwatch
        }
    }

    private func summaryArgument(for scenario: AppNotificationScenario, context: AppNotificationContext) -> String {
        switch scenario {
        case .habitReminder:
            let fallback = "Habit"
            let name = (context.itemName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? fallback : name
        case .taskReminder, .taskOverdue:
            let fallback = "Task"
            let name = (context.itemName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? fallback : name
        default:
            return "Alarmo"
        }
    }
}
