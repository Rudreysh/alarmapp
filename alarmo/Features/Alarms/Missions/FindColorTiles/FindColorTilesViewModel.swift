import Foundation
import SwiftUI
import Combine

class FindColorTilesViewModel: ObservableObject {
    // Current Game State
    @Published var tiles: [Tile] = []
    @Published var targetColor: Color = .yellow
    @Published var roundIndex: Int = 1
    @Published var remainingTargets: Int = 0
    @Published var showSuccessOverlay: Bool = false
    @Published var isGameOver: Bool = false
    @Published var isShowingPattern: Bool = false
    @Published var isPreviewMode: Bool = false
    
    // Settings
    let totalRounds: Int
    let difficulty: MissionDifficulty
    @Published var soundEnabled: Bool
    
    private var missionCompletion: (() -> Void)?
    private let palette: [Color] = [.yellow, .cyan, .green, .orange, .pink, .purple]
    private let hapticGenerator = UINotificationFeedbackGenerator()
    
    init(settings: FindColorTilesSettings, isPreviewMode: Bool = false, onComplete: (() -> Void)? = nil) {
        self.totalRounds = settings.rounds
        self.difficulty = settings.difficulty
        self.soundEnabled = settings.soundEnabled
        self.isPreviewMode = isPreviewMode
        self.missionCompletion = onComplete
        
        generateRound()
    }
    
    func generateRound() {
        let n = difficulty.gridSize
        let totalTiles = n * n
        let count = Int.random(in: difficulty.targetRange)
        
        self.targetColor = palette.randomElement() ?? .yellow
        self.remainingTargets = count
        
        var newTiles = (0..<totalTiles).map { Tile(id: $0, isTarget: false) }
        
        var targetIndices = Set<Int>()
        while targetIndices.count < count {
            targetIndices.insert(Int.random(in: 0..<totalTiles))
        }
        
        for index in targetIndices {
            newTiles[index] = Tile(id: index, isTarget: true)
        }
        
        self.tiles = newTiles
        
        // Start memorization phase
        self.isShowingPattern = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                self.isShowingPattern = false
            }
        }
    }
    
    func handleTap(on index: Int) {
        guard !showSuccessOverlay, !isGameOver, !isShowingPattern, tiles[index].state == .idle else { return }
        
        if tiles[index].isTarget {
            tiles[index].state = .found
            remainingTargets -= 1
            triggerHaptic(.success)
            
            if remainingTargets == 0 {
                completeRound()
            }
        } else {
            tiles[index].state = .wrongMarked
            triggerHaptic(.error)
        }
    }
    
    private func completeRound() {
        showSuccessOverlay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if self.roundIndex < self.totalRounds {
                self.roundIndex += 1
                self.generateRound()
                self.showSuccessOverlay = false
            } else {
                self.isGameOver = true
                self.showSuccessOverlay = false
                self.missionCompletion?()
            }
        }
    }
    
    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        hapticGenerator.notificationOccurred(type)
    }
}
