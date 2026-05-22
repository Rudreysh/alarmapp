import Foundation
import SwiftUI

// MARK: - Models

enum TileState: Equatable {
    case idle
    case found
    case wrongMarked
}

struct Tile: Identifiable, Equatable {
    let id: Int
    let isTarget: Bool
    var state: TileState = .idle
}

enum MissionDifficulty: Int, Codable, CaseIterable {
    case veryEasy = 0
    case normal = 1
    case hard = 2
    case veryHard = 3
    
    var label: String {
        switch self {
        case .veryEasy: return "Very easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        case .veryHard: return "Very hard"
        }
    }
    
    var gridSize: Int {
        switch self {
        case .veryEasy: return 3
        case .normal: return 5
        case .hard: return 6
        case .veryHard: return 7
        }
    }
    
    var targetRange: ClosedRange<Int> {
        switch self {
        case .veryEasy: return 2...3
        case .normal: return 6...9
        case .hard: return 8...12
        case .veryHard: return 10...16
        }
    }
}

struct FindColorTilesSettings: Codable {
    var difficulty: MissionDifficulty = .normal
    var rounds: Int = 3
    var soundEnabled: Bool = true
}

// MARK: - Persistence Helper

class MissionSettingsStore {
    static let shared = MissionSettingsStore()
    private let userDefaults = UserDefaults.standard
    
    func save<T: Codable>(_ settings: T, for key: String) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: "mission_settings_\(key)")
        }
    }
    
    func load<T: Codable>(for key: String, default: T) -> T {
        guard let data = userDefaults.data(forKey: "mission_settings_\(key)"),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return `default`
        }
        return decoded
    }
}
