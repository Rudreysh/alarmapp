import XCTest
@testable import alarmo

@MainActor
final class PenaltyEngineTests: XCTestCase {
    private let engine = PenaltyEngine.shared
    private let store = SettingsStore.shared
    private let credits = PenaltyCreditsManager.shared

    override func setUp() async throws {
        try await super.setUp()
        store.penaltyCreditsBalance = 0
        store.penaltyAmountEuro = 5
        store.penaltyRules = .default
        credits.addTestCredits(100)
    }

    func testSnoozeThresholdChargesOnlyOnceWhenCrossed() {
        var session = AlarmSession(
            alarmId: UUID(),
            isActive: true,
            snoozeCount: 4,
            hasMissions: false,
            missionStatus: .completed,
            status: .ringing
        )
        let alarm = Alarm(
            id: session.alarmId,
            name: "Morning",
            emoji: "🌞",
            hour: 7,
            minute: 0,
            isDaily: true,
            repeatMask: RepeatMask.allDays,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "Orkney",
            soundVolume: 1.0,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: 5,
            snoozeCount: 3,
            wallpaperId: "default",
            createdAt: Date(),
            penaltyEnabled: true
        )

        let first = engine.chargeIfNeeded(
            alarm: alarm,
            session: &session,
            violation: .snoozeThresholdExceeded,
            note: "test"
        )
        let second = engine.chargeIfNeeded(
            alarm: alarm,
            session: &session,
            violation: .snoozeThresholdExceeded,
            note: "test-again"
        )

        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(session.violations.filter { $0.type == .snoozeThresholdExceeded }.count, 1)
    }

    func testDisabledPerAlarmPreventsCharge() {
        var session = AlarmSession(
            alarmId: UUID(),
            isActive: true,
            snoozeCount: 10,
            hasMissions: false,
            missionStatus: .completed,
            status: .ringing
        )
        let alarm = Alarm(
            id: session.alarmId,
            name: "Morning",
            emoji: "🌞",
            hour: 7,
            minute: 0,
            isDaily: true,
            repeatMask: RepeatMask.allDays,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "Orkney",
            soundVolume: 1.0,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: 5,
            snoozeCount: 3,
            wallpaperId: "default",
            createdAt: Date(),
            penaltyEnabled: false
        )

        XCTAssertFalse(
            engine.chargeIfNeeded(
                alarm: alarm,
                session: &session,
                violation: .snoozeThresholdExceeded,
                note: "test"
            )
        )
    }

    func testDisabledGlobalTriggerPreventsCharge() {
        store.penaltyRules.triggerSnoozeThresholdEnabled = false

        var session = AlarmSession(
            alarmId: UUID(),
            isActive: true,
            snoozeCount: 10,
            hasMissions: false,
            missionStatus: .completed,
            status: .ringing
        )
        let alarm = Alarm(
            id: session.alarmId,
            name: "Morning",
            emoji: "🌞",
            hour: 7,
            minute: 0,
            isDaily: true,
            repeatMask: RepeatMask.allDays,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "Orkney",
            soundVolume: 1.0,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: 5,
            snoozeCount: 3,
            wallpaperId: "default",
            createdAt: Date(),
            penaltyEnabled: true
        )

        XCTAssertFalse(
            engine.chargeIfNeeded(
                alarm: alarm,
                session: &session,
                violation: .snoozeThresholdExceeded,
                note: "test"
            )
        )
    }
}
