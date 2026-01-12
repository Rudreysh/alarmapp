import SwiftUI

struct ExitDiscountDialogView: View {
    let titleText: String
    let onExit: () -> Void
    let onGetOffer: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
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
                        .background(Colors.accentRed)
                        .cornerRadius(14)
                }
            }
        }
        .padding(Spacing.l)
        .background(Color(red: 0.17, green: 0.18, blue: 0.21))
        .cornerRadius(22)
        .shadow(color: Colors.shadow, radius: 16, x: 0, y: 10)
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}
