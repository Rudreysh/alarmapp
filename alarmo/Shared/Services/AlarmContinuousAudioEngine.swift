import Foundation
import AVFoundation

final class AlarmContinuousAudioEngine {
    static let shared = AlarmContinuousAudioEngine()

    private var player: AVAudioPlayer?
    private var currentSoundName: String?
    private var currentAlarmId: String?
    private var currentVolume: Float = 1.0
    private(set) var isPlaying: Bool = false
    private var lastConfirmedPlayingAt: Date?
    private var watchdogTimer: Timer?
    private let watchdogInterval: TimeInterval = 2.0
    private var observersInstalled = false

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    var isEngineActive: Bool {
        currentAlarmId != nil
    }

    func isPlayingAlarm(alarmId: String) -> Bool {
        currentAlarmId == alarmId && player?.isPlaying == true
    }

    func start(soundName: String, alarmId: String, volume: Float = 1.0) {
        if currentAlarmId == alarmId, player?.isPlaying == true {
            print("[Engine] engine already playing for this alarm — not restarting")
            lastConfirmedPlayingAt = Date()
            isPlaying = true
            startWatchdogIfNeeded()
            return
        }

        do {
            try configureSession()
        } catch {
            print("[Engine] Failed to configure session before start: \(error)")
        }

        if currentAlarmId != alarmId || player == nil {
            player?.stop()
            player = nil

            guard let url = findSoundURL(for: soundName) else {
                print("[Engine] Failed to resolve sound URL for \(soundName)")
                isPlaying = false
                currentSoundName = soundName
                currentAlarmId = alarmId
                return
            }

            do {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.numberOfLoops = -1
                newPlayer.volume = volume
                newPlayer.prepareToPlay()
                _ = newPlayer.play()
                player = newPlayer
                currentSoundName = soundName
                currentAlarmId = alarmId
                currentVolume = volume
                isPlaying = newPlayer.isPlaying
                lastConfirmedPlayingAt = Date()
                startWatchdogIfNeeded()
                print("[Engine] Started — alarmId: \(alarmId) sound: \(soundName) time: 0")
            } catch {
                print("[Engine] Failed to create AVAudioPlayer for \(soundName): \(error)")
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
        if isPlaying {
            lastConfirmedPlayingAt = Date()
        }
        startWatchdogIfNeeded()
    }

    func stop(reason: String) {
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
            print("[Engine] Failed to deactivate session while stopping: \(error)")
        }
        print("[Engine] Stopped — reason: \(reason)")
    }

    func confirmStillPlaying() -> Bool {
        let playing = player?.isPlaying == true
        isPlaying = playing
        if playing {
            lastConfirmedPlayingAt = Date()
        }
        return playing
    }

    // MARK: - Session + Recovery

    private init() {
        do {
            try configureSession()
        } catch {
            print("[Engine] Initial configureSession failed: \(error)")
        }
    }

    private func configureSession() throws {
        installObserversIfNeeded()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
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
        case .ended:
            do {
                try configureSession()
            } catch {
                print("[Engine] Interruption ended — configure session failed: \(error)")
            }
            _ = player?.play()
            isPlaying = player?.isPlaying == true
            if isPlaying {
                lastConfirmedPlayingAt = Date()
            }
            print("[Engine] Interruption ended — forcing resume")
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
            print("[Engine] Media services reset — configure session failed: \(error)")
        }

        guard let url = findSoundURL(for: soundName) else {
            print("[Engine] Media services reset — failed to resolve sound URL for \(soundName)")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = currentVolume
            newPlayer.prepareToPlay()
            _ = newPlayer.play()
            player = newPlayer
            isPlaying = newPlayer.isPlaying
            if isPlaying {
                lastConfirmedPlayingAt = Date()
            }
            print("[Engine] Media services reset — full recovery")
            print("[Engine] Recovered playback for alarmId: \(alarmId)")
        } catch {
            print("[Engine] Media services reset — failed to recreate player: \(error)")
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
    }

    private func watchdogTick() {
        guard currentAlarmId != nil else { return }
        if player?.isPlaying == true {
            lastConfirmedPlayingAt = Date()
            isPlaying = true
            print("[Engine] Watchdog confirmed playing")
            return
        }

        print("[Engine] Watchdog recovery triggered")
        do {
            try configureSession()
        } catch {
            print("[Engine] Watchdog failed to configure session: \(error)")
        }

        if player?.play() == true {
            isPlaying = true
            lastConfirmedPlayingAt = Date()
            return
        }

        guard let soundName = currentSoundName,
              let alarmId = currentAlarmId else { return }
        start(soundName: soundName, alarmId: alarmId, volume: currentVolume)
    }

    // MARK: - Sound Resolution

    private func findSoundURL(for name: String) -> URL? {
        let fileManager = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let extensions = ["mp3", "wav", "m4a", "caf"]
        let cleanedName = name.replacingOccurrences(of: " ", with: "_").lowercased()
        let dashCleanedName = name.replacingOccurrences(of: " ", with: "-").lowercased()

        if let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customDir = docsURL.appendingPathComponent("CustomSounds")
            for ext in extensions {
                let customFile = customDir.appendingPathComponent("\(name).\(ext)")
                if fileManager.fileExists(atPath: customFile.path) {
                    return customFile
                }
            }
        }

        if let enumerator = fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let fileExt = fileURL.pathExtension.lowercased()
                guard extensions.contains(fileExt) else { continue }
                if filename == name ||
                    filename.lowercased() == name.lowercased() ||
                    filename.lowercased() == cleanedName ||
                    filename.lowercased() == dashCleanedName {
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
}
