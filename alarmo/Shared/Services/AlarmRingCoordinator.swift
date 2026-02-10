import Foundation
import Combine
import SwiftData

@MainActor
final class AlarmRingCoordinator: ObservableObject {
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var isRinging: Bool = false
    @Published var isPreviewMode: Bool = false
    @Published var missionTimeoutTriggered: Bool = false
    @Published private(set) var activeSession: AlarmSession?
    @Published var penaltyToastMessage: String?

    private let soundPlayer = SoundPlayer()
    private let hapticsPlayer = HapticsPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    private weak var alarmStore: AlarmStore?
    private weak var foregroundScheduler: AlarmForegroundScheduler?
    private var modelContext: ModelContext?
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    private let penaltyEngine = PenaltyEngine.shared
    private let settings = SettingsStore.shared
    private let tamperService = TamperDetectionService.shared
    private var activeSnoozeCount: Int = 0
    private var alarmSessionSnapshots: [UUID: AlarmSession] = [:]
    private var missionTimeoutWorkItem: DispatchWorkItem?
    private var snoozeTransitionInFlight: Bool = false
    
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
        
        // Prevent duplicate ring starts from overlapping sources
        // (e.g. local notification + foreground timer callback).
        if isRinging, activeAlarm?.id == id {
            print("[AlarmRingCoordinator] ⏭️ Ignoring duplicate START RINGING for \(id) (Source: \(source))")
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
        if let restoredSession = alarmSessionSnapshots[alarm.id] {
            var session = restoredSession
            session.status = .ringing
            session.isActive = true
            activeSession = session
            activeSnoozeCount = session.snoozeCount
            print("[AlarmRingCoordinator] Restored session for \(alarm.id). SnoozeCount=\(activeSnoozeCount)")
        } else {
            activeSnoozeCount = 0
            activeSession = AlarmSession(
                alarmId: alarm.id,
                hasMissions: alarm.missions.contains(where: { $0.type != .off }),
                missionStatus: alarm.missions.contains(where: { $0.type != .off }) ? .inProgress : .completed,
                status: .ringing
            )
            print("[AlarmRingCoordinator] Created new session for \(alarm.id)")
        }
        
        // PERSISTENCE: Record that an alarm is ringing for dirty shutdown detection
        UserDefaults.standard.set(alarm.id.uuidString, forKey: "last_ringing_alarm_id")
        tamperService.begin(alarmId: alarm.id)
        
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
        if !isPreviewMode,
           let session = activeSession,
           session.hasMissions,
           session.missionStatus != .completed {
            // Mission-based alarms cannot be dismissed until mission completion.
            return
        }
        stopRingingInternal(preserveSession: false)
    }

