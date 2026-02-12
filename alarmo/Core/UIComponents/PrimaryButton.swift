import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case alarmDefault
        case blueGlass
    }

    let title: String
    var style: Style = .alarmDefault
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
                .background(backgroundView)
                .clipShape(RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                        .stroke(Color.white.opacity(style == .blueGlass ? 0.16 : 0), lineWidth: 1)
                )
                .shadow(
                    color: (style == .blueGlass ? Colors.accentTeal.opacity(0.18) : Colors.shadow),
                    radius: style == .blueGlass ? 14 : 10,
                    x: 0,
                    y: style == .blueGlass ? 8 : 6
                )
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .alarmDefault:
            Colors.accentRed
        case .blueGlass:
            LinearGradient(
                colors: [
                    Colors.accentTeal.opacity(0.95),
                    Colors.accentBlue.opacity(0.92)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
