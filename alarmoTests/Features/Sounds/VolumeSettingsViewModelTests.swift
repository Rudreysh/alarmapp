import XCTest
@testable import alarmo

final class VolumeSettingsViewModelTests: XCTestCase {
    func test_volumePercentText_updates() {
        let mockPlayer = MockAudioPreviewPlayer()
        let viewModel = OnboardingVolumeSettingsViewModel(volume: 0.95, gentleWakeUpEnabled: true, selectedSoundURL: nil, audioPlayer: mockPlayer)
        XCTAssertEqual(viewModel.volumePercentText, "95%")
    }

    func test_preview_usesAudioPlayer() {
        let mockPlayer = MockAudioPreviewPlayer()
        let url = URL(fileURLWithPath: "/tmp/a.mp3")
        let viewModel = OnboardingVolumeSettingsViewModel(volume: 0.5, gentleWakeUpEnabled: true, selectedSoundURL: url, audioPlayer: mockPlayer)
        viewModel.preview()
        XCTAssertTrue(mockPlayer.playCalled)
    }
}

private final class MockAudioPreviewPlayer: AudioPreviewPlayerProtocol {
    private(set) var playCalled = false
    var isPlaying: Bool { false }

    func play(url: URL, volume: Float, fadeIn: Bool) {
        playCalled = true
    }

    func stop() { }
}
