import AVFoundation
import Foundation

final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var spotifyPlaybackActive = false
    private var spotifyTrackUri: String?

    func playLooping(resourceName: String, volume: Float, fadeDuration: TimeInterval = 0) {
        stop()
        
        // Check if this is a Spotify track
        let spotifyInfo = resolveSpotifyTrack(resourceName: resourceName)
        
        if let trackUri = spotifyInfo.trackUri {
            // --- SPOTIFY TRACK ---
            // Strategy: Try Web API playback + always play fallback alarm as safety net.
            // User NEVER leaves the Alarmo app.
            print("[SoundPlayer] 🎵 Spotify alarm: \(resourceName) → \(trackUri)")
            spotifyTrackUri = trackUri
            spotifyPlaybackActive = true
            
            // First, check if we have a cached preview file
            if let cachedURL = spotifyInfo.cachedPreviewURL {
                print("[SoundPlayer] 🎵 Playing cached Spotify preview: \(cachedURL.lastPathComponent)")
                playLocalFile(url: cachedURL, volume: volume, fadeDuration: fadeDuration)
                return
            }
            
            // Try Spotify Web API playback (background, no app switch)
            Task {
                let controller = SpotifyPlaybackController.shared
                await controller.setVolume(Int(volume * 100))
                let success = await controller.playTrack(uri: trackUri)
                
                if success {
                    print("[SoundPlayer] ✅ Spotify is playing via Web API: \(resourceName)")
                    // Spotify is playing through its own audio — we're done.
                    // The fallback alarm below provides a safety backup.
                } else {
                    print("[SoundPlayer] ⚠️ Spotify Web API failed — fallback alarm is the only sound")
                }
            }
            
            // ALWAYS play a fallback alarm sound immediately.
            // - If Spotify API works: this plays quietly as a backup.
            // - If Spotify API fails: this is the alarm sound the user hears.
            let fallbackVolume = volume // Full volume — this IS the alarm if Spotify fails
            playFallbackSound(volume: fallbackVolume, fadeDuration: fadeDuration)
            
        } else {
            // --- REGULAR (non-Spotify) SOUND ---
            guard let url = findSoundURL(for: resourceName) else {
                print("[SoundPlayer] ❌ Could not find sound file for: \(resourceName)")
                return
            }
            playLocalFile(url: url, volume: volume, fadeDuration: fadeDuration)
        }
    }

    func stop() {
        if player?.isPlaying == true {
           print("[SoundPlayer] ⏹️ Audio Stopped")
        }
        player?.stop()
        player = nil
        
        // Also stop Spotify playback if active
        if spotifyPlaybackActive {
            spotifyPlaybackActive = false
            Task {
                let paused = await SpotifyPlaybackController.shared.pause()
                print("[SoundPlayer] ⏹️ Spotify paused: \(paused)")
            }
            spotifyTrackUri = nil
        }
    }
    
    // MARK: - Spotify Track Resolution
    
    private struct SpotifyTrackInfo {
        let trackUri: String?
        let trackId: String?
        let cachedPreviewURL: URL? // Local file if we downloaded the preview
    }
    
    /// Checks if the given resource name corresponds to a saved Spotify track.
    /// Returns the Spotify URI and optionally a cached local preview file.
    private func resolveSpotifyTrack(resourceName: String) -> SpotifyTrackInfo {
        let savedTracks = UserDefaults.standard.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        
        guard let trackData = savedTracks[resourceName] else {
            return SpotifyTrackInfo(trackUri: nil, trackId: nil, cachedPreviewURL: nil)
        }
        
        let uri = trackData["uri"] ?? ""
        let id = trackData["id"] ?? ""
        
        // Check for cached preview file
        var cachedURL: URL? = nil
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let cacheDir = documentsURL.appendingPathComponent("SpotifyPreviewCache")
            let cachedFile = cacheDir.appendingPathComponent("\(id).mp3")
            if FileManager.default.fileExists(atPath: cachedFile.path) {
                cachedURL = cachedFile
            }
        }
        
        let trackUri: String?
        if !uri.isEmpty {
            trackUri = uri
        } else if !id.isEmpty {
            trackUri = "spotify:track:\(id)"
        } else {
            trackUri = nil
        }
        
        return SpotifyTrackInfo(trackUri: trackUri, trackId: id, cachedPreviewURL: cachedURL)
    }
    
    // MARK: - Local Playback
    
    private func playLocalFile(url: URL, volume: Float, fadeDuration: TimeInterval) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            
            if fadeDuration > 0 {
                player?.volume = 0
                player?.play()
                player?.setVolume(volume, fadeDuration: fadeDuration)
                print("[SoundPlayer] ▶️ Playing with Fade (\(fadeDuration)s): \(url.lastPathComponent) (Target Vol: \(volume))")
            } else {
                player?.volume = volume
                player?.play()
                print("[SoundPlayer] ▶️ Playing: \(url.lastPathComponent) (Vol: \(volume))")
            }
        } catch {
             print("[SoundPlayer] ❌ Error configuring audio: \(error)")
        }
    }
    
    private func playFallbackSound(volume: Float, fadeDuration: TimeInterval) {
        guard let url = findFallbackSound() else {
            print("[SoundPlayer] ❌ No fallback sound available")
            return
        }
        playLocalFile(url: url, volume: volume, fadeDuration: fadeDuration)
    }
    
    // MARK: - Sound Lookup
    
    private func findSoundURL(for name: String) -> URL? {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        
        // Allowed extensions (we can expand this if needed)
        let extensions = ["mp3", "wav", "m4a", "caf"]
        
        let cleanedName = name.replacingOccurrences(of: " ", with: "_").lowercased()
        let dashCleanedName = name.replacingOccurrences(of: " ", with: "-").lowercased()
        
        // 1. First, quickly check custom downloaded sounds in Documents
        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customDir = docsURL.appendingPathComponent("CustomSounds")
            for ext in extensions {
                let customFile = customDir.appendingPathComponent("\(name).\(ext)")
                if fileManager.fileExists(atPath: customFile.path) { return customFile }
            }
        }
        
        // 2. Perform a recursive deep search in the app bundle
        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let fileExt = fileURL.pathExtension.lowercased()
                
                if extensions.contains(fileExt) {
                    // Try exact match, cleaned match, or dash-cleaned match
                    if filename == name || 
                       filename.lowercased() == name.lowercased() ||
                       filename.lowercased() == cleanedName ||
                       filename.lowercased() == dashCleanedName {
                        return fileURL
                    }
                }
            }
        }
        
        // 3. Fallback — any bundled ringtone
        return findFallbackSound()
    }
    
    /// Returns the first available bundled ringtone as a fallback
    private func findFallbackSound() -> URL? {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let extensions = ["mp3", "wav", "m4a", "caf"]
        
        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.isFileURL {
                    let ext = fileURL.pathExtension.lowercased()
                    if extensions.contains(ext) {
                        print("[SoundPlayer] ⚠️ Using fallback ringtone: \(fileURL.lastPathComponent)")
                        return fileURL
                    }
                }
            }
        }
        
        print("[SoundPlayer] ❌ CRITICAL: No audio files found anywhere in app bundle!")
        return nil
    }
}
