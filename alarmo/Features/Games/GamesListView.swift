import SwiftUI

struct GameItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let type: WakeUpMissionType
}

struct GamesListView: View {
    @State private var selectedGame: GameItem?
    
    let games: [GameItem] = [
        GameItem(
            id: "memoryMatch",
            title: "Memory Match",
            description: "Find matching pairs of cards to clear the grid.",
            icon: "brain.head.profile",
            color: .orange,
            type: .memoryMatch
        ),
        GameItem(
            id: "ticTacToe",
            title: "Tic Tac Toe",
            description: "Classic strategy game on 3x3, 4x4, or 5x5 boards.",
            icon: "xmark.square.fill",
            color: .orange,
            type: .ticTacToe
        ),
        GameItem(
            id: "findColorTiles",
            title: "Find Color Tiles",
            description: "Memorize and find the correct color tiles.",
            icon: "square.grid.2x2.fill",
            color: .cyan,
            type: .findColorTiles
        ),
        GameItem(
            id: "typing",
            title: "Typing",
            description: "Type the phrases correctly to wake up your brain.",
            icon: "keyboard.fill",
            color: .green,
            type: .typing
        ),
        GameItem(
            id: "math",
            title: "Math",
            description: "Solve arithmetic problems under pressure.",
            icon: "plus.forwardslash.minus",
            color: .purple,
            type: .math
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Morning Games")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                        
                        ForEach(games) { game in
                            GameCard(game: game) {
                                selectedGame = game
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .fullScreenCover(item: $selectedGame) { game in
                gameView(for: game)
            }
        }
    }
    
    @ViewBuilder
    private func gameView(for game: GameItem) -> some View {
        switch game.type {
        case .memoryMatch:
            MemoryMatchGameView(viewModel: MemoryMatchViewModel(onComplete: {
                selectedGame = nil
            }))
        case .ticTacToe:
            TicTacToeGameView(viewModel: TicTacToeViewModel(onComplete: {
                selectedGame = nil
            }))
        case .findColorTiles:
            FindColorTilesMissionView(viewModel: FindColorTilesViewModel(settings: FindColorTilesSettings(), onComplete: {
                selectedGame = nil
            }))
        case .typing:
            TypingMissionGameplayView(viewModel: TypingGameplayViewModel(
                settings: TypingSettings(),
                phrases: TypingSettings.defaultPhrases,
                isPreviewMode: true,
                onComplete: {
                    selectedGame = nil
                }
            ))
        case .math:
            MathMissionPlayView(viewModel: MathMissionViewModel(config: MathMissionConfig(), isPreviewMode: true, onComplete: {
                selectedGame = nil
            }))
        default:
            Text("Game Not Found")
        }
    }
}

struct GameCard: View {
    let game: GameItem
    let onPreview: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(game.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: game.icon)
                        .font(.system(size: 28))
                        .foregroundColor(game.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(game.description)
                        .font(.system(size: 14))
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            HStack {
                Spacer()
                Button(action: onPreview) {
                    Text("Preview")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(game.color)
                        .cornerRadius(20)
                }
            }
        }
        .padding(20)
        .background(Colors.cardSurface)
        .cornerRadius(24)
        .padding(.horizontal, 24)
        .appShadow(Shadows.card)
    }
}
