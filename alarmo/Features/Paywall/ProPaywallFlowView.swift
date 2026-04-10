import SwiftUI
import Combine

enum ProPaywallStep {
    case intro
    case features
    case reminder
    case planSelection
}

enum ProPlanOption: CaseIterable, Identifiable {
    case yearly
    case monthly
    case lifetime

    var id: String { "\(self)" }
}

final class ProPaywallViewModel: ObservableObject {
    @Published var step: ProPaywallStep
    @Published var selectedPlan: ProPlanOption = .yearly

    init(startStep: ProPaywallStep) {
        self.step = startStep
    }
}

struct ProPaywallFlowView: View {
    @StateObject private var viewModel: ProPaywallViewModel
    let onClose: () -> Void

    init(startStep: ProPaywallStep, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: ProPaywallViewModel(startStep: startStep))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Colors.bgSecondary,
                    Colors.bgPrimary
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            switch viewModel.step {
            case .intro:
                ProPaywallIntroView(onClose: onClose) {
                    withAnimation(.easeInOut) { viewModel.step = .features }
                }
            case .features:
                ProPaywallFeaturesView(onClose: onClose) {
                    withAnimation(.easeInOut) { viewModel.step = .reminder }
                }
            case .reminder:
                ProPaywallReminderView(onClose: onClose) {
                    withAnimation(.easeInOut) { viewModel.step = .planSelection }
                }
            case .planSelection:
                ProPaywallPlanSelectionView(
                    onClose: onClose,
                    selectedPlan: $viewModel.selectedPlan
                )
            }
        }
        .transition(.move(edge: .bottom))
    }
}

private struct PaywallHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Colors.accentTeal, Colors.accentBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("PRO")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.l)
    }
}

private struct ProPaywallIntroView: View {
    let onClose: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            PaywallHeader(onClose: onClose)

            Text("One alarm is enough\nwith Alarmo PRO")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .shadow(color: Colors.accentTeal.opacity(0.3), radius: 10, x: 0, y: 4)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.08, blue: 0.12).opacity(0.92),
                                Color(red: 0.06, green: 0.11, blue: 0.17).opacity(0.86),
                                Color(red: 0.03, green: 0.05, blue: 0.09).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                
                VStack(spacing: Spacing.l) {
                    PaywallToggleRow(text: "06:55")
                    PaywallToggleRow(text: "07:10")
                    PaywallToggleRow(text: "07:20")
                    PaywallToggleRow(text: "07:30", isOn: true)
                }
                .padding(24)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Continue", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("Trial availability depends on selected plan")
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .padding(.bottom, Spacing.l)
        }
    }
}

private struct PaywallToggleRow: View {
    let text: String
    var isOn: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text("AM")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isOn ? Colors.accentTeal : .white.opacity(0.4))
                
            Text(text)
                .foregroundColor(isOn ? .white : .white.opacity(0.7))
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .kerning(1.0)
            
            Spacer()
            
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .scaleEffect(1.1)
                .disabled(true)
        }
    }
}

private struct ProPaywallFeaturesView: View {
    let onClose: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PaywallHeader(onClose: onClose)

            Text("Save 30 minutes with\npowerful Pro features")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.l)

            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .foregroundColor(Colors.accentTeal)
                Text("Built for reliable wake-ups")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, Spacing.l)

            ProFeatureTable()
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Continue", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("Plans and trial eligibility shown at checkout")
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.l)
        }
    }
}

private struct ProFeatureTable: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .frame(height: 320)
                .overlay(
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Text("Basic alarm").foregroundColor(.white)
                            Text("Multiple mission  >").foregroundColor(Colors.accentTeal)
                            Text("Wake up check  >").foregroundColor(Colors.accentTeal)
                            Text("Louder alarm").foregroundColor(.white.opacity(0.6))
                            Text("Label reminder").foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        VStack(spacing: Spacing.l) {
                            Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "checkmark.circle.fill")
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.trailing, Spacing.l)

                        VStack(spacing: Spacing.l) {
                            Image(systemName: "checkmark.circle")
                            Image(systemName: "xmark")
                            Image(systemName: "xmark")
                            Image(systemName: "xmark")
                            Image(systemName: "xmark")
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(Spacing.l)
                )

            RoundedRectangle(cornerRadius: 18)
                .fill(Colors.accentBlue.opacity(0.25))
                .frame(width: 110, height: 320)
                .offset(x: -40)
                .overlay(
                    VStack {
                        Text("PRO")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, Spacing.m)
                )
        }
    }
}

private struct ProPaywallReminderView: View {
    let onClose: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PaywallHeader(onClose: onClose)

            Text("You'll be reminded\nbefore renewal")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.l)

            Text("Manage your subscription anytime")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, Spacing.l)

            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: Spacing.m) {
                        Text("🔔 Renewal reminder notifications available")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .background(Colors.accentBlue.opacity(0.4))
                            .clipShape(Capsule())

                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 90)
                            .overlay(Image(systemName: "bell.fill").foregroundColor(.yellow))
                    }
                )
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Continue", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("Plans and trial eligibility shown at checkout")
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.l)
        }
    }
}

private struct ProPaywallPlanSelectionView: View {
    let onClose: () -> Void
    @Binding var selectedPlan: ProPlanOption
    
