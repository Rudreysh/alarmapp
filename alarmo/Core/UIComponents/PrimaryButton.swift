import SwiftUI

private struct UsesOnboardingDefaultWhiteButtonKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var usesOnboardingDefaultWhiteButton: Bool {
        get { self[UsesOnboardingDefaultWhiteButtonKey.self] }
        set { self[UsesOnboardingDefaultWhiteButtonKey.self] = newValue }
    }
}

struct PrimaryButton: View {
    enum Style {
        case alarmDefault
        case blueGlass
    }

    let title: String
    var iconName: String? = nil
    var style: Style = .alarmDefault
    let action: () -> Void
    @Environment(\.usesOnboardingDefaultWhiteButton) private var usesOnboardingDefaultWhiteButton

    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle == .tiimo
    }

    private var usesDefaultOnboardingWhiteStyle: Bool {
        !isTiimo && usesOnboardingDefaultWhiteButton
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: buttonFontSize, weight: buttonFontWeight))
                }
                
                Text(title)
                    .font(.system(size: buttonFontSize, weight: buttonFontWeight))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .padding(.vertical, verticalPadding)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
        }
        .buttonStyle(AdaptiveButtonStyle(isTiimo: isTiimo))
        .accessibilityLabel(Text(title))
    }

    private var buttonFontSize: CGFloat {
        isTiimo ? 17 : 18
    }

    private var buttonFontWeight: Font.Weight {
        isTiimo ? .semibold : .bold
    }

    private var foregroundColor: Color {
        if usesDefaultOnboardingWhiteStyle {
            return .black
        }
        return isTiimo ? .white : Colors.textPrimary
    }

    private var fixedHeight: CGFloat? {
        (isTiimo || usesDefaultOnboardingWhiteStyle) ? 56 : nil
    }

    private var verticalPadding: CGFloat {
        (isTiimo || usesDefaultOnboardingWhiteStyle) ? 0 : Spacing.m
    }

    private var strokeColor: Color {
        if usesDefaultOnboardingWhiteStyle {
            return Color.white.opacity(0.18)
        }
        return Color.white.opacity(style == .blueGlass ? 0.35 : 0)
    }

    private var strokeWidth: CGFloat {
        usesDefaultOnboardingWhiteStyle ? 0.5 : 1
    }

    private var shadowColor: Color {
        if isTiimo {
            return .clear
        }
        if usesDefaultOnboardingWhiteStyle {
            return Color.black.opacity(0.22)
        }
        return style == .blueGlass ? Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3) : Colors.shadow
    }

    private var shadowRadius: CGFloat {
        usesDefaultOnboardingWhiteStyle ? 12 : (style == .blueGlass ? 15 : 10)
    }

    private var shadowY: CGFloat {
        usesDefaultOnboardingWhiteStyle ? 8 : (style == .blueGlass ? 10 : 6)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isTiimo {
            Color.black
        } else if usesDefaultOnboardingWhiteStyle {
            Color.white
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
