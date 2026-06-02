import Foundation

enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case namePrompt = 2
    case nameWelcome = 3
    case chronotypeQuestion = 4
    case struggleQuestion = 5
    case wakeLateImpactQuestion = 6
    case wakeFeelQuestion = 7
    case morningHardestQuestion = 8
    case halfAsleepQuestion = 9
    case snoozeCountQuestion = 10
    case snoozeAgeQuestion = 11
    case snoozeDailyDrain = 12
    case snoozeYearGrid = 13
    case snoozeLifetimeTotal = 14
    case snoozePayoff = 15
    case setTime = 16
    case wallpaper = 17
    case quoteCategories = 18
    case wallpaperPreview = 19
    case notifications = 20
    case alarmPermission = 21
    case screenTimeAccess = 22
    case motionAccess = 23
    case cameraAccess = 24
    case liveActivities = 25
    case healthAccess = 26
    case soundSelection = 27
    case soundVolume = 28
    case missionStub = 29
    case trackingExplainer = 30
    case paywall = 31

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }
}
