import Foundation
import AVFoundation

@inline(__always)
private func swiftlog(_ message: String) {
    print(message)
}

final class AlarmContinuousAudioEngine: NSObject, AVAudioPlayerDelegate {
    static let shared = AlarmContinuousAudioEngine()

    private var player: AVAudioPlayer?
    private var currentSoundName: String?
    private var currentAlarmId: String?
    private var currentVolume: Float = 1.0
    private(set) var targetVolume: Float = 1.0
    private(set) var isPlaying: Bool = false
    /// Cached health state updated by the engine's own watchdog.
    /// External high-frequency watchdogs should read this instead of calling
    /// confirmStillPlaying() directly.
    private(set) var cachedIsHealthy: Bool = false
    private var lastConfirmedPlayingAt: Date?
    private var watchdogTimer: Timer?
    private let watchdogInterval: TimeInterval = 2.0
    private var watchdogConsecutiveFailures: Int = 0
    private var watchdogRecoveryWorkItem: DispatchWorkItem?
    private var observersInstalled = false
    private let appGroupId = "group.ht.alarmo"
    private var interruptionGraceUntil: Date?
    
    private func log(_ message: String) {
        swiftlog(message)
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    var isEngineActive: Bool {
        currentAlarmId != nil
    }
    
    var isInInterruptionRecoveryWindow: Bool {
        guard let deadline = interruptionGraceUntil else { return false }
        return Date() < deadline
    }

    func isPlayingAlarm(alarmId: String) -> Bool {
        currentAlarmId == alarmId && player?.isPlaying == true
    }

    func start(soundName: String, alarmId: String, volume: Float = 1.0) {
        if currentAlarmId == alarmId, player?.isPlaying == true {
            swiftlog("[Engine] engine already playing for this alarm — not restarting")
            lastConfirmedPlayingAt = Date()
            isPlaying = true
            cachedIsHealthy = true
            Task { @MainActor in
                AlarmBackgroundAudioBridge.shared.resetWatchdogBackoff()
            }
            persistEngineState()
            startWatchdogIfNeeded()
            return
        }

        do {
            try configureSession()
        } catch {
            swiftlog("[Engine] Failed to configure session before start: \(error)")
            if let nsError = error as NSError?,
               nsError.domain == NSOSStatusErrorDomain,
               nsError.code == 560557684 {
                // Background + lock transition can temporarily deny activation
                // while another non-mixable owner is active. Give the system
                // a short recovery window and avoid runaway retry storms.
                interruptionGraceUntil = Date().addingTimeInterval(4.0)
            }
        }

        if currentAlarmId != alarmId || player == nil {
            player?.stop()
            player = nil

            guard let url = findSoundURL(for: soundName) else {
                swiftlog("[Engine] Failed to resolve sound URL for \(soundName)")
                isPlaying = false
                currentSoundName = soundName
                currentAlarmId = alarmId
                return
            }
            
            let fileSize = fileSizeAtURL(url)
            guard fileSize > 1000 else {
                log("[Engine] ERROR: Sound file too small (\(fileSize) bytes) — treating as corrupt")
                log("[Engine] File: \(url.lastPathComponent)")
                guard let fallbackURL = findFallbackSound() else {
                    log("[Engine] No fallback available — cannot start")
                    return
                }
                log("[Engine] Using fallback sound: \(fallbackURL.lastPathComponent)")
                startWithURL(fallbackURL, alarmId: alarmId)
                return
            }
            log("[Engine] Sound file validated: \(url.lastPathComponent) (\(fileSize) bytes)")

            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.delegate = self
                newPlayer.numberOfLoops = -1
                newPlayer.volume = volume
                targetVolume = volume
                newPlayer.prepareToPlay()
                let playSucceeded = newPlayer.play()
                let isPlayingAfterCall = newPlayer.isPlaying
                log("[Engine] play() returned: \(playSucceeded), isPlaying immediately after: \(isPlayingAfterCall)")
                log("[Engine] Sound: \(soundName), URL: \(url.lastPathComponent), fileSize: \(fileSizeAtURL(url)) bytes")
                
                if !playSucceeded || !isPlayingAfterCall {
                    log("[Engine] ERROR: play() failed immediately — sound file is likely invalid or corrupt")
                    log("[Engine] Full URL: \(url.absoluteString)")
                    player = nil
                    currentAlarmId = nil
                    currentSoundName = nil
                    isPlaying = false
                    cachedIsHealthy = false
                    return
                }
                player = newPlayer
                currentSoundName = soundName
                currentAlarmId = alarmId
                currentVolume = volume
                targetVolume = volume
                isPlaying = newPlayer.isPlaying
                // Mark healthy immediately after play() attempt to avoid a
                // startup window where external guards schedule conflicting
                // AlarmKit backups before the next watchdog confirmation.
                cachedIsHealthy = true
                lastConfirmedPlayingAt = Date()
                Task { @MainActor in
                    AlarmBackgroundAudioBridge.shared.resetWatchdogBackoff()
                }
                startWatchdogIfNeeded()
                persistEngineState()
                swiftlog("[Engine] Started — alarmId: \(alarmId) sound: \(soundName) time: 0")
                
                let capturedAlarmId = alarmId
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self,
                          self.currentAlarmId == capturedAlarmId,
                          let p = self.player else { return }
                    
                    if p.isPlaying {
                        self.log("[Engine] ✅ 200ms confirmation: playing at \(String(format: "%.3f", p.currentTime))s")
                        self.cachedIsHealthy = true
                    } else {
                        self.log("[Engine] ❌ 200ms confirmation: NOT playing — file may have decode error")
                        self.log("[Engine] currentTime at failure: \(p.currentTime)")
                        self.cachedIsHealthy = false
                        self.startWithFallbackSound(alarmId: capturedAlarmId)
                    }
                }
            } catch {
                swiftlog("[Engine] Failed to create AVAudioPlayer for \(soundName): \(error)")
                isPlaying = false
                currentSoundName = soundName
                currentAlarmId = alarmId
            }
            return
        }

