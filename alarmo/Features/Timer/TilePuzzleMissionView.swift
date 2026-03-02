import SwiftUI

// MARK: - Tile Puzzle Mission View
/// 3x3 sliding tile puzzle — user must solve it to unlock their apps.
struct TilePuzzleMissionView: View {
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var tiles: [Int] = []  // 0 = empty space
    @State private var moveCount: Int = 0
    @State private var isSolved: Bool = false
    @State private var solvedScale: CGFloat = 1.0
    
    private let gridSize = 3
    private let solved: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 0]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.15),
                    Color(red: 0.08, green: 0.10, blue: 0.22),
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.6))
                    Text(isSolved ? "Puzzle Solved! 🎉" : "Solve to Unlock")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .animation(.easeInOut, value: isSolved)
                    Text("\(moveCount) moves")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 36)
                
                // Puzzle grid
                VStack(spacing: 6) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<gridSize, id: \.self) { col in
                                let index = row * gridSize + col
                                tileView(at: index)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .scaleEffect(solvedScale)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    if isSolved {
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
                    } else {
                        Button(action: { shuffleTiles() }) {
                            Text("Shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.1))
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
        .onAppear { setupTiles() }
    }
    
    @ViewBuilder
    private func tileView(at index: Int) -> some View {
        let value = tiles.isEmpty ? 0 : tiles[index]
        let tileSize: CGFloat = (UIScreen.main.bounds.width - 80) / 3
        
        if value == 0 {
            // Empty space
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clear)
                .frame(width: tileSize, height: tileSize)
        } else {
            Button {
                moveTile(at: index)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.25, blue: 0.55),
                                    Color(red: 0.2, green: 0.18, blue: 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Text("\(value)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: tileSize, height: tileSize)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Puzzle Logic
    
    private func setupTiles() {
        tiles = solved
        shuffleTiles()
    }
    
    private func shuffleTiles() {
        moveCount = 0
        isSolved = false
        tiles = solved
        
        // Perform 200 valid random moves to ensure solvable
        var blankIndex = tiles.firstIndex(of: 0)!
        for _ in 0..<200 {
            let neighbors = validNeighbors(of: blankIndex)
            if let swapIndex = neighbors.randomElement() {
                tiles.swapAt(blankIndex, swapIndex)
                blankIndex = swapIndex
            }
        }
    }
    
    private func moveTile(at index: Int) {
        guard !isSolved else { return }
        guard let blankIndex = tiles.firstIndex(of: 0) else { return }
        
        let neighbors = validNeighbors(of: blankIndex)
        guard neighbors.contains(index) else { return }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            tiles.swapAt(blankIndex, index)
            moveCount += 1
        }
        
        checkSolved()
    }
    
    private func validNeighbors(of index: Int) -> [Int] {
        let row = index / gridSize
        let col = index % gridSize
        var neighbors: [Int] = []
        
        if row > 0 { neighbors.append(index - gridSize) } // up
        if row < gridSize - 1 { neighbors.append(index + gridSize) } // down
        if col > 0 { neighbors.append(index - 1) } // left
        if col < gridSize - 1 { neighbors.append(index + 1) } // right
        
        return neighbors
    }
    
    private func checkSolved() {
        if tiles == solved {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isSolved = true
                solvedScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    solvedScale = 1.0
                }
            }
        }
    }
}
