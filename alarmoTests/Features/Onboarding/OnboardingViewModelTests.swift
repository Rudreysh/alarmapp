import XCTest
@testable import alarmo

final class OnboardingViewModelTests: XCTestCase {
    func test_defaultState_isIntro_andTimeIs0700() {
        let viewModel = OnboardingViewModel()
        XCTAssertEqual(viewModel.state.currentStep, .intro)
        XCTAssertEqual(viewModel.selectedHour, 7)
        XCTAssertEqual(viewModel.selectedMinute, 0)
        XCTAssertEqual(viewModel.selectedTimeString, "07:00")
    }

    func test_nextStep_advancesFromIntroToSetTime() {
        let viewModel = OnboardingViewModel()
        viewModel.nextStep()
        XCTAssertEqual(viewModel.state.currentStep, .setTime)
    }

    func test_nextStep_advancesFromSetTimeToStep3Stub() {
        let viewModel = OnboardingViewModel()
        viewModel.nextStep()
        viewModel.nextStep()
        XCTAssertEqual(viewModel.state.currentStep, .step3Stub)
    }

    func test_selectedTime_updatesFormattedString() {
        let viewModel = OnboardingViewModel()
        viewModel.selectedHour = 9
        viewModel.selectedMinute = 5
        XCTAssertEqual(viewModel.selectedTimeString, "09:05")
    }
}
