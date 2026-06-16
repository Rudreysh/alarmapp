import SwiftUI

struct TicTacToeGameView: View {
    @StateObject var viewModel: TicTacToeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            // Background
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                    Text("\(viewModel.currentIndex + 1)/\(viewModel.totalRounds)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { viewModel.showTutorialSheet = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                Text("Tic Tac Toe")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.bottom, 20)
                
                // Status Row
                TTTStatusRow(status: viewModel.statusText, isThinking: viewModel.isThinking)
                
                if viewModel.boardSize == .fiveByFive {
                    Text("4 in a row to win")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.top, -8)
                }
                
                // Game Board
                gameBoard
                    .padding(.horizontal, 40)
                    .overlay(victoryOverlay)
                
                Spacer()
                
                if viewModel.isPreviewMode {
                    Text("PREVIEW MODE")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(MissionTheme.backgroundSubtleText)
                        .padding(.bottom, 20)
                }
            }
            
            if viewModel.showTutorialSheet {
                TTTTutorialSheet(isPresented: $viewModel.showTutorialSheet)
            }
        }
        .sheet(isPresented: $showStats) {
            statsDetailView
        }
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }
            Spacer()
            Text("Tic Tac Toe")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button(action: { viewModel.showTutorialSheet = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 24))
                    .foregroundColor(Colors.textPrimary)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var gameBoard: some View {
        let size = viewModel.boardSize.rawValue
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: size)
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<boardCount, id: \.self) { index in
                TTTCellView(
                    mark: viewModel.board[index],
                    isHighlighted: winningIndices.contains(index),
                    onTap: { viewModel.tapCell(at: index) }
                )
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
    
    private var boardCount: Int {
        viewModel.board.count
    }
    
    private var winningIndices: [Int] {
        if case .win(_, let indices) = viewModel.gameResult {
            return indices
        }
        return []
    }
    
    private var victoryOverlay: some View {
        Group {
            if viewModel.showVictory {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("Victory!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(MissionTheme.isTiimo ? Colors.textPrimary : .white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing))
                            .appShadow(Shadows.card)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var statsDetailView: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Session Stats")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    
                    VStack(spacing: 16) {
                        StatDetailRow(label: "Wins", value: "\(viewModel.stats.wins)", color: .green)
                        StatDetailRow(label: "Losses", value: "\(viewModel.stats.losses)", color: .red)
                        StatDetailRow(label: "Draws", value: "\(viewModel.stats.draws)", color: .gray)
                        Divider().background(MissionTheme.softStroke)
                        StatDetailRow(label: "Current Streak", value: "\(viewModel.stats.currentStreak)", color: .orange)
                        StatDetailRow(label: "Best Streak", value: "\(viewModel.stats.bestStreak)", color: .yellow)
                    }
                    .padding(24)
                    .background(Colors.cardSurface)
                    .cornerRadius(24)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showStats = false }
                        .foregroundColor(.teal)
                }
            }
        }
    }
}

struct StatDetailRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(MissionTheme.backgroundMutedText)
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
        }
    }
}
