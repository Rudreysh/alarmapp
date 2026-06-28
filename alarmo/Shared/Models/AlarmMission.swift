import Foundation

struct AlarmMission: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: WakeUpMissionType
    var difficulty: Int = 0 // 0: Very easy, 1: Easy, 2: Normal, 3: Hard, 4: Very hard
    var rounds: Int = 3
    var config: [String: Int] = [:]
    var customData: [String: String] = [:]
    
    var title: String {
        switch type {
        case .math: return "Math"
        case .typing: return "Typing"
        case .findColorTiles: return "Find Color Tiles"
        case .memoryMatch: return "Memory Match"
        case .ticTacToe: return "Tic Tac Toe"
        case .shake: return "Shake"
        case .step: return "Step"
        case .qrBarcode: return "QR/Barcode"
        case .householdItemHunt: return "Household Item Hunt"
        case .squat: return "Squat"
        case .objectHunt: return "Object Hunt"
        case .pushups: return "Push-ups"
        case .plank: return "Plank Hold"
        case .breathing: return "Breathing"
        case .bibleVerse: return "Bible Verse"
        case .quranVerse: return "Quran Verse"
        case .bhagavadGitaVerse: return "Bhagavad Gita Verse"
        case .affirmation: return "Affirmation"
        case .off: return "Off"
        }
    }
    
    var iconName: String {
        switch type {
        case .math: return "plus.forwardslash.minus"
        case .typing: return "keyboard"
        case .findColorTiles: return "square.grid.2x2.fill"
        case .memoryMatch: return "brain.head.profile"
        case .ticTacToe: return "xmark.square.fill"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .step: return "figure.walk"
        case .qrBarcode: return "barcode.viewfinder"
        case .householdItemHunt: return "camera.macro"
        case .squat: return "figure.strengthtraining.traditional"
        case .objectHunt: return "sparkle.magnifyingglass"
        case .pushups: return "figure.core.training"
        case .plank: return "timer.circle"
        case .breathing: return "wind"
        case .bibleVerse: return "book.closed"
        case .quranVerse: return "moon.stars"
        case .bhagavadGitaVerse: return "book.pages"
        case .affirmation: return "quote.bubble"
        case .off: return "xmark.circle"
        }
    }
}