        if player?.isPlaying != true {
            _ = player?.play()
        }
        isPlaying = player?.isPlaying == true
        cachedIsHealthy = isPlaying
        if isPlaying {
            lastConfirmedPlayingAt = Date()
        }
        startWatchdogIfNeeded()
    }

    func stop(reason: String) {
#if DEBUG
        let validStopReasons: Set<String> = ["user-stop", "user-snooze", "app-cleanup-stale"]
        if !validStopReasons.contains(reason) {
            fatalError("""
                [Engine] UNEXPECTED STOP — reason: '\(reason)'
                This stop should not happen. Check the call stack above.
                Only user-stop and user-snooze are valid stop reasons during alarm.
                """)
        }
#endif
        swiftlog("[Engine] Stopping — reason: \(reason)")
        cachedIsHealthy = false
        clearEngineState()
        stopWatchdog()
        player?.stop()
        player = nil
        isPlaying = false
        currentSoundName = nil
        currentAlarmId = nil
        lastConfirmedPlayingAt = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            swiftlog("[Engine] Failed to deactivate session while stopping: \(error)")
        }
        swiftlog("[Engine] Stopped — reason: \(reason)")
    }

    func confirmStillPlaying() -> Bool {
        guard let player else {
            swiftlog("[Engine] confirmStillPlaying → false: no player instance")
            isPlaying = false
            return false
        }

        let live = player.isPlaying
        isPlaying = live
        if live {
            lastConfirmedPlayingAt = Date()
            swiftlog("[Engine] confirmStillPlaying → true: currentTime=\(String(format: "%.2f", player.currentTime))s")
        } else {
            swiftlog("[Engine] confirmStillPlaying → false: player exists but isPlaying=false")
        }
        return live
    }

    func recoverIfNeeded() {
        guard !isEngineActive || !confirmStillPlaying() else {
            swiftlog("[Engine] recoverIfNeeded: engine healthy, no recovery needed")
            return
        }

        swiftlog("[Engine] recoverIfNeeded: engine not healthy, checking persisted state")

        guard let defaults = persistenceDefaults(),
              defaults.bool(forKey: "engine.wasPlaying"),
              let alarmId = defaults.string(forKey: "engine.currentAlarmId"),
              let soundName = defaults.string(forKey: "engine.currentSoundName") else {
            swiftlog("[Engine] recoverIfNeeded: no persisted state found, cannot recover")
            return
        }

        let persistedAt = defaults.double(forKey: "engine.persistedAt")
        let age = Date().timeIntervalSince1970 - persistedAt
        guard age < 3600 else {
            swiftlog("[Engine] recoverIfNeeded: persisted state is \(Int(age))s old — too stale, clearing")
            clearEngineState()
            return
        }

        swiftlog("[Engine] recoverIfNeeded: recovering — alarmId: \(alarmId) sound: \(soundName) age: \(Int(age))s")
        start(soundName: soundName, alarmId: alarmId, volume: 1.0)
    }

    // MARK: - Session + Recovery

    private override init() {
        super.init()
        do {
            try configureSession()
        } catch {
            swiftlog("[Engine] Initial configureSession failed: \(error)")
        }
    }

    private func configureSession() throws {
        installObserversIfNeeded()
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers prevents `cannotInterruptOthers` activation failures
        // while app is backgrounded/locked and system surfaces are transitioning.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        switch type {
        case .began:
            print("[Engine] Interruption began")
            // AlarmKit + lock/unlock transitions can briefly seize the session.
            // Treat this as expected and avoid triggering aggressive fallback loops.
            interruptionGraceUntil = Date().addingTimeInterval(4.0)
            cachedIsHealthy = true
        case .ended:
            swiftlog("[Engine] Interruption ended — attempting session recovery")
            interruptionGraceUntil = nil

            if let existingPlayer = player, !existingPlayer.isPlaying {
                // Re-assert media-domain session ownership before play() so iOS
                // routes side-button volume changes back to media (not ringer)
                // and player.volume = targetVolume reflects the same domain that
                // was active before the interruption.
                try? AVAudioSession.sharedInstance().setActive(true, options: [])
                let directResult = existingPlayer.play()
                if directResult && existingPlayer.isPlaying {
                    existingPlayer.volume = targetVolume
                    isPlaying = true
                    cachedIsHealthy = true
                    lastConfirmedPlayingAt = Date()
                    log("[Engine] ✅ Interruption ended — direct play succeeded at \(String(format: "%.2f", existingPlayer.currentTime))s")
                    log("[Engine] Volume reasserted to \(targetVolume) after interruption")
                    return
                }
            }

            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                let played = player?.play() ?? false
                if played && player?.isPlaying == true {
                    player?.volume = targetVolume
                    isPlaying = true
                    cachedIsHealthy = true
                    lastConfirmedPlayingAt = Date()
                    log("[Engine] ✅ Interruption ended — setActive+play succeeded at \(String(format: "%.2f", player?.currentTime ?? 0))s")
                    log("[Engine] Volume reasserted to \(targetVolume) after interruption")
                    return
                }
            } catch {
                log("[Engine] Interruption ended — setActive failed: \(error.localizedDescription)")
            }

            // Tight initial retries close the perceptible silence gap when iOS
            // hasn't fully released the session by the time .ended fires.
            // Longer tail kept as a safety net.
            let retryDelays: [TimeInterval] = [0.1, 0.25, 0.5, 1.0, 2.0, 4.0]
            for (index, delay) in retryDelays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self,
                          self.isEngineActive,
                          !(self.player?.isPlaying ?? false) else { return }
                    do {
                        try AVAudioSession.sharedInstance().setActive(true, options: [])
                        _ = self.player?.play()
                        if self.player?.isPlaying == true {
                            self.player?.volume = self.targetVolume
                            self.isPlaying = true
                            self.cachedIsHealthy = true
                            self.lastConfirmedPlayingAt = Date()
                            swiftlog("[Engine] Interruption recovery — retry \(index + 1) succeeded at +\(delay)s, currentTime=\(String(format: "%.2f", self.player?.currentTime ?? 0))s")
                            self.log("[Engine] Volume reasserted to \(self.targetVolume) after interruption")
                        }
                    } catch {
                        swiftlog("[Engine] Interruption recovery — retry \(index + 1) failed at +\(delay)s: \(error.localizedDescription)")
                    }
                }
            }
        @unknown default:
            break
        }
    }

    @objc
    private func handleMediaServicesReset() {
        guard let soundName = currentSoundName,
              let alarmId = currentAlarmId else { return }
        do {
            try configureSession()
        } catch {
            swiftlog("[Engine] Media services reset — configure session failed: \(error)")
        }

        guard let url = findSoundURL(for: soundName) else {
            swiftlog("[Engine] Media services reset — failed to resolve sound URL for \(soundName)")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.numberOfLoops = -1
            newPlayer.volume = currentVolume
            newPlayer.prepareToPlay()
            _ = newPlayer.play()
            player = newPlayer
            isPlaying = newPlayer.isPlaying
            if isPlaying {
                lastConfirmedPlayingAt = Date()
            }
            swiftlog("[Engine] Media services reset — full recovery")
            swiftlog("[Engine] Recovered playback for alarmId: \(alarmId)")
        } catch {
            swiftlog("[Engine] Media services reset — failed to recreate player: \(error)")
        }
    }

    // MARK: - Watchdog

    private func startWatchdogIfNeeded() {
        guard watchdogTimer == nil else { return }
        watchdogTimer = Timer.scheduledTimer(
            withTimeInterval: watchdogInterval,
            repeats: true
        ) { [weak self] _ in
            self?.watchdogTick()
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        watchdogRecoveryWorkItem?.cancel()
        watchdogRecoveryWorkItem = nil
        watchdogConsecutiveFailures = 0
    }

    private func watchdogTick() {
        guard isEngineActive else {
            cachedIsHealthy = false
            stopWatchdog()
            return
        }
        if isInInterruptionRecoveryWindow {
            cachedIsHealthy = true
            return
        }
        let healthy = confirmStillPlaying()
        cachedIsHealthy = healthy
        if healthy {
            watchdogConsecutiveFailures = 0
            if watchdogRecoveryWorkItem != nil {
                watchdogRecoveryWorkItem?.cancel()
                watchdogRecoveryWorkItem = nil
            }
            return
        }

        watchdogConsecutiveFailures += 1
        let backoffDelay = min(pow(2.0, Double(watchdogConsecutiveFailures - 1)), 8.0)
        swiftlog("[Engine] Watchdog failure \(watchdogConsecutiveFailures) — recovery in \(backoffDelay)s")

        guard watchdogRecoveryWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.watchdogRecoveryWorkItem = nil
            guard self.isEngineActive else { return }
            self.recoverPlayerIfNeeded()
        }
        watchdogRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + backoffDelay, execute: workItem)
    }

    private func recoverPlayerIfNeeded() {
        guard !confirmStillPlaying(),
              let soundName = currentSoundName,
              let alarmId = currentAlarmId else { return }

        swiftlog("[Engine] Watchdog recovery — restarting player. alarmId: \(alarmId)")

        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            swiftlog("[Engine] Watchdog: session activation failed: \(error.localizedDescription)")
            return
        }

        guard let url = findSoundURL(for: soundName),
              let newPlayer = try? AVAudioPlayer(contentsOf: url) else {
            swiftlog("[Engine] Watchdog: player creation failed for: \(soundName)")
            return
        }

        newPlayer.delegate = self
        newPlayer.numberOfLoops = -1
        newPlayer.volume = targetVolume
        newPlayer.prepareToPlay()
        _ = newPlayer.play()
        player = newPlayer
        isPlaying = newPlayer.isPlaying
        if isPlaying {
            lastConfirmedPlayingAt = Date()
            watchdogConsecutiveFailures = 0
            persistEngineState()
            swiftlog("[Engine] Watchdog recovery successful — playing from recovered player")
        }
    }

    private func persistenceDefaults() -> UserDefaults? {
        if let defaults = UserDefaults(suiteName: appGroupId) {
            return defaults
        }
        swiftlog("[Engine] WARNING: AppGroup '\(appGroupId)' not accessible — state not persisted")
        swiftlog("[Engine] Check: Target → Signing & Capabilities → App Groups is enabled")
        return UserDefaults.standard
    }

    private func persistEngineState() {
        guard let defaults = persistenceDefaults() else { return }
        defaults.set(currentAlarmId, forKey: "engine.currentAlarmId")
        defaults.set(currentSoundName, forKey: "engine.currentSoundName")
        defaults.set(true, forKey: "engine.wasPlaying")
        defaults.set(Date().timeIntervalSince1970, forKey: "engine.persistedAt")
        swiftlog("[Engine] State persisted to AppGroup — alarmId: \(currentAlarmId ?? "nil")")
    }

    private func clearEngineState() {
        guard let defaults = persistenceDefaults() else { return }
        defaults.removeObject(forKey: "engine.currentAlarmId")
        defaults.removeObject(forKey: "engine.currentSoundName")
        defaults.set(false, forKey: "engine.wasPlaying")
        defaults.removeObject(forKey: "engine.persistedAt")
        swiftlog("[Engine] AppGroup state cleared")
    }
    
    private func fileSizeAtURL(_ url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
    }
    
    private func startWithFallbackSound(alarmId: String) {
        log("[Engine] Attempting fallback to bundled default sound")
        guard let fallbackURL = findFallbackSound() else {
            log("[Engine] ERROR: No fallback sound available")
            return
        }
        log("[Engine] Fallback URL: \(fallbackURL.lastPathComponent)")
        startWithURL(fallbackURL, alarmId: alarmId)
    }
    
    private func startWithURL(_ url: URL, alarmId: String) {
        do {
            try configureSession()
        } catch {
            log("[Engine] Fallback configureSession failed: \(error.localizedDescription)")
        }
        
        do {
            let fallbackPlayer = try AVAudioPlayer(contentsOf: url)
            fallbackPlayer.numberOfLoops = -1
            fallbackPlayer.volume = targetVolume
            fallbackPlayer.delegate = self
            fallbackPlayer.prepareToPlay()
            let started = fallbackPlayer.play()
            log("[Engine] Fallback play() returned: \(started), volume=\(targetVolume)")
            if started {
                player = fallbackPlayer
                currentAlarmId = alarmId
                currentSoundName = url.deletingPathExtension().lastPathComponent
                currentVolume = targetVolume
                isPlaying = true
                cachedIsHealthy = true
                lastConfirmedPlayingAt = Date()
                startWatchdogIfNeeded()
                persistEngineState()
                log("[Engine] Fallback sound started successfully")
            } else {
                cachedIsHealthy = false
                isPlaying = false
            }
        } catch {
            log("[Engine] Fallback player init failed: \(error.localizedDescription)")
        }
    }

