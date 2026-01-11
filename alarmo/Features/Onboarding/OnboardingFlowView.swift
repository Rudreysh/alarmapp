import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingIntroView {
                withAnimation(.easeInOut) {
                    viewModel.nextStep()
                    path.append(.setTime)
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .setTime:
                    OnboardingSetTimeView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.step3Stub)
                        }
                    }
                case .step3Stub:
                    OnboardingStep3StubView()
                case .intro:
                    EmptyView()
                }
            }
        }
        .tint(Colors.accentRed)
    }
}
