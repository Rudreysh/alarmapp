import Foundation
import SwiftUI
import Combine

// MARK: - Points Configuration

/// Defines the point values for each action in the app.
/// Inspired by Alarmy's engagement model: reward discipline, penalize snoozing.
enum PointsConfig {
    // Alarm
    static let alarmDismissedClean     = 10   // Dismissed without snoozing
    static let alarmDismissedWithMission = 15 // Dismissed after completing a mission
    static let alarmSnoozePenalty      = -2   // Per snooze tap
    static let alarmMissedPenalty      = -5   // Alarm fired but never dismissed (missed)
    
    // Habits
    static let habitCompleted          = 5    // Marked a habit complete for the day
    static let habitStreakBonus         = 3    // Per consecutive day in current streak
    static let habitStreakMilestone7    = 20   // Bonus at 7-day streak
    static let habitStreakMilestone30   = 100  // Bonus at 30-day streak
    
    // Tasks
    static let taskCompleted           = 3    // Completed a task
    
    // Focus / Pomodoro
    static let focusPerFiveMinutes     = 1    // Per 5 minutes of completed focus
    static let focusSessionComplete    = 2    // Bonus for completing full session without skip
    
    // Daily
    static let dailyLogin              = 1    // First app open of the day
    
    // Levels: points needed per level (cumulative)
    static let pointsPerLevel          = 100
}

// MARK: - Points Reason (for transaction log)

enum PointsReason: String, Codable {
    // Alarm
    case alarmDismissedClean       = "alarm_dismissed_clean"
    case alarmDismissedWithMission = "alarm_dismissed_mission"
    case alarmSnoozed              = "alarm_snoozed"
    case alarmMissed               = "alarm_missed"
    
    // Habit
    case habitCompleted            = "habit_completed"
    case habitStreakBonus           = "habit_streak_bonus"
    case habitStreakMilestone       = "habit_streak_milestone"
    
    // Task
    case taskCompleted             = "task_completed"
    
    // Focus
    case focusSession              = "focus_session"
    case focusSessionComplete      = "focus_session_complete"
    
    // Daily
    case dailyLogin                = "daily_login"
    
    // Manual / Admin
    case manual                    = "manual"
    
    var displayTitle: String {
        switch self {
        case .alarmDismissedClean: return "Alarm Dismissed"
        case .alarmDismissedWithMission: return "Mission Complete"
        case .alarmSnoozed: return "Snoozed"
        case .alarmMissed: return "Alarm Missed"
        case .habitCompleted: return "Habit Done"
        case .habitStreakBonus: return "Streak Bonus"
        case .habitStreakMilestone: return "Streak Milestone"
        case .taskCompleted: return "Task Done"
        case .focusSession: return "Focus Time"
        case .focusSessionComplete: return "Focus Complete"
        case .dailyLogin: return "Daily Check-in"
        case .manual: return "Adjustment"
        }
    }
    
    var icon: String {
        switch self {
        case .alarmDismissedClean, .alarmDismissedWithMission: return "alarm.fill"
        case .alarmSnoozed: return "zzz"
        case .alarmMissed: return "alarm.waves.left.and.right"
        case .habitCompleted: return "checkmark.circle.fill"
        case .habitStreakBonus, .habitStreakMilestone: return "flame.fill"
        case .taskCompleted: return "checkmark.square.fill"
        case .focusSession, .focusSessionComplete: return "timer"
        case .dailyLogin: return "sun.max.fill"
        case .manual: return "gearshape.fill"
        }
    }
}

// MARK: - Points Transaction

struct PointsTransaction: Codable, Identifiable {
    let id: UUID
    let date: Date
    let reason: PointsReason
    let amount: Int
    let entityId: UUID?      // Optional: alarm/habit/task ID
    let entityName: String?  // Display name
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

// MARK: - Points Service

final class PointsService: ObservableObject {
    static let shared = PointsService()
    
    private let settings = SettingsStore.shared
    private let transactionsKey = "points.transactions"
    private let lastLoginDateKey = "points.lastLoginDate"
    
    @Published var recentTransactions: [PointsTransaction] = []
    
