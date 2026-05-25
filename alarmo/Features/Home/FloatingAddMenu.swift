import SwiftUI

struct FloatingAddMenu: View {
    let onSelectHabit: () -> Void
    let onSelectQuick: () -> Void
    let onSelectAlarm: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(spacing: 14) {
                FloatingMenuIconButton(icon: "alarm.fill", tint: Colors.accentRed, action: onSelectAlarm)
                FloatingMenuIconButton(icon: "bolt.fill", tint: Colors.accentTeal, action: onSelectQuick)
                FloatingMenuIconButton(icon: "clock.fill", tint: Color.purple, action: onSelectHabit)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(Colors.cardSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Colors.cardStroke, lineWidth: 1.2)
            )
            .shadow(color: Colors.shadow.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .frame(width: 88)
    }
}

private struct FloatingMenuIconButton: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(tint)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(icon))
    }
}
