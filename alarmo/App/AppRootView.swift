import SwiftUI

struct AppRootView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        OnboardingFlowView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}

#Preview {
    AppRootView()
}
