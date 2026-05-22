import Foundation
import Combine

final class OnboardingVolumeSettingsViewModel: ObservableObject {
    @Published var volume: Float
    @Published var gentleWakeUpEnabled: Bool
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false

    private let audioPlayer: AudioPreviewPlayerProtocol
    private var cancellables = Set<AnyCancellable>()
    private let selectedSoundURL: URL?

    init(volume: Float,
         gentleWakeUpEnabled: Bool,
         selectedSoundURL: URL?,
         audioPlayer: AudioPreviewPlayerProtocol = AudioPreviewPlayer.shared) {
        self.volume = volume
        self.gentleWakeUpEnabled = gentleWakeUpEnabled
        
        if let validURL = selectedSoundURL {
            self.selectedSoundURL = validURL
        } else {
            self.selectedSoundURL = SoundCatalogRepository().loadAllSounds().first?.fileURL
        }
        
        self.audioPlayer = audioPlayer
        
        if let player = audioPlayer as? AudioPreviewPlayer {
            player.$isPlaying
                .receive(on: RunLoop.main)
                .assign(to: \.isPlaying, on: self)
                .store(in: &cancellables)
            
            player.$isBuffering
                .receive(on: RunLoop.main)
                .assign(to: \.isBuffering, on: self)
                .store(in: &cancellables)
        }
    }

    var volumePercentText: String {
        "\(Int(volume * 100))%"
    }

    func preview() {
        guard let url = selectedSoundURL else { return }
        if isPlaying || isBuffering {
            audioPlayer.stop()
        } else {
            audioPlayer.play(url: url, volume: volume, fadeIn: gentleWakeUpEnabled)
        }
    }
    
    func stopPlayback() {
        audioPlayer.stop()
    }
}
