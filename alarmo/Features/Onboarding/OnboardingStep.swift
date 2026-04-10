import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case wallpaper = 3
    case wallpaperPreview = 4
    case notifications = 5
    case screenTimeAccess = 6
    case motionAccess = 7
    case liveActivities = 8
    case healthAccess = 9
    case soundSelection = 10
    case soundVolume = 11
    case missionStub = 12
    case trackingExplainer = 13
    case paywall = 14

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
