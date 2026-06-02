import SwiftUI

enum OnboardingMascotFlightCoordinateSpace {
    static let name = "onboardingMascotFlight"
}

struct OnboardingWelcomeMascotFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

struct OnboardingQuestionMascotFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

private struct OnboardingQuestionMascotHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingQuestionMascotHidden: Bool {
        get { self[OnboardingQuestionMascotHiddenKey.self] }
        set { self[OnboardingQuestionMascotHiddenKey.self] = newValue }
    }
}
