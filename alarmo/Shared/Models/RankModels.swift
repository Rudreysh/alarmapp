import Foundation
import SwiftUI

enum RankTier: String, Codable, CaseIterable {
    case bronze
    case silver
    case gold
    case platinum
    case diamond
    case champion
    case titan
    case olympian

    var accentColor: Color {
        switch self {
        case .bronze: return Color(red: 0.83, green: 0.48, blue: 0.20)
        case .silver: return Color(red: 0.72, green: 0.78, blue: 0.84)
        case .gold: return Color(red: 1.00, green: 0.76, blue: 0.18)
        case .platinum: return Color(red: 0.44, green: 0.86, blue: 0.86)
        case .diamond: return Color(red: 0.44, green: 0.66, blue: 1.00)
        case .champion: return Color(red: 0.72, green: 0.44, blue: 1.00)
        case .titan: return Color(red: 1.00, green: 0.30, blue: 0.27)
        case .olympian: return Color(red: 1.00, green: 0.86, blue: 0.42)
        }
    }
}

struct RankLevel: Identifiable, Codable, Hashable {
    let id: Int
    let tier: RankTier
    let stage: Int
    let displayName: String
    let minXP: Int
    let assetName: String
}

enum RankCatalog {
    static let masteryXP = 15840

    static let all: [RankLevel] = [
        .init(id: 1, tier: .bronze, stage: 1, displayName: "Bronze I", minXP: 0, assetName: "bronze_1"),
        .init(id: 2, tier: .bronze, stage: 2, displayName: "Bronze II", minXP: 130, assetName: "bronze_2"),
        .init(id: 3, tier: .bronze, stage: 3, displayName: "Bronze III", minXP: 290, assetName: "bronze_3"),
        .init(id: 4, tier: .silver, stage: 1, displayName: "Silver I", minXP: 490, assetName: "silver_1"),
        .init(id: 5, tier: .silver, stage: 2, displayName: "Silver II", minXP: 730, assetName: "silver_2"),
        .init(id: 6, tier: .silver, stage: 3, displayName: "Silver III", minXP: 1010, assetName: "silver_3"),
        .init(id: 7, tier: .gold, stage: 1, displayName: "Gold I", minXP: 1340, assetName: "gold_1"),
        .init(id: 8, tier: .gold, stage: 2, displayName: "Gold II", minXP: 1720, assetName: "gold_2"),
        .init(id: 9, tier: .gold, stage: 3, displayName: "Gold III", minXP: 2150, assetName: "gold_3"),
        .init(id: 10, tier: .platinum, stage: 1, displayName: "Platinum I", minXP: 2630, assetName: "platinum_1"),
        .init(id: 11, tier: .platinum, stage: 2, displayName: "Platinum II", minXP: 3160, assetName: "platinum_2"),
        .init(id: 12, tier: .platinum, stage: 3, displayName: "Platinum III", minXP: 3740, assetName: "platinum_3"),
        .init(id: 13, tier: .diamond, stage: 1, displayName: "Diamond I", minXP: 4370, assetName: "diamond_1"),
        .init(id: 14, tier: .diamond, stage: 2, displayName: "Diamond II", minXP: 5050, assetName: "diamond_2"),
        .init(id: 15, tier: .diamond, stage: 3, displayName: "Diamond III", minXP: 5780, assetName: "diamond_3"),
        .init(id: 16, tier: .champion, stage: 1, displayName: "Champion I", minXP: 6560, assetName: "champion_1"),
        .init(id: 17, tier: .champion, stage: 2, displayName: "Champion II", minXP: 7390, assetName: "champion_2"),
        .init(id: 18, tier: .champion, stage: 3, displayName: "Champion III", minXP: 8270, assetName: "champion_3"),
        .init(id: 19, tier: .titan, stage: 1, displayName: "Titan I", minXP: 9200, assetName: "titan_1"),
        .init(id: 20, tier: .titan, stage: 2, displayName: "Titan II", minXP: 10180, assetName: "titan_2"),
        .init(id: 21, tier: .titan, stage: 3, displayName: "Titan III", minXP: 11210, assetName: "titan_3"),
        .init(id: 22, tier: .olympian, stage: 1, displayName: "Olympian I", minXP: 12290, assetName: "olympian_1"),
        .init(id: 23, tier: .olympian, stage: 2, displayName: "Olympian II", minXP: 13420, assetName: "olympian_2"),
        .init(id: 24, tier: .olympian, stage: 3, displayName: "Olympian III", minXP: 14600, assetName: "olympian_3")
    ]

    static func rank(for xp: Int) -> RankLevel {
        all.last(where: { xp >= $0.minXP }) ?? all[0]
    }

    static func nextRank(after rank: RankLevel) -> RankLevel? {
        all.first(where: { $0.id == rank.id + 1 })
    }

    static func progress(totalXP: Int, current: RankLevel) -> Double {
        guard let next = nextRank(after: current) else {
            return min(1, Double(max(0, totalXP - current.minXP)) / Double(max(1, masteryXP - current.minXP)))
        }
        return min(1, max(0, Double(totalXP - current.minXP) / Double(next.minXP - current.minXP)))
    }
}
