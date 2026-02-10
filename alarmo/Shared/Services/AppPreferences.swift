import Foundation
import Combine

protocol AppPreferencesProtocol: AnyObject {
    var onboardingCompleted: Bool { get set }
    var hasShownFirstHomeDiscountFlow: Bool { get set }
    var hasTappedRemoveAdsBefore: Bool { get set }
    var hasSeenPaywallAtLeastOnce: Bool { get set }
    var devAlwaysShowUpsell: Bool { get set }
    var devAlwaysShowOnboarding: Bool { get set }
    var hasSeenDiscountExitDialog: Bool { get set }
    var hasTappedGetOfferFromDiscount: Bool { get set }
    var hasAnyAlarm: Bool { get set }
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
    @Published var onboardingCompleted: Bool { 
        didSet { 
            defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted)
            print("[AppPreferences] onboardingCompleted changed to: \(onboardingCompleted)")
        } 
    }
    @Published var hasShownFirstHomeDiscountFlow: Bool { didSet { defaults.set(hasShownFirstHomeDiscountFlow, forKey: Keys.hasShownFirstHomeDiscountFlow) } }
    @Published var hasTappedRemoveAdsBefore: Bool { didSet { defaults.set(hasTappedRemoveAdsBefore, forKey: Keys.hasTappedRemoveAdsBefore) } }
    @Published var hasSeenPaywallAtLeastOnce: Bool { didSet { defaults.set(hasSeenPaywallAtLeastOnce, forKey: Keys.hasSeenPaywallAtLeastOnce) } }
    @Published var devAlwaysShowUpsell: Bool { didSet { defaults.set(devAlwaysShowUpsell, forKey: Keys.devAlwaysShowUpsell) } }
    @Published var devAlwaysShowOnboarding: Bool
    @Published var hasSeenDiscountExitDialog: Bool { didSet { defaults.set(hasSeenDiscountExitDialog, forKey: Keys.hasSeenDiscountExitDialog) } }
    @Published var hasTappedGetOfferFromDiscount: Bool { didSet { defaults.set(hasTappedGetOfferFromDiscount, forKey: Keys.hasTappedGetOfferFromDiscount) } }
    @Published var hasAnyAlarm: Bool { didSet { defaults.set(hasAnyAlarm, forKey: Keys.hasAnyAlarm) } }
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
        self.onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
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
        self.devAlwaysShowOnboarding = Self.debugDefaultOnboardingValue
        self.hasSeenDiscountExitDialog = defaults.bool(forKey: Keys.hasSeenDiscountExitDialog)
        self.hasTappedGetOfferFromDiscount = defaults.bool(forKey: Keys.hasTappedGetOfferFromDiscount)
        self.hasAnyAlarm = defaults.bool(forKey: Keys.hasAnyAlarm)
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
        if defaults.object(forKey: Keys.onboardingSoundName) == nil {
            defaults.set("Addams Family", forKey: Keys.onboardingSoundName)
        }
        self.onboardingSoundName = defaults.string(forKey: Keys.onboardingSoundName) ?? "Addams Family"
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
        static let hasShownFirstHomeDiscountFlow = "alarmo.home.firstDiscountShown"
        static let hasTappedRemoveAdsBefore = "alarmo.removeAds.tapped"
        static let hasSeenPaywallAtLeastOnce = "alarmo.paywall.seen"
        static let devAlwaysShowUpsell = "alarmo.dev.alwaysShowUpsell"
        static let devAlwaysShowOnboarding = "alarmo.dev.alwaysShowOnboarding"
        static let hasSeenDiscountExitDialog = "alarmo.discount.exitDialog.seen"
        static let hasTappedGetOfferFromDiscount = "alarmo.discount.getOffer.tapped"
        static let hasAnyAlarm = "alarmo.alarm.hasAny"
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
