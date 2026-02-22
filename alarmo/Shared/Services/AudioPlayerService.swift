import AVFoundation
import Foundation
import Combine

protocol AudioPreviewPlayerProtocol {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    func play(url: URL, volume: Float, fadeIn: Bool)
    func stop()
}

final class AudioPreviewPlayer: ObservableObject, AudioPreviewPlayerProtocol {
    static let shared = AudioPreviewPlayer()
    
    private var player: AVPlayer?
    private var fadeTimer: Timer?
    private var playRequestedAt: Date?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false

    init() {} // Keep public for now to avoid breaking other inits, but encourage shared use

    func play(url: URL, volume: Float, fadeIn: Bool) {
        stop()
        
        print("[AudioPreviewPlayer] 🎵 Requesting Playback - URL: \(url.absoluteString)")
        let now = Date()
        self.playRequestedAt = now
        print("[AudioPreviewPlayer] Playback requested at: \(now.formatted(date: .omitted, time: .complete))")
        
        let isRemote = !url.isFileURL
        
        if isRemote {
            DispatchQueue.main.async { self.isBuffering = true }
        }

        // Setup Session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[AudioPreviewPlayer] Session setup failed: \(error)")
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = (fadeIn && !isRemote) ? 0.0 : volume
        player?.automaticallyWaitsToMinimizeStalling = true
        
        // Monitor timeControlStatus (Better for buffering detection)
        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { player, _ in
            DispatchQueue.main.async {
                self.isPlaying = player.timeControlStatus == .playing
                self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                
                if player.timeControlStatus == .playing, let requestedAt = self.playRequestedAt {
                    let latency = Date().timeIntervalSince(requestedAt)
                    print("[AudioPreviewPlayer] 🔊 Sound started playing! Latency: \(String(format: "%.2f", latency)) seconds.")
                    self.playRequestedAt = nil // Reset
                }
            }
        }

        // Monitor Status for errors
        statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            if item.status == .failed {
                print("[AudioPreviewPlayer] Item Failed: \(String(describing: item.error))")
                DispatchQueue.main.async { self.isBuffering = false }
            }
        }
        
        player?.play()
        
        if fadeIn && !isRemote {
            rampVolume(to: volume, duration: 30.0)
        }
    }

    func stop() {
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.pause()
        player = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isBuffering = false
        }
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
