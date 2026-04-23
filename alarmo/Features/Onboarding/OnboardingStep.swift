import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case wallpaper = 3
    case wallpaperPreview = 4
    case notifications = 5
    case alarmPermission = 6
    case screenTimeAccess = 7
    case motionAccess = 8
    case liveActivities = 9
    case healthAccess = 10
    case soundSelection = 11
    case soundVolume = 12
    case missionStub = 13
    case trackingExplainer = 14
    case paywall = 15

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
