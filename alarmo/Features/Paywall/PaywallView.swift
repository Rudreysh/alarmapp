import SwiftUI
import Combine

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @State private var showAllPlans = false
    let onClose: () -> Void
    let onSuccess: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Colors.bgSecondary, Colors.bgPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.l) {
                    PaywallHeader(onClose: onClose)

                    VStack(spacing: Spacing.s) {
                        PaywallFeatureCarousel()
                        Text("Unlock the full Pro experience")
                            .bodyText()
                            .foregroundColor(Colors.textSecondary)
                        Text("Choose your plan")
                            .screenTitle()
                            .foregroundColor(Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Plans and trial eligibility are shown at checkout")
                            .captionText()
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Spacing.l)

                    VStack(spacing: 10) {
                        ForEach(displayProducts) { product in
                            PaywallPlanCard(
                                product: product,
                                isSelected: viewModel.selectedPlan == product.plan
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectPlan(product.plan)
                                }
                            }
                        }

                        if hasHiddenPlans {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAllPlans = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("More plans")
                                        .font(.system(size: 13, weight: .semibold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
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
        .onChange(of: viewModel.selectedPlan) { _, newPlan in
            if newPlan == .lifetime && !showAllPlans {
                showAllPlans = true
            }
        }
        .alert(item: Binding(
            get: { viewModel.alertMessage.map { AlertItem(message: $0) } },
            set: { _ in viewModel.alertMessage = nil }
        )) { item in
            Alert(title: Text("Notice"), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private var sortedProducts: [PaywallProduct] {
        viewModel.products.sorted { planSortIndex($0.plan) < planSortIndex($1.plan) }
    }

    private var displayProducts: [PaywallProduct] {
        if showAllPlans {
            return sortedProducts
        }
        return sortedProducts.filter { $0.plan != .lifetime }
    }

    private var hasHiddenPlans: Bool {
        !showAllPlans && sortedProducts.contains(where: { $0.plan == .lifetime })
    }

    private func planSortIndex(_ plan: PaywallPlan) -> Int {
        switch plan {
        case .yearly: return 0
        case .monthly: return 1
        case .lifetime: return 2
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

private struct PaywallFeatureSlide: Identifiable {
    let id = UUID()
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
    let illustration: String
}

private struct PaywallFeatureCarousel: View {
    @State private var selectedIndex = 0
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    private let slides: [PaywallFeatureSlide] = [
        PaywallFeatureSlide(
            icon: "timer",
            accent: Colors.accentTeal,
            title: "Pomodoro focus",
            subtitle: "Deep work sessions with structure and rhythm.",
            illustration: "gauge.with.dots.needle.67percent"
        ),
        PaywallFeatureSlide(
            icon: "shield.lefthalf.filled",
            accent: Colors.accentOrange,
            title: "App blocking",
            subtitle: "Block distractions and stay locked in on goals.",
            illustration: "lock.shield.fill"
        ),
        PaywallFeatureSlide(
            icon: "alarm.fill",
            accent: Colors.accentRed,
            title: "Alarms + habits",
            subtitle: "Wake-up missions and streak tracking in one flow.",
            illustration: "checkmark.seal.fill"
        ),
        PaywallFeatureSlide(
            icon: "globe.americas.fill",
            accent: Colors.accentBlue,
            title: "Time overlap",
            subtitle: "Find the best shared time across global time zones.",
            illustration: "clock.badge.checkmark.fill"
        )
    ]

    var body: some View {
        VStack(spacing: Spacing.m) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    PaywallFeatureCard(slide: slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 252)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedIndex = (selectedIndex + 1) % slides.count
                }
            }

            HStack(spacing: Spacing.s) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedIndex ? Colors.textPrimary : Colors.textTertiary)
                        .frame(width: index == selectedIndex ? 24 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct PaywallFeatureCard: View {
    let slide: PaywallFeatureSlide

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 370
            let titleSize: CGFloat = compact ? 26 : 33
            let subtitleSize: CGFloat = compact ? 14 : 16
            let iconCircleSize: CGFloat = compact ? 48 : 54
            let iconSize: CGFloat = compact ? 21 : 24
            let illustrationCircleSize: CGFloat = compact ? 106 : 132
            let illustrationSize: CGFloat = compact ? 44 : 58

            ZStack {
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Colors.cardSurface.opacity(0.96),
                                Colors.bgSecondary.opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                    .stroke(Colors.cardStroke, lineWidth: 1)

                HStack(spacing: compact ? Spacing.s : Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        ZStack {
                            Circle()
                                .fill(slide.accent.opacity(0.20))
                                .frame(width: iconCircleSize, height: iconCircleSize)
                            Image(systemName: slide.icon)
                                .font(.system(size: iconSize, weight: .bold))
                                .foregroundColor(slide.accent)
                        }

                        Text(slide.title)
                            .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .lineLimit(compact ? 3 : 2)
                            .minimumScaleFactor(0.58)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(2)

                        Text(slide.subtitle)
                            .font(.system(size: subtitleSize, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(compact ? 4 : 3)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Circle()
                            .fill(slide.accent.opacity(0.16))
                            .frame(width: illustrationCircleSize, height: illustrationCircleSize)
                        Image(systemName: slide.illustration)
                            .font(.system(size: illustrationSize, weight: .semibold))
                            .foregroundColor(slide.accent)
                    }
                }
                .padding(Spacing.l)
            }
        }
        .shadow(color: Colors.shadow.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

private struct PaywallPlanCard: View {
    let product: PaywallProduct
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(isSelected ? Colors.accentTeal : Colors.textTertiary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isSelected ? Colors.textPrimary : Colors.bgSecondary)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .fontWeight(.semibold)
                            .foregroundColor(Colors.textPrimary)
                            .lineLimit(1)

                        if let trial = product.trialText {
                            Text(trial)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(product.isTrialAvailable ? Colors.accentTeal.opacity(0.2) : Colors.bgSecondary)
                                .foregroundColor(product.isTrialAvailable ? Colors.accentTeal : Colors.textSecondary)
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.priceString)
                            .font(.system(size: 16, weight: .bold))
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if !product.billingPeriodString.isEmpty {
                            Text(product.billingPeriodString)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                                .lineLimit(1)
                        }
                        if let old = product.oldPriceString {
                            Text(old)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                                .strikethrough()
                                .lineLimit(1)
                        }
                    }
                }

                if let badge = product.discountBadgeText, isSelected {
                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Colors.accentTeal)
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
