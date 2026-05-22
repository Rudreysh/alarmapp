import Foundation

enum EngineEffect {
    case flipUp(UUID)
    case flipDown(UUID)
    case markMatched([UUID])
    case updateScore(Int)
    case lockInput
    case unlockInput
    case gameWon
}

class MemoryMatchEngine {
    private let difficulty: MemoryDifficulty
    private var cards: [MemoryCard]
    private var firstSelectedID: UUID?
    private var secondSelectedID: UUID?
    private var isLocked = false
    
    var score: Int = 0
    var moves: Int = 0
    var matchesFound: Int = 0
    
    init(difficulty: MemoryDifficulty, cards: [MemoryCard]) {
        self.difficulty = difficulty
        self.cards = cards
    }
    
    func tap(cardID: UUID) -> [EngineEffect] {
        guard !isLocked else { return [] }
        
        guard let index = cards.firstIndex(where: { $0.id == cardID }),
              !cards[index].isFaceUp,
              !cards[index].isMatched else {
            return []
        }
        
        var effects: [EngineEffect] = []
        
        // Handling Bonus Card
        if cards[index].isBonus {
            effects.append(.flipUp(cardID))
            effects.append(.updateScore(5))
            score += 5
            return effects + [.lockInput] // Caller should handle 700ms delay and flip down
        }
        
        if firstSelectedID == nil {
            firstSelectedID = cardID
            cards[index].isFaceUp = true
            effects.append(.flipUp(cardID))
        } else if secondSelectedID == nil {
            secondSelectedID = cardID
            cards[index].isFaceUp = true
            effects.append(.flipUp(cardID))
            moves += 1
            
            effects.append(.lockInput)
            isLocked = true
            
            let firstID = firstSelectedID!
            let firstIdx = cards.firstIndex(where: { $0.id == firstID })!
            
            if cards[firstIdx].pairID == cards[index].pairID {
                // Match
                matchesFound += 1
                score += 10
                cards[firstIdx].isMatched = true
                cards[index].isMatched = true
                effects.append(.markMatched([firstID, cardID]))
                effects.append(.updateScore(10))
                
                firstSelectedID = nil
                secondSelectedID = nil
                isLocked = false
                effects.append(.unlockInput)
                
                if matchesFound == difficulty.pairCount {
                    effects.append(.gameWon)
                }
            } else {
                // Mismatch
                score = max(0, score - 1)
                effects.append(.updateScore(-1))
                // Caller must stay locked for a bit, then flip down
            }
        }
        
        return effects
    }
    
    func resolveMismatch() -> [EngineEffect] {
        guard let firstID = firstSelectedID, let secondID = secondSelectedID else { return [] }
        
        let firstIdx = cards.firstIndex(where: { $0.id == firstID })!
        let secondIdx = cards.firstIndex(where: { $0.id == secondID })!
        
        cards[firstIdx].isFaceUp = false
        cards[secondIdx].isFaceUp = false
        
        firstSelectedID = nil
        secondSelectedID = nil
        isLocked = false
        
        return [.flipDown(firstID), .flipDown(secondID), .unlockInput]
    }
    
    func resolveBonus(cardID: UUID) -> [EngineEffect] {
        if let index = cards.firstIndex(where: { $0.id == cardID }) {
            cards[index].isFaceUp = false
        }
        isLocked = false
        return [.flipDown(cardID), .unlockInput]
    }
}
