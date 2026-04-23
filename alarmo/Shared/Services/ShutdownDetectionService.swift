import Foundation
import UIKit
import Combine

/// Represents a detected shutdown or app termination attempt
struct ShutdownAttempt: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var timestamp: Date
    var alarmId: UUID
    var wasAlarmRinging: Bool
    var attemptType: ShutdownAttemptType
    var penaltyApplied: Bool = false
    var penaltyAmount: Int = 0
    
    enum ShutdownAttemptType: String, Codable {
        case appBackground = "App Entered Background"
        case appTerminated = "App Terminated"
        case deviceLock = "Device Locked"
        case unknown = "Unknown"
    }
}

/// Service to detect and log shutdown attempts
@MainActor
class ShutdownDetectionService: ObservableObject {
    @Published var isMonitoring: Bool = false
    private var alarmStore: AlarmStore?
    private weak var ringCoordinator: AlarmRingCoordinator?
    private var currentRingingAlarmId: UUID?
    private let settings = SettingsStore.shared
    private var lastLogKey: String?
    private var lastLogAt: Date = .distantPast
    
    func startMonitoring(alarmStore: AlarmStore, ringCoordinator: AlarmRingCoordinator, ringingAlarmId: UUID?) {
        print("[ShutdownDetection] 🛡️ Service starting... (Monitoring: \(isMonitoring), RingingID: \(ringingAlarmId?.uuidString ?? "None"))")
        NotificationCenter.default.removeObserver(self)
        self.alarmStore = alarmStore
        self.ringCoordinator = ringCoordinator
        self.currentRingingAlarmId = ringingAlarmId
        self.isMonitoring = true
        
        // Immediately check if we had a "Dirty Shutdown" last time
        checkForDirtyShutdown()
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        print("[ShutdownDetection] ✅ Monitoring active for app lifecycle events.")
    }
    
    func stopMonitoring() {
        self.isMonitoring = false
        self.currentRingingAlarmId = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func checkForDirtyShutdown() {
        if let lastRingingIdString = UserDefaults.standard.string(forKey: "last_ringing_alarm_id"),
           let alarmId = UUID(uuidString: lastRingingIdString) {

            // If the same alarm is currently ringing, this is not a dirty shutdown.
            if currentRingingAlarmId == alarmId {
                return
            }
            
            print("[ShutdownDetection] ⚠️ DIRTY SHUTDOWN DETECTED! App was killed while alarm \(lastRingingIdString) was ringing.")
            
            // Log the attempt and apply penalty
            logAttempt(type: .appTerminated, specificAlarmId: alarmId)
            
            // Clear the flag so we don't penalize twice
            UserDefaults.standard.removeObject(forKey: "last_ringing_alarm_id")
        }
    }
    
    @objc private func handleAppWillResignActive() {
        guard isMonitoring else { return }
        // Proactive: Log immediately when swiping up
        logAttempt(type: .appBackground)
    }
    
    @objc private func handleAppWillTerminate() {
        guard isMonitoring else { return }
        logAttempt(type: .appTerminated)
    }
    
    @objc private func handleAppDidEnterBackground() {
        guard isMonitoring else { return }
        logAttempt(type: .appBackground)
    }
    
    private func logAttempt(type: ShutdownAttempt.ShutdownAttemptType, specificAlarmId: UUID? = nil) {
        guard let alarmStore = alarmStore else { 
            print("[ShutdownDetection] ❌ No AlarmStore found.")
            return 
        }
        
        let targetId = specificAlarmId ?? currentRingingAlarmId
        guard let targetId else {
            print("[ShutdownDetection] Ignored \(type.rawValue): no active ringing alarm.")
            return
        }
        
        let dedupeKey = "\(targetId.uuidString)-\(type.rawValue)"
        if lastLogKey == dedupeKey && Date().timeIntervalSince(lastLogAt) < 1.5 {
            return
        }
        lastLogKey = dedupeKey
        lastLogAt = Date()
        
        // Find alarms that explicitly enabled the relevant protection.
        let alarmsToLog = alarmStore.alarms.filter { alarm in
            alarm.id == targetId && isProtectionEnabled(for: alarm, attemptType: type)
        }
        
        print("[ShutdownDetection] Found \(alarmsToLog.count) alarms to check. Target ID: \(targetId.uuidString)")

        for alarm in alarmsToLog {
            let isRinging = alarm.id == targetId
            var attempt = ShutdownAttempt(
                timestamp: Date(),
                alarmId: alarm.id,
                wasAlarmRinging: isRinging,
                attemptType: type
            )
            
            // Apply penalty if alarm was ringing and penalty is enabled
            if isRinging && alarm.penaltyEnabled {
                let violation = violationType(for: alarm, attemptType: type)
                let isTriggerEnabled = isTriggerEnabled(for: violation)

                if isTriggerEnabled {
                    let consumed = ringCoordinator?.handleViolation(
                        violation,
                        note: violation == .shutdownAttempt
                            ? "Shutdown protection triggered: \(type.rawValue)"
                            : "Tamper/uninstall pattern detected during active alarm: \(type.rawValue)"
                    ) ?? false
                    attempt.penaltyApplied = consumed
                    attempt.penaltyAmount = consumed ? settings.penaltyAmountEuro : 0
                    print("[ShutdownDetection] Penalty \(consumed ? "applied" : "not applied"): \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro) for alarm '\(alarm.name)'")
                } else {
                    print("[ShutdownDetection] Trigger disabled for \(violation.rawValue).")
                }
            }
            
            // Add to alarm's shutdown attempt log
            if var updatedAlarm = alarmStore.alarms.first(where: { $0.id == alarm.id }) {
                updatedAlarm.shutdownAttemptLog.append(attempt)
                alarmStore.update(updatedAlarm)
                print("[ShutdownDetection] Logged \(type.rawValue) for alarm '\(alarm.name)' (Ringing: \(isRinging))")
            }
        }
    }

    private func isProtectionEnabled(for alarm: Alarm, attemptType: ShutdownAttempt.ShutdownAttemptType) -> Bool {
        switch attemptType {
        case .appTerminated:
            // Termination can indicate uninstall tamper OR forced shutdown-style bypass.
            return alarm.blockAppsEnabled || alarm.shutdownProtectionEnabled
        case .appBackground, .deviceLock:
            return alarm.shutdownProtectionEnabled
        case .unknown:
            return alarm.blockAppsEnabled || alarm.shutdownProtectionEnabled
        }
    }

    private func violationType(for alarm: Alarm, attemptType: ShutdownAttempt.ShutdownAttemptType) -> AlarmViolationType {
        switch attemptType {
        case .appTerminated:
            // If uninstall protection is ON, treat termination as uninstall/tamper behavior.
            if alarm.blockAppsEnabled {
                return .uninstallTamper
            }
            return .shutdownAttempt
        case .appBackground, .deviceLock, .unknown:
            return .shutdownAttempt
        }
    }

    private func isTriggerEnabled(for violation: AlarmViolationType) -> Bool {
        switch violation {
        case .shutdownAttempt:
            return settings.penaltyRules.triggerShutdownAttemptEnabled
        case .uninstallTamper:
            return settings.penaltyRules.triggerUninstallTamperEnabled
        default:
            return false
        }
    }
}
