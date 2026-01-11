import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case permissions = 3
    case wallpaper = 4
    case wallpaperPreview = 5
    case soundStub = 6

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
