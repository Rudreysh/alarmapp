import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - Points Configuration (Discipline v1)

enum PointsConfig {
    // Alarm
    static let alarmDismissedClean = 20
    static let alarmDismissedWithMission = 20
    static let alarmDismissedAfterSnooze = 5
    static let alarmSnoozePenalty = 0
    static let alarmMissedPenalty = -20

    // Habits
    static let habitCompleted = 15
    static let habitSkippedPenalty = -5
    static let habitStreakMilestone = 50

    // Tasks
    static let taskCompleted = 10
    static let taskCompletedEarly = 15
    static let taskMissedPenalty = -10

    // Pomodoro / Focus
    static let focusSessionCompleted = 10
    static let focusSessionInterruptedPenalty = -5
    static let focusFourSessionBonus = 40

    // Backward-compatible names used by existing UI copy
    static let focusPerFiveMinutes = focusSessionCompleted
    static let focusSessionComplete = focusSessionCompleted

    // Stopwatch
    static let stopwatch20Min = 5
    static let stopwatch60Min = 10

    // Daily
    static let dailyLogin = 1

    // Discipline Levels (cumulative points)
    static let levelThresholds: [Int] = [0, 200, 500, 1000, 2000, 5000]
    static let levelTitles: [String] = [
        "Beginner",
        "Focused",
        "Consistent",
        "Disciplined",
        "Elite",
        "Monk Mode"
    ]
}

// MARK: - Points Reason (transaction log)

enum PointsReason: String, Codable {
    // Alarm
    case alarmDismissedClean = "alarm_dismissed_clean"
    case alarmDismissedWithMission = "alarm_dismissed_mission"
    case alarmDismissedAfterSnooze = "alarm_dismissed_after_snooze"
    case alarmSnoozed = "alarm_snoozed"
    case alarmMissed = "alarm_missed"

    // Habit
    case habitCompleted = "habit_completed"
    case habitSkipped = "habit_skipped"
    case habitStreakMilestone = "habit_streak_milestone"

    // Task
    case taskCompleted = "task_completed"
    case taskCompletedEarly = "task_completed_early"
    case taskMissed = "task_missed"

    // Focus / Pomodoro
    case focusSessionComplete = "focus_session_complete"
    case focusInterrupted = "focus_interrupted"
    case focusFourSessionBonus = "focus_4_session_bonus"

    // Stopwatch
    case stopwatchSession20 = "stopwatch_session_20"
    case stopwatchSession60 = "stopwatch_session_60"

    // Daily / Manual
    case dailyLogin = "daily_login"
    case manual = "manual"

    var displayTitle: String {
        switch self {
        case .alarmDismissedClean: return "Alarm Dismissed"
        case .alarmDismissedWithMission: return "Mission Complete"
        case .alarmDismissedAfterSnooze: return "Alarm After Snooze"
        case .alarmSnoozed: return "Snoozed"
        case .alarmMissed: return "Alarm Missed"
        case .habitCompleted: return "Habit Done"
        case .habitSkipped: return "Habit Skipped"
        case .habitStreakMilestone: return "Habit Milestone"
        case .taskCompleted: return "Task Done"
        case .taskCompletedEarly: return "Task Early"
        case .taskMissed: return "Task Missed"
        case .focusSessionComplete: return "Focus Complete"
        case .focusInterrupted: return "Focus Interrupted"
        case .focusFourSessionBonus: return "Focus Bonus"
        case .stopwatchSession20: return "Stopwatch 20m"
        case .stopwatchSession60: return "Stopwatch 60m"
        case .dailyLogin: return "Daily Check-in"
        case .manual: return "Adjustment"
        }
    }

    var icon: String {
        switch self {
        case .alarmDismissedClean, .alarmDismissedWithMission, .alarmDismissedAfterSnooze:
            return "alarm.fill"
        case .alarmSnoozed:
            return "zzz"
        case .alarmMissed:
            return "alarm.waves.left.and.right"
        case .habitCompleted:
            return "checkmark.circle.fill"
        case .habitSkipped:
            return "minus.circle.fill"
        case .habitStreakMilestone:
            return "flame.fill"
        case .taskCompleted, .taskCompletedEarly:
            return "checkmark.square.fill"
        case .taskMissed:
            return "xmark.square.fill"
        case .focusSessionComplete, .focusInterrupted, .focusFourSessionBonus:
            return "timer"
        case .stopwatchSession20, .stopwatchSession60:
            return "stopwatch.fill"
        case .dailyLogin:
            return "sun.max.fill"
        case .manual:
            return "gearshape.fill"
        }
    }
}

