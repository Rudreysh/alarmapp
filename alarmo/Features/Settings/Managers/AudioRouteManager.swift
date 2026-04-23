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
            self.checkCurrentRoute()
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
    /// Uses `.playback` category which is the only reliable way to bypass the silent switch.
    /// Also sets the session as active with `.notifyOthersOnDeactivation` so other audio ducks.
    static func configureAlarmSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .playback category ignores the silent/mute switch on iOS.
        // No options = force output to speaker (not bluetooth) for maximum audibility.
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
        print("[AudioRouteManager] 🔔 Alarm audio session configured (.playback, override silent)")
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
