import Foundation

struct OnboardingState {
    var currentStep: OnboardingStep = .intro
    var selectedHour: Int = AppConstants.defaultHour
    var selectedMinute: Int = AppConstants.defaultMinute
    var notificationsAuthorized = false
    var selectedWallpaper: WallpaperRef?
    var wallpaperCategories: [WallpaperCategory] = []
}
