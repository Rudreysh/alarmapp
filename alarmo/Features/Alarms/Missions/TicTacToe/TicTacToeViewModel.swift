import Foundation
import SwiftUI
import Combine

@MainActor
class TicTacToeViewModel: ObservableObject {
    @Published var board: [TTTMark] = []
    @Published var boardSize: TTTBoardSize = .threeByThree
    @Published var difficulty: TTTDifficulty = .medium
    @Published var currentTurn: TTTPlayer = .humanX
    @Published var gameResult: TTTGameResult = .playing
    @Published var isThinking: Bool = false
    @Published var statusText: String = "Your turn"
    @Published var stats = TTTStats()
    @Published var showVictory: Bool = false
    @Published var showTutorialSheet: Bool = false
    @Published var currentIndex: Int = 0
    
    let isPreviewMode: Bool
    let totalRounds: Int
    
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private var ai: TicTacToeAI?
    private var onComplete: (() -> Void)?
    
    init(rounds: Int = 1, isPreviewMode: Bool = false, onComplete: (() -> Void)? = nil) {
        self.totalRounds = rounds
        self.isPreviewMode = isPreviewMode
        self.onComplete = onComplete
        self.showTutorialSheet = !UserDefaults.standard.bool(forKey: "ticTacToe.dontShowTutorial")
        loadStats()
        newGame(size: .threeByThree, difficulty: .medium)
    }
    
    func newGame(size: TTTBoardSize, difficulty: TTTDifficulty) {
        self.boardSize = size
        self.difficulty = difficulty
        self.board = Array(repeating: .empty, count: size.rawValue * size.rawValue)
        self.currentTurn = .humanX
        self.gameResult = .playing
        self.isThinking = false
        self.statusText = "Your turn"
        self.showVictory = false
        self.ai = TicTacToeAI(difficulty: difficulty, size: size.rawValue, winLength: size.winLength)
    }
    
    func restart() {
        newGame(size: boardSize, difficulty: difficulty)
    }
    
    func tapCell(at index: Int) {
        guard gameResult == .playing, currentTurn == .humanX, !isThinking, board[index] == .empty else { return }
        
        impactGenerator.impactOccurred()
        board[index] = .x
        checkGameStatus()
        
        if gameResult == .playing {
            currentTurn = .aiO
            statusText = "AI thinking..."
            triggerAIMove()
        }
    }
    
    private func triggerAIMove() {
        isThinking = true
        
        // Artificial delay for UX
        let delay = Double.random(in: 0.3...0.6)
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            let boardCopy = self.board
            if let ai = self.ai {
                // Since AI is MainActor, we can call it directly here (we are on MainActor)
                // However, we want to avoid blocking the main thread if calculation is heavy.
                // But TicTacToeAI uses TicTacToeEngine which is MainActor, so it MUST run on MainActor.
                // For 3x3 this is instant. For 5x5 it might be slow.
                // If it's slow, we should refactor TicTacToeEngine to be nonisolated.
                // But assuming we can't change Engine, we just run it here.
                
                let move = ai.computeMove(board: boardCopy)
                
                if let move = move {
                    self.board[move] = .o
                    impactGenerator.impactOccurred()
                }
            }
            
            self.isThinking = false
            self.checkGameStatus()
            
            if self.gameResult == .playing {
                self.currentTurn = .humanX
                self.statusText = "Your turn"
            }
        }
    }
    
    private func checkGameStatus() {
        let result = TicTacToeEngine.checkResult(board: board, size: boardSize.rawValue, winLength: boardSize.winLength)
        self.gameResult = result
        
        switch result {
        case .win(let mark, _):
            if mark == .x {
                statusText = "You win!"
                showVictory = true
                stats.wins += 1
                stats.currentStreak += 1
                stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
                hapticGenerator.notificationOccurred(.success)
                saveStats()
                
                handleRoundComplete()
            } else {
                statusText = "AI Won! Try again."
                stats.losses += 1
                stats.currentStreak = 0
                hapticGenerator.notificationOccurred(.error)
                saveStats()
                
                handleRoundFailure()
            }
        case .draw:
            statusText = "Draw! Try again."
            stats.draws += 1
            stats.currentStreak = 0
            hapticGenerator.notificationOccurred(.warning)
            saveStats()
            
            handleRoundFailure()
        case .playing:
            break
        }
    }
    
    private func handleRoundFailure() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.restart()
        }
    }
    
    private func handleRoundComplete() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.currentIndex + 1 < self.totalRounds {
                self.currentIndex += 1
                self.restart()
            } else {
                // Mission completion handling
                self.onComplete?()
            }
        }
    }
    
    private func saveStats() {
        let key = "ticTacToe.stats.\(boardSize.rawValue).\(difficulty.rawValue)"
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func loadStats() {
        let key = "ticTacToe.stats.\(boardSize.rawValue).\(difficulty.rawValue)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(TTTStats.self, from: data) {
            self.stats = decoded
        } else {
            self.stats = TTTStats()
        }
    }
    
    func changeConfig() {
        loadStats()
        restart()
    }
}
