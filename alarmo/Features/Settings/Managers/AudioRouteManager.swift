import Foundation
import AVFoundation
import Combine

class AudioRouteManager: ObservableObject {
    static let shared = AudioRouteManager()

    private static let soundOutputModeDefaultsKey = "settings.soundOutputMode"
    
    @Published var isExternalConnected: Bool = false
    
    private init() {
        checkCurrentRoute()
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            self.handleRouteChange()
        }
    }
    
    func apply(mode: SoundOutputMode) {
        do {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.soundOutputModeDefaultsKey)
            try Self.configurePlaybackSession(duckOthers: false)
            print("[AudioRouteManager] Applied mode: \(mode.rawValue)")
            checkCurrentRoute()
        } catch {
            print("[AudioRouteManager] Failed to apply session: \(error)")
        }
    }

    static func configurePlaybackSession(duckOthers: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        let mode = currentModeFromDefaults()
        var options = playbackOptions(for: mode)
        if duckOthers {
            options.insert(.duckOthers)
        }

        try session.setCategory(.playback, mode: .default, options: options)
        try session.setActive(true)
    }

    /// Configure audio session specifically for alarm ringing.
    /// `.playback` is the only category that reliably bypasses the silent switch.
    /// `.mixWithOthers` lets us coexist with AlarmKit's audio session without
    /// being paused by its activation/deactivation during UI transitions.
    static func configureAlarmSession() throws {
        let session = AVAudioSession.sharedInstance()
        let alarmOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]
        try session.setCategory(.playback, mode: .default, options: alarmOptions)
        do {
            try session.setActive(true, options: [])
        } catch {
            print("[AudioRouteManager] ⚠️ setActive(true) failed (\(error)) — attempting hard reset")
            guard !AlarmContinuousAudioEngine.shared.isEngineActive else {
                print("[AudioRouteManager] Session reset BLOCKED — engine owns session during alarm")
                return
            }
            print("[AudioRouteManager] Session reset proceeding — engine not active")
            try? session.setActive(false, options: [])
            try session.setCategory(.playback, mode: .default, options: alarmOptions)
            try session.setActive(true, options: [])
        }
    }

    /// Force a deactivate-then-activate cycle. Use this when the audio
    /// session is suspected to be in a stuck state (e.g. on app resume after
    /// AlarmKit interfered). Any currently-playing AVAudioPlayer should be
    /// reasserted by callers AFTER this returns.
    func forceResetAlarmSession() {
        // GUARD: Engine owns the audio session while alarm is ringing.
        // Resetting the session here would call setActive(false) which stops the engine player.
        // willEnterForeground and protectedDataDidBecomeAvailable both trigger this.
        guard !AlarmContinuousAudioEngine.shared.isEngineActive else {
            print("[AudioRouteManager] forceResetAlarmSession SKIPPED — engine active, session owned by engine")
            return
        }
        print("[AudioRouteManager] forceResetAlarmSession proceeding — engine not active")
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        print("[AudioRouteManager] 🔄 Force-reset alarm audio session")
    }

    private static func currentModeFromDefaults() -> SoundOutputMode {
        guard
            let raw = UserDefaults.standard.string(forKey: soundOutputModeDefaultsKey),
            let mode = SoundOutputMode(rawValue: raw)
        else {
            return .currentDevice
        }
        return mode
    }

    private static func playbackOptions(for mode: SoundOutputMode) -> AVAudioSession.CategoryOptions {
        switch mode {
        case .currentDevice:
            return []
        case .externalPreferred:
            return [.allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
        }
    }
    
    private func checkCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        let hasExternal = Self.hasExternalOutput(route: currentRoute)
        
        DispatchQueue.main.async {
            self.isExternalConnected = hasExternal
        }
    }

    private func handleRouteChange() {
        guard !AlarmContinuousAudioEngine.shared.isEngineActive else {
            print("[AudioRouteManager] Route change ignored — engine owns session")
            return
        }
        checkCurrentRoute()
    }

    private static func hasExternalOutput(route: AVAudioSessionRouteDescription) -> Bool {
        route.outputs.contains(where: { output in
            switch output.portType {
            case .bluetoothA2DP,
                 .bluetoothHFP,
                 .bluetoothLE,
                 .airPlay,
                 .headphones,
                 .lineOut,
                 .usbAudio,
                 .carAudio:
                return true
            default:
                return false
            }
        })
    }
    
    var isExternalOutputAvailable: Bool {
        return isExternalConnected
    }
}
