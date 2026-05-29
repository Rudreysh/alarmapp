import Foundation
import AVFoundation
import UIKit

@inline(__always)
private func swiftlog(_ message: String) {
    print(message)
}

final class AlarmContinuousAudioEngine: NSObject, AVAudioPlayerDelegate {
    static let shared = AlarmContinuousAudioEngine()

    static func verifyBundledAlarmAssetsOnLaunch() {
        _ = shared.findFallbackSound()
    }

    private var player: AVAudioPlayer?
    private var currentSoundName: String?
    private var currentAlarmId: String?
    private(set) var currentAlarmRunId: UUID?
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
    private var meterTimer: DispatchSourceTimer?
    private let meterQueue = DispatchQueue(label: "ht.alarmo.engine.meter")
    private let meterInterval: TimeInterval = 0.25
    private var watchdogConsecutiveFailures: Int = 0
    private var watchdogRecoveryWorkItem: DispatchWorkItem?
    private var postStopRampWorkItem: DispatchWorkItem?
    private var observersInstalled = false
    private var routeChangeObserver: NSObjectProtocol?
    private var volumeObserver: NSKeyValueObservation?
    private var volumeEnforcementActive = false
    private let appGroupId = "group.ht.alarmo"
    private var interruptionGraceUntil: Date?
    private var isCurrentlyInterrupted: Bool = false
    private var wasHealthyBeforeInterruption: Bool = false
    private(set) var isProgressingNow: Bool = false
    
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

    var currentPlayerVolume: Float {
        player?.volume ?? 0
    }

    func isPlayingAlarm(alarmId: String) -> Bool {
        currentAlarmId == alarmId && player?.isPlaying == true
    }

    // Compatibility API used by diagnostics in newer UI branches.
    func resolvedSoundURLForDiagnostics(soundName: String) -> URL? {
        findSoundURL(for: soundName)
    }

    func start(soundName: String, alarmId: String, volume: Float = 1.0) {
        guard AlarmAudioStateController.shared.canStartAudibleAppAudio(reason: "engine-start") else {
            return
        }
        if currentAlarmId == alarmId, player?.isPlaying == true {
            swiftlog("[Engine] engine already playing for this alarm — not restarting")
            debugVolumeSnapshot(context: "start-already-playing")
            lastConfirmedPlayingAt = Date()
            isPlaying = true
            cachedIsHealthy = true
            startMeteringIfNeeded()
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
                if currentAlarmRunId == nil {
                    currentAlarmRunId = UUID()
                }
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
                startMeteringIfNeeded()
                persistEngineState()
                swiftlog("[Engine] Started — alarmId: \(alarmId) sound: \(soundName) time: 0")
                debugVolumeSnapshot(context: "start-success")
                
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
        let validStopReasons: Set<String> = [
            "user-stop",
            "user-snooze",
            "app-cleanup-stale",
            "notification-stop-action"
        ]
        if !validStopReasons.contains(reason) {
            swiftlog("""
                [Engine] ⚠️ UNEXPECTED STOP REASON '\(reason)' (continuing without crash)
                Update validStopReasons if this path is intentional.
                """)
        }
#endif
        swiftlog("[Engine] Stopping — reason: \(reason)")
        cachedIsHealthy = false
        isProgressingNow = false
        clearEngineState()
        stopWatchdog()
        stopMetering()
        stopRouteChangeObserver()
        stopVolumeObserver()
        player?.stop()
        player = nil
        isPlaying = false
        currentSoundName = nil
        currentAlarmId = nil
        currentAlarmRunId = nil
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
            isProgressingNow = false
            return false
        }

        let live = player.isPlaying
        isPlaying = live
        isProgressingNow = live
        if live {
            lastConfirmedPlayingAt = Date()
            let output = AVAudioSession.sharedInstance().outputVolume
            swiftlog("[Engine] confirmStillPlaying → true: currentTime=\(String(format: "%.2f", player.currentTime))s playerVolume=\(String(format: "%.2f", player.volume)) targetVolume=\(String(format: "%.2f", targetVolume)) outputVolume=\(String(format: "%.2f", output))")
        } else {
            swiftlog("[Engine] confirmStillPlaying → false: player exists but isPlaying=false")
        }
        return live
    }

