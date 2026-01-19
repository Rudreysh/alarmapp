import Foundation

class TicTacToeEngine {
    static func checkResult(board: [TTTMark], size: Int, winLength: Int) -> TTTGameResult {
        // Check rows
        for r in 0..<size {
            for c in 0...(size - winLength) {
                let start = r * size + c
                let indices = (0..<winLength).map { start + $0 }
                if let winner = checkLine(board: board, indices: indices) {
                    return .win(winner, indices)
                }
            }
        }
        
        // Check columns
        for c in 0..<size {
            for r in 0...(size - winLength) {
                let start = r * size + c
                let indices = (0..<winLength).map { start + $0 * size }
                if let winner = checkLine(board: board, indices: indices) {
                    return .win(winner, indices)
                }
            }
        }
        
        // Check diagonal (top-left to bottom-right)
        for r in 0...(size - winLength) {
            for c in 0...(size - winLength) {
                let start = r * size + c
                let indices = (0..<winLength).map { start + $0 * (size + 1) }
                if let winner = checkLine(board: board, indices: indices) {
                    return .win(winner, indices)
                }
            }
        }
        
        // Check diagonal (top-right to bottom-left)
        for r in 0...(size - winLength) {
            for c in (winLength - 1)..<size {
                let start = r * size + c
                let indices = (0..<winLength).map { start + $0 * (size - 1) }
                if let winner = checkLine(board: board, indices: indices) {
                    return .win(winner, indices)
                }
            }
        }
        
        // Check for draw
        if !board.contains(.empty) {
            return .draw
        }
        
        return .playing
    }
    
    private static func checkLine(board: [TTTMark], indices: [Int]) -> TTTMark? {
        guard !indices.isEmpty else { return nil }
        let first = board[indices[0]]
        if first == .empty { return nil }
        for i in 1..<indices.count {
            if board[indices[i]] != first {
                return nil
            }
        }
        return first
    }
    
    // Evaluation function for AI (4x4, 5x5)
    static func evaluate(board: [TTTMark], size: Int, winLength: Int, aiMark: TTTMark) -> Int {
        var score = 0
        let humanMark: TTTMark = (aiMark == .x) ? .o : .x
        
        let lines = getAllLines(size: size, winLength: winLength)
        for line in lines {
            score += evaluateLine(board: board, indices: line, aiMark: aiMark, humanMark: humanMark, winLength: winLength)
        }
        
        return score
    }
    
    private static func evaluateLine(board: [TTTMark], indices: [Int], aiMark: TTTMark, humanMark: TTTMark, winLength: Int) -> Int {
        var aiCount = 0
        var humanCount = 0
        
        for idx in indices {
            if board[idx] == aiMark {
                aiCount += 1
            } else if board[idx] == humanMark {
                humanCount += 1
            }
        }
        
        if aiCount > 0 && humanCount > 0 {
            return 0 // Blocked line
        }
        
        if aiCount > 0 {
            // AI potential
            if aiCount == winLength { return 10000 }
            return Int(pow(10.0, Double(aiCount)))
        }
        
        if humanCount > 0 {
            // Human potential
            if humanCount == winLength { return -10000 }
            return -Int(pow(11.0, Double(humanCount))) // Weight human slightly higher to prefer blocking
        }
        
        return 0
    }
    
    static func getAllLines(size: Int, winLength: Int) -> [[Int]] {
        var lines: [[Int]] = []
        
        // Rows
        for r in 0..<size {
            for c in 0...(size - winLength) {
                let start = r * size + c
                lines.append((0..<winLength).map { start + $0 })
            }
        }
        
        // Columns
        for c in 0..<size {
            for r in 0...(size - winLength) {
                let start = r * size + c
                lines.append((0..<winLength).map { start + $0 * size })
            }
        }
        
        // Diagonals
        for r in 0...(size - winLength) {
            for c in 0...(size - winLength) {
                let start = r * size + c
                lines.append((0..<winLength).map { start + $0 * (size + 1) })
            }
        }
        for r in 0...(size - winLength) {
            for c in (winLength - 1)..<size {
                let start = r * size + c
                lines.append((0..<winLength).map { start + $0 * (size - 1) })
            }
        }
        
        return lines
    }
}
