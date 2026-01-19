import SwiftUI

struct FloatingAddMenu: View {
    let onSelectTimer: () -> Void
    let onSelectHabit: () -> Void
    let onSelectQuick: () -> Void
    let onSelectAlarm: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            VStack(spacing: 0) {
                MenuRow(icon: "timer", title: "Timer", tint: Color.orange) {
                    onSelectTimer()
                }
            }
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

            VStack(spacing: 0) {
                MenuRow(icon: "calendar", title: "Habit alarm", tint: Color.purple) {
                    onSelectHabit()
                }
                Divider().background(Color.black.opacity(0.1))
                MenuRow(icon: "bolt.fill", title: "Quick alarm", tint: Color.blue) {
                    onSelectQuick()
                }
            }
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

            VStack(spacing: 0) {
                MenuRow(icon: "alarm", title: "Alarm", tint: Colors.accentRed) {
                    onSelectAlarm()
                }
            }
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, Spacing.l)
        .padding(.bottom, AppConstants.tabBarHeight + 80)
    }
}

private struct MenuRow: View {
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
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 200)
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}
