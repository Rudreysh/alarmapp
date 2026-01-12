import SwiftUI

struct AppRootView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var appPreferences = AppPreferences()

    var body: some View {
        Group {
            if !appPreferences.devAlwaysShowOnboarding && appPreferences.onboardingCompleted {
                MainTabContainerView(preferences: appPreferences)
            } else {
                OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
}
