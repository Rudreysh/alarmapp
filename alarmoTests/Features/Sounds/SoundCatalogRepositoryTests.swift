import XCTest
@testable import alarmo

final class SoundCatalogRepositoryTests: XCTestCase {
    func test_loadBundledSounds_mapsTitlesAndCategories() throws {
        // Setup
        let tempDir = try TestHelpers.makeTempDirectory()
        let url1 = tempDir.appendingPathComponent("alarm_tone_test.mp3")
        let url2 = tempDir.appendingPathComponent("vivaldi_winter.mp3")
        FileManager.default.createFile(atPath: url1.path, contents: Data())
        FileManager.default.createFile(atPath: url2.path, contents: Data())

        // Create Mocks
        let mockDefinitions = [
            SoundConfig.SoundDefinition(filename: "alarm_tone_test.mp3"),
            SoundConfig.SoundDefinition(filename: "vivaldi_winter.mp3")
        ]
        
        let mockLookup: (String, String?) -> URL? = { filename, _ in
            if filename == "alarm_tone_test.mp3" { return url1 }
            if filename == "vivaldi_winter.mp3" { return url2 }
            return nil
        }
        
        // Execute
        let repo = SoundCatalogRepository(soundDefinitions: mockDefinitions, bundleLookup: mockLookup)
        let sounds = try repo.loadBundledSounds()

        // Assert
        XCTAssertEqual(sounds.count, 2)
        
        // Check sorting/mapping
        // The order depends on the input definitions order
        let alarmSound = sounds.first { $0.title == "Alarm Tone Test" }
        XCTAssertNotNil(alarmSound)
        XCTAssertEqual(alarmSound?.category, .alarmTone)
        
        let classicSound = sounds.first { $0.title == "Vivaldi Winter" }
        XCTAssertNotNil(classicSound)
        XCTAssertEqual(classicSound?.category, .classic)
    }
}
