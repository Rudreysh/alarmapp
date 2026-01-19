import SwiftUI

struct MemoryCardView: View {
    let card: MemoryCard
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Card Back
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .overlay(
                    Text("?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                )
                .opacity(card.isFaceUp || card.isMatched ? 0 : 1)
            
            // Card Front
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.2))
                .overlay(
                    Group {
                        if card.imageName != nil {
                            Image(systemName: card.systemIcon ?? "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(12)
                                .foregroundColor(.white)
                        } else if let icon = card.systemIcon {
                            Image(systemName: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(12)
                                .foregroundColor(card.isBonus ? .orange : .white)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(card.isMatched ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 2)
                )
                .opacity(card.isFaceUp || card.isMatched ? 1 : 0)
        }
        .rotation3DEffect(.degrees(card.isFaceUp || card.isMatched ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            onTap()
        }
    }
}

struct MemoryTopBar: View {
    let onHighScores: () -> Void
    let onRestart: () -> Void
    let onNewGame: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            MissionActionButton(title: "High Scores", color: Color.teal, action: onHighScores)
            MissionActionButton(title: "Restart", color: Color.orange, action: onRestart)
            MissionActionButton(title: "New Game", color: Color.teal, action: onNewGame)
        }
        .padding(.horizontal, 16)
    }
}



struct MemoryStatsRow: View {
    let timer: Int
    let moves: Int
    let matches: Int
    let total: Int
    let score: Int
    
    var body: some View {
        HStack {
            MissionStatItem(icon: "stopwatch", value: formatTime(timer))
            Spacer()
            MissionStatItem(icon: "arrow.left.and.right", label: "Moves", value: "\(moves)")
            Spacer()
            MissionStatItem(icon: "checkmark.circle", label: "Matches", value: "\(matches)/\(total)")
            Spacer()
            MissionStatItem(icon: "star.fill", label: "Score", value: "\(score)")
        }
        .padding(.horizontal, 20)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}



struct MemoryDifficultyPicker: View {
    @Binding var selected: MemoryDifficulty
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(MemoryDifficulty.allCases) { diff in
                Button(action: { selected = diff }) {
                    Text(diff.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selected == diff ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected == diff ? Color.orange : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct MemoryTutorialSheet: View {
    @Binding var isPresented: Bool
    @State private var dontShowAgain = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("How to Play:")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .padding(24)
                .background(
                    LinearGradient(colors: [.orange, .teal], startPoint: .leading, endPoint: .trailing)
                )
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        MissionTutorialStep(num: 1, text: "Click on a card to flip it and reveal its symbol")
                        MissionTutorialStep(num: 2, text: "Click on a second card to try to find its match")
                        MissionTutorialStep(num: 3, text: "If the two cards match, they stay revealed")
                        MissionTutorialStep(num: 4, text: "If the cards don't match, they flip back face down")
                        MissionTutorialStep(num: 5, text: "Continue until all pairs are matched")
                        MissionTutorialStep(num: 6, text: "Complete the game in the fewest moves possible")
                    }
                    .padding(24)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        dontShowAgain.toggle()
                        UserDefaults.standard.set(dontShowAgain, forKey: "memoryMatch.dontShowTutorial")
                    }) {
                        HStack {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            Text("Don't show again")
                        }
                        .foregroundColor(Colors.textSecondary)
                    }
                    
                    Button(action: { isPresented = false }) {
                        Text("Got it!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal)
                            .cornerRadius(12)
                    }
                }
                .padding(24)
            }
            .background(Colors.cardSurface)
            .cornerRadius(24)
            .padding(24)
        }
    }
}


