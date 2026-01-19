import Foundation
import SwiftUI

enum TTTMark: String, Codable {
    case empty = ""
    case x = "X"
    case o = "O"
}

enum TTTPlayer {
    case humanX
    case aiO
}

enum TTTDifficulty: Int, Codable, CaseIterable, Identifiable {
    case easy = 0
    case medium = 1
    case hard = 2
    
    var id: Int { self.rawValue }
    
    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

enum TTTBoardSize: Int, Codable, CaseIterable, Identifiable {
    case threeByThree = 3
    case fourByFour = 4
    case fiveByFive = 5
    
    var id: Int { self.rawValue }
    
    var label: String {
        return "\(self.rawValue)x\(self.rawValue)"
    }
    
    var winLength: Int {
        switch self {
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .fiveByFive: return 4 // As per requirements
        }
    }
}

enum TTTGameResult: Equatable {
    case playing
    case draw
    case win(TTTMark, [Int]) // winner mark and winning indices
}

struct TTTStats: Codable {
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
}

struct TicTacToeHighScore: Codable {
    var wins: Int
    var losses: Int
    var draws: Int
    var bestStreak: Int
}
