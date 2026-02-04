import SwiftUI

struct OnboardingSetTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ProgressHeader(step: 1, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

                Text("Set your alarm time")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.m)

                TimeWheelPickerView(
                    hour: Binding(
                        get: { viewModel.selectedHour },
                        set: { viewModel.selectedHour = $0 }
                    ),
                    minute: Binding(
                        get: { viewModel.selectedMinute },
                        set: { viewModel.selectedMinute = $0 }
                    ),
                    second: Binding(
                        get: { viewModel.selectedSecond },
                        set: { viewModel.selectedSecond = $0 }
                    )
                )

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }
}
