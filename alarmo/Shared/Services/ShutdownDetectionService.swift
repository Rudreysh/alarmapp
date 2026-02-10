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
    private var currentRingingAlarmId: UUID?
    
    func startMonitoring(alarmStore: AlarmStore, ringingAlarmId: UUID?) {
        print("[ShutdownDetection] 🛡️ Service starting... (Monitoring: \(isMonitoring), RingingID: \(ringingAlarmId?.uuidString ?? "None"))")
        self.alarmStore = alarmStore
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
        print("[ShutdownDetection] 🚨 DETECTED: \(type.rawValue) \(specificAlarmId != nil ? "for specific ID: " + specificAlarmId!.uuidString : "")")
        guard let alarmStore = alarmStore else { 
            print("[ShutdownDetection] ❌ No AlarmStore found.")
            return 
        }
        
        let targetId = specificAlarmId ?? currentRingingAlarmId
        
        // Find all alarms that should be checked
        let alarmsToLog = alarmStore.alarms.filter { alarm in
            alarm.shutdownProtectionEnabled || alarm.id == targetId
        }
        
        print("[ShutdownDetection] Found \(alarmsToLog.count) alarms to check. Target ID: \(targetId?.uuidString ?? "None")")

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
                attempt.penaltyApplied = true
                attempt.penaltyAmount = alarm.penaltyAmountEuro
                print("[ShutdownDetection] 💰 Penalty applied: €\(alarm.penaltyAmountEuro) for alarm '\(alarm.name)'")
            }
            
            // Add to alarm's shutdown attempt log
            if var updatedAlarm = alarmStore.alarms.first(where: { $0.id == alarm.id }) {
                updatedAlarm.shutdownAttemptLog.append(attempt)
                alarmStore.update(updatedAlarm)
                print("[ShutdownDetection] 📝 Logged attempt to alarm '\(alarm.name)' storage.")
            }
        }
    }
}
