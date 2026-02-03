import Foundation

@MainActor
struct TicTacToeAI: Sendable {
    let difficulty: TTTDifficulty
    let size: Int
    let winLength: Int
    let aiMark: TTTMark = .o
    let humanMark: TTTMark = .x
    
    init(difficulty: TTTDifficulty, size: Int, winLength: Int) {
        self.difficulty = difficulty
        self.size = size
        self.winLength = winLength
    }
    
    func computeMove(board: [TTTMark]) -> Int? {
        switch difficulty {
        case .easy:
            return easyMove(board: board)
        case .medium:
            return mediumMove(board: board)
        case .hard:
            return hardMove(board: board)
        }
    }
    
    private func easyMove(board: [TTTMark]) -> Int? {
        let emptyIndices = board.indices.filter { board[$0] == .empty }
        guard !emptyIndices.isEmpty else { return nil }
        
        let shouldTryToBlock = Double.random(in: 0...1) < 0.35
        let shouldTryToWin = Double.random(in: 0...1) < 0.25
        
        if shouldTryToWin, let winMove = findImmediateMove(board: board, mark: aiMark) {
            return winMove
        }
        
        if shouldTryToBlock, let blockMove = findImmediateMove(board: board, mark: humanMark) {
            return blockMove
        }
        
        return emptyIndices.randomElement()
    }
    
    private func mediumMove(board: [TTTMark]) -> Int? {
        if let winMove = findImmediateMove(board: board, mark: aiMark) {
            return winMove
        }
        
        if let blockMove = findImmediateMove(board: board, mark: humanMark) {
            return blockMove
        }
        
        // Prefer center and corners heuristic
        let center = (size * size) / 2
        if board[center] == .empty && Double.random(in: 0...1) < 0.5 {
            return center
        }
        
        let emptyIndices = board.indices.filter { board[$0] == .empty }
        // Select move that increases our potential lines
        var bestMove = emptyIndices.randomElement()
        var maxScore = -1000000
        
        for idx in emptyIndices.shuffled().prefix(10) {
            var tempBoard = board
            tempBoard[idx] = aiMark
            let score = TicTacToeEngine.evaluate(board: tempBoard, size: size, winLength: winLength, aiMark: aiMark)
            if score > maxScore {
                maxScore = score
                bestMove = idx
            }
        }
        
        return bestMove
    }
    
    private func hardMove(board: [TTTMark]) -> Int? {
        if size == 3 {
            // Perfect play via minimax
            let result = minimax(board: board, depth: 0, isMaximizing: true, alpha: -1000000, beta: 1000000)
            return result.index
        } else {
            // Depth limited minimax for 4x4 and 5x5
            let depthLimit = size == 4 ? 6 : 4
            let result = minimax(board: board, depth: 0, isMaximizing: true, alpha: -1000000, beta: 1000000, depthLimit: depthLimit)
            return result.index
        }
    }
    
    private func findImmediateMove(board: [TTTMark], mark: TTTMark) -> Int? {
        let emptyIndices = board.indices.filter { board[$0] == .empty }
        for idx in emptyIndices {
            var tempBoard = board
            tempBoard[idx] = mark
            let res = TicTacToeEngine.checkResult(board: tempBoard, size: size, winLength: winLength)
            if case .win(let winner, _) = res, winner == mark {
                return idx
            }
        }
        return nil
    }
    
    private func minimax(board: [TTTMark], depth: Int, isMaximizing: Bool, alpha: Int, beta: Int, depthLimit: Int? = nil) -> (score: Int, index: Int?) {
        let res = TicTacToeEngine.checkResult(board: board, size: size, winLength: winLength)
        
        switch res {
        case .win(let winner, _):
            return (winner == aiMark ? 100000 - depth : -100000 + depth, nil)
        case .draw:
            return (0, nil)
        case .playing:
            if let limit = depthLimit, depth >= limit {
                return (TicTacToeEngine.evaluate(board: board, size: size, winLength: winLength, aiMark: aiMark), nil)
            }
        }
        
        var currentAlpha = alpha
        var currentBeta = beta
        let emptyIndices = getHeuristicMoves(board: board)
        
        if isMaximizing {
            var maxScore = -1000000
            var bestMove: Int? = nil
            
            for idx in emptyIndices {
                var tempBoard = board
                tempBoard[idx] = aiMark
                let score = minimax(board: tempBoard, depth: depth + 1, isMaximizing: false, alpha: currentAlpha, beta: currentBeta, depthLimit: depthLimit).score
                if score > maxScore {
                    maxScore = score
                    bestMove = idx
                }
                currentAlpha = max(currentAlpha, maxScore)
                if currentBeta <= currentAlpha { break }
            }
            return (maxScore, bestMove)
        } else {
            var minScore = 1000000
            var bestMove: Int? = nil
            
            for idx in emptyIndices {
                var tempBoard = board
                tempBoard[idx] = humanMark
                let score = minimax(board: tempBoard, depth: depth + 1, isMaximizing: true, alpha: currentAlpha, beta: currentBeta, depthLimit: depthLimit).score
                if score < minScore {
                    minScore = score
                    bestMove = idx
                }
                currentBeta = min(currentBeta, minScore)
                if currentBeta <= currentAlpha { break }
            }
            return (minScore, bestMove)
        }
    }
    
    private func getHeuristicMoves(board: [TTTMark]) -> [Int] {
        let emptyIndices = board.indices.filter { board[$0] == .empty }
        if size == 3 { return emptyIndices }
        
        // For larger boards, prioritize cells adjacent to existing marks
        var scoredMoves: [(Int, Int)] = []
        for idx in emptyIndices {
            let r = idx / size
            let c = idx % size
            var score = 0
            
            // Check neighbors
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = r + dr
                    let nc = c + dc
                    if nr >= 0 && nr < size && nc >= 0 && nc < size {
                        let nIdx = nr * size + nc
                        if board[nIdx] != .empty {
                            score += (board[nIdx] == aiMark ? 2 : 3) // Slightly prefer blocking moves in heuristic
                        }
                    }
                }
            }
            
            // Center preference
            let distToCenter = abs(r - size/2) + abs(c - size/2)
            score += (size - distToCenter)
            
            scoredMoves.append((idx, score))
        }
        
        return scoredMoves.sorted { $1.1 < $0.1 }.map { $0.0 }.prefix(size == 5 ? 10 : 16).map { $0 }
    }
}
