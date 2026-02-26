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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(style == .blueGlass ? Color.black : Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(style == .blueGlass ? 0.25 : 0), lineWidth: 1)
            )
            .shadow(
                color: (style == .blueGlass ? Color(red: 0, green: 0.7, blue: 0.9).opacity(0.3) : Colors.shadow),
                radius: style == .blueGlass ? 15 : 10,
                x: 0,
                y: style == .blueGlass ? 10 : 6
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
                    Color(red: 0.55, green: 0.88, blue: 1.0), // Light vibrant cyan
                    Color(red: 0.0, green: 0.65, blue: 0.95)   // Deep vibrant blue
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
