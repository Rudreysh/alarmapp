import SwiftUI

struct DiscountPaywallView: View {
    @StateObject private var viewModel: DiscountPaywallViewModel
    let preferences: AppPreferencesProtocol
    let onSkip: () -> Void
    let onApply: () -> Void

    init(preferences: AppPreferencesProtocol, onSkip: @escaping () -> Void, onApply: @escaping () -> Void, onGetOffer: @escaping () -> Void, onSuccess: @escaping () -> Void) {
        self.preferences = preferences
        self.onSkip = onSkip
        self.onApply = onApply
        let model = DiscountPaywallViewModel(preferences: preferences)
        model.onRequestDismissPaywall = onSkip
        model.onRequestGetOffer = onGetOffer
        model.onPurchaseSucceeded = onSuccess
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
            .onTapGesture { onSkip() }

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
                        Button(action: onSkip) {
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
                            HStack(alignment: .top) {
                                Label("ALARMO PRO", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    if viewModel.showDiscountBadge {
                                        Text("50% OFF")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Colors.accentRed)
                                            .clipShape(Capsule())
                                    }
                                    Text(viewModel.offerBadgeText.uppercased())
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Colors.accentGreen)
                                        .cornerRadius(4)
                                }
                            }

                            HStack(alignment: .bottom, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let oldPrice = viewModel.offerOldPriceText, !oldPrice.isEmpty {
                                        Text(oldPrice)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Colors.textTertiary)
                                            .strikethrough()
                                            .lineLimit(1)
                                    }

                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(priceAmount(from: viewModel.offerPriceText))
                                            .font(.system(size: 24, weight: .black))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.78)
                                        if let suffix = pricePeriodSuffix(from: viewModel.offerPriceText) {
                                            Text(suffix)
                                                .font(.system(size: 20, weight: .heavy))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: 8)

                                Text(viewModel.offerPlanName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Colors.textTertiary)
                                    .lineLimit(1)
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

                        if viewModel.showDiscountBadge {
                            Text("Save 50% on your first year")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Colors.accentTeal)
                                .padding(.top, 4)
                        }

                        // CTA Button
                        Button {
                            Task { @MainActor in
                                preferences.hasSeenDiscountExitDialog = true
                                await viewModel.purchaseOffer()
                            }
                        } label: {
                            Text(viewModel.showDiscountBadge ? "Claim 50% Off" : "Start 7-Day Free Trial")
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

private extension DiscountPaywallView {
    func priceAmount(from text: String) -> String {
        if let slashIndex = text.firstIndex(of: "/") {
            return String(text[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func pricePeriodSuffix(from text: String) -> String? {
        guard let slashIndex = text.firstIndex(of: "/") else { return nil }
        let suffix = String(text[slashIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return suffix.isEmpty ? nil : suffix.lowercased()
    }
}
