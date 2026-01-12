import AVFoundation
import Foundation

protocol AudioPreviewPlayerProtocol {
    var isPlaying: Bool { get }
    func play(url: URL, volume: Float, fadeIn: Bool)
    func stop()
}

final class AudioPreviewPlayer: AudioPreviewPlayerProtocol {
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?

    var isPlaying: Bool { player?.isPlaying == true }

    func play(url: URL, volume: Float, fadeIn: Bool) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = fadeIn ? 0.0 : volume
            player?.play()
            if fadeIn {
                rampVolume(to: volume, duration: 3.0)
            }
        } catch {
            return
        }
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.stop()
        player = nil
    }

    private func rampVolume(to target: Float, duration: TimeInterval) {
        fadeTimer?.invalidate()
        let steps = 20
        let interval = duration / Double(steps)
        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { return }
            currentStep += 1
            let progress = min(Float(currentStep) / Float(steps), 1)
            self.player?.volume = target * progress
            if progress >= 1 {
                timer.invalidate()
            }
        }
    }
}
