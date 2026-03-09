import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    let onClose: () -> Void
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            Colors.bgSecondary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.l) {
                    PaywallHeader(onClose: onClose)

                    VStack(spacing: Spacing.s) {
                        LaurelHeader()
                        Text("Unlock the full Pro experience")
                            .bodyText()
                            .foregroundColor(Colors.textSecondary)
                        Text("Plans and trial eligibility are shown at checkout")
                            .screenTitle()
                            .foregroundColor(Colors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.l)

                    VStack(spacing: Spacing.m) {
                        ForEach(viewModel.products) { product in
                            PaywallPlanCard(
                                product: product,
                                isSelected: viewModel.selectedPlan == product.plan
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectPlan(product.plan)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)

                    PrimaryButton(title: "Start Free Trial", style: .blueGlass) {
                        Task { @MainActor in
                            await viewModel.purchaseSelected()
                            if viewModel.alertMessage == nil {
                                onSuccess()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)

                    Button("Restore Purchases") {
                        Task { @MainActor in
                            await viewModel.restorePurchases()
                            if SubscriptionManager.shared.isPro {
                                onSuccess()
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.accentTeal)

                    Text(footerDisclaimerText)
                        .captionText()
                        .foregroundColor(Colors.textSecondary)
                        .padding(.bottom, Spacing.l)
                }
            }
        }
        .task { await viewModel.load() }
        .alert(item: Binding(
            get: { viewModel.alertMessage.map { AlertItem(message: $0) } },
            set: { _ in viewModel.alertMessage = nil }
        )) { item in
            Alert(title: Text("Notice"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var footerDisclaimerText: String {
        guard let selected = viewModel.selectedProduct() else {
            return "Subscription terms shown at checkout."
        }
        if selected.billingPeriodString.isEmpty {
            return selected.trialText ?? "Subscription terms shown at checkout."
        }
        if let trial = selected.trialText {
            return "\(trial), then \(selected.billingPeriodString)"
        }
        return selected.billingPeriodString
    }
}

private struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}

private struct PaywallHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: Spacing.s) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Colors.accentTeal)
                    .padding(6)
                    .background(Colors.bgSecondary)
                    .clipShape(Circle())
                Text("PRO")
                    .bodyText()
                    .foregroundColor(Colors.textPrimary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(Colors.textSecondary)
                    .padding(10)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.l)
    }
}

private struct LaurelHeader: View {
    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "leaf")
            Text("1")
                .font(.system(size: 28, weight: .bold))
            Image(systemName: "leaf")
        }
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(Colors.textPrimary)
        .overlay(
            Text("Trusted by alarm users")
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .offset(y: 24)
        )
        .padding(.top, Spacing.s)
    }
}

private struct PaywallPlanCard: View {
    let product: PaywallProduct
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(isSelected ? Colors.accentTeal : Colors.textTertiary)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.bgSecondary)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(product.displayName)
                            .bodyText()
                            .fontWeight(.semibold)
                            .foregroundColor(Colors.textPrimary)

                        if let trial = product.trialText {
                            Text(trial)
                                .captionText()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(product.isTrialAvailable ? Colors.accentTeal.opacity(0.2) : Colors.bgSecondary)
                                .foregroundColor(product.isTrialAvailable ? Colors.accentTeal : Colors.textSecondary)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        Text(product.priceString)
                            .bodyText()
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                        if !product.billingPeriodString.isEmpty {
                            Text(product.billingPeriodString)
                                .captionText()
                                .foregroundColor(Colors.textSecondary)
                        }
                        if let old = product.oldPriceString {
                            Text(old)
                                .captionText()
                                .foregroundColor(Colors.textSecondary)
                                .strikethrough()
                        }
                    }
                }

                if let badge = product.discountBadgeText, isSelected {
                    Text(badge)
                        .captionText()
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Colors.accentTeal)
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(Spacing.l)
            .background(Colors.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radii.card)
                    .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(Radii.card)
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}
