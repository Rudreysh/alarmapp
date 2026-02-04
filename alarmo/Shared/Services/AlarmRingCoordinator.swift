import Foundation
import Combine

@MainActor
final class AlarmRingCoordinator: ObservableObject {
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var isRinging: Bool = false
    @Published var isPreviewMode: Bool = false

    private let soundPlayer = SoundPlayer()
    private let hapticsPlayer = HapticsPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    private weak var alarmStore: AlarmStore?
    private weak var foregroundScheduler: AlarmForegroundScheduler?

    func configure(alarmStore: AlarmStore, foregroundScheduler: AlarmForegroundScheduler) {
        self.alarmStore = alarmStore
        self.foregroundScheduler = foregroundScheduler
    }

    func startRinging(alarmId: String, source: RingSource) {
        guard let id = UUID(uuidString: alarmId) else {
             print("[AlarmRingCoordinator] ❌ Invalid UUID string: \(alarmId)")
             return
        }
        
        guard let alarm = alarmStore?.alarm(by: id) else {
             print("[AlarmRingCoordinator] ❌ Alarm not found in store: \(alarmId)")
             return
        }

        print("[AlarmRingCoordinator] 🔔 START RINGING: \(alarm.name) (Source: \(source)) wallpaperId=\(alarm.wallpaperId) sound=\(alarm.soundName)")
        
        activeAlarm = alarm
        isRinging = true
        isPreviewMode = false
        
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: alarm.soundVolume, fadeDuration: TimeInterval(alarm.gentleWakeUpSeconds))
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        } else {
             print("[AlarmRingCoordinator] Vibration disabled or not supported on simulator")
        }
    }

    func startPreview(alarm: Alarm) {
        print("[AlarmRingCoordinator] 👁️ START PREVIEW: \(alarm.name) wallpaperId=\(alarm.wallpaperId) sound=\(alarm.soundName)")
        activeAlarm = alarm
        isPreviewMode = true
        isRinging = true
        
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: alarm.soundVolume, fadeDuration: TimeInterval(alarm.gentleWakeUpSeconds))
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        }
    }

    func stopRinging() {
        soundPlayer.stop()
        hapticsPlayer.stop()
        isRinging = false
        
        if let alarm = activeAlarm {
            if alarm.type == .quick {
                print("[AlarmRingCoordinator] 🗑️ Auto-deleting Quick Alarm: \(alarm.name)")
                alarmStore?.remove(id: alarm.id)
            } else if alarm.repeatMask == 0 && !alarm.isDaily {
                print("[AlarmRingCoordinator] 🔕 Disabling one-shot alarm: \(alarm.name)")
                alarmStore?.toggleEnabled(id: alarm.id, enabled: false)
            }
        }
        
        activeAlarm = nil
        isPreviewMode = false
        foregroundScheduler?.scheduleNext()
    }

    func snooze() {
        guard let alarm = activeAlarm else { return }
        stopRinging()
        let minutes = alarm.snoozeMinutes > 0 ? alarm.snoozeMinutes : 5
        scheduler.scheduleSnooze(alarm: alarm, minutes: minutes)
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
            self?.startRinging(alarmId: alarm.id.uuidString, source: .foregroundTimer)
        }
        foregroundScheduler?.scheduleNext()
    }
}

enum RingSource {
    case notification
    case foregroundTimer
}
