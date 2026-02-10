import Foundation
import Combine

/// Best-effort tamper detection for active alarm sessions.
/// iOS does not expose real-time app uninstall signals. This service uses
/// heartbeat-gap heuristics during an active session and evaluates on resume.
@MainActor
final class TamperDetectionService: ObservableObject {
    static let shared = TamperDetectionService()

    private enum Keys {
        static let activeAlarmId = "tamper.activeAlarmId"
        static let lastHeartbeatAt = "tamper.lastHeartbeatAt"
    }

    private var heartbeatTimer: Timer?

    private init() {}

    func begin(alarmId: UUID) {
        UserDefaults.standard.set(alarmId.uuidString, forKey: Keys.activeAlarmId)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastHeartbeatAt)
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastHeartbeatAt)
        }
    }

    func end() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        UserDefaults.standard.removeObject(forKey: Keys.activeAlarmId)
        UserDefaults.standard.removeObject(forKey: Keys.lastHeartbeatAt)
    }

    func evaluateOnForeground(ringCoordinator: AlarmRingCoordinator) {
        guard let activeIdString = UserDefaults.standard.string(forKey: Keys.activeAlarmId),
              let activeId = UUID(uuidString: activeIdString),
              let activeAlarm = ringCoordinator.activeAlarm,
              activeAlarm.id == activeId else {
            return
        }

        let last = UserDefaults.standard.double(forKey: Keys.lastHeartbeatAt)
        guard last > 0 else { return }
        let gap = Date().timeIntervalSince1970 - last

        // 45s gap during an active alarm session is treated as tamper-like behavior.
        if gap > 45 {
            _ = ringCoordinator.handleViolation(
                .uninstallTamper,
                note: "Tamper heuristic: heartbeat gap \(Int(gap))s while alarm active"
            )
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastHeartbeatAt)
    }
}
