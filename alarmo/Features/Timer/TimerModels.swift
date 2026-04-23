import Foundation

enum TimerMode: String, CaseIterable, Identifiable, Codable {
    case pomo = "Pomodoro"
    case stopwatch = "Stopwatch"
    case countdown = "Countdown"
    
    var id: String { self.rawValue }
}

enum TimerState {
    case idle
    case running
    case paused
}

struct TimerPreset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var mode: TimerMode
    var duration: TimeInterval // Used for Pomo
    
    // Default presets
    static let defaults: [TimerPreset] = [
        TimerPreset(name: "Focus", icon: "brain.head.profile", mode: .pomo, duration: 25 * 60),
        TimerPreset(name: "Short Break", icon: "cup.and.saucer", mode: .pomo, duration: 5 * 60),
        TimerPreset(name: "Reading", icon: "book", mode: .pomo, duration: 45 * 60)
    ]
}
