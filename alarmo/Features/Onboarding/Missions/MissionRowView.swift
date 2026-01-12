import SwiftUI

struct MissionRowView: View {
    let option: MissionOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                if let icon = option.icon, let background = option.iconBackground {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(background)
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(width: 48, height: 48)
                }

                Text(option.title)
                    .bodyText()
                    .fontWeight(.semibold)
                    .foregroundColor(Colors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .frame(height: 88)
            .background(isSelected ? Colors.bgSecondary : Colors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.card)
                    .stroke(isSelected ? Colors.textPrimary.opacity(0.4) : Colors.cardStroke, lineWidth: 1)
            )
            .cornerRadius(Radii.card)
            .appShadow(Shadows.card)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text("Mission: \(option.title)"))
        .accessibilityValue(Text(isSelected ? "Selected" : ""))
    }
}
