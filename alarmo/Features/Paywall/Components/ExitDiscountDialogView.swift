import SwiftUI

struct ExitDiscountDialogView: View {
    let titleText: String
    let onClose: () -> Void
    let onExit: () -> Void
    let onGetOffer: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(Colors.textSecondary)
                        .padding(6)
                }
            }

            Text(titleText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.m) {
                Button(action: onExit) {
                    Text("Exit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Colors.cardSurface)
                        .cornerRadius(14)
                }

                Button(action: onGetOffer) {
                    Text("Get offer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            LinearGradient(
                                colors: [Colors.accentTeal, Colors.accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
            }
        }
        .padding(Spacing.l)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.20),
                    Color(red: 0.05, green: 0.08, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(22)
        .shadow(color: Colors.shadow, radius: 16, x: 0, y: 10)
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}
