import XCTest
@testable import alarmo

final class AlarmSchedulingCoreTests: XCTestCase {
    func test_pathSelection_prefersAlarmKitWhenSupported() async throws {
        let alarmKit = MockScheduler(name: "alarmkit", supported: true)
        let legacy = MockLegacyScheduler(name: "legacy", supported: true)
        let facade = AlarmManagerFacade(
            pathResolver: { .alarmKit },
            alarmKitScheduler: alarmKit,
            legacyScheduler: legacy,
            requestStore: AlarmScheduleRequestStore(fileURL: tempFileURL("path-selection-1"))
        )

        XCTAssertEqual(facade.selectedPath, .alarmKit)
        XCTAssertEqual(facade.implementationName, "alarmkit")
    }

    func test_pathSelection_fallsBackToLegacyWhenAlarmKitUnsupported() async throws {
        let alarmKit = MockScheduler(name: "alarmkit", supported: false)
        let legacy = MockLegacyScheduler(name: "legacy", supported: true)
        let facade = AlarmManagerFacade(
            pathResolver: { .alarmKit },
            alarmKitScheduler: alarmKit,
            legacyScheduler: legacy,
            requestStore: AlarmScheduleRequestStore(fileURL: tempFileURL("path-selection-2"))
        )

        XCTAssertEqual(facade.selectedPath, .legacyNotification)
        XCTAssertEqual(facade.implementationName, "legacy")
    }

    func test_requestStore_roundTripsEncodedData() async throws {
        let url = tempFileURL("store-roundtrip")
        let id = UUID()
        let expected = AlarmScheduleRequest(
            id: id,
            title: "Morning",
            fireDate: Date(timeIntervalSince1970: 1_234_567),
            enabled: true,
            soundName: "cockpitalert",
            repeats: false,
            snoozeEnabled: true
        )

        let storeA = AlarmScheduleRequestStore(fileURL: url)
        await storeA.upsert(expected)

        let storeB = AlarmScheduleRequestStore(fileURL: url)
        let actual = await storeB.request(for: id)
        XCTAssertEqual(actual, expected)
    }

    func test_alarmScheduleMapper_mapsAlarmModel() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let alarm = makeAlarm(
            id: UUID(),
            name: "  Workout  ",
            hour: 7,
            minute: 45,
            repeatMask: RepeatMask.monday | RepeatMask.tuesday | RepeatMask.wednesday | RepeatMask.thursday | RepeatMask.friday,
            snoozeMinutes: 5
        )

