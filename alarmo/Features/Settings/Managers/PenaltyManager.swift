import Foundation
import UIKit
import Combine

class PenaltyManager: ObservableObject {
    static let shared = PenaltyManager()
    
    private let store = SettingsStore.shared
    private var activeMissionAlarmId: UUID? = nil
    private var isMissionActive: Bool = false
    
    private init() {
        setupObservers()
    }
    
    func startMissionMonitoring(alarmId: UUID) {
        guard store.preventPowerOffEnabled else { return }
        self.activeMissionAlarmId = alarmId
        self.isMissionActive = true
        print("[PenaltyManager] Monitoring started for mission: \(alarmId)")
    }
    
    func stopMissionMonitoring() {
        self.isMissionActive = false
        self.activeMissionAlarmId = nil
        print("[PenaltyManager] Monitoring stopped")
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            self.handleAppInterruption(reason: .backgrounded)
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            self.handleAppInterruption(reason: .appKilled)
        }
    }
    
    private func handleAppInterruption(reason: CheatReason) {
        guard isMissionActive else { return }

        // TEMPORARILY DISABLED (Penalty rollout paused):
        // Penalty event recording/charging is intentionally disabled.
        // Keep this logic in source control for future implementation.
        /*
        // Record Cheat
        let event = CheatEvent(reason: reason)
        store.cheatEvents.append(event)

        // Apply Penalty if payment is connected
        let amount = store.perCheatAmountCents
        let record = PenaltyRecord(
            amountCents: amount,
            status: store.isPenaltyPaymentConnected ? .paid : .pending,
            cheatEventId: event.id
        )
        store.penaltyRecords.append(record)

        print("[PenaltyManager] Recorded CHEAT: \(reason.rawValue). Penalty: \(amount) cents.")
        */
        print("[PenaltyManager] Penalty handling disabled. Interruption reason: \(reason.rawValue)")
    }
}
