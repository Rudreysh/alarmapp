import Foundation
import Combine

final class AlarmForegroundScheduler: ObservableObject {
    private var timer: Timer?
    private let alarmStore: AlarmStore
    private let ringCoordinator: AlarmRingCoordinator

    init(alarmStore: AlarmStore, ringCoordinator: AlarmRingCoordinator) {
        self.alarmStore = alarmStore
        self.ringCoordinator = ringCoordinator
    }

    func start() {
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func scheduleNext() {
        timer?.invalidate()
        let now = Date()
        guard let next = nextAlarm(from: now) else { return }
        let interval = max(0.5, next.date.timeIntervalSince(now))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.ringCoordinator.startRinging(alarmId: next.alarm.id.uuidString, source: .foregroundTimer)
            self.scheduleNext()
        }
    }

    private func nextAlarm(from date: Date) -> (alarm: Alarm, date: Date)? {
        let enabled = alarmStore.alarms.filter { $0.enabled }
        var candidate: (Alarm, Date)?
        for alarm in enabled {
            if let next = AlarmStore.nextFireDate(for: alarm, from: date) {
                if let current = candidate {
                    if next < current.1 { candidate = (alarm, next) }
                } else {
                    candidate = (alarm, next)
                }
            }
        }
        return candidate
    }
}
