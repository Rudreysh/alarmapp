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
    private let scheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    private weak var alarmStore: AlarmStore?
    private weak var foregroundScheduler: AlarmForegroundScheduler?
    private var modelContext: ModelContext?
    private let accountabilityManager = AccountabilityEnforcementManager.shared
    private let shieldEngine = AccountabilityShieldEngine.shared
    private let settings = SettingsStore.shared
    private let pointsService = PointsService.shared
    private let tamperService = TamperDetectionService.shared
    private var activeSnoozeCount: Int = 0
    private var alarmSessionSnapshots: [UUID: AlarmSession] = [:]
    private var missionTimeoutWorkItem: DispatchWorkItem?
    private var snoozeTransitionInFlight: Bool = false
    
    func configure(alarmStore: AlarmStore, foregroundScheduler: AlarmForegroundScheduler?, modelContext: ModelContext) {
        self.alarmStore = alarmStore
        self.foregroundScheduler = foregroundScheduler
        self.modelContext = modelContext
    }

    @discardableResult
    func startRinging(alarmId: String, source: RingSource) -> Bool {
        guard let id = UUID(uuidString: alarmId) else {
             print("[AlarmRingCoordinator] ❌ Invalid UUID string: \(alarmId)")
             return false
        }
        
        // Prevent duplicate ring starts from overlapping sources
        // (e.g. local notification + foreground timer callback).
        if isRinging, activeAlarm?.id == id {
            print("[AlarmRingCoordinator] ⏭️ Ignoring duplicate START RINGING for \(id) (Source: \(source))")
            return true
        }
        
        guard let alarm = alarmStore?.alarm(by: id) else {
             print("[AlarmRingCoordinator] ❌ Alarm not found in store: \(alarmId)")
             return false
        }

        Task {
            await AlarmManagerFacade.shared.markAlarmFired(id: alarm.id)
        }

        // Once user engages with the ring flow, clear one-shot/snooze follow-up notifications.
        scheduler.cancelRuntimeRingNotifications(for: alarm)

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
        if alarm.blockAppsEnabled {
            tamperService.begin(alarmId: alarm.id)
        } else {
            tamperService.end()
        }
        
        accountabilityManager.beginAlarmEnforcement(alarm: alarm)
        shieldEngine.sessionDidStart(alarm: alarm, session: activeSession)
        
        // Real alarm playback must be loud immediately. iOS does not expose a public API
        // to force the device hardware volume, so we max out Alarmo's own player volume.
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
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
        return true
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
        stopRingingInternal(preserveSession: false, completed: true)
    }

    private func stopRingingInternal(preserveSession: Bool, completed: Bool = false) {
        missionTimeoutWorkItem?.cancel()
        missionTimeoutWorkItem = nil
        AlarmBackgroundAudioBridge.shared.stop(alarmId: activeAlarm?.id.uuidString)
        soundPlayer.stop()
        hapticsPlayer.stop()
        isRinging = false
        UserDefaults.standard.removeObject(forKey: "last_ringing_alarm_id")
        tamperService.end()
        
        if let alarm = activeAlarm {
            NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: alarm.id.uuidString)

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
                
                // Award points for alarm dismissal
                if completed {
                    let hadMission = alarm.missions.contains(where: { $0.type != .off })
                    pointsService.alarmDismissed(
                        alarmId: alarm.id,
                        alarmName: alarm.name,
                        snoozeCount: activeSnoozeCount,
                        hadMission: hadMission
                    )
                }
            }

            // Re-arm repeating alarms so the next runtime follow-up chain is always present.
            if !preserveSession,
               let refreshed = alarmStore?.alarm(by: alarm.id),
               refreshed.enabled,
               refreshed.repeatMask > 0 {
                scheduler.schedule(alarm: refreshed)
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
        if !preserveSession {
            shieldEngine.sessionDidEnd(alarm: activeAlarm, reason: "Stopped Ringing", completed: completed)
        }
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
        
        // Update wake-up streak: increment if no snooze was used
        let streakKey = "qs_streak"
        if activeSnoozeCount == 0 {
            let current = UserDefaults.standard.integer(forKey: streakKey)
            UserDefaults.standard.set(current + 1, forKey: streakKey)
        } else {
            // Snoozed at least once — reset streak
            UserDefaults.standard.set(0, forKey: streakKey)
        }
        
        stopRingingInternal(preserveSession: false, completed: true)
    }

    func snooze() {
        guard !snoozeTransitionInFlight else {
            print("[AlarmRingCoordinator] Snooze ignored: transition already in progress")
            return
        }
        guard let alarm = activeAlarm else { return }
        snoozeTransitionInFlight = true
        
        // Fetch fresh alarm to ensure penalty settings are up-to-date
        let currentAlarm = alarmStore?.alarm(by: alarm.id) ?? alarm
        
        activeSnoozeCount += 1
        print("[AlarmRingCoordinator] Snooze tapped. Count=\(activeSnoozeCount), Threshold=\(settings.snoozePenaltyThreshold), PenaltyEnabled=\(currentAlarm.penaltyEnabled)")
        
        var consumedPenalty = false
        if var session = activeSession {
            // Update session settings from fresh alarm
            session.penaltyEnabled = currentAlarm.penaltyEnabled
            session.snoozeCount = activeSnoozeCount
            session.status = .snoozed
            
            consumedPenalty = PenaltyEngine.shared.chargeIfNeeded(
                alarm: currentAlarm,
                session: &session,
                violation: .snoozeThresholdExceeded,
                note: "Snooze tapped \(activeSnoozeCount)x; threshold=\(settings.snoozePenaltyThreshold)"
            )
            if consumedPenalty {
                penaltyToastMessage = "Penalty charged: \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)"
            }
            activeSession = session
            alarmSessionSnapshots[currentAlarm.id] = session
            shieldEngine.syncSession(session)
        }

        let configuredSeconds = max(0, currentAlarm.snoozeSeconds)
        let configuredMinutes = max(0, currentAlarm.snoozeMinutes)
        let totalSeconds = configuredSeconds > 0 ? (configuredMinutes * 60 + configuredSeconds) : (configuredMinutes > 0 ? configuredMinutes * 60 : 300)

        // Using Task for MainActor isolation
        let performSnoozeTransition = { @MainActor [weak self] in
            guard let self else { return }
            // Log Snoozed Event
            if !self.isPreviewMode {
                let event = ActivityEvent(
                    domain: .alarm,
                    entityId: currentAlarm.id,
                    status: .snoozed,
                    metadata: [
                        "durationMinutes": "\(currentAlarm.snoozeMinutes)",
                        "durationSeconds": "\(currentAlarm.snoozeSeconds)"
                    ]
                )
                self.modelContext?.insert(event)
                try? self.modelContext?.save()
                
                // Deduct points for snoozing
                self.pointsService.alarmSnoozed(
                    alarmId: currentAlarm.id,
                    alarmName: currentAlarm.name
                )
            }

            self.stopRingingInternal(preserveSession: true, completed: false)
            self.scheduler.scheduleSnooze(alarm: currentAlarm, totalSeconds: totalSeconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(totalSeconds)) { [weak self] in
                self?.startRinging(alarmId: currentAlarm.id.uuidString, source: .foregroundTimer)
            }
            self.foregroundScheduler?.scheduleNext()
            self.snoozeTransitionInFlight = false
        }

        if consumedPenalty {
            // Let the user see penalty feedback briefly before the UI dismisses into snooze.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                Task { await performSnoozeTransition() }
            }
        } else {
             Task { await performSnoozeTransition() }
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
            Task { @MainActor [weak self] in
                guard let self, let active = self.activeAlarm else { return }
                guard var session = self.settings.activeAlarmSession ?? self.activeSession else { return }
                
                // Use Shield Engine
                self.shieldEngine.reportViolation(
                    alarm: active,
                    session: &session,
                    type: .alarmMissionFailed,
                    note: "Mission timeout (\(timeout)s)"
                )
                self.activeSession = session
                
                self.missionTimeoutTriggered = true
            }
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
            stopRingingInternal(preserveSession: false, completed: true)
            return
        }

    }

    @discardableResult
    func handleViolation(_ violation: AlarmViolationType, note: String) -> Bool {
        // Triggered by Shutdown/Tamper service
        guard let alarm = activeAlarm else { return false }
        var session = settings.activeAlarmSession ?? activeSession ?? AlarmSession(
            alarmId: alarm.id,
            hasMissions: alarm.missions.contains(where: { $0.type != .off }),
            missionStatus: alarm.missions.contains(where: { $0.type != .off }) ? .inProgress : .completed,
            status: .ringing
        )
        
        let result = shieldEngine.reportViolation(
            alarm: alarm,
            session: &session,
            type: violation,
            note: note
        )
        activeSession = session
        alarmSessionSnapshots[alarm.id] = session
        shieldEngine.syncSession(session)
        if result {
            penaltyToastMessage = "Penalty charged: \(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)"
        }
        return result
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
