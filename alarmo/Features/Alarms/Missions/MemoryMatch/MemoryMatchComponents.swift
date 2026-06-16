import SwiftUI
import Combine

struct MemoryCardView: View {
    let card: MemoryCard
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Card Back
            RoundedRectangle(cornerRadius: 12)
                .fill(MissionTheme.softFillStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MissionTheme.softStroke, lineWidth: 1)
                )
                .overlay(
                    Text("?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(MissionTheme.backgroundSubtleText)
                )
                .opacity(card.isFaceUp || card.isMatched ? 0 : 1)
            
            // Card Front
            RoundedRectangle(cornerRadius: 12)
                .fill(Colors.cardSurface)
                .overlay(
                    Group {
                        if card.imageName != nil {
                            Image(systemName: card.systemIcon ?? "photo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(12)
                                .foregroundColor(Colors.textPrimary)
                        } else if let icon = card.systemIcon {
                            Image(systemName: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(12)
                                .foregroundColor(card.isBonus ? .orange : Colors.textPrimary)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(card.isMatched ? Color.green.opacity(0.5) : MissionTheme.softStroke, lineWidth: 2)
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
                        .foregroundColor(selected == diff ? MissionTheme.selectedControlText : MissionTheme.unselectedControlText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected == diff ? MissionTheme.selectedControlFill : Colors.cardSurface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == diff ? MissionTheme.selectedControlFill : Colors.cardStroke, lineWidth: 2)
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
            MissionTheme.overlayScrim.ignoresSafeArea()
            
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Colors.textPrimary)
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Colors.bgSecondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 16) {
                        AnimatedMemoryTutorialDemo()
                        MemoryTutorialInfoRow(
                            icon: "hand.tap.fill",
                            iconColor: Colors.accentTeal,
                            title: "Tap Any Card",
                            text: "Tap cards in the 3x3 grid to reveal symbols."
                        )
                        MemoryTutorialInfoRow(
                            icon: "checkmark.circle.fill",
                            iconColor: Colors.accentGreen,
                            title: "Correct Match",
                            text: "When two symbols match, those cards stay open."
                        )
                        MemoryTutorialInfoRow(
                            icon: "xmark.circle.fill",
                            iconColor: Colors.accentRed,
                            title: "Wrong Match",
                            text: "If symbols differ, they flip back face-down."
                        )
                        MemoryTutorialInfoRow(
                            icon: "flag.checkered",
                            iconColor: Colors.accentOrange,
                            title: "Mission Pass",
                            text: "Find all matching pairs to pass the mission."
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 6)
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
                            .background(MissionTheme.primaryButtonGradient)
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

private struct AnimatedMemoryTutorialDemo: View {
    @State private var phase = 0
    private let ticker = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private let demoSymbols = ["🧩", "🔔", "🧠", "🌙", "🧩", "⏰", "🔔", "⭐️", "🧠"]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    MemoryTutorialCard(
                        symbol: demoSymbols[index],
                        faceUp: isFaceUp(index),
                        matched: isMatched(index),
                        mismatch: isMismatch(index)
                    )
                }
            }

            HStack(spacing: 8) {
                Image(systemName: phase == 2 ? "checkmark.circle.fill" : (phase == 3 ? "xmark.circle.fill" : "hand.tap.fill"))
                    .foregroundColor(phase == 2 ? Colors.accentGreen : (phase == 3 ? Colors.accentRed : Colors.accentTeal))
                Text(statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Colors.bgSecondary)
            .cornerRadius(12)
        }
        .padding(14)
        .background(Colors.bgSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(16)
        .onReceive(ticker) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                phase = (phase + 1) % 5
            }
        }
    }

    private var statusText: String {
        switch phase {
        case 1:
            return "Second card selected"
        case 2:
            return "Correct pair stays open"
        case 3:
            return "Wrong pair selected"
        case 4:
            return "Wrong pair flips back down"
        default:
            return "Tap cards to start matching"
        }
    }

    private func isFaceUp(_ index: Int) -> Bool {
        switch phase {
        case 1:
            return index == 0 || index == 4
        case 2:
            return index == 0 || index == 4
        case 3:
            return index == 0 || index == 4 || index == 1 || index == 3
        case 4:
            return index == 0 || index == 4
        default:
            return false
        }
    }

    private func isMatched(_ index: Int) -> Bool {
        phase >= 2 && (index == 0 || index == 4)
    }

    private func isMismatch(_ index: Int) -> Bool {
        phase == 3 && (index == 1 || index == 3)
    }
}

private struct MemoryTutorialCard: View {
    let symbol: String
    let faceUp: Bool
    let matched: Bool
    let mismatch: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Colors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 2)
                )
            Group {
                if faceUp {
                    Text(symbol)
                        .font(.system(size: 28))
                } else {
                    Text("?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                }
            }
        }
        .frame(height: 62)
        .rotation3DEffect(
            .degrees(faceUp ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeInOut(duration: 0.35), value: faceUp)
    }

    private var borderColor: Color {
        if matched { return Colors.accentGreen }
        if mismatch { return Colors.accentRed }
        return Colors.cardStroke
    }
}

private struct MemoryTutorialInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            Spacer()
        }
    }
}
