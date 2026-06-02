import SwiftUI

enum MissionTheme {
    static var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch
    }

    static var backgroundText: Color {
        Colors.textPrimary
    }

    static var backgroundMutedText: Color {
        isTiimo ? Colors.textSecondary : Color.white.opacity(0.8)
    }

    static var backgroundSubtleText: Color {
        isTiimo ? Colors.textTertiary : Color.white.opacity(0.5)
    }

    static var softFill: Color {
        isTiimo ? Colors.bgSecondary : Color.white.opacity(0.1)
    }

    static var softFillStrong: Color {
        isTiimo ? Colors.bgSecondary.opacity(0.92) : Color.white.opacity(0.15)
    }

    static var softStroke: Color {
        isTiimo ? Colors.cardStroke : Color.white.opacity(0.1)
    }

    static var segmentedTrackFill: Color {
        isTiimo ? Colors.bgSecondary : Color.white.opacity(0.05)
    }

    static var selectedControlFill: Color {
        isTiimo ? Colors.accentBlue : Color.white
    }

    static var selectedControlText: Color {
        isTiimo ? .white : Colors.bgPrimary
    }

    static var unselectedControlFill: Color {
        isTiimo ? Colors.cardSurface : Color.white.opacity(0.2)
    }

    static var unselectedControlText: Color {
        isTiimo ? Colors.textSecondary : .orange
    }

    static var overlayScrim: Color {
        isTiimo ? Color.black.opacity(0.18) : Color.black.opacity(0.8)
    }

    static var timerCapsuleFill: Color {
        isTiimo ? Colors.bgSecondary : Color.white.opacity(0.1)
    }

    static var exampleBadgeFill: Color {
        isTiimo ? Colors.pillGreen : Color.blue
    }

    static var exampleBadgeText: Color {
        isTiimo ? Colors.accentBlue : .white
    }

    static var secondaryButtonFill: Color {
        isTiimo ? Colors.bgSecondary : Color.white.opacity(0.12)
    }

    static var secondaryButtonText: Color {
        isTiimo ? Colors.textPrimary : .white
    }

    static var primaryButtonGradient: LinearGradient {
        if isTiimo {
            return LinearGradient(
                colors: [Color(hex: "#1A1A1A"), Color(hex: "#111111")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.78, blue: 0.92),
                Color(red: 0.05, green: 0.66, blue: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryButtonShadow: Color {
        isTiimo ? Color.black.opacity(0.14) : Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3)
    }

    static var successScrim: Color {
        isTiimo ? Color.black.opacity(0.22) : Color.black.opacity(0.6)
    }

    static var successCardFill: Color {
        isTiimo ? Colors.cardSurface : Color.black.opacity(0.85)
    }
}

struct MissionActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(20)
                .appShadow(Shadows.card)
        }
    }
}

struct MissionStatItem: View {
    let icon: String
    var label: String? = nil
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(Colors.textSecondary)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(MissionTheme.backgroundText)
        }
    }
}

struct MissionTutorialStep: View {
    let num: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .teal], startPoint: .top, endPoint: .bottom))
                    .frame(width: 28, height: 28)
                Text("\(num)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(MissionTheme.backgroundMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
