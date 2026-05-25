import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case namePrompt = 2
    case chronotypeQuestion = 3
    case struggleQuestion = 4
    case wakeLateImpactQuestion = 5
    case wakeFeelQuestion = 6
    case morningHardestQuestion = 7
    case halfAsleepQuestion = 8
    case snoozeCountQuestion = 9
    case snoozeAgeQuestion = 10
    case snoozeDailyDrain = 11
    case snoozeYearGrid = 12
    case snoozeLifetimeTotal = 13
    case snoozePayoff = 14
    case setTime = 15
    case wallpaper = 16
    case quoteCategories = 17
    case wallpaperPreview = 18
    case notifications = 19
    case alarmPermission = 20
    case screenTimeAccess = 21
    case motionAccess = 22
    case cameraAccess = 23
    case liveActivities = 24
    case healthAccess = 25
    case soundSelection = 26
    case soundVolume = 27
    case missionStub = 28
    case trackingExplainer = 29
    case paywall = 30

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
