import Foundation
import Combine

protocol AppPreferencesProtocol: AnyObject {
    var onboardingCompleted: Bool { get set }
    var forceShowOnboardingNextLaunch: Bool { get set }
    var hasShownFirstHomeDiscountFlow: Bool { get set }
    var hasTappedRemoveAdsBefore: Bool { get set }
    var hasSeenPaywallAtLeastOnce: Bool { get set }
    var devAlwaysShowUpsell: Bool { get set }
    var devAlwaysShowOnboarding: Bool { get set }
    var hasSeenDiscountExitDialog: Bool { get set }
    var hasTappedGetOfferFromDiscount: Bool { get set }
    var hasAnyAlarm: Bool { get set }
    var hasSeenAddAlarmTooltip: Bool { get set }
    var hasSeenTimerTooltip: Bool { get set }
    var hasSeenPlanTooltip: Bool { get set }
    var hasSeenOverlapTooltip: Bool { get set }
    var hasSeenEditAlarmTooltip: Bool { get set }
    var hasSeenQuickLogTooltip: Bool { get set }
    var hasSeenTimerMusicTooltip: Bool { get set }
    var hasSeenOverlapTimeTravelTooltip: Bool { get set }
    var hasSeenHomeQuickSettingsTooltip: Bool { get set }
    var hasSeenHomeToggleTooltip: Bool { get set }
    var hasSeenHomeActionsTooltip: Bool { get set }
    var hasSeenHomeDeleteTooltip: Bool { get set }
    var hasSeenEditAlarmTimeTooltip: Bool { get set }
    var hasSeenEditAlarmNavTooltip: Bool { get set }
    var hasSeenEditAlarmNameTooltip: Bool { get set }
    var hasSeenEditAlarmMissionTooltip: Bool { get set }
    var hasSeenEditAlarmTimezoneTooltip: Bool { get set }
    var hasSeenEditAlarmToggleTooltip: Bool { get set }
    var hasSeenEditAlarmActionsTooltip: Bool { get set }
    var hasSeenTimerTimeIntegerTooltip: Bool { get set }
    var hasSeenTimerCircleTooltip: Bool { get set }
    var hasSeenTimerIntervalTooltip: Bool { get set }
    var hasSeenTimerBlockListTooltip: Bool { get set }
    var hasSeenTimerStartTooltip: Bool { get set }
    var timerFlipStartEnabled: Bool { get set }
    var timerStrictModeEnabled: Bool { get set }
    var timerOLEDAntiBurnInEnabled: Bool { get set }
    // Plan
    var hasSeenPlanFabTooltip: Bool { get set }
    var hasSeenPlanHabitVsTaskTooltip: Bool { get set }
    var hasSeenPlanSwipeTooltip: Bool { get set }
    var hasSeenPlanCalendarTooltip: Bool { get set }
    // Overlap
    var hasSeenOverlapAddCityTooltip: Bool { get set }
    var hasSeenOverlapAnalysisTooltip: Bool { get set }
    var hasSeenOverlapContextMenuTooltip: Bool { get set }
    var onboardingAlarmHour: Int { get set }
    var onboardingAlarmMinute: Int { get set }
    var onboardingAlarmSecond: Int { get set }
    var onboardingAlarmEnabled: Bool { get set }
    var onboardingRepeatMask: Int { get set }
    var onboardingSoundName: String { get set }
    var onboardingSoundVolume: Float { get set }
    var onboardingWallpaperId: String { get set }
    
    // Focus Settings
    var pomoDurationMinutes: Int { get set }
    var shortBreakMinutes: Int { get set }
    var longBreakMinutes: Int { get set }
    var pomosPerLongBreak: Int { get set }
    var autoStartNextPomo: Bool { get set }
    var autoStartBreak: Bool { get set }
    var autoPomoCycle: Int { get set }
    var pomoEndingSoundName: String { get set }
    var ambientSoundName: String { get set }
    var breakEndingSoundName: String { get set }
    var vibrationDurationSeconds: Int { get set }
    var stopwatchSoundName: String { get set }
    var stopwatchVibrationSeconds: Int { get set }
    
    // Focus Accountability
    var focusEnforcementMode: EnforcementMode { get set }
    var focusBlockAppsEnabled: Bool { get set }
    var focusPenaltyEnabled: Bool { get set }
    var focusPenaltyAmountEuro: Int { get set }
}

final class AppPreferences: ObservableObject, AppPreferencesProtocol {
    private static let defaultAlarmSoundName = "Cockpit Alert"

