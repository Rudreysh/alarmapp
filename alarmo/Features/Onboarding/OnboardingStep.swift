import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case permissions = 3
    case wallpaper = 4
    case wallpaperPreview = 5
    case soundSelection = 6
    case soundVolume = 7
    case missionStub = 8
    case trackingExplainer = 9
    case paywall = 10
    case home = 11

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
