import Foundation

struct OnboardingState {
    var currentStep: OnboardingStep = .intro
    var selectedHour: Int = AppConstants.defaultHour
    var selectedMinute: Int = AppConstants.defaultMinute
    var selectedSecond: Int = AppConstants.defaultSecond
    var notificationsAuthorized = false
    var selectedWallpaper: WallpaperRef?
    var wallpaperCategories: [WallpaperCategory] = []
    var selectedSoundId: String?
    var selectedSoundURL: URL?
    var selectedSoundName: String?
    var selectedVolume: Float = 0.95
    var gentleWakeUpEnabled = true
    var missionType: WakeUpMissionType = .off
    var dailyMotivationEnabled: Bool = false
    var onboardingCompleted = false
}
