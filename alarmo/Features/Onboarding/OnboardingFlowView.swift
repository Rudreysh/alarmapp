import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @ObservedObject var appPreferences: AppPreferences
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
                            path.append(.soundSelection)
                        }
                    }
                case .soundSelection:
                    OnboardingSoundSelectionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.soundVolume)
                        }
                    }
                case .soundVolume:
                    OnboardingVolumeSettingsView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            viewModel.nextStep()
                            path.append(.missionStub)
                        }
                    }
                case .missionStub:
                    OnboardingMissionView(onboardingViewModel: viewModel) {
                        withAnimation(.easeInOut) {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                            viewModel.setStep(.soundVolume)
                        }
                    } onDone: {
                        withAnimation(.easeInOut) {
                            path.append(.trackingExplainer)
                        }
                    }
                case .trackingExplainer:
                    TrackingExplainerView {
                        withAnimation(.easeInOut) {
                            path.append(.paywall)
                        }
                    }
                case .paywall:
                    PaywallView(onClose: {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingCompleted = true
                            viewModel.completeOnboarding()
                            path.removeAll()
                            path.append(.home)
                        }
                    }, onSuccess: {
                        withAnimation(.easeInOut) {
                            appPreferences.onboardingCompleted = true
                            viewModel.completeOnboarding()
                            path.removeAll()
                            path.append(.home)
                        }
                    })
                case .intro:
                    EmptyView()
                case .home:
                    MainTabContainerView(preferences: appPreferences)
                }
            }
        }
        .tint(Colors.accentRed)
    }
}
