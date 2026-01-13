import XCTest
@testable import alarmo

final class HomeViewModelTests: XCTestCase {
    func test_firstHomeVisit_showsCelebrationThenPaywall_andPersistsFlag() {
        let prefs = MockAppPreferences()
        let viewModel = HomeViewModel(preferences: prefs)

        viewModel.onAppear()

        XCTAssertTrue(viewModel.showCelebration)
        XCTAssertTrue(prefs.hasShownFirstHomeDiscountFlow)
        XCTAssertFalse(viewModel.showDiscountPaywall)

        viewModel.celebrationDidFinish()

        XCTAssertFalse(viewModel.showCelebration)
        XCTAssertTrue(viewModel.showDiscountPaywall)
        XCTAssertTrue(prefs.hasSeenPaywallAtLeastOnce)
    }

    func test_subsequentHomeVisit_showsTopBanner_notCelebration() {
        let prefs = MockAppPreferences()
        prefs.hasShownFirstHomeDiscountFlow = true
        let viewModel = HomeViewModel(preferences: prefs)

        viewModel.onAppear()

        XCTAssertFalse(viewModel.showCelebration)
    }

    func test_removeAds_firstTap_showsCelebrationThenPaywall_andPersistsFlag() {
        let prefs = MockAppPreferences()
        let viewModel = HomeViewModel(preferences: prefs)

        viewModel.tapRemoveAds()

        XCTAssertTrue(prefs.hasTappedRemoveAdsBefore)
        XCTAssertTrue(viewModel.showCelebration)

        viewModel.celebrationDidFinish()

        XCTAssertTrue(viewModel.showDiscountPaywall)
    }

    func test_removeAds_secondTap_showsPaywallOnly() {
        let prefs = MockAppPreferences()
        prefs.hasTappedRemoveAdsBefore = true
        let viewModel = HomeViewModel(preferences: prefs)

        viewModel.tapRemoveAds()

        XCTAssertFalse(viewModel.showCelebration)
        XCTAssertTrue(viewModel.showDiscountPaywall)
    }
}

private final class MockAppPreferences: AppPreferencesProtocol {
    var onboardingCompleted: Bool = false
    var hasShownFirstHomeDiscountFlow: Bool = false
    var hasTappedRemoveAdsBefore: Bool = false
    var hasSeenPaywallAtLeastOnce: Bool = false
    var devAlwaysShowUpsell: Bool = false
    var devAlwaysShowOnboarding: Bool = false
    var hasSeenDiscountExitDialog: Bool = false
    var hasTappedGetOfferFromDiscount: Bool = false
    var hasAnyAlarm: Bool = false
    var onboardingAlarmHour: Int = 7
    var onboardingAlarmMinute: Int = 0
    var onboardingAlarmEnabled: Bool = true
    var onboardingRepeatMask: Int = 126
    var onboardingSoundName: String = "Orkney"
    var onboardingSoundVolume: Float = 0.8
    var onboardingWallpaperId: String = "default"
}
