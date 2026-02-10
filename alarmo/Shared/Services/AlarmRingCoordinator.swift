import Foundation
import Combine
import SwiftData

@MainActor
final class AlarmRingCoordinator: ObservableObject {
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var isRinging: Bool = false
    @Published var isPreviewMode: Bool = false
    @Published var missionTimeoutTriggered: Bool = false

    private let soundPlayer = SoundPlayer()
    private let hapticsPlayer = HapticsPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    private weak var alarmStore: AlarmStore?
    private weak var foregroundScheduler: AlarmForegroundScheduler?
    private var modelContext: ModelContext?
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    private var activeSnoozeCount: Int = 0
    private var missionTimeoutWorkItem: DispatchWorkItem?
    
    func configure(alarmStore: AlarmStore, foregroundScheduler: AlarmForegroundScheduler, modelContext: ModelContext) {
        self.alarmStore = alarmStore
        self.foregroundScheduler = foregroundScheduler
        self.modelContext = modelContext
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
        missionTimeoutTriggered = false
        activeSnoozeCount = 0
        accountabilityManager.beginAlarmEnforcement(alarm: alarm)
        
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: alarm.soundVolume, fadeDuration: TimeInterval(alarm.gentleWakeUpSeconds))
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        } else {
             print("[AlarmRingCoordinator] Vibration disabled or not supported on simulator")
        }

        // Log Fired Event
        if !isPreviewMode {
            let event = ActivityEvent(
                domain: .alarm,
                entityId: alarm.id,
                status: .fired
            )
            modelContext?.insert(event)
            try? modelContext?.save()
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
        missionTimeoutWorkItem?.cancel()
        missionTimeoutWorkItem = nil
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

            // Log Dismissed Event
            if !isPreviewMode {
                let event = ActivityEvent(
                    domain: .alarm,
                    entityId: alarm.id,
                    status: .dismissed
                )
                modelContext?.insert(event)
                try? modelContext?.save()
            }
        }
        
        activeAlarm = nil
        activeSnoozeCount = 0
        isPreviewMode = false
        accountabilityManager.endAlarmEnforcement()
        foregroundScheduler?.scheduleNext()
    }
    func snooze() {
        guard let alarm = activeAlarm else { return }
        
        activeSnoozeCount += 1
        if alarm.penaltyEnabled && activeSnoozeCount >= alarm.penaltyRules.alarmSnoozeThreshold {
            let consumed = accountabilityManager.handleAlarmExcessSnoozePenalty(alarm: alarm)
            recordPenaltyEvent(on: alarm, type: .alarmExcessSnooze, consumed: consumed)
            // At threshold we block further snooze escalation by keeping alarm ringing.
            return
        }
        
        // Log Snoozed Event
        if !isPreviewMode {
            let event = ActivityEvent(
                domain: .alarm,
                entityId: alarm.id,
                status: .snoozed,
                metadata: ["durationMinutes": "\(alarm.snoozeMinutes)"]
            )
            modelContext?.insert(event)
            try? modelContext?.save()
        }

        stopRinging()
        let minutes = alarm.snoozeMinutes > 0 ? alarm.snoozeMinutes : 5
        scheduler.scheduleSnooze(alarm: alarm, minutes: minutes)
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
            self?.startRinging(alarmId: alarm.id.uuidString, source: .foregroundTimer)
        }
        foregroundScheduler?.scheduleNext()
    }

    func beginMissionMonitoring() {
        guard let alarm = activeAlarm else { return }
        missionTimeoutWorkItem?.cancel()
        let timeout = max(30, alarm.penaltyRules.alarmMissionTimeoutSeconds)
        let work = DispatchWorkItem { [weak self] in
            guard let self, let active = self.activeAlarm else { return }
            let consumed = self.accountabilityManager.handleAlarmMissionFailurePenalty(alarm: active)
            self.recordPenaltyEvent(on: active, type: .alarmMissionFailed, consumed: consumed)
            self.missionTimeoutTriggered = true
        }
        missionTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(timeout), execute: work)
    }

    func completeMission(success: Bool) {
        missionTimeoutWorkItem?.cancel()
        missionTimeoutWorkItem = nil
        if !success, let alarm = activeAlarm {
            let consumed = accountabilityManager.handleAlarmMissionFailurePenalty(alarm: alarm)
            recordPenaltyEvent(on: alarm, type: .alarmMissionFailed, consumed: consumed)
            missionTimeoutTriggered = true
        }
    }

    private func recordPenaltyEvent(on alarm: Alarm, type: PenaltyEventType, consumed: Bool) {
        var updated = alarm
        let amount = consumed ? alarm.penaltyAmountEuro : 0
        updated.lastPenaltyEventAt = Date()
        updated.penaltyEventLog.append(
            PenaltyEventRecord(
                date: Date(),
                eventType: type,
                amountEuro: amount,
                sourceId: alarm.id,
                note: consumed ? nil : "Insufficient penalty credits"
            )
        )
        alarmStore?.update(updated)
        activeAlarm = updated
    }
}

enum RingSource {
    case notification
    case foregroundTimer
}
