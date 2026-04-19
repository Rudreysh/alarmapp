import SwiftUI

struct FloatingAddMenu: View {
    let onSelectTimer: () -> Void
    let onSelectHabit: () -> Void
    let onSelectQuick: () -> Void
    let onSelectAlarm: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(spacing: 0) {
                FloatingMenuRow(icon: "timer", title: "Pomodoro", tint: Color.orange) {
                    onSelectTimer()
                }
            }
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1.2)
            )
            .shadow(color: Colors.shadow.opacity(0.35), radius: 12, x: 0, y: 6)

            VStack(spacing: 0) {
                FloatingMenuRow(icon: "calendar", title: "Habit alarm", tint: Color.purple) {
                    onSelectHabit()
                }
                Divider().background(Colors.cardStroke)
                FloatingMenuRow(icon: "bolt.fill", title: "Quick alarm", tint: Color.blue) {
                    onSelectQuick()
                }
            }
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1.2)
            )
            .shadow(color: Colors.shadow.opacity(0.35), radius: 12, x: 0, y: 6)

            VStack(spacing: 0) {
                FloatingMenuRow(icon: "alarm", title: "Alarm", tint: Colors.accentRed) {
                    onSelectAlarm()
                }
            }
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1.2)
            )
            .shadow(color: Colors.shadow.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .frame(width: 210)
    }
}

private struct FloatingMenuRow: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}
