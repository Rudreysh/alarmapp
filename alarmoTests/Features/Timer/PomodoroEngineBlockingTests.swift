import XCTest
@testable import alarmo

@MainActor
final class PomodoroEngineBlockingTests: XCTestCase {
    func test_focusBlockingControlsLockDuringRunningFocus() {
        let engine = PomodoroEngine()
        let blockList = AppList(type: .block, name: "Test Block")

        engine.setActiveBlockList(blockList)
        var config = engine.config
        config.blockAppsEnabled = true
        engine.updateConfig(config)
        engine.start()

        XCTAssertTrue(engine.isFocusBlockingControlsLocked)
    }

    func test_updateConfigCannotDisableBlockingWhileFocusLocked() {
        let engine = PomodoroEngine()
        let blockList = AppList(type: .block, name: "Test Block")

        engine.setActiveBlockList(blockList)
        var config = engine.config
        config.blockAppsEnabled = true
        engine.updateConfig(config)
        engine.start()

        var attempted = engine.config
        attempted.blockAppsEnabled = false
        attempted.selectedBlockListId = ""
        engine.updateConfig(attempted)

        XCTAssertTrue(engine.config.blockAppsEnabled)
        XCTAssertEqual(engine.config.selectedBlockListId, blockList.id.uuidString)
    }

    func test_setActiveBlockListCannotChangeWhileFocusLocked() {
        let engine = PomodoroEngine()
        let firstList = AppList(type: .block, name: "First Block")
        let secondList = AppList(type: .block, name: "Second Block")

        engine.setActiveBlockList(firstList)
        var config = engine.config
        config.blockAppsEnabled = true
        engine.updateConfig(config)
        engine.start()

        engine.setActiveBlockList(secondList)
        XCTAssertEqual(engine.activeBlockList?.id, firstList.id)

        engine.setActiveBlockList(nil)
        XCTAssertEqual(engine.activeBlockList?.id, firstList.id)
    }
}
