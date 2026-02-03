import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool
    
    // Extended properties for detailed task creation
    var note: String
    var tags: [String]
    var focusDurationMinutes: Int
    var isIntervalTimer: Bool
    var isAnytime: Bool
    
    // Interval Specifics (Optional/Advanced)
    var sessionsPerCycle: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var autoStartNextSession: Bool
    var autoStartNextCycle: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        isArchived: Bool = false,
        note: String = "",
        tags: [String] = [],
        focusDurationMinutes: Int = 25,
        isIntervalTimer: Bool = false,
        isAnytime: Bool = true,
        sessionsPerCycle: Int = 4,
        shortBreakMinutes: Int = 5,
        longBreakMinutes: Int = 25,
        autoStartNextSession: Bool = true,
        autoStartNextCycle: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.note = note
        self.tags = tags
        self.focusDurationMinutes = focusDurationMinutes
        self.isIntervalTimer = isIntervalTimer
        self.isAnytime = isAnytime
        self.sessionsPerCycle = sessionsPerCycle
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.autoStartNextSession = autoStartNextSession
        self.autoStartNextCycle = autoStartNextCycle
    }
}
