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
    }

    #if DEBUG
    private static let debugDefaultUpsellValue = true
    private static let debugDefaultOnboardingValue = true
    #else
    private static let debugDefaultUpsellValue = false
    private static let debugDefaultOnboardingValue = false
    #endif
}
