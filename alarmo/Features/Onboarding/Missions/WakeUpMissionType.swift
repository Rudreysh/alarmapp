import Foundation

enum WakeUpMissionType: String, CaseIterable, Codable, Equatable {
    case math
    case typing
    case findColorTiles
    case memoryMatch
    case ticTacToe
    case shake
    case step
    case qrBarcode
    case off
    
    var isProFeature: Bool {
        switch self {
        case .typing, .findColorTiles, .step, .qrBarcode:
            return true
        default:
            return false
        }
    }
}
