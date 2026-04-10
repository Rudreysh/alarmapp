import Foundation
import AVFoundation
import AudioToolbox
import Combine
import SwiftUI
import Darwin

protocol SoundPreviewPlayerProtocol {
    var isBuffering: Bool { get }
    var isPlaying: Bool { get }
    func play(resourceName: String, volume: Float)
    func stop()
    func setVolume(_ volume: Float)
}

final class SoundPreviewPlayer: NSObject, ObservableObject, SoundPreviewPlayerProtocol, AVAudioPlayerDelegate {
    static let shared = SoundPreviewPlayer()
    
    private var player: AVPlayer?
    private var localAudioPlayer: AVAudioPlayer?
    private let repository = SoundCatalogRepository()
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    
    // Simulator-only: PID of afplay subprocess (macOS /usr/bin/afplay, bypasses iOS audio bridge)
    private var afplayPID: pid_t = 0
    // Simulator-only: Path to the file being played by afplay (for cleanup)
    private var afplayTempPath: String? = nil
    // Simulator-only: downloaded temp file played via AVAudioPlayer (remote previews)
    private var simulatorPreviewTempPath: String? = nil
    // Guards async simulator preview/export tasks from racing after repeated taps
    private var activePreviewRequestID = UUID()
    // One-time host diagnostics for simulator audio failures
    private var hasLoggedSimulatorAudioDiagnostics = false
    
    @Published var isBuffering: Bool = false
    @Published var isPlaying: Bool = false
    @Published var playingResourceName: String? = nil
    @Published var spotifyPlaybackActive: Bool = false
    private var playRequestedAt: Date?
    private var isSpotifyPlaying = false

    private func beginPreviewRequest(reason: String) -> UUID {
        let id = UUID()
        activePreviewRequestID = id
        print("[SoundPreviewPlayer] 🧭 New preview request \(id.uuidString.prefix(8)) (\(reason))")
        return id
    }

    private func isCurrentPreviewRequest(_ id: UUID) -> Bool {
        activePreviewRequestID == id
    }
    
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

    private func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    func play(resourceName: String, volume: Float) {
        stop()
        _ = beginPreviewRequest(reason: "play:\(resourceName)")
        
        DispatchQueue.main.async {
            self.playingResourceName = resourceName
            self.spotifyPlaybackActive = false
        }
        
        let now = Date()
        self.playRequestedAt = now
        print("[SoundPreviewPlayer] Playback requested at: \(now.formatted(date: .omitted, time: .complete))")

        let allSounds = repository.loadAllSounds()
        let normalizedTarget = normalizedTitle(resourceName)
        guard let asset = allSounds.first(where: { normalizedTitle($0.title) == normalizedTarget }) else {
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
        print("[SoundPreviewPlayer] 🔍 DIAG — isFileURL: \(asset.fileURL.isFileURL) | isRemote: \(isRemote) | url: \(asset.fileURL.absoluteString)")
        
        playURL(asset.fileURL, volume: volume)
    }
    
    private func playURL(_ url: URL, volume: Float) {
        print("[SoundPreviewPlayer] 🔍 playURL() — isFileURL: \(url.isFileURL) | \(url.lastPathComponent)")
        #if targetEnvironment(simulator)
        // ─────────────────────────────────────────────────────────────────────
        // SIMULATOR: Every iOS audio API fails on this Mac (HALC bridge broken).
        //   AVPlayer  → -12746  | AVAudioPlayer → -66680 | AudioServices → silent
        //   NSSound   → class not found | afplay direct → 'fmt?' (bad MP3 encoding)
        //
        // Working solution (two steps):
        //   1. AVAssetExportSession → temp .m4a  (pure CPU transcode, any input format)
        //   2. afplay <temp.m4a>                  (macOS CoreAudio, bypasses iOS bridge)
        // ─────────────────────────────────────────────────────────────────────
        let requestID = activePreviewRequestID
        Task {
            await self.playSimulatorPreviewViaAfplay(url, volume: volume, requestID: requestID)
        }
        #endif
        #if targetEnvironment(simulator)
        return
        #endif

        // ── Device (or remote URL on Simulator): AVFoundation path ───────────
        do {
            try AudioRouteManager.configurePlaybackSession(duckOthers: true)
        } catch {
            print("[SoundPreviewPlayer] ⚠️ AVAudioSession setup error: \(error.localizedDescription)")
        }
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("[SoundPreviewPlayer] ❌ Local file does not exist: \(url.path)")
                DispatchQueue.main.async {
                    self.playingResourceName = nil
                    self.isPlaying = false
                    self.isBuffering = false
                }
                return
            }
            print("[SoundPreviewPlayer] ✅ Local file verified at: \(url.path)")
        } else {
            print("[SoundPreviewPlayer] 🌐 Remote URL: \(url.absoluteString)")
        }

