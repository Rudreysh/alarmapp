import XCTest
@testable import alarmo

final class OnboardingMissionViewModelTests: XCTestCase {
    func test_defaultSelection_isOff() {
        let onboarding = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        let viewModel = OnboardingMissionViewModel(onboardingViewModel: onboarding)
        XCTAssertEqual(viewModel.selected, .off)
    }

    func test_select_updatesMission() {
        let onboarding = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        let viewModel = OnboardingMissionViewModel(onboardingViewModel: onboarding)
        let option = viewModel.options.first { $0.id == .math }!
        viewModel.select(option)
        XCTAssertEqual(onboarding.state.missionType, .math)
    }

    func test_optionsOrder() {
        let onboarding = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        let viewModel = OnboardingMissionViewModel(onboardingViewModel: onboarding)
        let order = viewModel.options.map { $0.id }
        XCTAssertEqual(order, [.math, .typing, .findColorTiles, .shake, .off])
    }
}

private final class MockNotificationPermissionService: NotificationPermissionService {
    func isAuthorized() async -> Bool { false }
    func requestAuthorization() async -> Bool { false }
}