    private func stopRingingInternal(preserveSession: Bool) {
        missionTimeoutWorkItem?.cancel()
        missionTimeoutWorkItem = nil
        soundPlayer.stop()
        hapticsPlayer.stop()
        isRinging = false
        UserDefaults.standard.removeObject(forKey: "last_ringing_alarm_id")
        tamperService.end()
        
        if let alarm = activeAlarm {
            if preserveSession, var session = activeSession {
                session.status = .snoozed
                session.isActive = true
                alarmSessionSnapshots[alarm.id] = session
            } else {
                alarmSessionSnapshots.removeValue(forKey: alarm.id)
            }

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
        if !preserveSession {
            activeSnoozeCount = 0
            activeSession = nil
        } else {
            activeSession = nil
        }
        isPreviewMode = false
        accountabilityManager.endAlarmEnforcement()
        foregroundScheduler?.scheduleNext()
    }

    func dismissTapped() {
        guard let activeAlarm else { return }
        if activeAlarm.missions.contains(where: { $0.type != .off }) {
            beginMissionMonitoring()
            return
        }
        if var session = activeSession {
            session.status = .completed
            session.isActive = false
            activeSession = session
        }
        stopRingingInternal(preserveSession: false)
    }

    func snooze() {
        guard !snoozeTransitionInFlight else {
            print("[AlarmRingCoordinator] Snooze ignored: transition already in progress")
            return
        }
        guard let alarm = activeAlarm else { return }
        snoozeTransitionInFlight = true
        
        activeSnoozeCount += 1
        print("[AlarmRingCoordinator] Snooze tapped. Count=\(activeSnoozeCount), Threshold=\(settings.snoozePenaltyThreshold), PenaltyEnabled=\(alarm.penaltyEnabled)")
        var consumedPenalty = false
        if var session = activeSession {
            session.snoozeCount = activeSnoozeCount
            session.status = .snoozed
            let consumed = penaltyEngine.chargeIfNeeded(
                alarm: alarm,
                session: &session,
                violation: .snoozeThresholdExceeded,
                note: "Snooze threshold exceeded"
            )
            activeSession = session
            alarmSessionSnapshots[alarm.id] = session
            if consumed {
                consumedPenalty = true
                recordPenaltyEvent(on: alarm, type: .snoozeThresholdExceeded, consumed: true)
                penaltyToastMessage = "Penalty charged: \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)"
            }
        }

        let configuredSeconds = max(0, alarm.snoozeSeconds)
        let configuredMinutes = max(0, alarm.snoozeMinutes)
        let totalSeconds = configuredSeconds > 0 ? (configuredMinutes * 60 + configuredSeconds) : (configuredMinutes > 0 ? configuredMinutes * 60 : 300)

        let performSnoozeTransition = { [weak self] in
            guard let self else { return }
            // Log Snoozed Event
            if !self.isPreviewMode {
                let event = ActivityEvent(
                    domain: .alarm,
                    entityId: alarm.id,
                    status: .snoozed,
                    metadata: [
                        "durationMinutes": "\(alarm.snoozeMinutes)",
                        "durationSeconds": "\(alarm.snoozeSeconds)"
                    ]
                )
                self.modelContext?.insert(event)
                try? self.modelContext?.save()
            }

            self.stopRingingInternal(preserveSession: true)
            self.scheduler.scheduleSnooze(alarm: alarm, totalSeconds: totalSeconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(totalSeconds)) { [weak self] in
                self?.startRinging(alarmId: alarm.id.uuidString, source: .foregroundTimer)
            }
            self.foregroundScheduler?.scheduleNext()
            self.snoozeTransitionInFlight = false
        }

        if consumedPenalty {
            // Let the user see penalty feedback briefly before the UI dismisses into snooze.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: performSnoozeTransition)
        } else {
            performSnoozeTransition()
        }
    }

    func beginMissionMonitoring() {
        guard activeAlarm != nil else { return }
        if var session = activeSession {
            session.status = .ringing
            activeSession = session
        }
        missionTimeoutWorkItem?.cancel()
        let timeout = max(30, settings.penaltyRules.alarmMissionTimeoutSeconds)
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
        if success {
            if var session = activeSession {
                session.missionStatus = .completed
                session.status = .completed
                session.isActive = false
                activeSession = session
                alarmSessionSnapshots.removeValue(forKey: session.alarmId)
            }
            stopRingingInternal(preserveSession: false)
            return
        }

        if !success, let alarm = activeAlarm {
            let consumed = accountabilityManager.handleAlarmMissionFailurePenalty(alarm: alarm)
            recordPenaltyEvent(on: alarm, type: .alarmMissionFailed, consumed: consumed)
            missionTimeoutTriggered = true
        }
    }

    @discardableResult
    func handleViolation(_ violation: AlarmViolationType, note: String) -> Bool {
        guard let alarm = activeAlarm, var session = activeSession else { return false }
        let consumed = penaltyEngine.chargeIfNeeded(
            alarm: alarm,
            session: &session,
            violation: violation,
            note: note
        )
        activeSession = session
        if consumed {
            recordPenaltyEvent(
                on: alarm,
                type: violation == .shutdownAttempt ? .shutdownAttempt : .uninstallTamper,
                consumed: true
            )
            penaltyToastMessage = "Penalty charged: \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)"
        }
        return consumed
    }

    private func recordPenaltyEvent(on alarm: Alarm, type: PenaltyEventType, consumed: Bool) {
        var updated = alarm
        let amount = consumed ? settings.penaltyAmountEuro : 0
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
