import Foundation
import AVFoundation
import Combine

class AudioRouteManager: ObservableObject {
    static let shared = AudioRouteManager()
    
    @Published var isExternalConnected: Bool = false
    
    private init() {
        checkCurrentRoute()
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            self.checkCurrentRoute()
        }
    }
    
    func apply(mode: SoundOutputMode) {
        let session = AVAudioSession.sharedInstance()
        do {
            var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP, .allowBluetoothA2DP]
            
            if mode == .currentDevice {
                options.insert(.defaultToSpeaker)
            }
            
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setActive(true)
            
            print("[AudioRouteManager] Applied mode: \(mode.rawValue). Options: \(options)")
        } catch {
            print("[AudioRouteManager] Failed to apply session: \(error)")
        }
    }
    
    private func checkCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        let hasExternal = currentRoute.outputs.contains { output in
            return output.portType == .bluetoothA2DP || 
                   output.portType == .bluetoothHFP || 
                   output.portType == .bluetoothLE
        }
        
        DispatchQueue.main.async {
            self.isExternalConnected = hasExternal
        }
    }
    
    var isExternalOutputAvailable: Bool {
        return isExternalConnected
    }
}
