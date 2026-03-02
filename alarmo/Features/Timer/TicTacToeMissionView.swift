import SwiftUI

// MARK: - Tic-Tac-Toe Mission View
/// User must beat a simple AI to unlock. The AI plays randomly (beatable with strategy).
struct TicTacToeMissionView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var isPlayerTurn: Bool = true
    @State private var gameMessage: String = "Your turn — play X to win"
    @State private var gameOver: Bool = false
    @State private var playerWon: Bool = false
    @State private var winningLine: [Int]? = nil
    
    private let linePatterns: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
        [0, 3, 6], [1, 4, 7], [2, 5, 8], // cols
        [0, 4, 8], [2, 4, 6]              // diagonals
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.18),
                    Color(red: 0.05, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "number.square")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Beat me to unlock")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(gameMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .animation(.easeInOut, value: gameMessage)
                }
                .padding(.bottom, 32)
                
                // Board
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(90), spacing: 8), count: 3), spacing: 8) {
                    ForEach(0..<9, id: \.self) { index in
                        cellView(index: index)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    if playerWon {
                        Button(action: { onComplete() }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if gameOver {
                        Button(action: { resetGame() }) {
                            Text("Try Again")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Button(action: { onCancel() }) {
                        Text("Nevermind")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
    }
    
    @ViewBuilder
    private func cellView(index: Int) -> some View {
        let isWinCell = winningLine?.contains(index) == true
        
        Button {
            guard !gameOver, isPlayerTurn, board[index].isEmpty else { return }
            makeMove(at: index, player: "X")
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isWinCell ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isWinCell ? Color.green.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Text(board[index])
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(board[index] == "X" ? .white : Color(red: 1.0, green: 0.4, blue: 0.4))
            }
            .frame(width: 90, height: 90)
        }
        .buttonStyle(.plain)
        .scaleEffect(board[index].isEmpty ? 1.0 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: board[index])
    }
    
    private func makeMove(at index: Int, player: String) {
        board[index] = player
        
        if let line = checkWin(for: player) {
            winningLine = line
            gameOver = true
            if player == "X" {
                playerWon = true
                gameMessage = "You won! 🎉"
            } else {
                gameMessage = "You lost. Try again!"
            }
            return
        }
        
        if board.allSatisfy({ !$0.isEmpty }) {
            gameOver = true
            gameMessage = "Draw! Try again."
            return
        }
        
        if player == "X" {
            isPlayerTurn = false
            gameMessage = "AI thinking…"
            // Brief delay for AI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                aiMove()
            }
        }
    }
    
    private func aiMove() {
        // Simple AI: try to win, then block, then random
        if let winMove = findBestMove(for: "O") {
            makeMove(at: winMove, player: "O")
        } else if let blockMove = findBestMove(for: "X") {
            makeMove(at: blockMove, player: "O")
        } else {
            // Random empty cell
            let empty = board.indices.filter { board[$0].isEmpty }
            if let random = empty.randomElement() {
                makeMove(at: random, player: "O")
            }
        }
        isPlayerTurn = true
        if !gameOver {
            gameMessage = "Your turn"
        }
    }
    
    private func findBestMove(for player: String) -> Int? {
        for pattern in linePatterns {
            let values = pattern.map { board[$0] }
            if values.filter({ $0 == player }).count == 2 && values.contains("") {
                return pattern.first { board[$0].isEmpty }
            }
        }
        return nil
    }
    
    private func checkWin(for player: String) -> [Int]? {
        for pattern in linePatterns {
            if pattern.allSatisfy({ board[$0] == player }) {
                return pattern
            }
        }
        return nil
    }
    
    private func resetGame() {
        board = Array(repeating: "", count: 9)
        isPlayerTurn = true
        gameOver = false
        playerWon = false
        winningLine = nil
        gameMessage = "Your turn — play X to win"
    }
}
