import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case alarmDefault
        case blueGlass
    }

    let title: String
    var iconName: String? = nil
    var style: Style = .alarmDefault
    let action: () -> Void

    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle == .tiimo
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: isTiimo ? 17 : 18, weight: isTiimo ? .semibold : .bold))
                }
                
                Text(title)
                    .font(.system(size: isTiimo ? 17 : 18, weight: isTiimo ? .semibold : .bold))
            }
            .foregroundColor(isTiimo ? .white : Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: isTiimo ? 56 : nil)
            .padding(.vertical, isTiimo ? 0 : Spacing.m)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(style == .blueGlass ? 0.35 : 0), lineWidth: 1)
            )
            .shadow(
                color: isTiimo ? .clear : (style == .blueGlass ? Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3) : Colors.shadow),
                radius: style == .blueGlass ? 15 : 10,
                x: 0,
                y: style == .blueGlass ? 10 : 6
            )
        }
        .buttonStyle(AdaptiveButtonStyle(isTiimo: isTiimo))
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isTiimo {
            Color(hex: "#7F77DD")
        } else {
            switch style {
            case .alarmDefault:
                Colors.accentRed
            case .blueGlass:
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.78, blue: 0.92).opacity(0.85),
                        Color(red: 0.05, green: 0.66, blue: 0.84).opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }
}

struct AdaptiveButtonStyle: ButtonStyle {
    let isTiimo: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        if isTiimo {
            configuration.label
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
