import SwiftUI

struct OnboardingMissionView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var viewModel: OnboardingMissionViewModel
    let onBack: () -> Void
    let onDone: () -> Void

    init(onboardingViewModel: OnboardingViewModel, onBack: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.onboardingViewModel = onboardingViewModel
        self._viewModel = StateObject(wrappedValue: OnboardingMissionViewModel(onboardingViewModel: onboardingViewModel))
        self.onBack = onBack
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Colors.bgSecondary.opacity(0.6))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                ProgressHeader(step: 4, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)

                Text("Choose a wake-\nup mission")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: Spacing.m) {
                    ForEach(viewModel.options) { option in
                        MissionRowView(option: option, isSelected: viewModel.selected == option.id) {
                            viewModel.select(option)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Done", style: .blueGlass) {
                    onboardingViewModel.completeOnboarding()
                    onDone()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}
