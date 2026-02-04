import AVFoundation
import Foundation

final class SoundPlayer {
    private var player: AVAudioPlayer?

    func playLooping(resourceName: String, volume: Float, fadeDuration: TimeInterval = 0) {
        stop()
        
        // Robust Lookup
        guard let url = findSoundURL(for: resourceName) else {
            print("[SoundPlayer] ❌ Could not find sound file for: \(resourceName)")
            return
        }

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

    func stop() {
        if player?.isPlaying == true {
           print("[SoundPlayer] ⏹️ Audio Stopped")
        }
        player?.stop()
        player = nil
    }
    
    private func findSoundURL(for name: String) -> URL? {
        // Try strict name first (e.g. "forest.mp3")
        if let url = Bundle.main.url(forResource: name, withExtension: nil) { return url }
        
        // Try cleaning name (e.g. "Forest" -> "forest.mp3" or "forest")
        let cleaned = name.replacingOccurrences(of: " ", with: "_").lowercased()
        
        // 1. Check known subfolder "BundledSounds/ringtones" with extension
        if let url = Bundle.main.url(forResource: cleaned, withExtension: "mp3", subdirectory: "BundledSounds/ringtones") {
            return url
        }
        
        // 2. Check root/flattened with extension
        if let url = Bundle.main.url(forResource: cleaned, withExtension: "mp3") {
            return url
        }
        
        // 3. Fallback: Check for ANY mp3 in specific folder unique to this app structure
        if let urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "BundledSounds/ringtones"), let first = urls.first {
             print("[SoundPlayer] ⚠️ Falling back to first found ringtone: \(first.lastPathComponent)")
             return first
        }
        
        return nil
    }
}
