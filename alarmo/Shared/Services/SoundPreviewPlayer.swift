import Foundation
import AVFoundation

protocol SoundPreviewPlayerProtocol {
    func play(resourceName: String, volume: Float)
    func stop()
}

final class SoundPreviewPlayer: SoundPreviewPlayerProtocol {
    private var player: AVAudioPlayer?

    func play(resourceName: String, volume: Float) {
        stop()
        let cleaned = resourceName.replacingOccurrences(of: " ", with: "_").lowercased()
        let url = Bundle.main.url(forResource: cleaned, withExtension: "mp3", subdirectory: "BundledSounds/ringtones")
            ?? Bundle.main.url(forResource: cleaned, withExtension: "mp3")
        guard let url else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = volume
            player?.play()
        } catch {
            return
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