// MARK: - Streaks

enum DisciplineStreakType: String, CaseIterable, Codable {
    case wakeUp
    case focus
    case habit
    case task
}

struct DisciplineStreakState: Codable {
    var current: Int = 0
    var longest: Int = 0
    var lastActivityLocalDate: String?
}

struct DailyDisciplineBreakdown {
    var alarm: Int = 0
    var pomodoro: Int = 0
    var habit: Int = 0
    var task: Int = 0
    var stopwatch: Int = 0
    var penalties: Int = 0

    var total: Int {
        alarm + pomodoro + habit + task + stopwatch + penalties
    }
}

// MARK: - Points Transaction

struct PointsTransaction: Codable, Identifiable {
    let id: UUID
    let date: Date
    let reason: PointsReason
    let amount: Int
    let entityId: UUID?
    let entityName: String?
    let note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        reason: PointsReason,
        amount: Int,
        entityId: UUID? = nil,
        entityName: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.reason = reason
        self.amount = amount
        self.entityId = entityId
        self.entityName = entityName
        self.note = note
    }
}

// MARK: - Discipline Event Input

struct DisciplineEventInput {
    enum Kind {
        case alarmDismissed(snoozeCount: Int, hadMission: Bool)
        case alarmSnoozed
        case alarmMissed
        case habitCompleted(streakDays: Int)
        case habitSkipped
        case taskCompleted(beforeDeadline: Bool)
        case taskMissed
        case pomodoroCompleted(durationSeconds: Int, interrupted: Bool)
        case stopwatchCompleted(durationSeconds: Int)
    }

    var kind: Kind
    var entityId: UUID?
    var entityName: String?
}

// MARK: - Points Service

final class PointsService: ObservableObject {
    static let shared = PointsService()

    private let settings = SettingsStore.shared
    private let rankService = RankProgressService.shared
    private let rewardFeedback = RewardFeedbackService.shared
    private let transactionsKey = "points.transactions"
    private let lastLoginDateKey = "points.lastLoginDate"
    private let streaksKey = "discipline.streaks"

    @Published var recentTransactions: [PointsTransaction] = []

    var totalPoints: Int {
        get { settings.points }
        set { settings.points = newValue }
    }

    var disciplineScore: Int { totalPoints }

    private var streaks: [String: DisciplineStreakState] = [:]

    var currentLevel: Int {
        let idx = PointsConfig.levelThresholds.lastIndex(where: { totalPoints >= $0 }) ?? 0
        return idx + 1
    }

    var levelTitle: String {
        let idx = max(0, min(currentLevel - 1, PointsConfig.levelTitles.count - 1))
        return PointsConfig.levelTitles[idx]
    }

    var pointsInCurrentLevel: Int {
        guard let currentThreshold = PointsConfig.levelThresholds[safe: currentLevel - 1] else { return 0 }
        return max(0, totalPoints - currentThreshold)
    }

    var pointsToNextLevel: Int {
        guard let nextThreshold = PointsConfig.levelThresholds[safe: currentLevel] else { return 0 }
        return max(0, nextThreshold - totalPoints)
    }

    var levelProgress: Double {
        guard let currentThreshold = PointsConfig.levelThresholds[safe: currentLevel - 1],
              let nextThreshold = PointsConfig.levelThresholds[safe: currentLevel],
              nextThreshold > currentThreshold else {
            return 1
        }
        let span = nextThreshold - currentThreshold
        let progressed = totalPoints - currentThreshold
        return min(1, max(0, Double(progressed) / Double(span)))
    }

    var todayTransactions: [PointsTransaction] {
        let calendar = Calendar.current
        return recentTransactions.filter { calendar.isDateInToday($0.date) }
    }

    var todayPoints: Int {
        todayTransactions.reduce(0) { $0 + $1.amount }
    }

