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
    case breathing
    case off
    
    var isProFeature: Bool {
        switch self {
        case .typing, .findColorTiles, .step, .qrBarcode, .householdItemHunt, .squat:
            return true
        default:
            return false
        }
    }
}
