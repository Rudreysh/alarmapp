import Foundation

/// What the user says is the core thing that wrecks their mornings. The
/// `scrolling` case bridges into the app-blocking pillar (turns on
/// block-after-wake by default).
enum MorningProblem: String, CaseIterable, Codable {
    case sleepThrough
    case snooze
    case scrolling
    case stayInBed
    case tired
}

/// How hard the user wants it to be to silence the alarm. Drives mission
/// difficulty and the snooze cap.
enum AlarmDifficulty: String, CaseIterable, Codable {
    case easy
    case medium
    case hard
    case extreme
}

/// When distracting apps catch the user — used to suggest a blocking schedule.
enum AppsWhenContext: String, CaseIterable, Codable {
    case afterWaking
    case beforeSleep
    case work
    case boredStressed
    case wheneverUnlock
}

/// When Alarmo should block the chosen apps.
enum BlockingSchedule: String, CaseIterable, Codable {
    case afterAlarmUntilMission   // default / recommended
    case focusTime
    case beforeSleep
    case customLater
}

struct OnboardingState {
    var currentStep: OnboardingStep = .intro
    var firstName: String = ""
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
    var selectedQuoteCategoryIDs: Set<String> = ["all"]
    var gentleWakeUpEnabled = true
    var missionType: WakeUpMissionType = .off
    var dailyMotivationEnabled: Bool = false
    var onboardingCompleted = false

    // MARK: - Redesign answers (drive personalization + safe feature defaults)
    var morningProblem: MorningProblem?
    var alarmDifficulty: AlarmDifficulty?
    var appsWhen: AppsWhenContext?
    /// Self-estimated daily screen hours (0…8, where 8 means "8+").
    var dailyScreenHours: Double = 4
    /// Friendly category IDs the user wants blocked (maps to
    /// `MockActivityPickerSheet.categories` ids, e.g. "social", "entertainment").
    var blockedCategoryIDs: Set<String> = []
    var blockAdultContent: Bool = false
    var blockingSchedule: BlockingSchedule = .afterAlarmUntilMission
}
