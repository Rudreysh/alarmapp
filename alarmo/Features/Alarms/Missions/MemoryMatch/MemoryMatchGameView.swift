import SwiftUI

struct MemoryMatchGameView: View {
    @StateObject var viewModel: MemoryMatchViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showHighScores = false
    
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
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("\(viewModel.currentIndex + 1)/\(viewModel.totalRounds)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { viewModel.showTutorialSheet = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                Text("Memory Match")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // Stats Row
                MemoryStatsRow(
                    timer: viewModel.timerSeconds,
                    moves: viewModel.moves,
                    matches: viewModel.matchesFound,
                    total: viewModel.totalPairs,
                    score: viewModel.score
                )
                .foregroundColor(.white)
                
                // Game Grid
                gameGrid
                    .padding(.horizontal, 20)
                    .overlay(victoryOverlay)
                
                Spacer()
                
                if viewModel.isPreviewMode {
                    Text("PREVIEW MODE")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
            }
            
            if viewModel.showTutorialSheet {
                MemoryTutorialSheet(isPresented: $viewModel.showTutorialSheet)
            }
        }
        .sheet(isPresented: $showHighScores) {
            MemoryMatchHighScoresView()
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
            Text("Memory Match")
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
    
    private var gameGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: viewModel.difficulty.cols)
        
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.cards) { card in
                MemoryCardView(card: card) {
                    viewModel.tapCard(card.id)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
    
    private var rulesSection: some View {
        VStack(spacing: 0) {
            Button(action: { 
                withAnimation {
                    viewModel.gameRulesExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Game Rules")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: viewModel.gameRulesExpanded ? "chevron.down" : "chevron.up")
                }
                .foregroundColor(.orange)
                .padding(.bottom, 8)
            }
            
            if viewModel.gameRulesExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    RuleBullet(text: "Click on a card to flip it and reveal its symbol")
                    RuleBullet(text: "Click on a second card to try to find its match")
                    RuleBullet(text: "If the two cards match, they stay revealed")
                    RuleBullet(text: "If the cards don't match, they flip back face down")
                    RuleBullet(text: "Complete the game in the fewest moves possible")
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Button("Show tutorial") {
                viewModel.showTutorialSheet = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Colors.textSecondary)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
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
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.teal, .green], startPoint: .leading, endPoint: .trailing))
                            .appShadow(Shadows.card)
                    )
                    
                    Text("Final Score: \(viewModel.score)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct RuleBullet: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
                .font(.system(size: 18, weight: .bold))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
