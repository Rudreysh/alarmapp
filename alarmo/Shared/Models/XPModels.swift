import Foundation

enum XPSourceType: String, Codable, Hashable {
    case alarmStop = "alarm_stop"
    case alarmMission = "alarm_mission"
    case noSnooze = "no_snooze"
    case pomodoroComplete = "pomodoro_complete"
    case pomodoroInterrupted = "pomodoro_interrupted"
    case habitCompletion = "habit_completion"
    case taskCompletion = "task_completion"
    case dailyCheckIn = "daily_check_in"
    case stopwatchComplete = "stopwatch_complete"
    case streakMilestone = "streak_milestone"
    case manual
}

enum XPCategory: String, Codable, Hashable {
    case wake
    case habit
    case focus
    case missionBonus
    case noSnoozeBonus
    case streakBonus
    case daily
}

struct XPSource: Hashable {
    let type: XPSourceType
    let sourceId: String
    let alarmId: String?
    let sessionId: String?
    let habitId: String?
    let metadata: [String: String]

    init(type: XPSourceType, sourceId: String, alarmId: String? = nil, sessionId: String? = nil, habitId: String? = nil, metadata: [String: String] = [:]) {
        self.type = type
        self.sourceId = sourceId
        self.alarmId = alarmId
        self.sessionId = sessionId
        self.habitId = habitId
        self.metadata = metadata
    }
}

struct XPTransaction: Identifiable, Codable, Hashable {
    let id: String
    let sourceType: XPSourceType
    let sourceId: String
    let category: XPCategory
    let amount: Int
    let awardedAt: Date
    let localDay: String
    let alarmId: String?
    let sessionId: String?
    let habitId: String?
    let metadata: [String: String]
}

struct DailyXPBreakdown: Codable, Hashable {
    let localDay: String
    var baseWakeXP: Int = 0
    var baseHabitXP: Int = 0
    var baseFocusXP: Int = 0
    var bonusMissionXP: Int = 0
    var bonusNoSnoozeXP: Int = 0
    var bonusStreakXP: Int = 0
    var uncappedTotalXP: Int = 0
    var cappedTotalXP: Int = 0
    var capHit: Bool = false
}

struct XPGrantResult {
    let transaction: XPTransaction?
    let requestedAmount: Int
    let awardedAmount: Int
    let totalXPBefore: Int
    let totalXPAfter: Int
    let oldRank: RankLevel
    let newRank: RankLevel
    let skippedReason: String?

    var didGrant: Bool { transaction != nil && awardedAmount > 0 }
    var didRankUp: Bool { newRank.id > oldRank.id }
}
