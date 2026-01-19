import SwiftUI

struct TTTCellView: View {
    let mark: TTTMark
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHighlighted ? Color.orange : Color.clear, lineWidth: 3)
                    )
                
                if mark != .empty {
                    Text(mark.rawValue)
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(mark == .x ? .orange : Color.white.opacity(0.9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(TTTButtonStyle())
    }
}

struct TTTButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct TTTDifficultyPicker: View {
    @Binding var selected: TTTDifficulty
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TTTDifficulty.allCases) { diff in
                Button(action: {
                    selected = diff
                    onChange()
                }) {
                    Text(diff.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(selected == diff ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == diff ? Color.orange : Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct TTTSizePicker: View {
    @Binding var selected: TTTBoardSize
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TTTBoardSize.allCases) { size in
                Button(action: {
                    selected = size
                    onChange()
                }) {
                    Text(size.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(selected == size ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == size ? Color.orange : Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct TTTStatusRow: View {
    let status: String
    let isThinking: Bool
    
    var body: some View {
        HStack {
            if isThinking {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 4)
            }
            Text(status)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct TTTStatsRow: View {
    let stats: TTTStats
    
    var body: some View {
        HStack {
            MissionStatItem(icon: "checkmark.circle", label: "Wins", value: "\(stats.wins)")
            Spacer()
            MissionStatItem(icon: "xmark.circle", label: "Losses", value: "\(stats.losses)")
            Spacer()
            MissionStatItem(icon: "minus.circle", label: "Draws", value: "\(stats.draws)")
            Spacer()
            MissionStatItem(icon: "flame.fill", label: "Streak", value: "\(stats.currentStreak)")
        }
        .padding(.horizontal, 24)
    }
}

struct TTTTutorialSheet: View {
    @Binding var isPresented: Bool
    @State private var dontShowAgain = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 0) {
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
                .background(LinearGradient(colors: [.orange, .teal], startPoint: .leading, endPoint: .trailing))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        MissionTutorialStep(num: 1, text: "Tap an empty square to place your 'X'")
                        MissionTutorialStep(num: 2, text: "Try to get 3, 4, or 5 in a row depending on the board size")
                        MissionTutorialStep(num: 3, text: "Note: In 5x5 mode, only 4 in a row is needed to win!")
                        MissionTutorialStep(num: 4, text: "Beat the AI to complete the mission")
                    }
                    .padding(24)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        dontShowAgain.toggle()
                        UserDefaults.standard.set(dontShowAgain, forKey: "ticTacToe.dontShowTutorial")
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