        // ── AVPlayer (remote URLs, or any URL on a real device) ──────────────

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.volume = volume
        avPlayer.automaticallyWaitsToMinimizeStalling = !url.isFileURL
        
        self.player = avPlayer
        
        statusObserver = playerItem.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                if item.status == .failed {
                    print("[SoundPreviewPlayer] ❌ Item failed: \(String(describing: item.error))")
                    if let underlying = (item.error as NSError?)?.userInfo["NSUnderlyingError"] as? NSError {
                         print("[SoundPreviewPlayer] ❌ Underlying error: \(underlying.debugDescription)")
                    }
                    self.isBuffering = false
                    self.isPlaying = false
                    self.playingResourceName = nil
                } else if item.status == .readyToPlay {
                    print("[SoundPreviewPlayer] ✅ Item ready to play.")
                }
            }
        }

        timeControlObserver = avPlayer.observe(\.timeControlStatus, options: [.new]) { p, _ in
            DispatchQueue.main.async {
                self.isBuffering = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.isPlaying = p.timeControlStatus == .playing
                
                if p.timeControlStatus == .playing, let requestedAt = self.playRequestedAt {
                    let latency = Date().timeIntervalSince(requestedAt)
                    print("[SoundPreviewPlayer] 🔊 Playback started. Latency: \(String(format: "%.2f", latency))s")
                    self.playRequestedAt = nil
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            self?.isPlaying = false
            if self?.playingResourceName == url.lastPathComponent.replacingOccurrences(of: ".\(url.pathExtension)", with: "") {
                self?.playingResourceName = nil
            }
        }

        print("[SoundPreviewPlayer] 🏁 Calling player.play() for: \(url.lastPathComponent)")
        avPlayer.play()
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

    // MARK: - Simulator Helpers

    @MainActor
    private func playSimulatorPreviewViaAfplay(_ url: URL, volume: Float, requestID: UUID) async {
        guard isCurrentPreviewRequest(requestID) else {
            print("[SoundPreviewPlayer] ⏭️ Ignoring stale simulator preview task before start (\(requestID.uuidString.prefix(8)))")
            return
        }
        let localSourceURL: URL

        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("[SoundPreviewPlayer] ❌ File missing: \(url.path)")
                isPlaying = false
                isBuffering = false
                playingResourceName = nil
                return
            }
            localSourceURL = url
        } else {
            isBuffering = true
            guard let downloadedURL = await downloadRemotePreviewToTemp(url) else {
                print("[SoundPreviewPlayer] ❌ Remote preview download failed on simulator")
                isPlaying = false
                isBuffering = false
                playingResourceName = nil
                return
            }
            guard isCurrentPreviewRequest(requestID) else {
                print("[SoundPreviewPlayer] ⏭️ Stale simulator preview task after download (\(requestID.uuidString.prefix(8)))")
                try? FileManager.default.removeItem(at: downloadedURL)
                return
            }
            localSourceURL = downloadedURL
        }

        // First try native AVAudioPlayer on the simulator (same mechanism used by SoundPlayer,
        // which is already proven to work in Pomodoro in this session).
        if playSimulatorPreviewWithAVAudioPlayer(
            localSourceURL,
            volume: volume,
            deleteTempAfterPlay: !url.isFileURL
        ) {
            print("[SoundPreviewPlayer] ✅ Simulator preview playing via AVAudioPlayer")
            return
        }
        print("[SoundPreviewPlayer] ⚠️ AVAudioPlayer simulator preview failed — falling back to export+afplay")

        isBuffering = true
        print("[SoundPreviewPlayer] ⏱️ Exporting 20s .m4a preview (handles any source format)...")
        guard let m4aURL = await exportTrimmedPreview(from: localSourceURL, maxDuration: 20.0) else {
            if !url.isFileURL { try? FileManager.default.removeItem(at: localSourceURL) }
            print("[SoundPreviewPlayer] ❌ Export failed — no preview on simulator")
            isPlaying = false
            isBuffering = false
            playingResourceName = nil
            return
        }
        if !url.isFileURL { try? FileManager.default.removeItem(at: localSourceURL) }
        guard isCurrentPreviewRequest(requestID) else {
            print("[SoundPreviewPlayer] ⏭️ Stale simulator preview task after export (\(requestID.uuidString.prefix(8)))")
            try? FileManager.default.removeItem(at: m4aURL)
            return
        }

        print("[SoundPreviewPlayer] ✅ Export → \(m4aURL.lastPathComponent), launching afplay...")
        isBuffering = false
        if !playWithAfplay(m4aURL, volume: volume, deleteTempAfterPlay: true) {
            try? FileManager.default.removeItem(at: m4aURL)
            isPlaying = false
            isBuffering = false
            playingResourceName = nil
        }
    }

    @MainActor
    @discardableResult
    private func playSimulatorPreviewWithAVAudioPlayer(_ url: URL, volume: Float, deleteTempAfterPlay: Bool) -> Bool {
        do {
            try AudioRouteManager.configurePlaybackSession(duckOthers: true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = 0
            player.volume = volume
            player.prepareToPlay()

            guard player.play() else {
                print("[SoundPreviewPlayer] ❌ AVAudioPlayer.play() returned false for \(url.lastPathComponent)")
                return false
            }

            localAudioPlayer = player
            simulatorPreviewTempPath = deleteTempAfterPlay ? url.path : nil
            isBuffering = false
            isPlaying = true
            if let requestedAt = playRequestedAt {
                let latency = Date().timeIntervalSince(requestedAt)
                print("[SoundPreviewPlayer] 🔊 AVAudioPlayer preview started. Latency: \(String(format: "%.2f", latency))s")
                playRequestedAt = nil
            }
            return true
        } catch {
            print("[SoundPreviewPlayer] ❌ AVAudioPlayer simulator preview error: \(error)")
            return false
        }
    }

    private func downloadRemotePreviewToTemp(_ remoteURL: URL) async -> URL? {
        do {
            print("[SoundPreviewPlayer] 🌐 Downloading remote preview for simulator: \(remoteURL.absoluteString)")
            let (tmpURL, response) = try await URLSession.shared.download(from: remoteURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[SoundPreviewPlayer] ❌ Remote preview HTTP status: \(http.statusCode)")
                try? FileManager.default.removeItem(at: tmpURL)
                return nil
            }

            let ext = remoteURL.pathExtension.isEmpty ? "bin" : remoteURL.pathExtension
            let localURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("alarmo_remote_preview_\(UUID().uuidString).\(ext)")

            if FileManager.default.fileExists(atPath: localURL.path) {
                try? FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: localURL)
            return localURL
        } catch {
            print("[SoundPreviewPlayer] ❌ Remote preview download error: \(error)")
            return nil
        }
    }

    private func didExitNormally(_ status: Int32) -> Bool {
        (status & 0x7f) == 0
    }

    private func exitCode(from status: Int32) -> Int32 {
        (status >> 8) & 0xff
    }

    private func wasTerminatedBySignal(_ status: Int32) -> Bool {
        let signalBits = status & 0x7f
        return signalBits != 0 && signalBits != 0x7f
    }

    private func terminatingSignal(from status: Int32) -> Int32 {
        status & 0x7f
    }

    private func logSimulatorAudioDiagnosticsIfNeeded(trigger: String) {
        #if targetEnvironment(simulator)
        guard !hasLoggedSimulatorAudioDiagnostics else { return }
        hasLoggedSimulatorAudioDiagnostics = true

        print("[SoundPreviewPlayer] 🧪 Simulator audio diagnostics (\(trigger))")
        print("[SoundPreviewPlayer] 🧪 isSimulator=true | HOME=\(NSHomeDirectory())")
        let env = ProcessInfo.processInfo.environment
        let interesting = env.keys
            .filter { $0.hasPrefix("SIMULATOR_") || $0.hasPrefix("DYLD_") || $0 == "AUDIODEV" }
            .sorted()
        for key in interesting {
            print("[SoundPreviewPlayer] 🧪 env \(key)=\(env[key] ?? "")")
        }

        do {
            let session = AVAudioSession.sharedInstance()
            print("[SoundPreviewPlayer] 🧪 AVAudioSession category=\(session.category.rawValue) mode=\(session.mode.rawValue)")
            let route = session.currentRoute
            let outputs = route.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
            let inputs = route.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
            print("[SoundPreviewPlayer] 🧪 Route outputs=[\(outputs)] inputs=[\(inputs)]")
            print("[SoundPreviewPlayer] 🧪 secondaryAudioShouldBeSilencedHint=\(session.secondaryAudioShouldBeSilencedHint)")
        } catch {
            print("[SoundPreviewPlayer] 🧪 AVAudioSession diagnostic error: \(error)")
        }
        #endif
    }

    /// Launches /usr/bin/afplay as a macOS subprocess via posix_spawn.
    /// afplay uses macOS CoreAudio DIRECTLY, 100% outside the broken iOS audio bridge.
    @discardableResult
    private func playWithAfplay(_ url: URL, volume: Float, deleteTempAfterPlay: Bool) -> Bool {
        stopAfplayProcess()  // kill any previous instance and clean up

        let afplayPath = "/usr/bin/afplay"
        guard FileManager.default.fileExists(atPath: afplayPath) else {
            print("[SoundPreviewPlayer] ❌ /usr/bin/afplay not found")
            return false
        }

        let volStr = String(format: "%.4f", min(max(Double(volume), 0), 2))
        print("[SoundPreviewPlayer] 🔍 Launching host afplay: volume=\(volStr) file=\(url.lastPathComponent)")

        // ─────────────────────────────────────────────────────────────────────
        // CLEAN ENVIRONMENT STRATEGY:
        // We MUST NOT pass 'environ' because it contains Simulator-specific 
        // DYLD and CoreAudio variables that redirect audio to the broken bridge.
        // We pass a minimal environment to force afplay to behave as a host process.
        // ─────────────────────────────────────────────────────────────────────
        var env: [UnsafeMutablePointer<CChar>?] = [
            strdup("PATH=/usr/bin:/bin:/usr/sbin:/sbin"),
            strdup("HOME=\(NSHomeDirectory())"),
            strdup("USER=\(NSUserName())"),
            nil
        ]
        defer { env.compactMap { $0 }.forEach { free($0) } }

        // Args: afplay -v <vol> <path>
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup(afplayPath),
            strdup("-v"),
            strdup(volStr),
            strdup(url.path),
            nil
        ]
        defer { args.compactMap { $0 }.forEach { free($0) } }

        var pid: pid_t = 0
        let spawnStatus = env.withUnsafeMutableBufferPointer { envBuf in
            args.withUnsafeMutableBufferPointer { argBuf in
                posix_spawn(&pid, afplayPath, nil, nil, argBuf.baseAddress, envBuf.baseAddress)
            }
        }

        guard spawnStatus == 0 else {
            print("[SoundPreviewPlayer] ❌ posix_spawn(afplay) failed: \(spawnStatus)")
            return false
        }

        afplayPID = pid
        if deleteTempAfterPlay {
            afplayTempPath = url.path
        }

        print("[SoundPreviewPlayer] 🔊 afplay started (PID=\(pid)) with clean environment")

        // Only mark as "playing" after a short grace period if the subprocess is still alive.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.afplayPID == pid else { return }
            var status: Int32 = 0
            let w = waitpid(pid, &status, WNOHANG)
            guard w == 0 else {
                print("[SoundPreviewPlayer] ❌ afplay exited immediately (raw_status=\(status))")
                self.logSimulatorAudioDiagnosticsIfNeeded(trigger: "afplay immediate exit")
                self.stopAfplayProcess()
                return
            }
            self.isPlaying = true
            self.isBuffering = false
            if let requestedAt = self.playRequestedAt {
                let latency = Date().timeIntervalSince(requestedAt)
                print("[SoundPreviewPlayer] 🔊 afplay playback active. Latency: \(String(format: "%.2f", latency))s")
                self.playRequestedAt = nil
            }
        }

        // Poll every 0.1s to detect when afplay (child process) exits naturally
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self, self.afplayPID == pid else { timer.invalidate(); return }
            var status: Int32 = 0
            let w = waitpid(pid, &status, WNOHANG)
            if w != 0 {  // child exited (or error)
                timer.invalidate()
                DispatchQueue.main.async {
                    guard self.afplayPID == pid else { return }
                    if w == pid {
                        if self.didExitNormally(status) {
                            print("[SoundPreviewPlayer] ⏹️ afplay exited with code \(self.exitCode(from: status))")
                        } else if self.wasTerminatedBySignal(status) {
                            print("[SoundPreviewPlayer] ⏹️ afplay killed by signal \(self.terminatingSignal(from: status))")
                        } else {
                            print("[SoundPreviewPlayer] ⏹️ afplay exited (raw status=\(status))")
                        }
                    }
                    self.stopAfplayProcess()
                }
            }
        }
        return true
    }

    /// Kills any running afplay subprocess and cleans up temp files.
    private func stopAfplayProcess() {
        if afplayPID != 0 {
            let pid = afplayPID
            afplayPID = 0
            kill(pid, SIGTERM)
            waitpid(pid, nil, WNOHANG)
            print("[SoundPreviewPlayer] ⏹️ afplay PID=\(pid) terminated")
        }
        
        if let tempPath = afplayTempPath {
            afplayTempPath = nil
            try? FileManager.default.removeItem(atPath: tempPath)
            print("[SoundPreviewPlayer] 🗑️ Trimmed preview temp file deleted: \(tempPath)")
        }
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingResourceName = nil
        }
    }

    /// Exports the first `maxDuration` seconds of a sound file to a temp .m4a using
    /// AVAssetExportSession (pure CPU software transcode — no audio hardware, no HALC).
    /// Returns the temp file URL on success, or nil on failure.
    private func exportTrimmedPreview(from url: URL, maxDuration: Double) async -> URL? {
        let asset = AVURLAsset(url: url)
        // Load duration properly (async-safe)
        let fullDuration: Double
        do {
            let cmDuration = try await asset.load(.duration)
            fullDuration = CMTimeGetSeconds(cmDuration)
        } catch {
            print("[SoundPreviewPlayer] ❌ Failed to load asset duration: \(error)")
            return nil
        }
        let trimSec = min(fullDuration, maxDuration)
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: trimSec, preferredTimescale: 600))
        print("[SoundPreviewPlayer] 🔍 Exporting \(String(format: "%.1f", trimSec))s preview from \(String(format: "%.1f", fullDuration))s source...")
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("[SoundPreviewPlayer] ❌ Could not create AVAssetExportSession")
            return nil
        }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("alarmo_preview_\(UUID().uuidString).m4a")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange
        await exportSession.export()
        if exportSession.status == .completed {
            let size = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int) ?? 0
            print("[SoundPreviewPlayer] ✅ Export success: \(tempURL.lastPathComponent) (\(size) bytes)")
            return tempURL
        } else {
            print("[SoundPreviewPlayer] ❌ Export status: \(exportSession.status.rawValue) | error: \(exportSession.error?.localizedDescription ?? "none")")
            return nil
        }
    }

    /// Stream audio directly from a remote URL for preview (no permanent download).
    func playStreamURL(_ url: URL, resourceName: String, volume: Float = 1.0) {
        stop()
        _ = beginPreviewRequest(reason: "stream:\(resourceName)")
        DispatchQueue.main.async {
            self.playingResourceName = resourceName
            self.isBuffering = true
            self.spotifyPlaybackActive = false
        }
        print("[SoundPreviewPlayer] 🎧 Streaming preview: \(resourceName) from \(url.lastPathComponent)")
        playURL(url, volume: volume)
    }

    func stop() {
        _ = beginPreviewRequest(reason: "stop")
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player = nil
        localAudioPlayer?.stop()
        localAudioPlayer = nil
        if let tempPath = simulatorPreviewTempPath {
            simulatorPreviewTempPath = nil
            try? FileManager.default.removeItem(atPath: tempPath)
            print("[SoundPreviewPlayer] 🗑️ Simulator preview temp file deleted: \(tempPath)")
        }
        
        // Stop afplay subprocess (simulator) if active
        stopAfplayProcess()
        
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
        localAudioPlayer?.volume = volume
    }
    
    // MARK: - AVAudioPlayerDelegate (Simulator local-file playback)
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            // Only reset if this is still the current player
            if self.localAudioPlayer === player {
                self.isPlaying = false
                self.playingResourceName = nil
                if let tempPath = self.simulatorPreviewTempPath {
                    self.simulatorPreviewTempPath = nil
                    try? FileManager.default.removeItem(atPath: tempPath)
                    print("[SoundPreviewPlayer] 🗑️ Simulator preview temp file deleted after playback: \(tempPath)")
                }
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print("[SoundPreviewPlayer] ❌ AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isBuffering = false
            self.playingResourceName = nil
            if let tempPath = self.simulatorPreviewTempPath {
                self.simulatorPreviewTempPath = nil
                try? FileManager.default.removeItem(atPath: tempPath)
                print("[SoundPreviewPlayer] 🗑️ Simulator preview temp file deleted after decode error: \(tempPath)")
            }
        }
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
