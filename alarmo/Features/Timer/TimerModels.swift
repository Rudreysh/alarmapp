import Foundation

enum TimerMode: String, CaseIterable, Identifiable {
    case pomo = "Pomo"
    case stopwatch = "Stopwatch"
    
    var id: String { self.rawValue }
}

enum TimerState {
    case idle
    case running
    case paused
}
