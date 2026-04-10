import Foundation
import SwiftData
import SwiftUI

// Enum for the type of plan item
enum PlanItemType: String, Codable, Sendable {
    case task
    case habit
    case focusSession
    case note
}

// Simplified Repeated Rule
enum RepeatFrequency: String, Codable, Sendable {
    case none
    case daily
    case weekly
    case monthly
    case custom
}

struct RepeatRule: Codable, Sendable {
    var frequency: RepeatFrequency = .none
    var interval: Int = 1
    var weekdays: Set<Int>? // 1=Sun, 7=Sat. Changed from [Int] for set operations ease or convert.
    var dayOfMonth: Int?
    var endDate: Date?
    
    // Helper to check occurrence
    func occurs(on date: Date, createdAt: Date) -> Bool {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: createdAt)
        let targetDay = calendar.startOfDay(for: date)
        
        if targetDay < startDay {
            return false
        }
        
        if let endDate, targetDay > calendar.startOfDay(for: endDate) {
            return false
        }
        
        let safeInterval = max(1, interval)
        
        switch frequency {
        case .none:
            return calendar.isDate(targetDay, inSameDayAs: startDay)
        case .daily:
            let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
            return daysSinceStart % safeInterval == 0
        case .weekly:
            let weekday = calendar.component(.weekday, from: targetDay)
            guard weekdays?.contains(weekday) == true else { return false }
            let startWeek = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start ?? startDay
            let targetWeek = calendar.dateInterval(of: .weekOfYear, for: targetDay)?.start ?? targetDay
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: startWeek, to: targetWeek).weekOfYear ?? 0
            return weeksSinceStart % safeInterval == 0
        case .monthly:
            let startComponents = calendar.dateComponents([.day], from: startDay)
            let targetComponents = calendar.dateComponents([.day], from: targetDay)
            let expectedDay = dayOfMonth ?? startComponents.day ?? 1
            let maxDay = calendar.range(of: .day, in: .month, for: targetDay)?.count ?? expectedDay
            guard targetComponents.day == min(expectedDay, maxDay) else { return false }
            let monthsSinceStart = calendar.dateComponents([.month], from: startDay, to: targetDay).month ?? 0
            return monthsSinceStart % safeInterval == 0
        case .custom:
            let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
            return daysSinceStart % safeInterval == 0
        }
    }
}

// Interval Timer Settings for Focus Sessions
struct IntervalTimerSettings: Codable, Sendable {
    var focusMinutes: Int = 25
    var sessionsPerCycle: Int = 4
    var shortBreakMinutes: Int = 5
    var longBreakMinutes: Int = 25
    var autoStartNextSession: Bool = true
    var autoStartNextCycle: Bool = false
}

// Mission configuration (reusing concept from AlarmMission but simplified for SwiftData embedding if needed, or just link)
// For simplicity, we'll embed the requirements directly or use a struct.
struct MissionRequirement: Codable, Sendable {
    var type: String = "none" // qr, steps, math
    var targetValue: String? // e.g. "12345" for QR or "500" for steps
    var difficulty: Int = 0
    
    var isEnabled: Bool { type != "none" }
}

// HABIT SETTINGS ENUMS
enum HabitIntent: String, Codable, CaseIterable, Sendable {
    case build
    case quit
}

enum GoalPeriod: String, Codable, CaseIterable, Sendable {
    case dayLong
    case weekLong
    case monthLong
    
    var title: String {
        switch self {
        case .dayLong: return "Daily"
        case .weekLong: return "Weekly"
        case .monthLong: return "Monthly"
        }
    }
}

enum MetricKind: String, Codable, CaseIterable, Sendable {
    case time
    case count
    case quantity
}

enum Ringtone: String, Codable, CaseIterable, Sendable {
    case systemDefault
    case classic
    case chirp
    case subtle
    
    var fileName: String? {
        switch self {
        case .systemDefault: return nil
        case .classic: return "classic.caf" // Placeholder, will rely on system default if not found
        case .chirp: return "chirp.caf"
        case .subtle: return "subtle.caf"
        }
    }
}

@Model
final class PlanItem {
    var id: UUID
    var title: String
    var subtitle: String?
    var iconName: String
    var tintKey: String // "red", "blue", etc.
    var type: PlanItemType
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var archivedAt: Date?
    var isPinned: Bool
    
    // Scheduling
    var anytime: Bool
    var scheduledDate: Date? // Date only (time components ignored)
    var scheduledTime: Date? // Time components only
    var repeatRule: RepeatRule
    
    // Reminders
    var reminderEnabled: Bool
    var reminderTimes: [Date] // Stored as Dates representing time of day
    
    // Focus / Timer
    var defaultDurationSeconds: Int?
    var intervalTimerEnabled: Bool
    var intervalSettings: IntervalTimerSettings?
    
    // Mission
    var mission: MissionRequirement
    