    var todayBreakdown: DailyDisciplineBreakdown {
        var breakdown = DailyDisciplineBreakdown()
        for tx in todayTransactions {
            switch tx.reason {
            case .alarmDismissedClean, .alarmDismissedWithMission, .alarmDismissedAfterSnooze:
                breakdown.alarm += tx.amount
            case .focusSessionComplete, .focusFourSessionBonus, .focusInterrupted:
                breakdown.pomodoro += tx.amount
            case .habitCompleted, .habitStreakMilestone, .habitSkipped:
                breakdown.habit += tx.amount
            case .taskCompleted, .taskCompletedEarly, .taskMissed:
                breakdown.task += tx.amount
            case .stopwatchSession20, .stopwatchSession60:
                breakdown.stopwatch += tx.amount
            case .alarmMissed, .alarmSnoozed:
                breakdown.penalties += tx.amount
            case .dailyLogin, .manual:
                break
            }
        }
        return breakdown
    }

    var wakeUpStreak: Int { streak(for: .wakeUp).current }
    var focusStreak: Int { streak(for: .focus).current }
    var habitStreak: Int { streak(for: .habit).current }
    var taskStreak: Int { streak(for: .task).current }

    private init() {
        loadTransactions()
        loadStreaks()
    }

    // MARK: - Core award/deduct

    @discardableResult
    func award(
        reason: PointsReason,
        amount: Int,
        entityId: UUID? = nil,
        entityName: String? = nil,
        note: String? = nil
    ) -> PointsTransaction {
        let oldLevel = currentLevel
        let tx = PointsTransaction(
            reason: reason,
            amount: amount,
            entityId: entityId,
            entityName: entityName,
            note: note
        )

        totalPoints = max(0, totalPoints + amount)
        recentTransactions.insert(tx, at: 0)

        if recentTransactions.count > 500 {
            recentTransactions = Array(recentTransactions.prefix(500))
        }

        saveTransactions()
        routeToXP(reason: reason, amount: amount, entityId: entityId, entityName: entityName, note: note, transactionId: tx.id)

        let newLevel = currentLevel
        if newLevel > oldLevel {
            scheduleAchievementNotification(
                title: "Discipline level up",
                body: "You reached level \(newLevel): \(levelTitle)."
            )
        }

        return tx
    }

    private func routeToXP(
        reason: PointsReason,
        amount: Int,
        entityId: UUID?,
        entityName: String?,
        note: String?,
        transactionId: UUID
    ) {
        guard amount > 0 else { return }

        let id = entityId?.uuidString ?? transactionId.uuidString
        var title = reason.displayTitle
        let displayName: String? = {
            guard let name = entityName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            return name
        }()
        let grant: XPGrantResult?

        switch reason {
        case .alarmDismissedClean:
            grant = rankService.addXP(
                source: XPSource(type: .alarmStop, sourceId: id, alarmId: id, metadata: ["name": entityName ?? "Alarm"]),
                amount: 12,
                category: .wake
            )
            let bonus = rankService.addXP(
                source: XPSource(type: .noSnooze, sourceId: id, alarmId: id),
                amount: 5,
                category: .noSnoozeBonus
            )
            rewardFeedback.handle(bonus, title: "No snooze")
        case .alarmDismissedWithMission:
            grant = rankService.addXP(
                source: XPSource(type: .alarmStop, sourceId: id, alarmId: id, metadata: ["name": entityName ?? "Alarm"]),
                amount: 12,
                category: .wake
            )
            let mission = rankService.addXP(
                source: XPSource(type: .alarmMission, sourceId: id, alarmId: id),
                amount: 6,
                category: .missionBonus
            )
            rewardFeedback.handle(mission, title: "Mission")
        case .alarmDismissedAfterSnooze:
            grant = rankService.addXP(
                source: XPSource(type: .alarmStop, sourceId: id, alarmId: id),
                amount: 6,
                category: .wake
            )
        case .habitCompleted:
            title = displayName ?? "Habit complete"
            grant = rankService.addXP(
                source: XPSource(type: .habitCompletion, sourceId: id, habitId: id, metadata: ["name": entityName ?? "Habit"]),
                amount: 4,
                category: .habit
            )
        case .taskCompleted:
            title = displayName ?? "Task complete"
            grant = rankService.addXP(
                source: XPSource(type: .taskCompletion, sourceId: id, habitId: id, metadata: ["name": entityName ?? "Task"]),
                amount: 4,
                category: .habit
            )
        case .taskCompletedEarly:
            title = displayName ?? "Task complete"
            grant = rankService.addXP(
                source: XPSource(type: .taskCompletion, sourceId: id, habitId: id, metadata: ["name": entityName ?? "Task", "timing": "early"]),
                amount: 5,
                category: .habit
            )
        case .focusSessionComplete:
            grant = rankService.addXP(
                source: XPSource(type: .pomodoroComplete, sourceId: transactionId.uuidString, sessionId: id, metadata: ["name": entityName ?? "Focus"]),
                amount: 7,
                category: .focus
            )
        case .focusFourSessionBonus:
            grant = rankService.addXP(
                source: XPSource(type: .streakMilestone, sourceId: "focus_4_\(rankService.localDay(for: Date()))", sessionId: id),
                amount: 12,
                category: .streakBonus
            )
        case .habitStreakMilestone:
            grant = rankService.addXP(
                source: XPSource(type: .streakMilestone, sourceId: "habit_\(id)_\(note ?? "milestone")", habitId: id),
                amount: 20,
                category: .streakBonus
            )
        case .stopwatchSession20:
            grant = rankService.addXP(
                source: XPSource(type: .stopwatchComplete, sourceId: transactionId.uuidString, sessionId: id),
                amount: 4,
                category: .focus
            )
        case .stopwatchSession60:
            grant = rankService.addXP(
                source: XPSource(type: .stopwatchComplete, sourceId: transactionId.uuidString, sessionId: id),
                amount: 10,
                category: .focus
            )
        case .dailyLogin:
            grant = rankService.addXP(
                source: XPSource(type: .dailyCheckIn, sourceId: "daily_login"),
                amount: 1,
                category: .daily
            )
        case .alarmSnoozed, .alarmMissed, .habitSkipped, .taskMissed, .focusInterrupted, .manual:
            grant = nil
        }

        if let grant {
            rewardFeedback.handle(grant, title: title)
        }
    }