        let mapped = AlarmScheduleMapper.map(alarm: alarm, now: now)
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped?.id, alarm.id)
        XCTAssertEqual(mapped?.title, "Workout")
        XCTAssertEqual(mapped?.soundName, alarm.soundName)
        XCTAssertEqual(mapped?.repeats, true)
        XCTAssertEqual(mapped?.snoozeEnabled, true)
        XCTAssertEqual(mapped?.enabled, true)
    }

    func test_cancelAndReschedule_flowThroughFacade() async throws {
        let alarmKit = MockScheduler(name: "alarmkit", supported: true)
        let legacy = MockLegacyScheduler(name: "legacy", supported: true)
        let facade = AlarmManagerFacade(
            pathResolver: { .alarmKit },
            alarmKitScheduler: alarmKit,
            legacyScheduler: legacy,
            requestStore: AlarmScheduleRequestStore(fileURL: tempFileURL("cancel-reschedule"))
        )

        let id = UUID()
        let initial = Date().addingTimeInterval(120)
        let updated = Date().addingTimeInterval(240)

        try await facade.scheduleAlarm(
            id: id,
            title: "Test",
            date: initial,
            sound: "cockpitalert",
            snoozeEnabled: true
        )
        try await facade.rescheduleAlarm(id: id, newDate: updated)
        await facade.cancelAlarm(id: id)

        XCTAssertEqual(alarmKit.scheduledIDs, [id])
        XCTAssertEqual(alarmKit.rescheduledIDs, [id])
        XCTAssertEqual(alarmKit.cancelledIDs, [id])
    }

    func test_fallback_whenAlarmKitScheduleFails_usesLegacyScheduler() async throws {
        let alarmKit = MockScheduler(name: "alarmkit", supported: true)
        alarmKit.scheduleError = AlarmSchedulingError.schedulingRejected("forced")
        let legacy = MockLegacyScheduler(name: "legacy", supported: true)
        let facade = AlarmManagerFacade(
            pathResolver: { .alarmKit },
            alarmKitScheduler: alarmKit,
            legacyScheduler: legacy,
            requestStore: AlarmScheduleRequestStore(fileURL: tempFileURL("fallback-schedule"))
        )

        let id = UUID()
        try await facade.scheduleAlarm(
            id: id,
            title: "Fallback",
            date: Date().addingTimeInterval(90),
            sound: "cockpitalert",
            snoozeEnabled: true
        )

        XCTAssertEqual(alarmKit.scheduledIDs, [id])
        XCTAssertEqual(legacy.scheduledIDs, [id])
    }

    private func makeAlarm(
        id: UUID,
        name: String,
        hour: Int,
        minute: Int,
        repeatMask: Int,
        snoozeMinutes: Int
    ) -> Alarm {
        Alarm(
            id: id,
            name: name,
            emoji: "⏰",
            hour: hour,
            minute: minute,
            isDaily: false,
            repeatMask: repeatMask,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "cockpitalert",
            soundVolume: 1.0,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: snoozeMinutes,
            snoozeCount: 0,
            wallpaperId: "default",
            createdAt: Date()
        )
    }

    private func tempFileURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("alarmo-tests-\(name)-\(UUID().uuidString).json")
    }
}

private final class MockScheduler: AlarmScheduler {
    let implementationName: String
    let isSupportedOnCurrentDevice: Bool

    var scheduleError: Error?
    var scheduledIDs: [UUID] = []
    var cancelledIDs: [UUID] = []
    var rescheduledIDs: [UUID] = []
    var snoozedIDs: [UUID] = []

    init(name: String, supported: Bool) {
        implementationName = name
        isSupportedOnCurrentDevice = supported
    }

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws {
        scheduledIDs.append(id)
        if let scheduleError {
            throw scheduleError
        }
    }

    func cancelAlarm(id: UUID) async {
        cancelledIDs.append(id)
    }

    func rescheduleAlarm(id: UUID, newDate: Date) async throws {
        rescheduledIDs.append(id)
    }

    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor] {
        []
    }

    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws {
        snoozedIDs.append(id)
    }

    func markAlarmFired(id: UUID) async {}
}

private final class MockLegacyScheduler: AlarmScheduler, AlarmSchedulerProtocol {
    let implementationName: String
    let isSupportedOnCurrentDevice: Bool

    var scheduledIDs: [UUID] = []
    var cancelledIDs: [UUID] = []

    init(name: String, supported: Bool) {
        implementationName = name
        isSupportedOnCurrentDevice = supported
    }

    func scheduleAlarm(
        id: UUID,
        title: String,
        date: Date,
        sound: String,
        snoozeEnabled: Bool
    ) async throws {
        scheduledIDs.append(id)
    }

    func cancelAlarm(id: UUID) async {
        cancelledIDs.append(id)
    }

    func rescheduleAlarm(id: UUID, newDate: Date) async throws {}
    func listScheduledAlarms() async -> [ScheduledAlarmDescriptor] { [] }
    func snoozeAlarm(id: UUID, interval: TimeInterval) async throws {}
    func markAlarmFired(id: UUID) async {}

    func schedule(alarm: Alarm) {
        scheduledIDs.append(alarm.id)
    }

    func cancel(alarmId: UUID) {
        cancelledIDs.append(alarmId)
    }

    func scheduleSnooze(alarm: Alarm, totalSeconds: Int) {}
    func cancelRuntimeRingNotifications(for alarm: Alarm) {}
}
