import Foundation

// MARK: - Difficulty

enum FocusDifficultyMode: String, Codable, CaseIterable, Equatable {
    case normal
    case deepFocus

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .deepFocus: return "Deep Focus"
        }
    }

    var description: String {
        switch self {
        case .normal: return "You can stop the session early anytime."
        case .deepFocus: return "Cannot stop the session while focused. Apps stay blocked until the session ends."
        }
    }

    var icon: String {
        switch self {
        case .normal: return "play.circle.fill"
        case .deepFocus: return "lock.fill"
        }
    }

    var color: String {
        switch self {
        case .normal: return "orange"
        case .deepFocus: return "red"
        }
    }
}

// MARK: - Break Mode
enum SessionBreakMode: String, Codable, CaseIterable, Equatable {
    case easy
    case harder
    case hardcore
    
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .harder: return "Harder"
        case .hardcore: return "Hardcore"
        }
    }
    
    var subtitle: String {
        switch self {
        case .easy: return "Take short breaks or cancel freely."
        case .harder: return "Complete a mission before each break."
        case .hardcore: return "No breaks or early stops allowed."
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "shield"
        case .harder: return "shield.lefthalf.filled"
        case .hardcore: return "shield.fill"
        }
    }
}

// MARK: - Unblock Challenge
typealias UnblockChallenge = WakeUpMissionType

extension UnblockChallenge {
    var titleForFocus: String {
        switch self {
        case .math: return "Math Problems"
        case .typing: return "Typing Challenge"
        case .findColorTiles: return "Find Color Tiles"
        case .memoryMatch: return "Memory Match"
        case .ticTacToe: return "Tic-Tac-Toe"
        case .shake: return "Shake Phone"
        case .step: return "Walk Steps"
        case .qrBarcode: return "Scan Barcode"
        case .squat: return "Do Squats"
        case .breathing: return "Deep Breathing"
        case .off: return "None"
        }
    }
    
    var subtitleForFocus: String {
        switch self {
        case .math: return "Solve math to proceed"
        case .typing: return "Type the exact text"
        case .findColorTiles: return "Memorize and find tiles"
        case .memoryMatch: return "Match all pairs to proceed"
        case .ticTacToe: return "Win a game against AI"
        case .shake: return "Shake vigorously to awaken"
        case .step: return "Walk a set number of steps"
        case .qrBarcode: return "Scan a distant QR code"
        case .squat: return "Complete exercise to proceed"
        case .breathing: return "Take 3 deep breaths to proceed"
        case .off: return "No challenge required"
        }
    }
    
    var iconForFocus: String {
        switch self {
        case .math: return "plus.forwardslash.minus"
        case .typing: return "keyboard"
        case .findColorTiles: return "square.grid.2x2.fill"
        case .memoryMatch: return "brain.head.profile"
        case .ticTacToe: return "number.square"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .step: return "figure.walk"
        case .qrBarcode: return "barcode.viewfinder"
        case .squat: return "figure.strengthtraining.traditional"
        case .breathing: return "wind"
        case .off: return "xmark.circle"
        }
    }
}

// MARK: - Configuration
struct IntervalTimerConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var focusSeconds: Int = 25 * 60
    var sessionsPerCycle: Int = 4
    var shortBreakSeconds: Int = 5 * 60
    var longBreakSeconds: Int = 20 * 60
    var autoStartNextSession: Bool = false
    var autoStartBreak: Bool = false
    var autoStartNextCycle: Bool = false

    // App Blocking
    var blockAppsEnabled: Bool = false
    var blockDuringBreaks: Bool = false
    var difficultyMode: FocusDifficultyMode = .normal
    var selectedBlockListId: String = ""
    
    // Session Intervention
    var breakMode: SessionBreakMode = .easy
    var enabledChallenges: [UnblockChallenge] = [.math]

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