    func recoverIfNeeded() {
        let phase = AlarmAudioStateController.shared.phase
        if phase == .alarmKitSettling || phase == .appEnginePreparing {
            swiftlog("[Engine] recoverIfNeeded: skipped during phase \(phase.rawValue)")
            return
        }
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
        startRouteChangeObserver()
        startVolumeObserver()
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers is REQUIRED here. AlarmKit keeps its own (silent) alarm
        // sound session active for the ENTIRE ring (it owns the persistent
        // lock-screen surface). The app engine can only activate its AVAudioPlayer
        // alongside it by mixing. An exclusive session makes setActive(true) fail
        // with cannotInterruptOthers during the settle window, permanently blocking
        // takeover and trapping the app in alarmKitFallback + a respawn storm
        // (verified on device — do NOT remove .mixWithOthers).
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        enforceBuiltInSpeakerOutput(context: "session-configure")
    }

    private func configureSessionCategoryOnly() throws {
        installObserversIfNeeded()
        startRouteChangeObserver()
        startVolumeObserver()
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers required — see configureSession() for the full rationale.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    /// Force alarm audio onto the built-in speaker, overriding any connected
    /// AirPods / Bluetooth speaker / wired headphones. Without this, iOS routes
    /// the alarm to whatever output happens to be connected and the phone
    /// speaker stays silent. Called after every `setActive(true)` in the ring
    /// path. Verifies the route landed on the speaker and retries up to 3 times.
    /// Synchronous by design — call sites are synchronous; the brief retry sleep
    /// only runs in the rare case the first override does not take effect.
    private func enforceBuiltInSpeakerOutput(context: String) {
        let session = AVAudioSession.sharedInstance()
        var lastError: Error?

        for attempt in 1...3 {
            do {
                try session.overrideOutputAudioPort(.speaker)

                let onSpeaker = session.currentRoute.outputs
                    .contains { $0.portType == .builtInSpeaker }

                if onSpeaker {
                    log("[Engine] Speaker enforced attempt=\(attempt) context=\(context)")
                    return
                }

                log("[Engine] Speaker override called but route not speaker yet attempt=\(attempt) context=\(context)")
                if attempt < 3 { Thread.sleep(forTimeInterval: 0.2) }
            } catch {
                lastError = error
                log("[Engine] overrideOutputAudioPort failed attempt=\(attempt) context=\(context) error=\(error)")
                if attempt < 3 { Thread.sleep(forTimeInterval: 0.2) }
            }
        }

        log("[Engine] CRITICAL: Could not enforce speaker after 3 attempts context=\(context) lastError=\(String(describing: lastError))")
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

    /// Re-apply the built-in-speaker override whenever the audio route changes
    /// during a ring session. `overrideOutputAudioPort(.speaker)` is point-in-time:
    /// if AirPods / Bluetooth connect AFTER the alarm starts, audio leaves the
    /// speaker. This observer catches that and forces it back.
    /// Self-guarded so repeated calls across ring sessions are safe; removed in stop().
    private func startRouteChangeObserver() {
        guard routeChangeObserver == nil else { return }
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isEngineActive else { return }
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            self.log("[Engine] Route changed during ring — reason=\(reason)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.isEngineActive else { return }
                self.enforceBuiltInSpeakerOutput(context: "route-change-\(reason)")
            }
        }
        log("[Engine] Route change observer installed")
    }

    private func stopRouteChangeObserver() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
            log("[Engine] Route change observer removed")
        }
    }

    /// Observe system output volume during ringing. If the user presses volume
    /// down below the floor (0.15), maximise the player's own volume headroom and
    /// trigger AlarmKit's audible fallback (ringer domain, unaffected by the media
    /// volume buttons) so the alarm cannot be silenced with the volume rocker.
    /// Self-guarded; removed in stop().
    private func startVolumeObserver() {
        guard volumeObserver == nil else { return }
        volumeEnforcementActive = true
        volumeObserver = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new, .old]
        ) { [weak self] session, change in
            guard let self, self.volumeEnforcementActive, self.isEngineActive else { return }
            let newVol = change.newValue ?? session.outputVolume
            let oldVol = change.oldValue ?? newVol
            guard newVol < oldVol else { return }
            if newVol < 0.15 {
                self.log("[Engine] Volume dropped to \(String(format: "%.2f", newVol)) during ring — enforcing floor")
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isEngineActive else { return }
                    self.player?.volume = 1.0
                    AlarmAudioStateController.shared.recordFallback(reason: "volume-floor-\(String(format: "%.2f", newVol))")
                    self.log("[Engine] Floor enforced: player.volume=1.0 + AlarmKit audible fallback triggered")
                }
            }
        }
        log("[Engine] Volume observer installed — floor enforcement active")
    }

    private func stopVolumeObserver() {
        volumeEnforcementActive = false
        volumeObserver?.invalidate()
        volumeObserver = nil
        log("[Engine] Volume observer removed")
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
            let phase = AlarmAudioStateController.shared.phase
            log("[Engine] Interruption began — phase=\(phase.rawValue)")
            debugVolumeSnapshot(context: "interruption-began")
            isCurrentlyInterrupted = true
            wasHealthyBeforeInterruption = cachedIsHealthy

            if phase == .alarmKitSettling || phase == .appEnginePreparing {
                log("[Engine] Interruption during settling/preparing — expected, not fighting")
                cachedIsHealthy = false
                isProgressingNow = false
                return
            }

            if phase == .appEnginePrimary || phase == .appEngineFadingIn {
                cachedIsHealthy = false
                isProgressingNow = false
                interruptionGraceUntil = Date().addingTimeInterval(4.0)
            }
        case .ended:
            log("[Engine] Interruption ended")
            debugVolumeSnapshot(context: "interruption-ended")
            isCurrentlyInterrupted = false
            interruptionGraceUntil = nil
            let phase = AlarmAudioStateController.shared.phase

            if phase == .alarmKitSettling || phase == .appEnginePreparing {
                log("[Engine] Interruption ended during settling/preparing — scheduling takeover grace")
                AlarmAudioStateController.shared.scheduleEarlyTakeoverAfterInterruptionEnd()
                return
            }

            guard phase == .appEnginePrimary || phase == .appEngineFadingIn else {
                return
            }

            if let existingPlayer = player, !existingPlayer.isPlaying {
                let directResult = existingPlayer.play()
                if directResult && existingPlayer.isPlaying {
                    existingPlayer.volume = targetVolume
                    isPlaying = true
                    cachedIsHealthy = true
                    isProgressingNow = true
                    lastConfirmedPlayingAt = Date()
                    log("[Engine] ✅ Interruption ended — direct play succeeded at \(String(format: "%.2f", existingPlayer.currentTime))s")
                    return
                }
            }

            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                enforceBuiltInSpeakerOutput(context: "interruption-ended")
                let played = player?.play() ?? false
                if played && player?.isPlaying == true {
                    player?.volume = targetVolume
                    isPlaying = true
                    cachedIsHealthy = true
                    isProgressingNow = true
                    lastConfirmedPlayingAt = Date()
                    log("[Engine] ✅ Interruption ended — setActive+play succeeded at \(String(format: "%.2f", player?.currentTime ?? 0))s")
                    return
                }
            } catch {
                log("[Engine] Interruption ended — setActive failed: \(error.localizedDescription)")
            }
            scheduleInterruptionRetries()
        @unknown default:
            break
        }
    }

    private func scheduleInterruptionRetries() {
        let retryDelays: [TimeInterval] = [0.5, 1.0, 2.0, 4.0]
        for (index, delay) in retryDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      self.isEngineActive,
                      !(self.player?.isPlaying ?? false),
                      !self.isCurrentlyInterrupted else { return }
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: [])
                    self.enforceBuiltInSpeakerOutput(context: "interruption-retry")
                    _ = self.player?.play()
                    if self.player?.isPlaying == true {
                        self.player?.volume = self.targetVolume
                        self.isPlaying = true
                        self.cachedIsHealthy = true
                        self.isProgressingNow = true
                        self.lastConfirmedPlayingAt = Date()
                        self.log("[Engine] ✅ Interruption retry \(index + 1) succeeded at +\(delay)s")
                    }
                } catch {
                    self.log("[Engine] Interruption retry \(index + 1) failed at +\(delay)s: \(error.localizedDescription)")
                }
            }
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
        let phase = AlarmAudioStateController.shared.phase
        if phase == .alarmKitSettling || phase == .appEnginePreparing {
            return
        }
        if isInInterruptionRecoveryWindow {
            cachedIsHealthy = true
            return
        }
        let healthy = confirmStillPlaying()
        cachedIsHealthy = healthy
        isProgressingNow = healthy
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

    func prepareSilently(soundName: String, alarmId: String, alarmRunId: UUID) {
        if currentAlarmRunId == alarmRunId, player != nil {
            log("[Engine] prepareSilently: already prepared for runId \(alarmRunId.uuidString)")
            return
        }

        log("[Engine] prepareSilently: alarmId=\(alarmId) sound=\(soundName)")
        currentAlarmId = alarmId
        currentAlarmRunId = alarmRunId
        currentSoundName = soundName
        currentVolume = AlarmAudioStateController.appEngineInitialVolume
        targetVolume = AlarmAudioStateController.appEngineFinalTargetVolume
        isPlaying = false
        cachedIsHealthy = false
        isProgressingNow = false

        do {
            try configureSessionCategoryOnly()
            log("[Engine] prepareSilently: session category configured (not activated)")
        } catch {
            log("[Engine] prepareSilently: setCategory failed: \(error.localizedDescription)")
        }

        guard let url = findSoundURL(for: soundName) else {
            log("[Engine] prepareSilently: sound URL not found for '\(soundName)'")
            AlarmAudioStateController.shared.recordFallback(reason: "sound-url-not-found")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = AlarmAudioStateController.appEngineInitialVolume
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            player = newPlayer
            log("[Engine] prepareSilently: player created, prepareToPlay() called, volume=0.0")
            log("[Engine] prepareSilently: duration=\(String(format: "%.2f", newPlayer.duration))s")
            AlarmAudioStateController.shared.recordAppEnginePrepared()
            Task { @MainActor in
                SystemOutputVolumeFloorManager.shared.attemptRaiseOutputVolumeFloor(
                    minimumVolume: AlarmAudioStateController.preAlarmMinimumOutputVolume,
                    reason: "prepare-silently-prewarm"
                )
            }
        } catch {
            log("[Engine] prepareSilently: player creation failed: \(error.localizedDescription)")
            AlarmAudioStateController.shared.recordFallback(reason: "player-creation-failed")
        }
    }

    func startFadeIn(alarmRunId: UUID, fadeInDuration: TimeInterval = 8.0, targetVolume: Float = 1.0) {
        swiftlog("[Engine] startFadeIn ENTRY — requestedRunId=\(alarmRunId.uuidString) currentRunId=\(currentAlarmRunId?.uuidString ?? "nil") player=\(player != nil ? "exists" : "nil") phase=\(AlarmAudioStateController.shared.phase.rawValue)")
        debugVolumeSnapshot(context: "startFadeIn-entry")
        guard currentAlarmRunId == alarmRunId else {
            log("[Engine] startFadeIn BLOCKED — runId MISMATCH: current=\(currentAlarmRunId?.uuidString ?? "nil") requested=\(alarmRunId.uuidString)")
            AlarmAudioStateController.shared.recordFallback(reason: "fadein-runid-mismatch")
            return
        }
        guard let p = player else {
            log("[Engine] startFadeIn BLOCKED — no player exists")
            AlarmAudioStateController.shared.recordFallback(reason: "no-player-at-fadein")
            return
        }
        log("[Engine] startFadeIn proceeding with player — duration=\(String(format: "%.2f", p.duration))s")

        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            enforceBuiltInSpeakerOutput(context: "fade-in-activate")
            log("[Engine] startFadeIn: session activated")
            let activatedOutput = AVAudioSession.sharedInstance().outputVolume
            let appState = UIApplication.shared.applicationState
            log("[Volume] outputVolume=\(String(format: "%.2f", activatedOutput)) playerVolume=\(String(format: "%.2f", p.volume)) phase=\(AlarmAudioStateController.shared.phase.rawValue) reason=start-fadein-activated")
            if appState != .active && activatedOutput <= 0.01 {
                log("[Engine] startFadeIn: locked/background with near-zero outputVolume (\(String(format: "%.2f", activatedOutput))) — switching to AlarmKit fallback")
                AlarmAudioStateController.shared.recordFallback(reason: "locked-zero-output-at-fadein")
                return
            }
        } catch {
            log("[Engine] startFadeIn: session activation failed: \(error.localizedDescription)")
            AlarmAudioStateController.shared.recordFallback(reason: "session-activation-failed-at-fadein")
            return
        }

        p.volume = AlarmAudioStateController.appEngineInitialVolume
        log("[Engine] startFadeIn: starting at volume \(String(format: "%.2f", AlarmAudioStateController.appEngineInitialVolume))")
        self.targetVolume = targetVolume
        let playResult = p.play()
        guard playResult && p.isPlaying else {
            log("[Engine] startFadeIn: play() failed — result=\(playResult) isPlaying=\(p.isPlaying)")
            AlarmAudioStateController.shared.recordFallback(reason: "play-failed-at-fadein")
            return
        }

        isPlaying = true
        isProgressingNow = true
        startMeteringIfNeeded()
        AlarmAudioStateController.shared.recordFadeInStarted()
        Task { @MainActor in
            SystemOutputVolumeFloorManager.shared.attemptRaiseOutputVolumeFloor(
                minimumVolume: AlarmAudioStateController.preAlarmMinimumOutputVolume,
                reason: "app-engine-fade-in-start"
            )
        }
        let firstTarget = min(max(AlarmAudioStateController.appEngineFirstFadeTargetVolume, 0), targetVolume)
        let firstLeg = min(2.0, fadeInDuration)
        let secondLeg = max(0.0, fadeInDuration - firstLeg)
        p.setVolume(firstTarget, fadeDuration: firstLeg)
        if secondLeg > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + firstLeg) { [weak self] in
                guard let self, self.currentAlarmRunId == alarmRunId, self.player?.isPlaying == true else { return }
                self.player?.setVolume(targetVolume, fadeDuration: secondLeg)
                self.debugVolumeSnapshot(context: "startFadeIn-second-leg")
            }
        }
        log("[Engine] startFadeIn: fade started duration=\(String(format: "%.2f", fadeInDuration)) target=\(targetVolume) firstTarget=\(firstTarget)")

        let capturedRunId = alarmRunId
        DispatchQueue.main.asyncAfter(deadline: .now() + AlarmAudioStateController.appEngineProgressCheckDelay) { [weak self] in
            self?.verifyFadeInProgress(alarmRunId: capturedRunId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeInDuration) { [weak self] in
            guard let self,
                  self.currentAlarmRunId == capturedRunId,
                  self.player?.isPlaying == true else { return }
            self.cachedIsHealthy = true
            self.isProgressingNow = true
            self.lastConfirmedPlayingAt = Date()
            self.log("[Engine] Volume ramp complete: \(String(format: "%.2f", self.player?.volume ?? 0))")
            self.debugVolumeSnapshot(context: "startFadeIn-ramp-complete")
            AlarmAudioStateController.shared.recordEnginePrimary()
            Task { @MainActor in
                AlarmBackgroundAudioBridge.shared.resetWatchdogBackoff()
            }
            self.startWatchdogIfNeeded()
            self.persistEngineState()
        }
    }

    /// Boosts volume after AlarmKit slide-to-stop/side-button handling without
    /// ever reducing current player volume.
    func applyPostSlideVolumeBoost(
        reason: String,
        minimumStartVolume: Float = AlarmAudioStateController.postSlideMinimumVolume,
        targetVolume requestedTargetVolume: Float = AlarmAudioStateController.postSlideTargetVolume,
        duration: TimeInterval = AlarmAudioStateController.postSlideRampDuration
    ) {
        guard let p = player else {
            log("[Engine][PostSlideBoost] no player available — reason=\(reason)")
            return
        }

        if !p.isPlaying {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                enforceBuiltInSpeakerOutput(context: "post-slide-boost")
            } catch {
                log("[Engine][PostSlideBoost] session activation failed — reason=\(reason) error=\(error.localizedDescription)")
            }
            let resumed = p.play()
            log("[Engine][PostSlideBoost] player was not playing; play()=\(resumed) currentTime=\(String(format: "%.2f", p.currentTime)) reason=\(reason)")
            guard resumed, p.isPlaying else { return }
        }

        let currentVolume = p.volume
        let startVolume = max(currentVolume, minimumStartVolume)
        let finalTarget = max(startVolume, requestedTargetVolume)
        let session = AVAudioSession.sharedInstance()
        let outputVolume = session.outputVolume
        let route = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        let appState = UIApplication.shared.applicationState.rawValue

        log(
            "[Engine][PostSlideBoost] reason=\(reason) " +
            "currentVolume=\(String(format: "%.2f", currentVolume)) " +
            "minStart=\(String(format: "%.2f", minimumStartVolume)) " +
            "target=\(String(format: "%.2f", requestedTargetVolume)) " +
            "duration=\(String(format: "%.2f", duration)) " +
            "outputVolume=\(String(format: "%.2f", outputVolume)) " +
            "route=\(route) appState=\(appState) " +
            "phase=\(AlarmAudioStateController.shared.phase.rawValue)"
        )

        if outputVolume <= 0.10 {
            log("[Engine][PostSlideBoost] system outputVolume is low; cannot raise system volume programmatically")
        }
        log("[Engine][PostSlideBoost] playerVolume=\(String(format: "%.2f", currentVolume)) outputVolume=\(String(format: "%.2f", outputVolume))")

        if currentVolume >= finalTarget - 0.01 {
            log("[Engine][PostSlideBoost] current volume already near target (\(String(format: "%.2f", currentVolume))) — no boost needed")
            debugVolumeSnapshot(context: "post-slide-boost-noop-\(reason)")
            schedulePostSlideDiagnostics(reason: "\(reason)-noop")
            return
        }

        if currentVolume < startVolume {
            p.volume = startVolume
            log("[Engine][PostSlideBoost] raising start volume from \(String(format: "%.2f", currentVolume)) to \(String(format: "%.2f", startVolume))")
        } else {
            log("[Engine][PostSlideBoost] preserving current volume \(String(format: "%.2f", currentVolume)), no drop")
        }

        postStopRampWorkItem?.cancel()
        let rampWorkItem = DispatchWorkItem { [weak self, weak p] in
            guard let self, let player = p else { return }
            let steps = max(1, Int(duration / 0.1))
            let stepDuration = duration / Double(steps)
            let delta = (finalTarget - startVolume) / Float(steps)
            for index in 1...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(index)) { [weak self, weak p] in
                    guard let self, let player = p, player.isPlaying else { return }
                    let next = min(finalTarget, startVolume + delta * Float(index))
                    player.volume = next
                    if index == 1 || index == steps || index % max(1, steps / 5) == 0 {
                        self.log("[Engine][PostSlideBoost] step volume=\(String(format: "%.2f", next))")
                    }
                    if index == steps {
                        self.log("[Engine][PostSlideBoost] complete volume=\(String(format: "%.2f", player.volume)) outputVolume=\(String(format: "%.2f", AVAudioSession.sharedInstance().outputVolume))")
                        self.debugVolumeSnapshot(context: "post-slide-boost-complete-\(reason)")
                    }
                }
            }
        }
        postStopRampWorkItem = rampWorkItem
        DispatchQueue.main.async(execute: rampWorkItem)
        debugVolumeSnapshot(context: "post-slide-boost-start-\(reason)")
        schedulePostSlideDiagnostics(reason: reason)
    }

    // Backward-compatible shim for existing call sites.
    func applyPostStopGentleRamp(
        duration: TimeInterval = AlarmAudioStateController.postSlideRampDuration,
        reason: String = "post-stop"
    ) {
        applyPostSlideVolumeBoost(
            reason: reason,
            minimumStartVolume: AlarmAudioStateController.postSlideMinimumVolume,
            targetVolume: AlarmAudioStateController.postSlideTargetVolume,
            duration: duration
        )
    }

    private func verifyFadeInProgress(alarmRunId: UUID) {
        guard currentAlarmRunId == alarmRunId, let p = player else { return }
        if p.isPlaying && p.currentTime > 0 {
            cachedIsHealthy = true
            isProgressingNow = true
            lastConfirmedPlayingAt = Date()
            log("[Engine] Fade-in verification: progressing at \(String(format: "%.3f", p.currentTime))s ✅")
            debugVolumeSnapshot(context: "fadein-progress-check")
        } else {
            cachedIsHealthy = false
            isProgressingNow = false
            log("[Engine] Fade-in verification: NOT progressing — fallback")
            AlarmAudioStateController.shared.recordFallback(reason: "fade-in-not-progressing")
        }
    }

    private func recoverPlayerIfNeeded() {
        guard !confirmStillPlaying(),
              let soundName = currentSoundName,
              let alarmId = currentAlarmId else { return }

        swiftlog("[Engine] Watchdog recovery — restarting player. alarmId: \(alarmId)")

        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            enforceBuiltInSpeakerOutput(context: "watchdog-recover")
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
            isProgressingNow = true
            lastConfirmedPlayingAt = Date()
            watchdogConsecutiveFailures = 0
            startMeteringIfNeeded()
            persistEngineState()
            swiftlog("[Engine] Watchdog recovery successful — playing from recovered player")
        }
    }

    private func startMeteringIfNeeded() {
        guard meterTimer == nil else { return }
        meterTimer = DispatchSource.makeTimerSource(queue: meterQueue)
        meterTimer?.schedule(
            deadline: .now() + meterInterval,
            repeating: meterInterval,
            leeway: .milliseconds(50)
        )
        meterTimer?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.meterTick()
            }
        }
        meterTimer?.resume()
    }

    private func stopMetering() {
        meterTimer?.setEventHandler {}
        meterTimer?.cancel()
        meterTimer = nil
    }

    private func meterTick() {
        guard isEngineActive, let p = player, p.isPlaying else {
            if !isEngineActive {
                stopMetering()
            }
            return
        }

        if !p.isMeteringEnabled {
            p.isMeteringEnabled = true
        }
        p.updateMeters()

        let avgDb = p.averagePower(forChannel: 0)
        let peakDb = p.peakPower(forChannel: 0)
        let avgLin = pow(10.0, avgDb / 20.0)
        let peakLin = pow(10.0, peakDb / 20.0)
        let output = AVAudioSession.sharedInstance().outputVolume

        swiftlog(
            "[Engine][Meter] phase=\(AlarmAudioStateController.shared.phase.rawValue) " +
            "time=\(String(format: "%.2f", p.currentTime))s " +
            "avgDbFS=\(String(format: "%.1f", avgDb)) peakDbFS=\(String(format: "%.1f", peakDb)) " +
            "avgLin=\(String(format: "%.3f", avgLin)) peakLin=\(String(format: "%.3f", peakLin)) " +
            "playerVolume=\(String(format: "%.2f", p.volume)) targetVolume=\(String(format: "%.2f", targetVolume)) " +
            "outputVolume=\(String(format: "%.2f", output))"
        )
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
                isProgressingNow = true
                lastConfirmedPlayingAt = Date()
                startWatchdogIfNeeded()
                persistEngineState()
                log("[Engine] Fallback sound started successfully")
                debugVolumeSnapshot(context: "fallback-start-success")
            } else {
                cachedIsHealthy = false
                isPlaying = false
                isProgressingNow = false
            }
        } catch {
            log("[Engine] Fallback player init failed: \(error.localizedDescription)")
        }
    }

    func debugVolumeSnapshot(context: String) {
        let session = AVAudioSession.sharedInstance()
        let output = session.outputVolume
        let category = session.category.rawValue
        let mode = session.mode.rawValue
        let route = session.currentRoute.outputs.map(\.portType.rawValue).joined(separator: ",")
        let playerVol = player?.volume ?? -1
        let time = player?.currentTime ?? -1
        let playing = player?.isPlaying ?? false
        swiftlog("[Engine][Levels] context=\(context) phase=\(AlarmAudioStateController.shared.phase.rawValue) playerVolume=\(String(format: "%.2f", playerVol)) targetVolume=\(String(format: "%.2f", targetVolume)) outputVolume=\(String(format: "%.2f", output)) isPlaying=\(playing) currentTime=\(String(format: "%.2f", time)) category=\(category) mode=\(mode) route=\(route)")
    }

    private func schedulePostSlideDiagnostics(reason: String) {
        let checkpoints: [TimeInterval] = [0.5, 1.5, 2.5]
        for delay in checkpoints {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.debugVolumeSnapshot(context: "post-slide-diagnostic-\(reason)-t\(String(format: "%.1f", delay))")
            }
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

    // Preferred fallback sound names in priority order — these are guaranteed bundled alarm tones.
    // Checked before the general bundle scan so SFX/rank sounds are never used as the fallback.
    private static let preferredFallbackSoundKeys = ["defaultalarm", "clockalarm", "alarm"]

    private func findFallbackSound() -> URL? {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let extensions = ["mp3", "wav", "m4a", "caf"]

        var audibleFiles: [URL] = []
        var silentCandidate: URL?

        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                guard fileURL.isFileURL, extensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                let key = normalizedSoundKey(fileURL.deletingPathExtension().lastPathComponent)
                if key.contains("alarmosilence") || key.contains("silencealarm") {
                    if silentCandidate == nil { silentCandidate = fileURL }
                } else {
                    audibleFiles.append(fileURL)
                }
            }
        }

        // 1. Try preferred alarm-tone names so SFX rank sounds are never used as fallback
        for preferredKey in Self.preferredFallbackSoundKeys {
            if let match = audibleFiles.first(where: {
                normalizedSoundKey($0.deletingPathExtension().lastPathComponent) == preferredKey
            }) {
                log("[Engine] findFallbackSound: using preferred fallback '\(match.lastPathComponent)'")
                return match
            }
        }

        // 2. Any non-SFX / non-rank audio file (alarm tones, ringtones, etc.)
        if let alarmTone = audibleFiles.first(where: {
            !$0.path.contains("/SFX/") && !$0.path.contains("/Ranks/")
        }) {
            log("[Engine] findFallbackSound: using audible fallback '\(alarmTone.lastPathComponent)'")
            return alarmTone
        }

        // 3. Last resort: any audible file including SFX
        if let first = audibleFiles.first {
            log("[Engine] findFallbackSound: using SFX fallback '\(first.lastPathComponent)'")
            return first
        }

        if let silentCandidate {
            log("[Engine] findFallbackSound: only silent fallback available '\(silentCandidate.lastPathComponent)'")
            return silentCandidate
        }

        log("[Engine] findFallbackSound: no fallback sound found in bundle")
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