#if DEBUG
    func testSelectedSound(soundName: String) {
        log("[Engine] TEST: Testing sound file: \(soundName)")
        guard let url = findSoundURL(for: soundName) else {
            log("[Engine] TEST: Sound URL not found for: \(soundName)")
            return
        }
        let size = fileSizeAtURL(url)
        log("[Engine] TEST: URL=\(url.lastPathComponent) size=\(size) bytes")
        
        do {
            let testPlayer = try AVAudioPlayer(contentsOf: url)
            testPlayer.prepareToPlay()
            let started = testPlayer.play()
            log("[Engine] TEST: play() returned \(started), isPlaying=\(testPlayer.isPlaying)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                self.log("[Engine] TEST: 500ms check: isPlaying=\(testPlayer.isPlaying) currentTime=\(testPlayer.currentTime)")
                testPlayer.stop()
                self.log("[Engine] TEST: Complete — sound is \(testPlayer.isPlaying ? "NOT" : "") playable")
            }
        } catch {
            log("[Engine] TEST: Player init failed: \(error)")
        }
    }
#endif

    // MARK: - Sound Resolution

    private func findSoundURL(for name: String) -> URL? {
        let normalizedRequested = normalizedSoundKey(name)
        print("[findSoundURL] Searching for: '\(name)'")
        print("[findSoundURL] Normalized key: '\(normalizedRequested)'")
        if normalizedRequested.contains("alarmosilence") || normalizedRequested.contains("silencealarm") {
            log("[Engine] findSoundURL: blocked internal silent sound request '\(name)'")
            return findFallbackSound()
        }

        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let extensions = ["mp3", "wav", "m4a", "caf"]

        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customDir = docsURL.appendingPathComponent("CustomSounds")
            let files = (try? fileManager.contentsOfDirectory(atPath: customDir.path)) ?? []
            print("[findSoundURL] Path1 (CustomSounds): \(customDir.path)")
            print("[findSoundURL] Path1 files: \(Array(files.prefix(5)))")
            if let enumerator = fileManager.enumerator(at: customDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard extensions.contains(ext) else { continue }
                    let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                    if key == normalizedRequested {
                        print("[findSoundURL] Path1 MATCH: '\(fileURL.lastPathComponent)' key='\(key)'")
                        return fileURL
                    }
                }
            }
        }

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let assetsDir = appSupport.appendingPathComponent("Assets", isDirectory: true)
            let topFiles = (try? fileManager.contentsOfDirectory(atPath: assetsDir.path)) ?? []
            print("[findSoundURL] Path2 (AppSupport/Assets): \(assetsDir.path)")
            print("[findSoundURL] Path2 files: \(Array(topFiles.prefix(10)))")

            // Explicitly search common subdirectories first.
            let subdirs = ["", "sounds", "Sounds", "alarm", "Alarm"]
            for subdir in subdirs {
                let searchDir = subdir.isEmpty
                    ? assetsDir
                    : assetsDir.appendingPathComponent(subdir, isDirectory: true)
                guard fileManager.fileExists(atPath: searchDir.path) else { continue }
                let files = (try? fileManager.contentsOfDirectory(atPath: searchDir.path)) ?? []
                for file in files {
                    let ext = URL(fileURLWithPath: file).pathExtension.lowercased()
                    guard extensions.contains(ext) else { continue }
                    let fileBase = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                    let fileKey = normalizedSoundKey(fileBase)
                    if fileKey == normalizedRequested {
                        let matchURL = searchDir.appendingPathComponent(file, isDirectory: false)
                        print("[findSoundURL] Path2 MATCH in '\(subdir.isEmpty ? "Assets" : subdir)': '\(file)' key='\(fileKey)'")
                        return matchURL
                    }
                }
            }

            if let enumerator = fileManager.enumerator(at: assetsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard extensions.contains(ext) else { continue }
                    let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                    if key == normalizedRequested {
                        print("[findSoundURL] Path2 recursive MATCH: '\(fileURL.lastPathComponent)' key='\(key)'")
                        return fileURL
                    }
                }
            }
        }

        if let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
            let files = (try? fileManager.contentsOfDirectory(atPath: soundsDir.path)) ?? []
            print("[findSoundURL] Path3 (Library/Sounds): \(soundsDir.path)")
            print("[findSoundURL] Path3 files: \(files)")
            if let enumerator = fileManager.enumerator(at: soundsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard extensions.contains(ext) else { continue }
                    let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                    guard !key.contains("alarmosilence") else { continue }
                    if key == normalizedRequested {
                        print("[findSoundURL] Path3 MATCH: '\(fileURL.lastPathComponent)' key='\(key)'")
                        return fileURL
                    }
                }
            }
        }

        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let fileExt = fileURL.pathExtension.lowercased()
                guard extensions.contains(fileExt) else { continue }
                let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                if key == normalizedRequested {
                    print("[findSoundURL] Bundle MATCH: '\(fileURL.lastPathComponent)' key='\(key)'")
                    return fileURL
                }
            }
        }

        return findFallbackSound()
    }

    private func findFallbackSound() -> URL? {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let extensions = ["mp3", "wav", "m4a", "caf"]
        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.isFileURL && extensions.contains(fileURL.pathExtension.lowercased()) {
                    return fileURL
                }
            }
        }
        return nil
    }

    private func normalizedSoundKey(_ raw: String) -> String {
        let noExt = (raw as NSString).deletingPathExtension
        return noExt
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !flag {
                self.log("[Engine] ❌ audioPlayerDidFinishPlaying: successfully=false — playback error")
                self.log("[Engine] This means the sound file failed during playback (decode error or corruption)")
                self.cachedIsHealthy = false
                if let alarmId = self.currentAlarmId {
                    self.startWithFallbackSound(alarmId: alarmId)
                }
            } else {
                self.log("[Engine] audioPlayerDidFinishPlaying: successfully=true (unexpected — restarting)")
                if let alarmId = self.currentAlarmId,
                   let soundName = self.currentSoundName {
                    self.start(soundName: soundName, alarmId: alarmId, volume: self.targetVolume)
                }
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.log("[Engine] ❌ audioPlayerDecodeErrorDidOccur: \(error?.localizedDescription ?? "nil")")
            self.log("[Engine] The selected sound file is corrupt or in an unsupported format")
            self.cachedIsHealthy = false
            if let alarmId = self.currentAlarmId {
                self.startWithFallbackSound(alarmId: alarmId)
            }
        }
    }
}
