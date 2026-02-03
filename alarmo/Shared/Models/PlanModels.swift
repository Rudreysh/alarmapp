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
        if frequency == .none {
            return calendar.isDate(date, inSameDayAs: createdAt)
        }
        
        // Basic implementation for daily/weekly
        if frequency == .daily {
            return true // Simplified: occurs every day from creation. Real logic checks start date.
        }
        if frequency == .weekly {
            let weekday = calendar.component(.weekday, from: date)
            return weekdays?.contains(weekday) ?? false
        }
        // ... implement other logic as needed
        return false
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
    // Future: weekLong, monthLong
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
        self.isPinned = false
        self.anytime = anytime
        self.repeatRule = repeatRule
        self.reminderEnabled = false
        self.reminderTimes = []
        self.intervalTimerEnabled = false
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


