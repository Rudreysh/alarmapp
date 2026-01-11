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
                            path.append(.permissions)
                        }
                    }
                case .permissions:
                    OnboardingPermissionsView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            path.append(.wallpaper)
                        }
                    }
                case .wallpaper:
                    OnboardingWallpaperSelectionView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.wallpaperPreview)
                        }
                    }
                case .wallpaperPreview:
                    OnboardingWallpaperPreviewView(viewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                            viewModel.setStep(.wallpaper)
                        }
                    } onSelect: {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.soundStub)
                        }
                    }
                case .soundStub:
                    OnboardingSoundStubView()
                case .intro:
                    EmptyView()
                }
            }
        }
        .tint(Colors.accentRed)
    }
}
