import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case setTime = 2
    case wallpaper = 3
    case quoteCategories = 4
    case wallpaperPreview = 5
    case notifications = 6
    case alarmPermission = 7
    case screenTimeAccess = 8
    case motionAccess = 9
    case cameraAccess = 10
    case liveActivities = 11
    case healthAccess = 12
    case soundSelection = 13
    case soundVolume = 14
    case missionStub = 15
    case trackingExplainer = 16
    case paywall = 17

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