    var totalPoints: Int {
        get { settings.points }
        set { settings.points = newValue }
    }
    
    var currentLevel: Int {
        max(1, (totalPoints / PointsConfig.pointsPerLevel) + 1)
    }
    
    var pointsInCurrentLevel: Int {
        totalPoints % PointsConfig.pointsPerLevel
    }
    
    var pointsToNextLevel: Int {
        PointsConfig.pointsPerLevel - pointsInCurrentLevel
    }
    
    var levelProgress: Double {
        Double(pointsInCurrentLevel) / Double(PointsConfig.pointsPerLevel)
    }
    
    var levelTitle: String {
        switch currentLevel {
        case 1: return "Beginner"
        case 2: return "Early Bird"
        case 3: return "Rising Star"
        case 4: return "Disciplined"
        case 5: return "Focused"
        case 6: return "Committed"
        case 7: return "Champion"
        case 8: return "Master"
        case 9: return "Elite"
        case 10...: return "Legend"
        default: return "Beginner"
        }
    }
    
    private init() {
        loadTransactions()
    }
    
    // MARK: - Core Award/Deduct
    
    @discardableResult
    func award(
        reason: PointsReason,
        amount: Int,
        entityId: UUID? = nil,
        entityName: String? = nil,
        note: String? = nil
    ) -> PointsTransaction {
        let tx = PointsTransaction(
            reason: reason,
            amount: amount,
            entityId: entityId,
            entityName: entityName,
            note: note
        )
        
        totalPoints = max(0, totalPoints + amount)
        recentTransactions.insert(tx, at: 0)
        
        // Keep only last 200 transactions in memory
        if recentTransactions.count > 200 {
            recentTransactions = Array(recentTransactions.prefix(200))
        }
        
        saveTransactions()
        
        print("[PointsService] \(amount >= 0 ? "+" : "")\(amount) pts (\(reason.rawValue)) → Total: \(totalPoints)")
        return tx
    }
    
    // MARK: - Alarm Events
    
    /// Called when an alarm is successfully dismissed.
    /// `snoozeCount`: how many times the user snoozed before dismissing.
    /// `hadMission`: whether the alarm required a mission to dismiss.
    func alarmDismissed(alarmId: UUID, alarmName: String, snoozeCount: Int, hadMission: Bool) {
        // Guard: only award once per alarm ring session
        guard !hasTransactionToday(reason: .alarmDismissedClean, entityId: alarmId) &&
              !hasTransactionToday(reason: .alarmDismissedWithMission, entityId: alarmId) else {
            print("[PointsService] Already awarded points for alarm \(alarmName) today")
            return
        }
        
        // Award dismissal points
        if hadMission {
            award(
                reason: .alarmDismissedWithMission,
                amount: PointsConfig.alarmDismissedWithMission,
                entityId: alarmId,
                entityName: alarmName,
                note: "Mission completed"
            )
        } else if snoozeCount == 0 {
            award(
                reason: .alarmDismissedClean,
                amount: PointsConfig.alarmDismissedClean,
                entityId: alarmId,
                entityName: alarmName,
                note: "No snooze — great discipline!"
            )
        } else {
            // Snoozed but eventually dismissed  → reduced points
            let basePoints = max(1, PointsConfig.alarmDismissedClean + (snoozeCount * PointsConfig.alarmSnoozePenalty))
            award(
                reason: .alarmDismissedClean,
                amount: basePoints,
                entityId: alarmId,
                entityName: alarmName,
                note: "Dismissed after \(snoozeCount) snooze(s)"
            )
        }
    }
    
    /// Called each time the user presses snooze.
    func alarmSnoozed(alarmId: UUID, alarmName: String) {
        award(
            reason: .alarmSnoozed,
            amount: PointsConfig.alarmSnoozePenalty,
            entityId: alarmId,
            entityName: alarmName,
            note: "Snoozed alarm"
        )
    }
    
    // MARK: - Habit Events
    