    @Published var onboardingCompleted: Bool { 
        didSet { 
            defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted)
            print("[AppPreferences] onboardingCompleted changed to: \(onboardingCompleted)")
        } 
    }
    @Published var forceShowOnboardingNextLaunch: Bool { didSet { defaults.set(forceShowOnboardingNextLaunch, forKey: Keys.forceShowOnboardingNextLaunch) } }
    @Published var hasShownFirstHomeDiscountFlow: Bool { didSet { defaults.set(hasShownFirstHomeDiscountFlow, forKey: Keys.hasShownFirstHomeDiscountFlow) } }
    @Published var hasTappedRemoveAdsBefore: Bool { didSet { defaults.set(hasTappedRemoveAdsBefore, forKey: Keys.hasTappedRemoveAdsBefore) } }
    @Published var hasSeenPaywallAtLeastOnce: Bool { didSet { defaults.set(hasSeenPaywallAtLeastOnce, forKey: Keys.hasSeenPaywallAtLeastOnce) } }
    @Published var devAlwaysShowUpsell: Bool { didSet { defaults.set(devAlwaysShowUpsell, forKey: Keys.devAlwaysShowUpsell) } }
    @Published var devAlwaysShowOnboarding: Bool { didSet { defaults.set(devAlwaysShowOnboarding, forKey: Keys.devAlwaysShowOnboarding) } }
    @Published var hasSeenDiscountExitDialog: Bool { didSet { defaults.set(hasSeenDiscountExitDialog, forKey: Keys.hasSeenDiscountExitDialog) } }
    @Published var hasTappedGetOfferFromDiscount: Bool { didSet { defaults.set(hasTappedGetOfferFromDiscount, forKey: Keys.hasTappedGetOfferFromDiscount) } }
    @Published var hasAnyAlarm: Bool { didSet { defaults.set(hasAnyAlarm, forKey: Keys.hasAnyAlarm) } }
    @Published var hasSeenAddAlarmTooltip: Bool { didSet { defaults.set(hasSeenAddAlarmTooltip, forKey: Keys.hasSeenAddAlarmTooltip) } }
    @Published var hasSeenTimerTooltip: Bool { didSet { defaults.set(hasSeenTimerTooltip, forKey: Keys.hasSeenTimerTooltip) } }
    @Published var hasSeenPlanTooltip: Bool { didSet { defaults.set(hasSeenPlanTooltip, forKey: Keys.hasSeenPlanTooltip) } }
    @Published var hasSeenOverlapTooltip: Bool { didSet { defaults.set(hasSeenOverlapTooltip, forKey: Keys.hasSeenOverlapTooltip) } }
    @Published var hasSeenEditAlarmTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmTooltip, forKey: Keys.hasSeenEditAlarmTooltip) } }
    @Published var hasSeenQuickLogTooltip: Bool { didSet { defaults.set(hasSeenQuickLogTooltip, forKey: Keys.hasSeenQuickLogTooltip) } }
    @Published var hasSeenTimerMusicTooltip: Bool { didSet { defaults.set(hasSeenTimerMusicTooltip, forKey: Keys.hasSeenTimerMusicTooltip) } }
    @Published var hasSeenOverlapTimeTravelTooltip: Bool { didSet { defaults.set(hasSeenOverlapTimeTravelTooltip, forKey: Keys.hasSeenOverlapTimeTravelTooltip) } }
    @Published var hasSeenHomeQuickSettingsTooltip: Bool { didSet { defaults.set(hasSeenHomeQuickSettingsTooltip, forKey: Keys.hasSeenHomeQuickSettingsTooltip) } }
    @Published var hasSeenHomeToggleTooltip: Bool { didSet { defaults.set(hasSeenHomeToggleTooltip, forKey: Keys.hasSeenHomeToggleTooltip) } }
    @Published var hasSeenHomeActionsTooltip: Bool { didSet { defaults.set(hasSeenHomeActionsTooltip, forKey: Keys.hasSeenHomeActionsTooltip) } }
    @Published var hasSeenHomeDeleteTooltip: Bool { didSet { defaults.set(hasSeenHomeDeleteTooltip, forKey: Keys.hasSeenHomeDeleteTooltip) } }
    @Published var hasSeenEditAlarmTimeTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmTimeTooltip, forKey: Keys.hasSeenEditAlarmTimeTooltip) } }
    @Published var hasSeenEditAlarmNavTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmNavTooltip, forKey: Keys.hasSeenEditAlarmNavTooltip) } }
    @Published var hasSeenEditAlarmNameTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmNameTooltip, forKey: Keys.hasSeenEditAlarmNameTooltip) } }
    @Published var hasSeenEditAlarmMissionTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmMissionTooltip, forKey: Keys.hasSeenEditAlarmMissionTooltip) } }
    @Published var hasSeenEditAlarmTimezoneTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmTimezoneTooltip, forKey: Keys.hasSeenEditAlarmTimezoneTooltip) } }
    @Published var hasSeenEditAlarmToggleTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmToggleTooltip, forKey: Keys.hasSeenEditAlarmToggleTooltip) } }
    @Published var hasSeenEditAlarmSoundTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmSoundTooltip, forKey: Keys.hasSeenEditAlarmSoundTooltip) } }
    @Published var hasSeenEditAlarmActionsTooltip: Bool { didSet { defaults.set(hasSeenEditAlarmActionsTooltip, forKey: Keys.hasSeenEditAlarmActionsTooltip) } }
    @Published var hasSeenTimerTimeIntegerTooltip: Bool { didSet { defaults.set(hasSeenTimerTimeIntegerTooltip, forKey: Keys.hasSeenTimerTimeIntegerTooltip) } }
    @Published var hasSeenTimerCircleTooltip: Bool { didSet { defaults.set(hasSeenTimerCircleTooltip, forKey: Keys.hasSeenTimerCircleTooltip) } }
    @Published var hasSeenTimerIntervalTooltip: Bool { didSet { defaults.set(hasSeenTimerIntervalTooltip, forKey: Keys.hasSeenTimerIntervalTooltip) } }
    @Published var hasSeenTimerBlockListTooltip: Bool { didSet { defaults.set(hasSeenTimerBlockListTooltip, forKey: Keys.hasSeenTimerBlockListTooltip) } }
    @Published var hasSeenTimerStartTooltip: Bool { didSet { defaults.set(hasSeenTimerStartTooltip, forKey: Keys.hasSeenTimerStartTooltip) } }
    @Published var timerFlipStartEnabled: Bool { didSet { defaults.set(timerFlipStartEnabled, forKey: Keys.timerFlipStartEnabled); log("set timerFlipStartEnabled=\(timerFlipStartEnabled)") } }
    @Published var timerStrictModeEnabled: Bool { didSet { defaults.set(timerStrictModeEnabled, forKey: Keys.timerStrictModeEnabled); log("set timerStrictModeEnabled=\(timerStrictModeEnabled)") } }
    @Published var timerOLEDAntiBurnInEnabled: Bool { didSet { defaults.set(timerOLEDAntiBurnInEnabled, forKey: Keys.timerOLEDAntiBurnInEnabled); log("set timerOLEDAntiBurnInEnabled=\(timerOLEDAntiBurnInEnabled)") } }
    // Plan
    @Published var hasSeenPlanFabTooltip: Bool { didSet { defaults.set(hasSeenPlanFabTooltip, forKey: Keys.hasSeenPlanFabTooltip) } }
    @Published var hasSeenPlanHabitVsTaskTooltip: Bool { didSet { defaults.set(hasSeenPlanHabitVsTaskTooltip, forKey: Keys.hasSeenPlanHabitVsTaskTooltip) } }
    @Published var hasSeenPlanSwipeTooltip: Bool { didSet { defaults.set(hasSeenPlanSwipeTooltip, forKey: Keys.hasSeenPlanSwipeTooltip) } }
    @Published var hasSeenPlanCalendarTooltip: Bool { didSet { defaults.set(hasSeenPlanCalendarTooltip, forKey: Keys.hasSeenPlanCalendarTooltip) } }
    // Overlap
    @Published var hasSeenOverlapAddCityTooltip: Bool { didSet { defaults.set(hasSeenOverlapAddCityTooltip, forKey: Keys.hasSeenOverlapAddCityTooltip) } }
    @Published var hasSeenOverlapAnalysisTooltip: Bool { didSet { defaults.set(hasSeenOverlapAnalysisTooltip, forKey: Keys.hasSeenOverlapAnalysisTooltip) } }
    @Published var hasSeenOverlapContextMenuTooltip: Bool { didSet { defaults.set(hasSeenOverlapContextMenuTooltip, forKey: Keys.hasSeenOverlapContextMenuTooltip) } }
    @Published var onboardingAlarmHour: Int { didSet { defaults.set(onboardingAlarmHour, forKey: Keys.onboardingAlarmHour) } }
    @Published var onboardingAlarmMinute: Int { didSet { defaults.set(onboardingAlarmMinute, forKey: Keys.onboardingAlarmMinute) } }
    @Published var onboardingAlarmSecond: Int { didSet { defaults.set(onboardingAlarmSecond, forKey: Keys.onboardingAlarmSecond) } }
    @Published var onboardingAlarmEnabled: Bool { didSet { defaults.set(onboardingAlarmEnabled, forKey: Keys.onboardingAlarmEnabled) } }
    @Published var onboardingRepeatMask: Int { didSet { defaults.set(onboardingRepeatMask, forKey: Keys.onboardingRepeatMask) } }
    @Published var onboardingSoundName: String { didSet { defaults.set(onboardingSoundName, forKey: Keys.onboardingSoundName) } }
    @Published var onboardingSoundVolume: Float { didSet { defaults.set(onboardingSoundVolume, forKey: Keys.onboardingSoundVolume) } }
    @Published var onboardingWallpaperId: String { didSet { defaults.set(onboardingWallpaperId, forKey: Keys.onboardingWallpaperId) } }
    
    // Focus Settings
    @Published var pomoDurationMinutes: Int { didSet { defaults.set(pomoDurationMinutes, forKey: Keys.pomoDurationMinutes); log("set pomoDurationMinutes=\(pomoDurationMinutes)") } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes); log("set shortBreakMinutes=\(shortBreakMinutes)") } }
    @Published var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes); log("set longBreakMinutes=\(longBreakMinutes)") } }
    @Published var pomosPerLongBreak: Int { didSet { defaults.set(pomosPerLongBreak, forKey: Keys.pomosPerLongBreak); log("set pomosPerLongBreak=\(pomosPerLongBreak)") } }
    @Published var autoStartNextPomo: Bool { didSet { defaults.set(autoStartNextPomo, forKey: Keys.autoStartNextPomo); log("set autoStartNextPomo=\(autoStartNextPomo)") } }
    @Published var autoStartBreak: Bool { didSet { defaults.set(autoStartBreak, forKey: Keys.autoStartBreak); log("set autoStartBreak=\(autoStartBreak)") } }
    @Published var autoPomoCycle: Int { didSet { defaults.set(autoPomoCycle, forKey: Keys.autoPomoCycle); log("set autoPomoCycle=\(autoPomoCycle)") } }
    @Published var pomoEndingSoundName: String { didSet { defaults.set(pomoEndingSoundName, forKey: Keys.pomoEndingSoundName); log("selected pomoEndingSoundName=\(pomoEndingSoundName)") } }
    @Published var ambientSoundName: String { didSet { defaults.set(ambientSoundName, forKey: Keys.ambientSoundName); log("selected ambientSoundName=\(ambientSoundName)") } }
    @Published var breakEndingSoundName: String { didSet { defaults.set(breakEndingSoundName, forKey: Keys.breakEndingSoundName); log("selected breakEndingSoundName=\(breakEndingSoundName)") } }
    @Published var vibrationDurationSeconds: Int { didSet { defaults.set(vibrationDurationSeconds, forKey: Keys.vibrationDurationSeconds); log("set vibrationDurationSeconds=\(vibrationDurationSeconds)") } }
    @Published var stopwatchSoundName: String { didSet { defaults.set(stopwatchSoundName, forKey: Keys.stopwatchSoundName); log("selected stopwatchSoundName=\(stopwatchSoundName)") } }
    @Published var stopwatchVibrationSeconds: Int { didSet { defaults.set(stopwatchVibrationSeconds, forKey: Keys.stopwatchVibrationSeconds); log("set stopwatchVibrationSeconds=\(stopwatchVibrationSeconds)") } }
    @Published var focusEnforcementMode: EnforcementMode { didSet { defaults.set(focusEnforcementMode.rawValue, forKey: Keys.focusEnforcementMode) } }
    @Published var focusBlockAppsEnabled: Bool { didSet { defaults.set(focusBlockAppsEnabled, forKey: Keys.focusBlockAppsEnabled) } }
    @Published var focusPenaltyEnabled: Bool { didSet { defaults.set(focusPenaltyEnabled, forKey: Keys.focusPenaltyEnabled) } }
    @Published var focusPenaltyAmountEuro: Int { didSet { defaults.set(min(10, max(1, focusPenaltyAmountEuro)), forKey: Keys.focusPenaltyAmountEuro) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let currentBuildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let previousBuildVersion = defaults.string(forKey: Keys.lastSeenBuildVersion)
        if let currentBuildVersion,
           let previousBuildVersion,
           previousBuildVersion != currentBuildVersion {
            defaults.set(true, forKey: Keys.forceShowOnboardingNextLaunch)
        }
        if let currentBuildVersion {
            defaults.set(currentBuildVersion, forKey: Keys.lastSeenBuildVersion)
        }

        self.onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        self.forceShowOnboardingNextLaunch = defaults.bool(forKey: Keys.forceShowOnboardingNextLaunch)
        self.hasShownFirstHomeDiscountFlow = defaults.bool(forKey: Keys.hasShownFirstHomeDiscountFlow)
        self.hasTappedRemoveAdsBefore = defaults.bool(forKey: Keys.hasTappedRemoveAdsBefore)
        self.hasSeenPaywallAtLeastOnce = defaults.bool(forKey: Keys.hasSeenPaywallAtLeastOnce)
        if defaults.object(forKey: Keys.devAlwaysShowUpsell) == nil {
            defaults.set(Self.debugDefaultUpsellValue, forKey: Keys.devAlwaysShowUpsell)
        }
        if defaults.object(forKey: Keys.devAlwaysShowOnboarding) == nil {
            defaults.set(Self.debugDefaultOnboardingValue, forKey: Keys.devAlwaysShowOnboarding)
        }
        self.devAlwaysShowUpsell = defaults.bool(forKey: Keys.devAlwaysShowUpsell)
        self.devAlwaysShowOnboarding = defaults.bool(forKey: Keys.devAlwaysShowOnboarding)
        self.hasSeenDiscountExitDialog = defaults.bool(forKey: Keys.hasSeenDiscountExitDialog)
        self.hasTappedGetOfferFromDiscount = defaults.bool(forKey: Keys.hasTappedGetOfferFromDiscount)
        self.hasAnyAlarm = defaults.bool(forKey: Keys.hasAnyAlarm)
        
        #if DEBUG
        // Always show tooltips for testing
        self.hasSeenAddAlarmTooltip = false
        self.hasSeenTimerTooltip = false
        self.hasSeenPlanTooltip = false
        self.hasSeenOverlapTooltip = false
        self.hasSeenEditAlarmTooltip = false
        self.hasSeenQuickLogTooltip = false
        self.hasSeenTimerMusicTooltip = false
        self.hasSeenOverlapTimeTravelTooltip = false
        self.hasSeenHomeQuickSettingsTooltip = false
        self.hasSeenHomeToggleTooltip = false
        self.hasSeenHomeActionsTooltip = false
        self.hasSeenHomeDeleteTooltip = false
        self.hasSeenEditAlarmSoundTooltip = false
        self.hasSeenEditAlarmTimeTooltip = false
        self.hasSeenEditAlarmNavTooltip = false
        self.hasSeenEditAlarmNameTooltip = false
        self.hasSeenEditAlarmMissionTooltip = false
        self.hasSeenEditAlarmTimezoneTooltip = false
        self.hasSeenEditAlarmToggleTooltip = false
        self.hasSeenEditAlarmActionsTooltip = false
        self.hasSeenTimerTimeIntegerTooltip = false
        self.hasSeenTimerCircleTooltip = false
        self.hasSeenTimerIntervalTooltip = false
        self.hasSeenTimerBlockListTooltip = false
        self.hasSeenTimerStartTooltip = false
        self.timerFlipStartEnabled = false
        self.timerStrictModeEnabled = false
        self.timerOLEDAntiBurnInEnabled = true
        self.hasSeenPlanFabTooltip = false
        self.hasSeenPlanHabitVsTaskTooltip = false
        self.hasSeenPlanSwipeTooltip = false
        self.hasSeenPlanCalendarTooltip = false
        self.hasSeenOverlapAddCityTooltip = false
        self.hasSeenOverlapAnalysisTooltip = false
        self.hasSeenOverlapContextMenuTooltip = false
        #else
        self.hasSeenAddAlarmTooltip = defaults.bool(forKey: Keys.hasSeenAddAlarmTooltip)
        self.hasSeenTimerTooltip = defaults.bool(forKey: Keys.hasSeenTimerTooltip)
        self.hasSeenPlanTooltip = defaults.bool(forKey: Keys.hasSeenPlanTooltip)
        self.hasSeenOverlapTooltip = defaults.bool(forKey: Keys.hasSeenOverlapTooltip)
        self.hasSeenEditAlarmTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmTooltip)
        self.hasSeenQuickLogTooltip = defaults.bool(forKey: Keys.hasSeenQuickLogTooltip)
        self.hasSeenTimerMusicTooltip = defaults.bool(forKey: Keys.hasSeenTimerMusicTooltip)
        self.hasSeenOverlapTimeTravelTooltip = defaults.bool(forKey: Keys.hasSeenOverlapTimeTravelTooltip)
        self.hasSeenHomeQuickSettingsTooltip = defaults.bool(forKey: Keys.hasSeenHomeQuickSettingsTooltip)
        self.hasSeenHomeToggleTooltip = defaults.bool(forKey: Keys.hasSeenHomeToggleTooltip)
        self.hasSeenHomeActionsTooltip = defaults.bool(forKey: Keys.hasSeenHomeActionsTooltip)
        self.hasSeenHomeDeleteTooltip = defaults.bool(forKey: Keys.hasSeenHomeDeleteTooltip)
        self.hasSeenEditAlarmTimeTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmTimeTooltip)
        self.hasSeenEditAlarmNavTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmNavTooltip)
        self.hasSeenEditAlarmNameTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmNameTooltip)
        self.hasSeenEditAlarmMissionTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmMissionTooltip)
        self.hasSeenEditAlarmTimezoneTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmTimezoneTooltip)
        self.hasSeenEditAlarmToggleTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmToggleTooltip)
        self.hasSeenEditAlarmSoundTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmSoundTooltip)
        self.hasSeenEditAlarmActionsTooltip = defaults.bool(forKey: Keys.hasSeenEditAlarmActionsTooltip)
        self.hasSeenTimerTimeIntegerTooltip = defaults.bool(forKey: Keys.hasSeenTimerTimeIntegerTooltip)
        self.hasSeenTimerCircleTooltip = defaults.bool(forKey: Keys.hasSeenTimerCircleTooltip)
        self.hasSeenTimerIntervalTooltip = defaults.bool(forKey: Keys.hasSeenTimerIntervalTooltip)
        self.hasSeenTimerBlockListTooltip = defaults.bool(forKey: Keys.hasSeenTimerBlockListTooltip)
        self.hasSeenTimerStartTooltip = defaults.bool(forKey: Keys.hasSeenTimerStartTooltip)
        self.timerFlipStartEnabled = defaults.object(forKey: Keys.timerFlipStartEnabled) as? Bool ?? false
        self.timerStrictModeEnabled = defaults.object(forKey: Keys.timerStrictModeEnabled) as? Bool ?? false
        self.timerOLEDAntiBurnInEnabled = defaults.object(forKey: Keys.timerOLEDAntiBurnInEnabled) as? Bool ?? true
        self.hasSeenPlanFabTooltip = defaults.bool(forKey: Keys.hasSeenPlanFabTooltip)
        self.hasSeenPlanHabitVsTaskTooltip = defaults.bool(forKey: Keys.hasSeenPlanHabitVsTaskTooltip)
        self.hasSeenPlanSwipeTooltip = defaults.bool(forKey: Keys.hasSeenPlanSwipeTooltip)
        self.hasSeenPlanCalendarTooltip = defaults.bool(forKey: Keys.hasSeenPlanCalendarTooltip)
        self.hasSeenOverlapAddCityTooltip = defaults.bool(forKey: Keys.hasSeenOverlapAddCityTooltip)
        self.hasSeenOverlapAnalysisTooltip = defaults.bool(forKey: Keys.hasSeenOverlapAnalysisTooltip)
        self.hasSeenOverlapContextMenuTooltip = defaults.bool(forKey: Keys.hasSeenOverlapContextMenuTooltip)
        #endif
        
        let storedHour = defaults.object(forKey: Keys.onboardingAlarmHour) as? Int
        let storedMinute = defaults.object(forKey: Keys.onboardingAlarmMinute) as? Int
        let storedSecond = defaults.object(forKey: Keys.onboardingAlarmSecond) as? Int
        self.onboardingAlarmHour = storedHour ?? AppConstants.defaultHour
        self.onboardingAlarmMinute = storedMinute ?? AppConstants.defaultMinute
        self.onboardingAlarmSecond = storedSecond ?? AppConstants.defaultSecond
        if defaults.object(forKey: Keys.onboardingAlarmEnabled) == nil {
            defaults.set(true, forKey: Keys.onboardingAlarmEnabled)
        }
        self.onboardingAlarmEnabled = defaults.bool(forKey: Keys.onboardingAlarmEnabled)
        if defaults.object(forKey: Keys.onboardingRepeatMask) == nil {
            defaults.set(126, forKey: Keys.onboardingRepeatMask)
        }
        self.onboardingRepeatMask = defaults.integer(forKey: Keys.onboardingRepeatMask)
        let storedOnboardingSound = defaults.string(forKey: Keys.onboardingSoundName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyInvalidOnboardingSoundNames: Set<String> = [
            "",
            "default",
            "orkney",
            "addams family"
        ]
        let normalizedStoredOnboardingSound = storedOnboardingSound?.lowercased() ?? ""
        if storedOnboardingSound == nil ||
            legacyInvalidOnboardingSoundNames.contains(normalizedStoredOnboardingSound) {
            defaults.set(Self.defaultAlarmSoundName, forKey: Keys.onboardingSoundName)
        }
        self.onboardingSoundName = defaults.string(forKey: Keys.onboardingSoundName) ?? Self.defaultAlarmSoundName
        if defaults.object(forKey: Keys.onboardingSoundVolume) == nil {
            defaults.set(0.8, forKey: Keys.onboardingSoundVolume)
        }
        self.onboardingSoundVolume = defaults.float(forKey: Keys.onboardingSoundVolume)
        let resolvedWallpaperId = Self.defaultWallpaperIdFromConfig()
        if defaults.object(forKey: Keys.onboardingWallpaperId) == nil {
            defaults.set(resolvedWallpaperId, forKey: Keys.onboardingWallpaperId)
        }
        let storedWallpaperId = defaults.string(forKey: Keys.onboardingWallpaperId)
        if storedWallpaperId == nil || storedWallpaperId == "default" {
            defaults.set(resolvedWallpaperId, forKey: Keys.onboardingWallpaperId)
        }
        self.onboardingWallpaperId = defaults.string(forKey: Keys.onboardingWallpaperId) ?? resolvedWallpaperId
        
        // Focus Settings Defaults
        self.pomoDurationMinutes = defaults.object(forKey: Keys.pomoDurationMinutes) as? Int ?? 25
        self.shortBreakMinutes = defaults.object(forKey: Keys.shortBreakMinutes) as? Int ?? 5
        self.longBreakMinutes = defaults.object(forKey: Keys.longBreakMinutes) as? Int ?? 15
        self.pomosPerLongBreak = defaults.object(forKey: Keys.pomosPerLongBreak) as? Int ?? 4
        self.autoStartNextPomo = defaults.bool(forKey: Keys.autoStartNextPomo)
        self.autoStartBreak = defaults.bool(forKey: Keys.autoStartBreak)
        self.autoPomoCycle = defaults.object(forKey: Keys.autoPomoCycle) as? Int ?? 4
        self.pomoEndingSoundName = defaults.string(forKey: Keys.pomoEndingSoundName) ?? "Addams Family"
        self.ambientSoundName = defaults.string(forKey: Keys.ambientSoundName) ?? "Rain Sound"
        self.breakEndingSoundName = defaults.string(forKey: Keys.breakEndingSoundName) ?? "Alan Jackson Remix"
        self.vibrationDurationSeconds = defaults.object(forKey: Keys.vibrationDurationSeconds) as? Int ?? 10
        self.stopwatchSoundName = defaults.string(forKey: Keys.stopwatchSoundName) ?? "Batman Beyond"
        self.stopwatchVibrationSeconds = defaults.object(forKey: Keys.stopwatchVibrationSeconds) as? Int ?? 10
        self.focusEnforcementMode = EnforcementMode(rawValue: defaults.string(forKey: Keys.focusEnforcementMode) ?? "") ?? .none
        self.focusBlockAppsEnabled = defaults.object(forKey: Keys.focusBlockAppsEnabled) as? Bool ?? false
        self.focusPenaltyEnabled = defaults.object(forKey: Keys.focusPenaltyEnabled) as? Bool ?? false
        self.focusPenaltyAmountEuro = defaults.object(forKey: Keys.focusPenaltyAmountEuro) as? Int ?? 1
    }

    private enum Keys {
        static let onboardingCompleted = "alarmo.onboarding.completed"
        static let forceShowOnboardingNextLaunch = "alarmo.onboarding.forceShowNextLaunch"
        static let lastSeenBuildVersion = "alarmo.app.lastSeenBuildVersion"
        static let hasShownFirstHomeDiscountFlow = "alarmo.home.firstDiscountShown"
        static let hasTappedRemoveAdsBefore = "alarmo.removeAds.tapped"
        static let hasSeenPaywallAtLeastOnce = "alarmo.paywall.seen"
        static let devAlwaysShowUpsell = "alarmo.dev.alwaysShowUpsell"
        static let devAlwaysShowOnboarding = "alarmo.dev.alwaysShowOnboarding"
        static let hasSeenDiscountExitDialog = "alarmo.discount.exitDialog.seen"
        static let hasTappedGetOfferFromDiscount = "alarmo.discount.getOffer.tapped"
        static let hasAnyAlarm = "alarmo.alarm.hasAny"
        static let hasSeenAddAlarmTooltip = "alarmo.home.hasSeenAddAlarmTooltip"
        static let hasSeenTimerTooltip = "alarmo.home.hasSeenTimerTooltip"
        static let hasSeenPlanTooltip = "alarmo.home.hasSeenPlanTooltip"
        static let hasSeenOverlapTooltip = "alarmo.home.hasSeenOverlapTooltip"
        static let hasSeenEditAlarmTooltip = "alarmo.home.hasSeenEditAlarmTooltip"
        static let hasSeenQuickLogTooltip = "alarmo.home.hasSeenQuickLogTooltip"
        static let hasSeenTimerMusicTooltip = "alarmo.home.hasSeenTimerMusicTooltip"
        static let hasSeenOverlapTimeTravelTooltip = "alarmo.home.hasSeenOverlapTimeTravelTooltip"
        static let hasSeenHomeQuickSettingsTooltip = "alarmo.home.hasSeenHomeQuickSettingsTooltip"
        static let hasSeenHomeToggleTooltip = "alarmo.home.hasSeenHomeToggleTooltip"
        static let hasSeenHomeActionsTooltip = "alarmo.home.hasSeenHomeActionsTooltip"
        static let hasSeenHomeDeleteTooltip = "alarmo.home.hasSeenHomeDeleteTooltip"
        static let hasSeenEditAlarmTimeTooltip = "alarmo.alarm.hasSeenEditAlarmTimeTooltip"
        static let hasSeenEditAlarmNavTooltip = "alarmo.alarm.hasSeenEditAlarmNavTooltip"
        static let hasSeenEditAlarmNameTooltip = "alarmo.alarm.hasSeenEditAlarmNameTooltip"
        static let hasSeenEditAlarmMissionTooltip = "alarmo.alarm.hasSeenEditAlarmMissionTooltip"
        static let hasSeenEditAlarmTimezoneTooltip = "alarmo.alarm.hasSeenEditAlarmTimezoneTooltip"
        static let hasSeenEditAlarmToggleTooltip = "hasSeenEditAlarmToggleTooltip"
        static let hasSeenEditAlarmSoundTooltip = "hasSeenEditAlarmSoundTooltip"
        static let hasSeenEditAlarmActionsTooltip = "hasSeenEditAlarmActionsTooltip"
        static let hasSeenTimerTimeIntegerTooltip = "alarmo.timer.hasSeenTimerTimeIntegerTooltip"
        static let hasSeenTimerCircleTooltip = "alarmo.timer.hasSeenTimerCircleTooltip"
        static let hasSeenTimerIntervalTooltip = "alarmo.timer.hasSeenTimerIntervalTooltip"
        static let hasSeenTimerBlockListTooltip = "alarmo.timer.hasSeenTimerBlockListTooltip"
        static let hasSeenTimerStartTooltip = "alarmo.timer.hasSeenTimerStartTooltip"
        static let timerFlipStartEnabled = "alarmo.focus.timerFlipStartEnabled"
        static let timerStrictModeEnabled = "alarmo.focus.timerStrictModeEnabled"
        static let timerOLEDAntiBurnInEnabled = "alarmo.focus.timerOLEDAntiBurnInEnabled"
        static let hasSeenPlanFabTooltip = "alarmo.plan.hasSeenFabTooltip"
        static let hasSeenPlanHabitVsTaskTooltip = "alarmo.plan.hasSeenHabitVsTaskTooltip"
        static let hasSeenPlanSwipeTooltip = "alarmo.plan.hasSeenSwipeTooltip"
        static let hasSeenPlanCalendarTooltip = "alarmo.plan.hasSeenCalendarTooltip"
        static let hasSeenOverlapAddCityTooltip = "alarmo.overlap.hasSeenAddCityTooltip"
        static let hasSeenOverlapAnalysisTooltip = "alarmo.overlap.hasSeenAnalysisTooltip"
        static let hasSeenOverlapContextMenuTooltip = "alarmo.overlap.hasSeenContextMenuTooltip"
        static let onboardingAlarmHour = "alarmo.alarm.onboardingHour"
        static let onboardingAlarmMinute = "alarmo.alarm.onboardingMinute"
        static let onboardingAlarmSecond = "alarmo.alarm.onboardingSecond"
        static let onboardingAlarmEnabled = "alarmo.alarm.onboardingEnabled"
        static let onboardingRepeatMask = "alarmo.alarm.onboardingRepeatMask"
        static let onboardingSoundName = "alarmo.alarm.onboardingSoundName"
        static let onboardingSoundVolume = "alarmo.alarm.onboardingSoundVolume"
        static let onboardingWallpaperId = "alarmo.alarm.onboardingWallpaperId"
        
        static let pomoDurationMinutes = "alarmo.focus.pomoDurationMinutes"
        static let shortBreakMinutes = "alarmo.focus.shortBreakMinutes"
        static let longBreakMinutes = "alarmo.focus.longBreakMinutes"
        static let pomosPerLongBreak = "alarmo.focus.pomosPerLongBreak"
        static let autoStartNextPomo = "alarmo.focus.autoStartNextPomo"
        static let autoStartBreak = "alarmo.focus.autoStartBreak"
        static let autoPomoCycle = "alarmo.focus.autoPomoCycle"
        static let pomoEndingSoundName = "alarmo.focus.pomoEndingSoundName"
        static let ambientSoundName = "alarmo.focus.ambientSoundName"
        static let breakEndingSoundName = "alarmo.focus.breakEndingSoundName"
        static let vibrationDurationSeconds = "alarmo.focus.vibrationDurationSeconds"
        static let stopwatchSoundName = "alarmo.focus.stopwatchSoundName"
        static let stopwatchVibrationSeconds = "alarmo.focus.stopwatchVibrationSeconds"
        static let focusEnforcementMode = "alarmo.focus.enforcementMode"
        static let focusBlockAppsEnabled = "alarmo.focus.blockAppsEnabled"
        static let focusPenaltyEnabled = "alarmo.focus.penaltyEnabled"
        static let focusPenaltyAmountEuro = "alarmo.focus.penaltyAmountEuro"
    }

    private static func defaultWallpaperIdFromConfig() -> String {
        if let firstCategory = WallpaperConfig.categories.first,
           let firstFilename = firstCategory.imageNames.first {
            return "\(firstCategory.id)-\(firstFilename)"
        }
        return "default"
    }

    #if DEBUG
    private static let debugDefaultUpsellValue = true
    private static let debugDefaultOnboardingValue = true
    #else
    private static let debugDefaultUpsellValue = false
    private static let debugDefaultOnboardingValue = false
    #endif
    
    private func log(_ message: String) {
        print("[FocusSettings] \(message)")
    }
}
