import Foundation
import SwiftUI
import Combine

@MainActor
class MemoryMatchViewModel: ObservableObject {
    @Published var cards: [MemoryCard] = []
    @Published var difficulty: MemoryDifficulty = .fourByFour
    @Published var timerSeconds: Int = 0
    @Published var moves: Int = 0
    @Published var matchesFound: Int = 0
    @Published var score: Int = 0
    @Published var showVictory: Bool = false
    @Published var showTutorialSheet: Bool = false
    @Published var gameRulesExpanded: Bool = false
    @Published var isLocked: Bool = false
    
    @Published var currentIndex: Int = 0
    
    let totalRounds: Int
    let isPreviewMode: Bool
    
    var totalPairs: Int { difficulty.pairCount }
    
    private var engine: MemoryMatchEngine?
    private var timerCancellable: AnyCancellable?
    private let hapticGenerator = UINotificationFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private var onComplete: (() -> Void)?
    
    private let imagePool = ["dog", "cat", "rabbit", "lion", "tiger", "bear", "panda", "koala", "fox", "monkey", "elephant", "giraffe", "cow", "pig", "chicken", "duck", "owl", "penguin"]
    private let symbolPool = ["leaf.fill", "flame.fill", "bolt.fill", "drop.fill", "hare.fill", "tortoise.fill", "ant.fill", "ladybug.fill", "crown.fill", "star.fill", "moon.fill", "sun.max.fill", "heart.fill", "cloud.fill", "umbrella.fill", "wind", "snowflake", "mountain.2.fill"]

    init(difficulty: MemoryDifficulty = .fourByFour, rounds: Int = 1, isPreviewMode: Bool = false, onComplete: (() -> Void)? = nil) {
        self.difficulty = difficulty
        self.totalRounds = rounds
        self.isPreviewMode = isPreviewMode
        self.onComplete = onComplete
        self.showTutorialSheet = !UserDefaults.standard.bool(forKey: "memoryMatch.dontShowTutorial")
        newGame(difficulty: difficulty)
    }
    
    func newGame(difficulty: MemoryDifficulty) {
        self.difficulty = difficulty
        self.cards = generateDeck(for: difficulty)
        self.engine = MemoryMatchEngine(difficulty: difficulty, cards: self.cards)
        self.timerSeconds = 0
        self.moves = 0
        self.matchesFound = 0
        self.score = 0
        self.showVictory = false
        self.isLocked = false
        stopTimer()
    }
    
    func restart() {
        newGame(difficulty: difficulty)
    }
    
    func tapCard(_ cardID: UUID) {
        guard let engine = engine, !isLocked else { return }
        
        // Start timer on first tap
        if timerSeconds == 0 && !timerIsRunning {
            startTimer()
        }
        
        let effects = engine.tap(cardID: cardID)
        applyEffects(effects, tappedID: cardID)
    }
    
    private func applyEffects(_ effects: [EngineEffect], tappedID: UUID) {
        for effect in effects {
            switch effect {
            case .flipUp(let id):
                if let index = cards.firstIndex(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        cards[index].isFaceUp = true
                    }
                    impactGenerator.impactOccurred()
                }
            case .flipDown(let id):
                if let index = cards.firstIndex(where: { $0.id == id }) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        cards[index].isFaceUp = false
                    }
                }
            case .markMatched(let ids):
                for id in ids {
                    if let index = cards.firstIndex(where: { $0.id == id }) {
                        cards[index].isMatched = true
                    }
                }
                matchesFound = engine?.matchesFound ?? 0
                hapticGenerator.notificationOccurred(.success)
            case .updateScore(_):
                score = engine?.score ?? 0
            case .lockInput:
                isLocked = true
                // If it's a mismatch or bonus, handle delay
                handleDelayedResolution(tappedID)
            case .unlockInput:
                isLocked = false
            case .gameWon:
                stopTimer()
                withAnimation {
                    showVictory = true
                }
                saveHighScore()
                
                handleRoundComplete()
            }
        }
        moves = engine?.moves ?? 0
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
    
    private func handleDelayedResolution(_ tappedID: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == tappedID }) else { return }
        
        if cards[index].isBonus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                let effects = self.engine?.resolveBonus(cardID: tappedID) ?? []
                self.applyEffects(effects, tappedID: tappedID)
            }
        } else if matchesFound == engine?.matchesFound {
            // It was a mismatch (matchesFound didn't increase in applyEffects yet if mismtach)
            // Actually Engine logic: if match, matchesFound increases and .markMatched is sent.
            // If mismatch, we just locked input.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let effects = self.engine?.resolveMismatch() ?? []
                self.applyEffects(effects, tappedID: tappedID)
            }
        }
    }
    
    private func generateDeck(for difficulty: MemoryDifficulty) -> [MemoryCard] {
        var deck: [MemoryCard] = []
        let pairCount = difficulty.pairCount
        
        // Pick random images/icons
        let images = Array(imagePool.shuffled().prefix(pairCount))
        let symbols = Array(symbolPool.shuffled().prefix(pairCount))
        
        for i in 0..<pairCount {
            // Create two cards for each pair
            deck.append(MemoryCard(pairID: i, imageName: images[i], systemIcon: symbols[i]))
            deck.append(MemoryCard(pairID: i, imageName: images[i], systemIcon: symbols[i]))
        }
        
        if difficulty.hasBonus {
            deck.append(MemoryCard(pairID: nil, imageName: nil, systemIcon: "star.fill"))
        }
        
        return deck.shuffled()
    }
    
    // Timer helper
    private var timerIsRunning: Bool = false
    private func startTimer() {
        timerIsRunning = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.timerSeconds += 1
            }
    }
    
    private func stopTimer() {
        timerIsRunning = false
        timerCancellable?.cancel()
    }
    
    private func saveHighScore() {
        let key = "memoryMatch.highscore.\(difficulty.rawValue)"
        let newScore = MemoryMatchHighScore(score: score, time: timerSeconds, moves: moves)
        
        if let data = UserDefaults.standard.data(forKey: key),
           let current = try? JSONDecoder().decode(MemoryMatchHighScore.self, from: data) {
            if newScore.score > current.score {
                if let encoded = try? JSONEncoder().encode(newScore) {
                    UserDefaults.standard.set(encoded, forKey: key)
                }
            }
        } else {
            if let encoded = try? JSONEncoder().encode(newScore) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
}
