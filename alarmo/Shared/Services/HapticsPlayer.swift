import AudioToolbox
import Foundation

final class HapticsPlayer {
    private var timer: Timer?

    func startRepeating() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
