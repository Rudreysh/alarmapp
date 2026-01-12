import XCTest
@testable import alarmo

final class AppPreferencesTests: XCTestCase {
    func test_persistedFlags_roundTrip() {
        let suiteName = "alarmo.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let prefs = AppPreferences(defaults: defaults)
        prefs.onboardingCompleted = true
        prefs.hasShownFirstHomeDiscountFlow = true
        prefs.hasTappedRemoveAdsBefore = true
        prefs.hasSeenPaywallAtLeastOnce = true

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.onboardingCompleted)
        XCTAssertTrue(reloaded.hasShownFirstHomeDiscountFlow)
        XCTAssertTrue(reloaded.hasTappedRemoveAdsBefore)
        XCTAssertTrue(reloaded.hasSeenPaywallAtLeastOnce)
    }
}
