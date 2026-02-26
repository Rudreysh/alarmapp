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
            // Background
            Color.black.opacity(0.8)
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
                        Text("FLASH SALE")
                            .font(.system(size: 10, weight: .black))
                            .kerning(2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Colors.accentRed)
                            .cornerRadius(4)

                        // 50% Watermark & Title
                        HStack(spacing: -5) {
                            Text("50%")
                                .font(.system(size: 70, weight: .black))
                                .foregroundColor(Colors.accentRed)
                                .italic()
                                .opacity(0.8)
                            
                            VStack(alignment: .leading, spacing: -6) {
                                Text("Limited")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Colors.textSecondary)
                                Text("Offer")
                                    .font(.system(size: 38, weight: .black))
                                    .foregroundColor(.white)
                            }
                        }

                        // Compact Yearly Plan Card
                        VStack(spacing: 10) {
                            HStack {
                                Label("ALMOE PRO", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
                                Spacer()
                                Text("-72%")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Colors.accentGreen)
                                    .cornerRadius(4)
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text("₹235")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                
                                Text("₹828")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Colors.textTertiary)
                                    .strikethrough()
                                
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
                            Text("Unlock 50% Off Now")
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
                        Color(red: 0.07, green: 0.08, blue: 0.1)
                        
                        // Top glow
                        Ellipse()
                            .fill(Colors.accentRed.opacity(0.08))
                            .frame(width: 300, height: 100)
                            .blur(radius: 40)
                            .offset(y: -150)
                    }
                )
                .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
            }
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
