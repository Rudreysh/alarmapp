import Foundation
import Combine
import UIKit

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
            triggerRingIfAllowed(alarm: due, at: now, sourceLabel: "scheduleNext")
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

    /// Phase 2 gate — when AlarmKit is the active scheduler path AND the app is
    /// not in the foreground, do NOT start the ring via the foreground timer
    /// (which would put the AppEngine in charge with no AlarmKit lock-screen
    /// UI). Instead, defer to AlarmKit's `.alerting` observation so the user
    /// always sees the system alarm UI on first ring.
    private func shouldDeferToAlarmKit() -> Bool {
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return false }
        return UIApplication.shared.applicationState != .active
    }

    @MainActor
    private func triggerRingNow(alarm: Alarm, at now: Date, sourceLabel: String) {
        self.lastTriggered[alarm.id] = now
        self.ringCoordinator.startRinging(alarmId: alarm.id.uuidString, source: .foregroundTimer)
        _ = sourceLabel
    }

    private func triggerRingIfAllowed(alarm: Alarm, at now: Date, sourceLabel: String) {
        if shouldDeferToAlarmKit() {
            // Mark debounce so we don't keep flooding logs every poll, and let
            // AlarmKit drive the ring session via its alerting callback.
            lastTriggered[alarm.id] = now
            print("[AlarmForegroundScheduler] deferring to AlarmKit (app not active, AlarmKit path) source=\(sourceLabel) alarm=\(alarm.id) — ring will start when AlarmKit alerts")
            return
        }
        Task { @MainActor in
            self.triggerRingNow(alarm: alarm, at: now, sourceLabel: sourceLabel)
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
                self.triggerRingIfAllowed(alarm: due, at: now, sourceLabel: "poll")
            }
        }
    }

    private func log(_ message: String) {
        print("[AlarmForegroundScheduler] \(message)")
    }
}
