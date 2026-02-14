import Foundation

// MARK: - Configuration
struct IntervalTimerConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var focusSeconds: Int = 25 * 60
    var sessionsPerCycle: Int = 4
    var shortBreakSeconds: Int = 5 * 60
    var longBreakSeconds: Int = 20 * 60
    var autoStartNextSession: Bool = false // Used for Focus (legacy name)
    var autoStartBreak: Bool = false       // Used for Break
    var autoStartNextCycle: Bool = false
    
    // Limits
    static let minFocusTime = 60
    static let maxFocusTime = 120 * 60
    static let minSessions = 2
    static let maxSessions = 10
}

// MARK: - Enums
enum SegmentKind: String, Codable, Equatable {
    case focus
    case shortBreak
    case longBreak
    
    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

enum PomodoroPhase: Codable, Equatable {
    case idle
    case running(segment: SegmentKind)
    case paused(segment: SegmentKind)
    case finishedSegment(segment: SegmentKind)
    case finishedCycle
}

// MARK: - Runtime State
struct PomodoroRuntimeState: Codable, Equatable {
    var phase: PomodoroPhase = .idle
    var currentSegment: SegmentKind? = nil
    var remainingSeconds: Int = 25 * 60
    var completedFocusInCycle: Int = 0
    var cycleIndex: Int = 0
    var selectedTaskId: UUID? = nil
    var overriddenTaskName: String? = nil
    var dateLastUpdated: Date? = nil
    var segmentEndDate: Date? = nil // Key for accuracy
}

// MARK: - Analytics
struct PomodoroEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var taskId: UUID?
    var segment: SegmentKind
    var plannedSeconds: Int
    var actualSeconds: Int
    var startedAt: Date
    var endedAt: Date
    var wasSkipped: Bool
    var cycleIndex: Int
    var focusIndexInCycle: Int
}
