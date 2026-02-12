import SwiftUI

struct PlanFloatingMenu: View {
    let onSelectTask: () -> Void
    let onSelectNote: () -> Void
    let onSelectHabit: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            
            // Task Option
            Button(action: onSelectTask) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PlanPalette.accent)
                        .frame(width: 28)
                    Text("Task")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 160)
                .planGlassPanel(cornerRadius: 18, fillOpacity: 0.11)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Habit Option
            Button(action: onSelectHabit) {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PlanPalette.accent)
                        .frame(width: 28)
                    Text("Habit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 160)
                .planGlassPanel(cornerRadius: 18, fillOpacity: 0.11)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Notes Option
            Button(action: onSelectNote) {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PlanPalette.accentSoft)
                        .frame(width: 28)
                    Text("Notes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PlanPalette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minWidth: 160)
                .planGlassPanel(cornerRadius: 18, fillOpacity: 0.11)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PlanPalette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minWidth: 160)
        }
    }
}
