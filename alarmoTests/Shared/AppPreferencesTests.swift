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
        prefs.hasAnyAlarm = true
        prefs.onboardingAlarmHour = 6
        prefs.onboardingAlarmMinute = 45
        prefs.onboardingAlarmEnabled = false
        prefs.onboardingRepeatMask = 62
        prefs.onboardingSoundName = "Radar"
        prefs.onboardingSoundVolume = 0.6

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.onboardingCompleted)
        XCTAssertTrue(reloaded.hasShownFirstHomeDiscountFlow)
        XCTAssertTrue(reloaded.hasTappedRemoveAdsBefore)
        XCTAssertTrue(reloaded.hasSeenPaywallAtLeastOnce)
        XCTAssertTrue(reloaded.hasAnyAlarm)
        XCTAssertEqual(reloaded.onboardingAlarmHour, 6)
        XCTAssertEqual(reloaded.onboardingAlarmMinute, 45)
        XCTAssertEqual(reloaded.onboardingAlarmEnabled, false)
        XCTAssertEqual(reloaded.onboardingRepeatMask, 62)
        XCTAssertEqual(reloaded.onboardingSoundName, "Radar")
        XCTAssertEqual(reloaded.onboardingSoundVolume, 0.6)
    }
}
