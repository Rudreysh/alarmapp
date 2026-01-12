import XCTest
@testable import alarmo

final class OnboardingViewModelTests: XCTestCase {
    func test_defaultState_isIntro_andTimeIs0700() {
        let viewModel = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        XCTAssertEqual(viewModel.state.currentStep, .intro)
        XCTAssertEqual(viewModel.selectedHour, 7)
        XCTAssertEqual(viewModel.selectedMinute, 0)
        XCTAssertEqual(viewModel.selectedTimeString, "07:00")
    }

    func test_nextStep_advancesFromIntroToSetTime() {
        let viewModel = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        viewModel.nextStep()
        XCTAssertEqual(viewModel.state.currentStep, .setTime)
    }

    func test_nextStep_advancesFromSetTimeToPermissions() {
        let viewModel = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        viewModel.nextStep()
        viewModel.nextStep()
        XCTAssertEqual(viewModel.state.currentStep, .permissions)
    }

    func test_selectedTime_updatesFormattedString() {
        let viewModel = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        viewModel.selectedHour = 9
        viewModel.selectedMinute = 5
        XCTAssertEqual(viewModel.selectedTimeString, "09:05")
    }

    func test_selectingWallpaper_enablesProceed() {
        let viewModel = OnboardingViewModel(permissionService: MockNotificationPermissionService())
        let item = WallpaperItem(
            id: "test",
            title: "Test",
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            category: "custom",
            source: .userPhoto(url: URL(fileURLWithPath: "/tmp/test.jpg"))
        )
        viewModel.selectWallpaper(item)
        XCTAssertTrue(viewModel.canProceedWallpaper)
    }

    func test_permissionRequest_updatesAuthorization() async {
        let service = MockNotificationPermissionService(result: true)
        let viewModel = OnboardingViewModel(permissionService: service)
        await viewModel.requestNotificationPermissionAndAdvance()
        XCTAssertTrue(viewModel.state.notificationsAuthorized)
    }
}

private final class MockNotificationPermissionService: NotificationPermissionService {
    private let result: Bool

    init(result: Bool = false) {
        self.result = result
    }

    func isAuthorized() async -> Bool {
        result
    }

    func requestAuthorization() async -> Bool {
        result
    }
}
