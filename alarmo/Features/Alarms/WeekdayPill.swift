import SwiftUI

struct WeekdayPill: View {
    let label: String
    let isSelected: Bool
    let isInteractive: Bool
    let onTap: () -> Void
    
    private let alarmWeekdayBlue = Color(red: 0.08, green: 0.78, blue: 0.92)

    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle.usesTiimoLayoutBranch
    }

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isTiimo ? (isSelected ? .white : Colors.textTertiary) : (isSelected ? .white : Colors.textSecondary))
                .frame(width: 36, height: 36)
                .background(isTiimo ? (isSelected ? Colors.accentBlue : Colors.pillGreen) : (isSelected ? alarmWeekdayBlue : Colors.cardSurface))
                .cornerRadius(isTiimo ? 18 : 12)
                .opacity(isInteractive ? 1.0 : 1.0)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .allowsHitTesting(isInteractive)
    }
}
