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
                    Color(red: 0.05, green: 0.12, blue: 0.24),
                    Color(red: 0.03, green: 0.08, blue: 0.16),
                    Color(red: 0.02, green: 0.04, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
                Image(systemName: "bolt.fill")
                    .foregroundColor(Colors.accentTeal)
                Text("PRO")
                    .font(.system(size: 16, weight: .semibold))
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

            Text("One alarm is enough\nwith Alarmy Pro")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)

            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .frame(height: 260)
                .overlay(
                    VStack(spacing: Spacing.m) {
                        PaywallToggleRow(text: "am 6:55")
                        PaywallToggleRow(text: "am 7:10")
                        PaywallToggleRow(text: "am 7:20")
                        PaywallToggleRow(text: "am 7:30", isOn: true)
                    }
                    .padding()
                )
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Try for $0", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("No charge until trial ends")
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
        HStack {
            Text(text)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Capsule()
                .fill(isOn ? Colors.accentTeal : Color.white.opacity(0.2))
                .frame(width: 44, height: 24)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .offset(x: isOn ? 10 : -10)
                )
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
                Text("100M+ wake up data analyzed")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, Spacing.l)

            ProFeatureTable()
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Start my free week", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("No charge until trial ends")
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

            Text("You'll be notified\n2 days before trial ends")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.l)

            Text("No worries on auto-renewal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, Spacing.l)

            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: Spacing.m) {
                        Text("🔔 We'll remind you on 17 Jan")
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

            PrimaryButton(title: "Start my free week", style: .blueGlass) {
                onNext()
            }
            .padding(.horizontal, Spacing.l)

            Text("No charge until trial ends")
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

    var body: some View {
        VStack(spacing: Spacing.l) {
            PaywallHeader(onClose: onClose)

            VStack(spacing: Spacing.s) {
                Text("#1 Ranked alarm app in 97 countries")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text("Start your 7-day\nFree trial for Pro")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.l)

            ProPlanCard(plan: .yearly, selected: selectedPlan == .yearly) {
                selectedPlan = .yearly
            }
            ProPlanCard(plan: .monthly, selected: selectedPlan == .monthly) {
                selectedPlan = .monthly
            }
            ProPlanCard(plan: .lifetime, selected: selectedPlan == .lifetime) {
                selectedPlan = .lifetime
            }

            HStack {
                Text("🎓 Are you a student?")
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, Spacing.l)

            Text("Experience the Life\n50 Million Users Are Enjoying\nfor Yourself")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)

            Spacer()

            PrimaryButton(title: "Start my free week", style: .blueGlass) {
                // Stub: implement purchase later
            }
            .padding(.horizontal, Spacing.l)

            Text("Automatic payment after free trial ends (in 7 days)")
                .captionText()
                .foregroundColor(Colors.textSecondary)
                .padding(.bottom, Spacing.l)
        }
    }
}

private struct ProPlanCard: View {
    let plan: ProPlanOption
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
                    if plan == .yearly {
                        Text("7-day free trial")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Colors.accentTeal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Colors.accentTeal.opacity(0.2))
                            .clipShape(Capsule())
                    } else if plan == .monthly {
                        Text("No free trial included")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
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
                    if plan == .yearly {
                        Text("₹ 828.00")
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
        switch plan {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    private var planPrice: String {
        switch plan {
        case .yearly: return "₹ 39.08 /month"
        case .monthly: return "₹ 69.00 /month"
        case .lifetime: return "₹ 1,129.00"
        }
    }

    private var planSubprice: String {
        switch plan {
        case .yearly: return "₹ 469.00 /year"
        case .monthly: return "₹ 828.00 /year"
        case .lifetime: return ""
        }
    }
}
