import SwiftUI

struct DiscountPaywallView: View {
    @StateObject private var viewModel: DiscountPaywallViewModel
    let onClose: () -> Void
    let onApply: () -> Void

    init(preferences: AppPreferencesProtocol, onClose: @escaping () -> Void, onApply: @escaping () -> Void, onGetOffer: @escaping () -> Void) {
        self.onClose = onClose
        self.onApply = onApply
        let model = DiscountPaywallViewModel(preferences: preferences)
        model.onRequestDismissPaywall = onClose
        model.onRequestGetOffer = onGetOffer
        _viewModel = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed app-themed backdrop to keep paywall consistent with Alarm/Home screens.
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Color.black.opacity(0.52)
            }
            .ignoresSafeArea()
            .onTapGesture { onClose() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Pull Indicator
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)

                    // Header
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    VStack(spacing: 16) {
                        // Badge
                        Text("SPECIAL OFFER")
                            .font(.system(size: 10, weight: .black))
                            .kerning(2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Colors.accentRed)
                            .cornerRadius(4)

                        // Offer Watermark & Title
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text("PRO")
                                .font(.system(size: 66, weight: .black))
                                .foregroundColor(Colors.accentRed)
                                .italic()
                                .opacity(0.86)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limited")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text("Offer")
                                    .font(.system(size: 44, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            // Slight right shift requested for better visual balance.
                            .offset(x: 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        // Compact Yearly Plan Card
                        VStack(spacing: 10) {
                            HStack {
                                Label("ALARMO PRO", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
                                Spacer()
                                Text(viewModel.offerBadgeText.uppercased())
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Colors.accentGreen)
                                    .cornerRadius(4)
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                if let oldPrice = viewModel.offerOldPriceText, !oldPrice.isEmpty {
                                    Text(oldPrice)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Colors.textTertiary)
                                        .strikethrough()
                                }

                                Text(viewModel.offerPriceText)
                                    .font(.system(size: 34, weight: .black))
                                    .foregroundColor(.white)

                                Text(viewModel.offerPlanName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Colors.textTertiary)

                                Spacer()
                            }

                            HStack(spacing: 6) {
                                Text(viewModel.offerBillingText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)

                                if let trial = viewModel.offerTrialText, !trial.isEmpty {
                                    Text("•")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Colors.textTertiary)

                                    Text(trial)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Colors.accentTeal)
                                }

                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )

                        // CTA Button
                        Button {
                            Task { @MainActor in viewModel.onTapUseCoupon() }
                        } label: {
                            Text("Continue to Pro Options")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    ZStack {
                                        Colors.accentTeal
                                        LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                                    }
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(SquishButtonStyle())
                        .padding(.top, 4)
                        
                        Text("Cancel anytime. Secure checkout.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Colors.textTertiary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80) // Pushed up much more to avoid TabBar
                    .padding(.top, 4)
                }
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.12, blue: 0.20),
                                Color(red: 0.05, green: 0.08, blue: 0.14),
                                Color(red: 0.03, green: 0.06, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Top glow
                        Ellipse()
                            .fill(Colors.accentTeal.opacity(0.14))
                            .frame(width: 300, height: 100)
                            .blur(radius: 40)
                            .offset(y: -150)
                    }
                )
                .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
            }
        }
        .task {
            await viewModel.loadPricingIfNeeded()
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.isExitDiscountDialogPresented)
    }
}

// Reuse existing helper
struct SquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
