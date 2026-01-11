import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case step3Stub = 3

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