    /// Called when a habit is marked complete for the day.
    /// `streakDays`: current consecutive day streak for this habit.
    func habitCompleted(habitId: UUID, habitName: String, streakDays: Int) {
        // Guard: only award once per habit per day
        guard !hasTransactionToday(reason: .habitCompleted, entityId: habitId) else {
            print("[PointsService] Already awarded habit points for \(habitName) today")
            return
        }
        
        award(
            reason: .habitCompleted,
            amount: PointsConfig.habitCompleted,
            entityId: habitId,
            entityName: habitName
        )
        
        // Streak bonus (only if streak > 1)
        if streakDays > 1 {
            let streakBonus = min(streakDays, 30) * PointsConfig.habitStreakBonus / 10  // Scale: 1pt per 3 days roughly
            if streakBonus > 0 {
                award(
                    reason: .habitStreakBonus,
                    amount: streakBonus,
                    entityId: habitId,
                    entityName: habitName,
                    note: "\(streakDays)-day streak"
                )
            }
        }
        
        // Milestone bonuses
        if streakDays == 7 {
            award(
                reason: .habitStreakMilestone,
                amount: PointsConfig.habitStreakMilestone7,
                entityId: habitId,
                entityName: habitName,
                note: "🔥 7-day streak milestone!"
            )
        } else if streakDays == 30 {
            award(
                reason: .habitStreakMilestone,
                amount: PointsConfig.habitStreakMilestone30,
                entityId: habitId,
                entityName: habitName,
                note: "🏆 30-day streak milestone!"
            )
        }
    }
    
    // MARK: - Task Events
    
    func taskCompleted(taskId: UUID, taskName: String) {
        guard !hasTransactionToday(reason: .taskCompleted, entityId: taskId) else {
            print("[PointsService] Already awarded task points for \(taskName) today")
            return
        }
        
        award(
            reason: .taskCompleted,
            amount: PointsConfig.taskCompleted,
            entityId: taskId,
            entityName: taskName
        )
    }
    
    // MARK: - Focus Events
    
    /// Called when a focus/pomodoro session completes.
    /// `durationSeconds`: actual focus duration.
    /// `wasSkipped`: whether the user skipped the session.
    func focusSessionEnded(taskId: UUID?, taskName: String?, durationSeconds: Int, wasSkipped: Bool) {
        guard durationSeconds >= 60 else { return } // Minimum 1 minute
        
        let fiveMinBlocks = durationSeconds / 300
        let focusPoints = max(1, fiveMinBlocks * PointsConfig.focusPerFiveMinutes)
        
        award(
            reason: .focusSession,
            amount: focusPoints,
            entityId: taskId,
            entityName: taskName ?? "Focus",
            note: "\(durationSeconds / 60) min focused"
        )
        
        // Bonus for completing without skipping
        if !wasSkipped && durationSeconds >= 300 { // At least 5 min
            award(
                reason: .focusSessionComplete,
                amount: PointsConfig.focusSessionComplete,
                entityId: taskId,
                entityName: taskName ?? "Focus",
                note: "Full session completed"
            )
        }
    }
    
    // MARK: - Daily Login
    
    func checkDailyLogin() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastLoginStr = UserDefaults.standard.string(forKey: lastLoginDateKey) ?? ""
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: today)
        
        if lastLoginStr != todayStr {
            UserDefaults.standard.set(todayStr, forKey: lastLoginDateKey)
            award(
                reason: .dailyLogin,
                amount: PointsConfig.dailyLogin,
                note: "Daily check-in"
            )
        }
    }
    
    // MARK: - Helpers
    
    private func hasTransactionToday(reason: PointsReason, entityId: UUID?) -> Bool {
        let calendar = Calendar.current
        return recentTransactions.contains { tx in
            tx.reason == reason &&
            tx.entityId == entityId &&
            calendar.isDateInToday(tx.date)
        }
    }
    
    /// Get today's transactions.
    var todayTransactions: [PointsTransaction] {
        let calendar = Calendar.current
        return recentTransactions.filter { calendar.isDateInToday($0.date) }
    }
    
    /// Get today's earned points.
    var todayPoints: Int {
        todayTransactions.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Persistence
    
    private func saveTransactions() {
        if let data = try? JSONEncoder().encode(Array(recentTransactions.prefix(500))) {
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
}
