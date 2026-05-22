import Foundation
import Combine

final class AlarmForegroundScheduler: ObservableObject {
    private var timer: Timer?
    private var pollTimer: Timer?
    private let alarmStore: AlarmStore
    private let ringCoordinator: AlarmRingCoordinator
    private var lastTriggered: [UUID: Date] = [:]

    init(alarmStore: AlarmStore, ringCoordinator: AlarmRingCoordinator) {
        self.alarmStore = alarmStore
        self.ringCoordinator = ringCoordinator
    }

    func start() {
        startPolling()
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func scheduleNext() {
        timer?.invalidate()
        let now = Date()
        
        // 1. Check if any alarm is due NOW
        if let due = dueAlarm(at: now) {
            AlarmDebug.logFire(alarmId: due.id.uuidString, source: "ForegroundCheck")
            Task { @MainActor in
                self.lastTriggered[due.id] = now
                self.ringCoordinator.startRinging(alarmId: due.id.uuidString, source: .foregroundTimer)
            }
            // If we found one, we stop scheduling new timers to avoid conflict, 
            // the ring flow will re-schedule when stopped.
            return
        }
        
        // 2. Schedule timer for NEXT alarm
        guard let next = nextAlarm(from: now) else { return }
        let interval = next.date.timeIntervalSince(now)
        
        print("[AlarmForegroundScheduler] Next check in \(String(format: "%.1f", interval))s for \(next.alarm.timeString)")
        
        timer = Timer.scheduledTimer(withTimeInterval: interval + 0.5, repeats: false) { [weak self] _ in
            self?.scheduleNext()
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

    private func dueAlarm(at date: Date) -> Alarm? {
        for alarm in alarmStore.alarms where alarm.enabled {
            // Use nextFireDate logic from 30 seconds ago to see if something reached its fire time "now"
            // Since nextFireDate returns the NEXT occurrence, checking from -30s will return the current minute's slot.
            guard let next = AlarmStore.nextFireDate(for: alarm, from: date.addingTimeInterval(-30)) else { continue }
            
            // Check if 'next' is effectively 'now' (within a 5-second window)
            let diff = abs(next.timeIntervalSince(date))
            if diff < 5 {
                // Debounce: verify we haven't triggered this within last minute
                if let last = lastTriggered[alarm.id], date.timeIntervalSince(last) < 60 {
                    continue
                }
                return alarm
            }
        }
        return nil
    }
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Date()
            if let due = self.dueAlarm(at: now) {
                self.log("poll due alarm: \(due.id)")
                Task { @MainActor in
                    self.lastTriggered[due.id] = now
                    self.ringCoordinator.startRinging(alarmId: due.id.uuidString, source: .foregroundTimer)
                }
            }
        }
    }

    private func log(_ message: String) {
        print("[AlarmForegroundScheduler] \(message)")
    }
}
