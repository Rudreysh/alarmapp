import XCTest
@testable import alarmo

final class CreateWakeUpAlarmViewModelTests: XCTestCase {
    func test_nextFireDate_dailyAdvancesToNextTime() {
        let viewModel = CreateWakeUpAlarmViewModel(
            defaultHour: 10,
            defaultMinute: 0,
            defaultRepeatMask: RepeatMask.allDays,
            defaultSoundName: "Orkney",
            defaultSoundVolume: 0.8
        )
        viewModel.draft.isDaily = true
        viewModel.draft.selectedWeekdays = Set(1...7)

        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 9, minute: 0))!
        let next = viewModel.nextFireDate(from: now)
        XCTAssertNotNil(next)
    }

    func test_nextFireDate_weekdaySelection() {
        let viewModel = CreateWakeUpAlarmViewModel(
            defaultHour: 10,
            defaultMinute: 0,
            defaultRepeatMask: RepeatMask.monToSat,
            defaultSoundName: "Orkney",
            defaultSoundVolume: 0.8
        )
        viewModel.draft.isDaily = false
        viewModel.draft.selectedWeekdays = [2] // Monday

        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 9, minute: 0))!
        let next = viewModel.nextFireDate(from: now)
        XCTAssertNotNil(next)
    }
}
