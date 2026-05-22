import SwiftUI

struct WeekdayPill: View {
    let label: String
    let isSelected: Bool
    let isInteractive: Bool
    let onTap: () -> Void
    
    private let alarmWeekdayBlue = Color(red: 0.08, green: 0.78, blue: 0.92)

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background(isSelected ? alarmWeekdayBlue : Colors.cardSurface)
                .cornerRadius(12)
                .opacity(isInteractive ? 1.0 : 1.0)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .allowsHitTesting(isInteractive)
    }
}