    @StateObject private var subManager = SubscriptionManager.shared
    @StateObject private var paywallViewModel = PaywallViewModel()
    @State private var showStudentAlert = false
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: Spacing.l) {
            PaywallHeader(onClose: onClose)

            VStack(spacing: Spacing.s) {
                Text("Upgrade to Pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text("Choose your plan")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.l)

            ProPlanCard(
                plan: .yearly,
                product: product(for: .yearly),
                selected: selectedPlan == .yearly
            ) {
                selectedPlan = .yearly
            }
            ProPlanCard(
                plan: .monthly,
                product: product(for: .monthly),
                selected: selectedPlan == .monthly
            ) {
                selectedPlan = .monthly
            }
            ProPlanCard(
                plan: .lifetime,
                product: product(for: .lifetime),
                selected: selectedPlan == .lifetime
            ) {
                selectedPlan = .lifetime
            }

            Button(action: {
                showStudentAlert = true
            }) {
                HStack {
                    Text("🎓 Are you a student?")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, Spacing.l)
            }
            .alert("Student Plan", isPresented: $showStudentAlert) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("Student verification is coming soon in a future update.")
            }
            .padding(.horizontal, Spacing.l)

            Text("Choose the Pro setup\nthat fits your routine")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: isProcessing ? "Processing..." : (selectedPlan == .yearly ? "Start my free week" : "Unlock Pro Now"), style: .blueGlass) {
                Task { @MainActor in
                    isProcessing = true
                    paywallViewModel.selectPlan(selectedPlan.paywallPlan)
                    await paywallViewModel.purchaseSelected()
                    await subManager.refreshEntitlements()
                    isProcessing = false
                    if paywallViewModel.alertMessage == nil && subManager.isPro {
                        onClose()
                    } else if paywallViewModel.alertMessage == nil {
                        paywallViewModel.alertMessage = "Purchase completed. Please tap Restore Purchases if Pro is not unlocked."
                    }
                }
            }
            .disabled(isProcessing)
            .padding(.horizontal, Spacing.l)

            Button("Restore Purchases") {
                Task { @MainActor in
                    await paywallViewModel.restorePurchases()
                    await subManager.refreshEntitlements()
                    if subManager.isPro {
                        onClose()
                    }
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Colors.accentTeal)

            Text(selectedPlanDetailsText)
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .padding(.bottom, Spacing.l)
        }
        .task {
            await paywallViewModel.load()
        }
        .alert("Notice", isPresented: Binding(
            get: { paywallViewModel.alertMessage != nil },
            set: { newValue in
                if !newValue { paywallViewModel.alertMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) { paywallViewModel.alertMessage = nil }
        } message: {
            Text(paywallViewModel.alertMessage ?? "")
        }
    }

    private func product(for option: ProPlanOption) -> PaywallProduct? {
        paywallViewModel.products.first { $0.plan == option.paywallPlan }
    }

    private var selectedPlanDetailsText: String {
        guard let selected = product(for: selectedPlan) else {
            return "Pricing and renewal terms are shown at checkout."
        }
        if let trial = selected.trialText, !trial.isEmpty, !selected.billingPeriodString.isEmpty {
            return "\(trial), then \(selected.billingPeriodString)"
        }
        if !selected.billingPeriodString.isEmpty {
            return selected.billingPeriodString
        }
        if let trial = selected.trialText, !trial.isEmpty {
            return trial
        }
        return "Pricing and renewal terms are shown at checkout."
    }
}

private struct ProPlanCard: View {
    let plan: ProPlanOption
    let product: PaywallProduct?
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(selected ? Colors.accentTeal : Colors.textTertiary)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selected ? .white : Colors.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(planTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    if let trial = product?.trialText, !trial.isEmpty {
                        Text(trial)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(product?.isTrialAvailable == true ? Colors.accentTeal : .white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background((product?.isTrialAvailable == true ? Colors.accentTeal.opacity(0.2) : Color.white.opacity(0.08)))
                            .clipShape(Capsule())
                    } else if plan == .lifetime {
                        Text("Pay once, use forever")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(planPrice)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    if !planSubprice.isEmpty {
                        Text(planSubprice)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    if let oldPrice = product?.oldPriceString, !oldPrice.isEmpty {
                        Text(oldPrice)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .strikethrough()
                    }
                }
            }
            .padding(Spacing.l)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Colors.accentTeal : Colors.cardStroke, lineWidth: selected ? 2 : 1)
            )
            .cornerRadius(20)
        }
        .buttonStyle(PressedScaleButtonStyle())
        .padding(.horizontal, Spacing.l)
    }

    private var planTitle: String {
        if let name = product?.displayName, !name.isEmpty {
            return name
        }
        switch plan {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    private var planPrice: String {
        if let price = product?.priceString, !price.isEmpty {
            return price
        }
        return "Price at checkout"
    }

    private var planSubprice: String {
        product?.billingPeriodString ?? ""
    }
}

private extension ProPlanOption {
    var paywallPlan: PaywallPlan {
        switch self {
        case .yearly: return .yearly
        case .monthly: return .monthly
        case .lifetime: return .lifetime
        }
    }
}
