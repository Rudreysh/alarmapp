import SwiftUI

struct OnboardingContentFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func onboardingContentFrame() -> some View {
        modifier(OnboardingContentFrame())
    }
}
