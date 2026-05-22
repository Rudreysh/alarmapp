import SwiftUI

struct PromoCard: View {
    let iconSystemName: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(Spacing.m)
            .background(Colors.promoCardBackground)
            .cornerRadius(22)
            .appShadow(Shadows.card)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .accessibilityLabel(Text(title))
    }
}
