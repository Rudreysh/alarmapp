import XCTest
@testable import alarmo

final class AlarmStoreTests: XCTestCase {
    func test_persistAndReload() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("alarms.json")

        let store = AlarmStore(fileURL: fileURL)
        let alarm = Alarm(
            id: UUID(),
            name: "Test",
            emoji: "🌞",
            hour: 7,
            minute: 30,
            isDaily: true,
            repeatMask: RepeatMask.allDays,
            enabled: true,
            createdAt: Date()
        )
        store.add(alarm)

        let reloaded = AlarmStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.alarms.count, 1)
        XCTAssertEqual(reloaded.alarms.first?.name, "Test")
    }
}