    // MARK: - Event router

    func record(event: DisciplineEventInput) {
        switch event.kind {
        case .alarmDismissed(let snoozeCount, let hadMission):
            guard let id = event.entityId else { return }
            alarmDismissed(alarmId: id, alarmName: event.entityName ?? "Alarm", snoozeCount: snoozeCount, hadMission: hadMission)
        case .alarmSnoozed:
            guard let id = event.entityId else { return }
            alarmSnoozed(alarmId: id, alarmName: event.entityName ?? "Alarm")
        case .alarmMissed:
            guard let id = event.entityId else { return }
            alarmMissed(alarmId: id, alarmName: event.entityName ?? "Alarm")
        case .habitCompleted(let streakDays):
            guard let id = event.entityId else { return }
            habitCompleted(habitId: id, habitName: event.entityName ?? "Habit", streakDays: streakDays)
        case .habitSkipped:
            guard let id = event.entityId else { return }
            habitSkipped(habitId: id, habitName: event.entityName ?? "Habit")
        case .taskCompleted(let beforeDeadline):
            guard let id = event.entityId else { return }
            taskCompleted(taskId: id, taskName: event.entityName ?? "Task", completedBeforeDeadline: beforeDeadline)
        case .taskMissed:
            guard let id = event.entityId else { return }
            taskMissed(taskId: id, taskName: event.entityName ?? "Task")
        case .pomodoroCompleted(let durationSeconds, let interrupted):
            pomodoroSessionEnded(taskId: event.entityId, taskName: event.entityName, durationSeconds: durationSeconds, interrupted: interrupted)
        case .stopwatchCompleted(let durationSeconds):
            stopwatchSessionCompleted(durationSeconds: durationSeconds, sessionLabel: event.entityName)
        }
    }

    // MARK: - Alarm events