    // Relation to logs
    @Relationship(deleteRule: .cascade) var completionLogs: [CompletionLog] = []
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        iconName: String = "circle",
        tintKey: String = "blue",
        type: PlanItemType = .task,
        createdAt: Date = Date(),
        anytime: Bool = true,
        repeatRule: RepeatRule = RepeatRule(),
        mission: MissionRequirement = MissionRequirement()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.tintKey = tintKey
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isArchived = false
        self.archivedAt = nil
        self.isPinned = false
        self.anytime = anytime
        self.repeatRule = repeatRule
        self.reminderEnabled = false
        self.reminderTimes = []
        self.intervalTimerEnabled = false
        self.mission = mission
    }
    
    // New fields for Notes/Advanced Tasks
    var category: String = "Inbox"
    var priority: String = "none" // none, low, medium, high
    var reminderOffset: TimeInterval? = nil // nil = on time (if reminderEnabled), >0 = seconds before
    var constantReminder: Bool = false
    // Relationship for Subtasks
    var tags: [String] = []
    var subtasks: [PlanItem] = []
    var parentTask: PlanItem?
    
    // NEW FIELDS (Habit V2)
    var habitIntent: HabitIntent? = HabitIntent.build
    var goalPeriod: GoalPeriod? = GoalPeriod.dayLong
    var goalValue: Double = 1.0
    var goalUnit: String = "times"
    var metricKind: MetricKind? = MetricKind.count
    var ringtone: Ringtone? = Ringtone.systemDefault
    var autoHealthTracking: String? = nil // "steps", "distance"

    
    // LOGIC
    func isSuccessful(on date: Date) -> Bool {
        let calendar = Calendar.current
        // Find logs for this day
        let logs = completionLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        // If no logs, fail (unless Quit habit with 0 allowed? No, usually implies need to track active days)
        // Actually for Quit, "Don't exceed 2". If no logs, deemed 0? So Success?
        // But usually habits require "Check in".
        // Let's assume explicit logs required for now.
        guard !logs.isEmpty else { return false }
        
        // Calculate total progress
        let totalValue = currentValue(on: date)
        
        switch habitIntent ?? .build {
        case .build:
            return totalValue >= goalValue
        case .quit:
            return totalValue <= goalValue
        }
    }
    
    func currentValue(on date: Date) -> Double {
        let calendar = Calendar.current
        let logs = completionLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        if metricKind == .time {
            let totalSeconds = logs.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
            return Double(totalSeconds) / 60.0 // minutes
        } else {
            return logs.reduce(0) { $0 + ($1.value ?? ($1.completed ? goalValue : 0)) }
        }
    }
    
    func isGoalMet(on date: Date = Date()) -> Bool {
        let val = currentValue(on: date)
        switch habitIntent ?? .build {
        case .build: return val >= goalValue
        case .quit: return val <= goalValue
        }
    }

    func progressFraction(on date: Date = Date()) -> Double {
        let current = currentValue(on: date)
        let target = goalValue

        switch habitIntent ?? .build {
        case .build:
            guard target > 0 else { return current > 0 ? 1 : 0 }
            return min(max(current / target, 0), 1)
        case .quit:
            guard target > 0 else { return current <= 0 ? 1 : 0 }
            guard current > 0 else { return 1 }
            return min(max(target / current, 0), 1)
        }
    }
}

// MARK: - Enums
enum PriorityLevel: String, CaseIterable, Codable {
    case high, medium, low, none
    
    var title: String {
        switch self {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        case .none: return "No Priority"
        }
    }
    
    var icon: String {
        return self == .none ? "flag" : "flag.fill"
    }
    
    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        case .none: return "gray"
        }
    }
    
    var uiColor: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return Colors.textSecondary
        }
    }
}

@Model
final class CompletionLog {
    var id: UUID
    var date: Date
    var completed: Bool
    var sessionType: String? // "focus", "shortBreak", "longBreak"
    var durationSeconds: Int?
    var value: Double? // Tracked value (count, quantity)
    var note: String? // Day-specific note
    
    // Relation
    var planItem: PlanItem?
    
    init(id: UUID = UUID(), date: Date = Date(), completed: Bool = true) {
        self.id = id
        self.date = date
        self.completed = completed
    }
}

// MARK: - Unified Event Logging for Reports

enum ActivityDomain: String, Codable, CaseIterable {
    case habit
    case task
    case alarm
    case pomodoro
    case stopwatch
}

enum ActivityStatus: String, Codable {
    case created
    case started
    case completed
    case interrupted
    case success
    case fail
    case skipped
    case fired
    case snoozed
    case dismissed
    case missed
}

@Model
final class ActivityEvent {
    var id: UUID
    var domain: ActivityDomain
    var entityId: UUID
    var timestampUTC: Date
    var localDate: String // yyyy-MM-dd
    var timeZoneIdAtEvent: String
    var status: ActivityStatus
    var value: Double?
    var metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        domain: ActivityDomain,
        entityId: UUID,
        timestampUTC: Date = Date(),
        status: ActivityStatus,
        value: Double? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.domain = domain
        self.entityId = entityId
        self.timestampUTC = timestampUTC
        self.status = status
        self.value = value
        self.metadata = metadata
        
        let tz = TimeZone.current
        self.timeZoneIdAtEvent = tz.identifier
        
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = tz
        self.localDate = f.string(from: timestampUTC)
    }
}
