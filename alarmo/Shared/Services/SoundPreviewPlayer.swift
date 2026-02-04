import Foundation
import AVFoundation
import Combine
import SwiftUI

protocol SoundPreviewPlayerProtocol {
    var isBuffering: Bool { get }
    var isPlaying: Bool { get }
    func play(resourceName: String, volume: Float)
    func stop()
    func setVolume(_ volume: Float)
}

final class SoundPreviewPlayer: ObservableObject, SoundPreviewPlayerProtocol {
    private var player: AVPlayer?
    private let repository = SoundCatalogRepository()
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    
    @Published var isBuffering: Bool = false
    @Published var isPlaying: Bool = false
    @Published var playingResourceName: String? = nil
    private var playRequestedAt: Date?

    func play(resourceName: String, volume: Float) {
        stop()
        
        DispatchQueue.main.async {
            self.playingResourceName = resourceName
        }
        
        let now = Date()
        self.playRequestedAt = now
        print("[SoundPreviewPlayer] Playback requested at: \(now.formatted(date: .omitted, time: .complete))")

        let allSounds = repository.loadAllSounds()
        guard let asset = allSounds.first(where: { $0.title == resourceName }) else {
            print("[SoundPreviewPlayer] Could not find sound asset for: \(resourceName)")
            return
        }
        
        print("[SoundPreviewPlayer] Playing: \(asset.title) URL: \(asset.fileURL)")
        let isRemote = !asset.fileURL.isFileURL
        
        if isRemote {
            DispatchQueue.main.async { self.isBuffering = true }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            
            let playerItem = AVPlayerItem(url: asset.fileURL)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
            player?.automaticallyWaitsToMinimizeStalling = true

            // Monitor Status
            statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
                if item.status == .failed {
                    print("[SoundPreviewPlayer] Item Failed: \(String(describing: item.error))")
                    DispatchQueue.main.async { self.isBuffering = false }
                }
            }

            // Monitor state
            timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { player, _ in
                DispatchQueue.main.async {
                    self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    self.isPlaying = player.timeControlStatus == .playing
                    
                    if player.timeControlStatus == .playing, let requestedAt = self.playRequestedAt {
                        let latency = Date().timeIntervalSince(requestedAt)
                        print("[SoundPreviewPlayer] 🔊 Sound started playing! Latency: \(String(format: "%.2f", latency)) seconds.")
                        self.playRequestedAt = nil
                    }
                }
            }

            player?.play()
        } catch {
            print("[SoundPreviewPlayer] Player setup failed: \(error)")
        }
    }

    func stop() {
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player = nil
        DispatchQueue.main.async { 
            self.isBuffering = false 
            self.isPlaying = false
            self.playingResourceName = nil
        }
    }
    
    func setVolume(_ volume: Float) {
        player?.volume = volume
    }
    
    func playWithFade(resourceName: String, duration: TimeInterval, maxVolume: Float) {
        if duration <= 0 {
            play(resourceName: resourceName, volume: maxVolume)
            return
        }
        
        // Start playing at 0 volume
        play(resourceName: resourceName, volume: 0)
        
        let steps = 40 // More steps for smoother fade
        let timeStep = duration / Double(steps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] timer in
            guard let self = self, self.playingResourceName == resourceName else {
                timer.invalidate()
                return
            }
            
            // Wait for it to actually start playing before ramping volume
            // But don't invalidate if it's just buffering
            guard self.isPlaying else { return }
            
            // Linear progression of step, but we could make it exponential if needed.
            // For now, let's just make it reliably work.
            let progress = Float(currentStep) / Float(steps)
            let newVolume = progress * maxVolume
            
            if currentStep >= steps {
                self.setVolume(maxVolume)
                timer.invalidate()
            } else {
                self.setVolume(newVolume)
                currentStep += 1
            }
        }
    }
}