    func alarmDismissed(alarmId: UUID, alarmName: String, snoozeCount: Int, hadMission: Bool) {
        guard !hasAnyTransactionToday(
            reasons: [.alarmDismissedClean, .alarmDismissedWithMission, .alarmDismissedAfterSnooze],
            entityId: alarmId
        ) else {
            return
        }

        if snoozeCount == 0 {
            let reason: PointsReason = hadMission ? .alarmDismissedWithMission : .alarmDismissedClean
            award(
                reason: reason,
                amount: PointsConfig.alarmDismissedClean,
                entityId: alarmId,
                entityName: alarmName,
                note: hadMission ? "Dismissed after mission" : "Dismissed on first ring"
            )
            _ = updateStreak(.wakeUp)
        } else {
            award(
                reason: .alarmDismissedAfterSnooze,
                amount: PointsConfig.alarmDismissedAfterSnooze,
                entityId: alarmId,
                entityName: alarmName,
                note: "Dismissed after \(snoozeCount) snooze(s)"
            )
            resetStreak(.wakeUp)
        }
    }

    func alarmSnoozed(alarmId: UUID, alarmName: String) {
        resetStreak(.wakeUp)
    }

    func alarmMissed(alarmId: UUID, alarmName: String) {
        guard !hasTransactionToday(reason: .alarmMissed, entityId: alarmId) else { return }
        award(
            reason: .alarmMissed,
            amount: PointsConfig.alarmMissedPenalty,
            entityId: alarmId,
            entityName: alarmName,
            note: "Alarm was not dismissed"
        )
        resetStreak(.wakeUp)
    }

    // MARK: - Habit events

    func habitCompleted(habitId: UUID, habitName: String, streakDays: Int) {
        guard !hasTransactionToday(reason: .habitCompleted, entityId: habitId) else { return }

        award(
            reason: .habitCompleted,
            amount: PointsConfig.habitCompleted,
            entityId: habitId,
            entityName: habitName
        )

        let updatedStreak = max(streakDays, updateStreak(.habit).current)

        if updatedStreak == 7 || updatedStreak == 30 {
            award(
                reason: .habitStreakMilestone,
                amount: PointsConfig.habitStreakMilestone,
                entityId: habitId,
                entityName: habitName,
                note: "\(updatedStreak)-day streak milestone"
            )
            scheduleAchievementNotification(
                title: "Habit streak milestone",
                body: "\(updatedStreak)-day streak reached for \(habitName)."
            )
        }
    }

    func habitSkipped(habitId: UUID, habitName: String) {
        award(
            reason: .habitSkipped,
            amount: PointsConfig.habitSkippedPenalty,
            entityId: habitId,
            entityName: habitName,
            note: "Habit skipped"
        )
        resetStreak(.habit)
    }

    // MARK: - Task events

    func taskCompleted(taskId: UUID, taskName: String, completedBeforeDeadline: Bool = false) {
        guard !hasAnyTransactionToday(
            reasons: [.taskCompleted, .taskCompletedEarly],
            entityId: taskId
        ) else {
            return
        }

        if completedBeforeDeadline {
            award(
                reason: .taskCompletedEarly,
                amount: PointsConfig.taskCompletedEarly,
                entityId: taskId,
                entityName: taskName,
                note: "Completed before deadline"
            )
        } else {
            award(
                reason: .taskCompleted,
                amount: PointsConfig.taskCompleted,
                entityId: taskId,
                entityName: taskName
            )
        }

        _ = updateStreak(.task)
    }

    func taskMissed(taskId: UUID, taskName: String) {
        award(
            reason: .taskMissed,
            amount: PointsConfig.taskMissedPenalty,
            entityId: taskId,
            entityName: taskName,
            note: "Task missed"
        )
        resetStreak(.task)
    }

    // MARK: - Focus / Pomodoro events

    func focusSessionEnded(taskId: UUID?, taskName: String?, durationSeconds: Int, wasSkipped: Bool) {
        pomodoroSessionEnded(taskId: taskId, taskName: taskName, durationSeconds: durationSeconds, interrupted: wasSkipped)
    }

