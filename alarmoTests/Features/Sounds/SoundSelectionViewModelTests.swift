import XCTest
@testable import alarmo

final class SoundSelectionViewModelTests: XCTestCase {
    func test_selectingCategory_filters() {
        let mockRepo = MockSoundCatalogRepository(sounds: [
            SoundAsset(id: "1", title: "A", fileURL: URL(fileURLWithPath: "/tmp/a.mp3"), category: .loud),
            SoundAsset(id: "2", title: "B", fileURL: URL(fileURLWithPath: "/tmp/b.mp3"), category: .classic)
        ])
        let mockPlayer = MockAudioPreviewPlayer()
        let viewModel = OnboardingSoundSelectionViewModel(repository: mockRepo, audioPlayer: mockPlayer)

        viewModel.selectCategory(.classic)
        XCTAssertEqual(viewModel.soundsForSelectedCategory().count, 1)
    }

    func test_tapSound_playsAndStops() {
        let sound = SoundAsset(id: "1", title: "A", fileURL: URL(fileURLWithPath: "/tmp/a.mp3"), category: .loud)
        let mockRepo = MockSoundCatalogRepository(sounds: [sound])
        let mockPlayer = MockAudioPreviewPlayer()
        let viewModel = OnboardingSoundSelectionViewModel(repository: mockRepo, audioPlayer: mockPlayer)

        viewModel.tapSound(sound, volume: 0.8)
        XCTAssertEqual(viewModel.nowPlayingSoundId, "1")
        XCTAssertTrue(mockPlayer.playCalled)

        viewModel.tapSound(sound, volume: 0.8)
        XCTAssertNil(viewModel.nowPlayingSoundId)
        XCTAssertTrue(mockPlayer.stopCalled)
    }
}

private struct MockSoundCatalogRepository: SoundCatalogRepositoryProtocol {
    let sounds: [SoundAsset]
    func loadBundledSounds() throws -> [SoundAsset] { sounds }
}

private final class MockAudioPreviewPlayer: AudioPreviewPlayerProtocol {
    private(set) var playCalled = false
    private(set) var stopCalled = false
    var isPlaying: Bool { false }

    func play(url: URL, volume: Float, fadeIn: Bool) {
        playCalled = true
    }

    func stop() {
        stopCalled = true
    }
}
