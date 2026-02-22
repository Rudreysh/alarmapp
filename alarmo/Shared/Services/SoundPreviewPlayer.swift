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
    static let shared = SoundPreviewPlayer()
    
    private var player: AVPlayer?
    private var localAudioPlayer: AVAudioPlayer?
    private let repository = SoundCatalogRepository()
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    
    @Published var isBuffering: Bool = false
    @Published var isPlaying: Bool = false
    @Published var playingResourceName: String? = nil
    @Published var spotifyPlaybackActive: Bool = false
    private var playRequestedAt: Date?
    private var isSpotifyPlaying = false
    
    /// Check saved tracks to find Spotify URI for a given resource name
    private func resolveSpotifyUri(for resourceName: String) -> String? {
        let savedTracks = UserDefaults.standard.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        if let trackData = savedTracks[resourceName] {
            if let uri = trackData["uri"], !uri.isEmpty {
                return uri
            }
            if let id = trackData["id"], !id.isEmpty {
                return "spotify:track:\(id)"
            }
        }
        return nil
    }
    
    /// Check if a cached preview file exists for this track
    private func cachedPreviewURL(for resourceName: String) -> URL? {
        let savedTracks = UserDefaults.standard.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        guard let trackData = savedTracks[resourceName], let id = trackData["id"], !id.isEmpty else { return nil }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cachedFile = documentsURL.appendingPathComponent("SpotifyPreviewCache/\(id).mp3")
        return FileManager.default.fileExists(atPath: cachedFile.path) ? cachedFile : nil
    }
    
    /// Check if a URL is a Spotify link (not a streamable audio file)
    private func isSpotifyLink(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        return urlString.contains("open.spotify.com") || urlString.hasPrefix("spotify:")
    }

    func play(resourceName: String, volume: Float) {
        stop()
        
        DispatchQueue.main.async {
            self.playingResourceName = resourceName
            self.spotifyPlaybackActive = false
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
        
        // Check for cached preview first
        if let cachedURL = cachedPreviewURL(for: resourceName) {
            print("[SoundPreviewPlayer] 🎵 Playing cached Spotify preview")
            playURL(cachedURL, volume: volume)
            return
        }
        
        // Check if this is a Spotify track (try Web API, NO app switching)
        if isSpotifyLink(asset.fileURL) || resolveSpotifyUri(for: resourceName) != nil {
            print("[SoundPreviewPlayer] Spotify track — using Web API playback")
            playSpotifyViaAPI(resourceName: resourceName)
            return
        }
        
        // Regular audio file
        let isRemote = !asset.fileURL.isFileURL
        if isRemote {
            DispatchQueue.main.async { self.isBuffering = true }
        }
        
        playURL(asset.fileURL, volume: volume)
    }
    
    private func playURL(_ url: URL, volume: Float) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
            player?.automaticallyWaitsToMinimizeStalling = true

            statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
                if item.status == .failed {
                    print("[SoundPreviewPlayer] Item failed: \(String(describing: item.error))")
                    DispatchQueue.main.async {
                        self.isBuffering = false
                        self.isPlaying = false
                    }
                }
            }

            timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { player, _ in
                DispatchQueue.main.async {
                    self.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                    self.isPlaying = player.timeControlStatus == .playing

                    if player.timeControlStatus == .playing, let requestedAt = self.playRequestedAt {
                        let latency = Date().timeIntervalSince(requestedAt)
                        print("[SoundPreviewPlayer] 🔊 Preview started. Latency: \(String(format: "%.2f", latency))s")
                        self.playRequestedAt = nil
                    }
                }
            }
            
            // Observe item end to reset UI state
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
                self?.isPlaying = false
            }

            player?.play()
        } catch {
            print("[SoundPreviewPlayer] Preview setup failed: \(error)")
        }
    }
    
    private func playSpotifyViaAPI(resourceName: String) {
        guard let uri = resolveSpotifyUri(for: resourceName) else {
            print("[SoundPreviewPlayer] No Spotify URI found for: \(resourceName)")
            // Fall back to a bundled sound for preview
            playFallbackPreview()
            return
        }
        
        DispatchQueue.main.async {
            self.isBuffering = true
        }
        
        isSpotifyPlaying = true
        
        Task {
            let controller = SpotifyPlaybackController.shared
            let success = await controller.playTrack(uri: uri)
            
            await MainActor.run {
                self.isBuffering = false
                
                if success {
                    self.isPlaying = true
                    self.spotifyPlaybackActive = true
                    print("[SoundPreviewPlayer] ✅ Spotify preview playing via Web API (stays in app!)")
                } else {
                    print("[SoundPreviewPlayer] ⚠️ Spotify Web API failed — playing fallback preview sound")
                    print("[SoundPreviewPlayer] ℹ️ To hear Spotify songs: Spotify Premium required + re-login in Settings")
                    self.isSpotifyPlaying = false
                    self.spotifyPlaybackActive = false
                    // Play a fallback bundled sound so the user hears something
                    self.playFallbackPreview()
                }
            }
        }
    }
    
    /// Plays a bundled alarm sound as fallback when Spotify preview fails
    private func playFallbackPreview() {
        // Try to find any MP3 in the bundle root (where Xcode flattens them)
        if let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil),
           let first = urls.first {
            print("[SoundPreviewPlayer] 🔊 Fallback preview: \(first.lastPathComponent)")
            playURL(first, volume: 0.7)
        } else if let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "BundledSounds/ringtones"),
                  let first = urls.first {
            print("[SoundPreviewPlayer] 🔊 Fallback preview (subdir): \(first.lastPathComponent)")
            playURL(first, volume: 0.7)
        } else {
            print("[SoundPreviewPlayer] ❌ No fallback sound available for preview")
            DispatchQueue.main.async {
                self.playingResourceName = nil
                self.isPlaying = false
            }
        }
    }

    func stop() {
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player = nil
        localAudioPlayer?.stop()
        localAudioPlayer = nil
        
        // Stop Spotify playback if active
        if isSpotifyPlaying {
            isSpotifyPlaying = false
            Task {
                await SpotifyPlaybackController.shared.pause()
            }
        }
        
        DispatchQueue.main.async { 
            self.isBuffering = false 
            self.isPlaying = false
            self.playingResourceName = nil
            self.spotifyPlaybackActive = false
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
        
        play(resourceName: resourceName, volume: 0)
        
        let steps = 40
        let timeStep = duration / Double(steps)
        
        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: timeStep, repeats: true) { [weak self] timer in
            guard let self = self, self.playingResourceName == resourceName else {
                timer.invalidate()
                return
            }
            
            guard self.isPlaying else { return }
            
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
