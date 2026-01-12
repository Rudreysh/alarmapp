import SwiftUI

struct DiscountPaywallView: View {
    @StateObject private var viewModel: DiscountPaywallViewModel
    let onClose: () -> Void
    let onApply: () -> Void

    init(preferences: AppPreferencesProtocol, onClose: @escaping () -> Void, onApply: @escaping () -> Void) {
        self.onClose = onClose
        self.onApply = onApply
        let model = DiscountPaywallViewModel(preferences: preferences)
        model.onRequestDismissPaywall = onClose
        _viewModel = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Colors.bgPrimary.opacity(0.6)
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack {
                    Spacer()
                    BottomSheetContainer {
                        HStack {
                            Spacer()
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(8)
                            }
                        }

                        Text("New user exclusive")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.pillGreen)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Colors.pillGreen.opacity(0.2))
                            .clipShape(Capsule())
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 6) {
                            Text("Only now")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("50% Off")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, Spacing.s)

                        DiscountPlanCard()
                            .padding(.top, Spacing.m)

                        PrimaryButton(title: "Use 50% off coupon") {
                            Task { @MainActor in
                                viewModel.onTapUseCoupon()
                            }
                        }
                        .padding(.top, Spacing.l)
                    }
                    .frame(height: proxy.size.height * 0.44)
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.l)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if viewModel.isExitDiscountDialogPresented {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    ExitDiscountDialogView(
                        titleText: "Your discount will be lost if\nyou exit....",
                        onExit: {
                            Task { @MainActor in
                                viewModel.onConfirmExitDiscount()
                            }
                        },
                        onGetOffer: {
                            Task { @MainActor in
                                viewModel.onConfirmGetOffer()
                            }
                        }
                    )
                    .offset(y: -120)
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
            }
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.18), value: viewModel.isExitDiscountDialogPresented)
        .onChange(of: viewModel.toastMessage) { message in
            guard message != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                viewModel.toastMessage = nil
            }
        }
        .overlay(alignment: .top) {
            if let message = viewModel.toastMessage {
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
                    .padding(.top, Spacing.l)
            }
        }
    }
}

private struct DiscountPlanCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Radii.card)
                .fill(Color(red: 0.10, green: 0.13, blue: 0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.card)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: Spacing.m) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Colors.saleBadgeStart, Colors.saleBadgeEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    VStack(spacing: 2) {
                        Text("Sale")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("50%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("PRO Yearly plan")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    Text("₹ 235.00 /year")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("₹ 828.00 (Monthly plan 12...)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .strikethrough()
                }

                Spacer()
            }
            .padding(Spacing.m)
        }
    }
}
