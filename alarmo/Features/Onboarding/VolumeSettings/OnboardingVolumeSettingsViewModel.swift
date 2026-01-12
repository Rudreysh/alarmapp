import Foundation
import Combine

final class OnboardingVolumeSettingsViewModel: ObservableObject {
    @Published var volume: Float
    @Published var gentleWakeUpEnabled: Bool

    private let audioPlayer: AudioPreviewPlayerProtocol
    private let selectedSoundURL: URL?

    init(volume: Float,
         gentleWakeUpEnabled: Bool,
         selectedSoundURL: URL?,
         audioPlayer: AudioPreviewPlayerProtocol = AudioPreviewPlayer()) {
        self.volume = volume
        self.gentleWakeUpEnabled = gentleWakeUpEnabled
        self.selectedSoundURL = selectedSoundURL
        self.audioPlayer = audioPlayer
    }

    var volumePercentText: String {
        "\(Int(volume * 100))%"
    }

    func preview() {
        guard let url = selectedSoundURL else { return }
        audioPlayer.play(url: url, volume: volume, fadeIn: gentleWakeUpEnabled)
    }
}
