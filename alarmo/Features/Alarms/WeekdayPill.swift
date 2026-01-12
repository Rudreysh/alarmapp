import SwiftUI

struct WeekdayPill: View {
    let label: String
    let isSelected: Bool
    let isInteractive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                .frame(width: 36, height: 36)
                .background(isSelected ? Colors.accentTeal.opacity(0.8) : Colors.cardSurface)
                .cornerRadius(12)
                .opacity(isInteractive ? 1.0 : 1.0)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .allowsHitTesting(isInteractive)
    }
}
