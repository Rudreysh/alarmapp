import Foundation
import Combine

@MainActor
final class AlarmRingCoordinator: ObservableObject {
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var isRinging: Bool = false

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
        guard let id = UUID(uuidString: alarmId),
              let alarm = alarmStore?.alarm(by: id) else { return }
        activeAlarm = alarm
        isRinging = true
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: alarm.soundVolume)
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        }
    }

    func stopRinging() {
        soundPlayer.stop()
        hapticsPlayer.stop()
        isRinging = false
        activeAlarm = nil
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
