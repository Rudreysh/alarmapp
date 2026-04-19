import Foundation

enum WakeUpMissionType: String, CaseIterable, Codable, Equatable, Identifiable {
    var id: String { rawValue }

    case math
    case typing
    case findColorTiles
    case memoryMatch
    case ticTacToe
    case shake
    case step
    case qrBarcode
    case householdItemHunt
    case squat
    case objectHunt
    case pushups
    case plank
    case breathing
    case bibleVerse
    case quranVerse
    case bhagavadGitaVerse
    case affirmation
    case off
    
    var isProFeature: Bool {
        switch self {
        case .typing, .findColorTiles, .step, .qrBarcode, .householdItemHunt, .squat, .objectHunt, .pushups, .plank:
            return true
        default:
            return false
        }
    }
}
