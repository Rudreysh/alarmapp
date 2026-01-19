import Foundation
import SwiftUI

enum MemoryDifficulty: String, CaseIterable, Identifiable, Codable {
    case threeByThree = "3x3"
    case fourByFour = "4x4"
    case fiveByFive = "5x5"
    case sixBySix = "6x6"
    
    var id: String { self.rawValue }
    
    var rows: Int {
        switch self {
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .fiveByFive: return 5
        case .sixBySix: return 6
        }
    }
    
    var cols: Int {
        switch self {
        case .threeByThree: return 3
        case .fourByFour: return 4
        case .fiveByFive: return 5
        case .sixBySix: return 6
        }
    }
    
    var totalCells: Int { rows * cols }
    
    var pairCount: Int {
        switch self {
        case .threeByThree: return 4 // 8 cards + 1 bonus
        case .fourByFour: return 8
        case .fiveByFive: return 12 // 24 cards + 1 bonus
        case .sixBySix: return 18
        }
    }
    
    var hasBonus: Bool {
        totalCells % 2 != 0
    }
}

struct MemoryCard: Identifiable, Equatable {
    let id: UUID = UUID()
    let pairID: Int? // nil if bonus
    let imageName: String?
    let systemIcon: String?
    var isFaceUp: Bool = false
    var isMatched: Bool = false
    
    var isBonus: Bool { pairID == nil }
}

struct MemoryMatchHighScore: Codable {
    var score: Int
    var time: Int
    var moves: Int
}
