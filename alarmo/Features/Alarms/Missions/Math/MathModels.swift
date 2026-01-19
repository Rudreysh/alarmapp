import Foundation

enum MathDifficulty: Int, CaseIterable, Codable {
    case veryEasy = 0
    case easy
    case normal
    case hard
    case veryHard
    case superHard
    case expert
    case hellMode
    
    var displayName: String {
        switch self {
        case .veryEasy: return "Very easy"
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .veryHard: return "Very hard"
        case .superHard: return "Super Hard"
        case .expert: return "Expert"
        case .hellMode: return "Hell mode"
        }
    }
}

struct MathProblem: Identifiable, Equatable {
    let id: UUID = UUID()
    let displayExpression: String
    let correctAnswer: Int
}

struct MathMissionConfig: Codable {
    var difficulty: MathDifficulty = .normal
    var repeatCount: Int = 3
    var isSoundEnabled: Bool = true
}
