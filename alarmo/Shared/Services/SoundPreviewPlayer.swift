import Foundation
import AVFoundation
import Combine
import SwiftUI

protocol SoundPreviewPlayerProtocol {
    var isBuffering: Bool { get }
    var isPlaying: Bool { get }
    func play(resourceName: String, volume: Float)
    func stop()
}

final class SoundPreviewPlayer: ObservableObject, SoundPreviewPlayerProtocol {
    private var player: AVPlayer?
    private let repository = SoundCatalogRepository()
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    
    @Published var isBuffering: Bool = false
    @Published var isPlaying: Bool = false
    private var playRequestedAt: Date?

    func play(resourceName: String, volume: Float) {
        stop()
        
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
        }
    }
}
