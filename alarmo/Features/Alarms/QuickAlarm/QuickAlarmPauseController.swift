import Foundation
import Combine

/// Tracks which Quick Alarms are paused and how many seconds remain, so a paused
/// countdown can be frozen in the UI and resumed later. Persisted so a pause
/// survives app relaunches.
@MainActor
final class QuickAlarmPauseStore: ObservableObject {
    static let shared = QuickAlarmPauseStore()

    /// alarmId → remaining seconds captured at pause time.
    @Published private(set) var paused: [String: Int] = [:]

    private let key = "quickAlarm.paused.v1"

    private init() { load() }

    func isPaused(_ id: UUID) -> Bool { paused[id.uuidString] != nil }
    func remaining(_ id: UUID) -> Int? { paused[id.uuidString] }

    func setPaused(_ id: UUID, remaining: Int) {
        paused[id.uuidString] = max(0, remaining)
        save()
    }

    func clear(_ id: UUID) {
        guard paused[id.uuidString] != nil else { return }
        paused.removeValue(forKey: id.uuidString)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(paused) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        paused = decoded
    }
}

/// Central pause/resume logic for Quick Alarms, used by the in-app card button.
///
/// Pausing disables the alarm (so the launch reconcile won't re-arm it) and
/// cancels the scheduled ring; resuming reschedules it for `now + remaining`.
@MainActor
enum QuickAlarmPauseCoordinator {
    /// Pause a running quick alarm: freeze the remaining time and stop the ring.
    static func pause(_ alarm: Alarm) {
        let remaining: Int
        if let next = AlarmStore.nextFireDate(for: alarm, from: Date()) {
            remaining = max(1, Int(next.timeIntervalSince(Date())))
        } else {
            remaining = 60
        }

        QuickAlarmPauseStore.shared.setPaused(alarm.id, remaining: remaining)
        AlarmManagerFacade.shared.cancel(alarmId: alarm.id)
        AlarmStore.shared.toggleEnabled(id: alarm.id, enabled: false)
    }

    /// Resume a paused quick alarm: reschedule it for `now + remaining`.
    static func resume(_ alarm: Alarm) {
        let remaining = max(1, QuickAlarmPauseStore.shared.remaining(alarm.id) ?? 60)
        let fireDate = Date().addingTimeInterval(TimeInterval(remaining))
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: fireDate)

        var updated = alarm
        updated.hour = comps.hour ?? updated.hour
        updated.minute = comps.minute ?? updated.minute
        updated.second = comps.second ?? 0
        updated.enabled = true

        AlarmStore.shared.update(updated)
        AlarmManagerFacade.shared.schedule(alarm: updated)
        QuickAlarmPauseStore.shared.clear(alarm.id)
    }

    /// Toggle pause/resume for a quick alarm.
    static func toggle(_ alarm: Alarm) {
        if QuickAlarmPauseStore.shared.isPaused(alarm.id) {
            resume(alarm)
        } else {
            pause(alarm)
        }
    }
}
