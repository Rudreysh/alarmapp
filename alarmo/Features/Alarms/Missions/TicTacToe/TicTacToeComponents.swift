import SwiftUI
import Combine

struct TTTCellView: View {
    let mark: TTTMark
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MissionTheme.softFillStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isHighlighted ? Color.orange : Color.clear, lineWidth: 3)
                    )
                
                if mark != .empty {
                    Text(mark.rawValue)
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(mark == .x ? .orange : Colors.textPrimary)
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
                        .foregroundColor(selected == diff ? MissionTheme.selectedControlText : MissionTheme.unselectedControlText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == diff ? MissionTheme.selectedControlFill : Colors.cardSurface)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selected == diff ? MissionTheme.selectedControlFill : Colors.cardStroke, lineWidth: 2)
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
                        .foregroundColor(selected == size ? MissionTheme.selectedControlText : MissionTheme.unselectedControlText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == size ? MissionTheme.selectedControlFill : Colors.cardSurface)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selected == size ? MissionTheme.selectedControlFill : Colors.cardStroke, lineWidth: 2)
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
                        AnimatedTTTTutorialDemo()
                        TTTTutorialInfoRow(
                            icon: "hand.tap.fill",
                            iconColor: Colors.accentTeal,
                            title: "Tap Empty Cells",
                            text: "You place X. AI places O."
                        )
                        TTTTutorialInfoRow(
                            icon: "checkmark.circle.fill",
                            iconColor: Colors.accentGreen,
                            title: "Correct Play",
                            text: "Complete a line before the AI does."
                        )
                        TTTTutorialInfoRow(
                            icon: "xmark.circle.fill",
                            iconColor: Colors.accentRed,
                            title: "Wrong Play",
                            text: "Tapping an occupied cell does nothing."
                        )
                        TTTTutorialInfoRow(
                            icon: "flag.checkered",
                            iconColor: Colors.accentOrange,
                            title: "Mission Pass",
                            text: "Beat AI in the board round to pass."
                        )
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 6)
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

private struct AnimatedTTTTutorialDemo: View {
    @State private var phase = 0
    private let ticker = Timer.publish(every: 0.95, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    TTTTutorialCell(
                        mark: mark(at: index),
                        highlighted: phase >= 5 && [0, 1, 2].contains(index)
                    )
                }
            }
            .padding(12)
            .background(Colors.bgSecondary)
            .cornerRadius(14)

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
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
            withAnimation(.easeInOut(duration: 0.28)) {
                phase = (phase + 1) % 7
            }
        }
    }

    private var statusText: String {
        switch phase {
        case 0:
            return "Tap an empty cell to place X"
        case 1...4:
            return "Alternate turns with AI"
        case 5:
            return "Correct: line completed"
        default:
            return "Wrong: occupied cells cannot be played"
        }
    }

    private var statusIcon: String {
        switch phase {
        case 5:
            return "checkmark.circle.fill"
        case 6:
            return "xmark.circle.fill"
        default:
            return "hand.tap.fill"
        }
    }

    private var statusColor: Color {
        switch phase {
        case 5:
            return Colors.accentGreen
        case 6:
            return Colors.accentRed
        default:
            return Colors.accentTeal
        }
    }

    private func mark(at index: Int) -> String {
        switch phase {
        case 0:
            return ""
        case 1:
            return index == 0 ? "X" : ""
        case 2:
            if index == 0 { return "X" }
            if index == 4 { return "O" }
            return ""
        case 3:
            if index == 0 || index == 1 { return "X" }
            if index == 4 { return "O" }
            return ""
        case 4:
            if index == 0 || index == 1 { return "X" }
            if index == 4 || index == 8 { return "O" }
            return ""
        case 5, 6:
            if index == 0 || index == 1 || index == 2 { return "X" }
            if index == 4 || index == 8 { return "O" }
            return ""
        default:
            return ""
        }
    }
}

private struct TTTTutorialCell: View {
    let mark: String
    let highlighted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Colors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(highlighted ? Colors.accentGreen : Colors.cardStroke, lineWidth: 2)
                )

            if !mark.isEmpty {
                Text(mark)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(mark == "X" ? Colors.accentOrange : Colors.textPrimary)
            }
        }
        .frame(height: 56)
    }
}

private struct TTTTutorialInfoRow: View {
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
