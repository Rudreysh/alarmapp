import SwiftUI

struct PlanFloatingMenu: View {
    let onSelectHabit: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Task row intentionally hidden for now; plus button creates habits directly.
            VStack(spacing: 0) {
                PlanMenuRow(icon: "list.bullet.rectangle.portrait.fill", title: "Habit", tint: Color.cyan) {
                    onSelectHabit()
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.95),
                        Color(red: 0.09, green: 0.12, blue: 0.17).opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            .frame(width: 210) // Consistent width
        }
    }
}

private struct PlanMenuRow: View {
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
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary) // White text for dark theme
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle()) // Simple press effect
    }
}