    func pomodoroSessionEnded(taskId: UUID?, taskName: String?, durationSeconds: Int, interrupted: Bool) {
        guard durationSeconds >= 60 else { return }

        if interrupted {
            award(
                reason: .focusInterrupted,
                amount: PointsConfig.focusSessionInterruptedPenalty,
                entityId: taskId,
                entityName: taskName ?? "Focus",
                note: "Focus interrupted at \(durationSeconds / 60)m"
            )
            resetStreak(.focus)
            return
        }

        award(
            reason: .focusSessionComplete,
            amount: PointsConfig.focusSessionCompleted,
            entityId: taskId,
            entityName: taskName ?? "Focus",
            note: "Completed \(durationSeconds / 60)m focus"
        )

        _ = updateStreak(.focus)

        let completedFocusSessionsToday = todayTransactions.filter { $0.reason == .focusSessionComplete }.count
        if completedFocusSessionsToday > 0, completedFocusSessionsToday % 4 == 0 {
            award(
                reason: .focusFourSessionBonus,
                amount: PointsConfig.focusFourSessionBonus,
                entityId: taskId,
                entityName: taskName ?? "Focus",
                note: "4-session completion bonus"
            )
        }
    }

    // MARK: - Stopwatch events

    func stopwatchSessionCompleted(durationSeconds: Int, sessionLabel: String? = nil) {
        guard durationSeconds >= 20 * 60 else { return }

        let reason: PointsReason
        let amount: Int
        if durationSeconds >= 60 * 60 {
            reason = .stopwatchSession60
            amount = PointsConfig.stopwatch60Min
        } else {
            reason = .stopwatchSession20
            amount = PointsConfig.stopwatch20Min
        }

        award(
            reason: reason,
            amount: amount,
            entityName: sessionLabel ?? "Stopwatch",
            note: "\(durationSeconds / 60)m session"
        )
    }

    // MARK: - Daily login

    func checkDailyLogin() {
        let today = localDateString(for: Date())
        let last = UserDefaults.standard.string(forKey: lastLoginDateKey) ?? ""
        if last != today {
            UserDefaults.standard.set(today, forKey: lastLoginDateKey)
        }
    }

    // MARK: - Streak helpers

    func streak(for type: DisciplineStreakType) -> DisciplineStreakState {
        streaks[type.rawValue] ?? DisciplineStreakState()
    }

    @discardableResult
    func updateStreak(_ type: DisciplineStreakType, on date: Date = Date()) -> DisciplineStreakState {
        let today = localDateString(for: date)
        let yesterday = localDateString(for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)

        var state = streak(for: type)
        if state.lastActivityLocalDate == today {
            return state
        }

        if state.lastActivityLocalDate == yesterday {
            state.current += 1
        } else {
            state.current = 1
        }

        state.longest = max(state.longest, state.current)
        state.lastActivityLocalDate = today
        streaks[type.rawValue] = state
        saveStreaks()
        objectWillChange.send()
        return state
    }

    func resetStreak(_ type: DisciplineStreakType) {
        var state = streak(for: type)
        guard state.current != 0 else { return }
        state.current = 0
        state.lastActivityLocalDate = nil
        streaks[type.rawValue] = state
        saveStreaks()
        objectWillChange.send()
    }

    // MARK: - Persistence

    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(recentTransactions) {
            UserDefaults.standard.set(data, forKey: transactionsKey)
        }
    }

    private func loadTransactions() {
        guard let data = UserDefaults.standard.data(forKey: transactionsKey),
              let decoded = try? JSONDecoder().decode([PointsTransaction].self, from: data) else {
            return
        }
        recentTransactions = decoded
    }

    private func saveStreaks() {
        if let data = try? JSONEncoder().encode(streaks) {
            UserDefaults.standard.set(data, forKey: streaksKey)
        }
    }

    private func loadStreaks() {
        guard let data = UserDefaults.standard.data(forKey: streaksKey),
              let decoded = try? JSONDecoder().decode([String: DisciplineStreakState].self, from: data) else {
            return
        }
        streaks = decoded
    }

    // MARK: - Internal helpers

    private func hasTransactionToday(reason: PointsReason, entityId: UUID?) -> Bool {
        let calendar = Calendar.current
        return recentTransactions.contains { tx in
            tx.reason == reason && tx.entityId == entityId && calendar.isDateInToday(tx.date)
        }
    }

    private func hasAnyTransactionToday(reasons: [PointsReason], entityId: UUID?) -> Bool {
        let reasonSet = Set(reasons)
        let calendar = Calendar.current
        return recentTransactions.contains { tx in
            reasonSet.contains(tx.reason) && tx.entityId == entityId && calendar.isDateInToday(tx.date)
        }
    }

    private func localDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func scheduleAchievementNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alarmo.discipline.achievement.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
