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
    var onboardingAlarmEnabled: Bool { get set }
    var onboardingRepeatMask: Int { get set }
    var onboardingSoundName: String { get set }
    var onboardingSoundVolume: Float { get set }
}

final class AppPreferences: ObservableObject, AppPreferencesProtocol {
    @Published var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) } }
    @Published var hasShownFirstHomeDiscountFlow: Bool { didSet { defaults.set(hasShownFirstHomeDiscountFlow, forKey: Keys.hasShownFirstHomeDiscountFlow) } }
    @Published var hasTappedRemoveAdsBefore: Bool { didSet { defaults.set(hasTappedRemoveAdsBefore, forKey: Keys.hasTappedRemoveAdsBefore) } }
    @Published var hasSeenPaywallAtLeastOnce: Bool { didSet { defaults.set(hasSeenPaywallAtLeastOnce, forKey: Keys.hasSeenPaywallAtLeastOnce) } }
    @Published var devAlwaysShowUpsell: Bool { didSet { defaults.set(devAlwaysShowUpsell, forKey: Keys.devAlwaysShowUpsell) } }
    @Published var devAlwaysShowOnboarding: Bool { didSet { defaults.set(devAlwaysShowOnboarding, forKey: Keys.devAlwaysShowOnboarding) } }
    @Published var hasSeenDiscountExitDialog: Bool { didSet { defaults.set(hasSeenDiscountExitDialog, forKey: Keys.hasSeenDiscountExitDialog) } }
    @Published var hasTappedGetOfferFromDiscount: Bool { didSet { defaults.set(hasTappedGetOfferFromDiscount, forKey: Keys.hasTappedGetOfferFromDiscount) } }
    @Published var hasAnyAlarm: Bool { didSet { defaults.set(hasAnyAlarm, forKey: Keys.hasAnyAlarm) } }
    @Published var onboardingAlarmHour: Int { didSet { defaults.set(onboardingAlarmHour, forKey: Keys.onboardingAlarmHour) } }
    @Published var onboardingAlarmMinute: Int { didSet { defaults.set(onboardingAlarmMinute, forKey: Keys.onboardingAlarmMinute) } }
    @Published var onboardingAlarmEnabled: Bool { didSet { defaults.set(onboardingAlarmEnabled, forKey: Keys.onboardingAlarmEnabled) } }
    @Published var onboardingRepeatMask: Int { didSet { defaults.set(onboardingRepeatMask, forKey: Keys.onboardingRepeatMask) } }
    @Published var onboardingSoundName: String { didSet { defaults.set(onboardingSoundName, forKey: Keys.onboardingSoundName) } }
    @Published var onboardingSoundVolume: Float { didSet { defaults.set(onboardingSoundVolume, forKey: Keys.onboardingSoundVolume) } }

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
        self.devAlwaysShowOnboarding = defaults.bool(forKey: Keys.devAlwaysShowOnboarding)
        self.hasSeenDiscountExitDialog = defaults.bool(forKey: Keys.hasSeenDiscountExitDialog)
        self.hasTappedGetOfferFromDiscount = defaults.bool(forKey: Keys.hasTappedGetOfferFromDiscount)
        self.hasAnyAlarm = defaults.bool(forKey: Keys.hasAnyAlarm)
        let storedHour = defaults.object(forKey: Keys.onboardingAlarmHour) as? Int
        let storedMinute = defaults.object(forKey: Keys.onboardingAlarmMinute) as? Int
        self.onboardingAlarmHour = storedHour ?? AppConstants.defaultHour
        self.onboardingAlarmMinute = storedMinute ?? AppConstants.defaultMinute
        if defaults.object(forKey: Keys.onboardingAlarmEnabled) == nil {
            defaults.set(true, forKey: Keys.onboardingAlarmEnabled)
        }
        self.onboardingAlarmEnabled = defaults.bool(forKey: Keys.onboardingAlarmEnabled)
        if defaults.object(forKey: Keys.onboardingRepeatMask) == nil {
            defaults.set(126, forKey: Keys.onboardingRepeatMask)
        }
        self.onboardingRepeatMask = defaults.integer(forKey: Keys.onboardingRepeatMask)
        if defaults.object(forKey: Keys.onboardingSoundName) == nil {
            defaults.set("Orkney", forKey: Keys.onboardingSoundName)
        }
        self.onboardingSoundName = defaults.string(forKey: Keys.onboardingSoundName) ?? "Orkney"
        if defaults.object(forKey: Keys.onboardingSoundVolume) == nil {
            defaults.set(0.8, forKey: Keys.onboardingSoundVolume)
        }
        self.onboardingSoundVolume = defaults.float(forKey: Keys.onboardingSoundVolume)
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
        static let onboardingAlarmEnabled = "alarmo.alarm.onboardingEnabled"
        static let onboardingRepeatMask = "alarmo.alarm.onboardingRepeatMask"
        static let onboardingSoundName = "alarmo.alarm.onboardingSoundName"
        static let onboardingSoundVolume = "alarmo.alarm.onboardingSoundVolume"
    }

    #if DEBUG
    private static let debugDefaultUpsellValue = true
    private static let debugDefaultOnboardingValue = true
    #else
    private static let debugDefaultUpsellValue = false
    private static let debugDefaultOnboardingValue = false
    #endif
}
