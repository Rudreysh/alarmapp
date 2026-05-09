import Foundation
import Combine
import SwiftData
import UIKit

@MainActor
final class AlarmRingCoordinator: ObservableObject {
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var isRinging: Bool = false
    @Published private(set) var isRingingUIVisible: Bool = false
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
    private var ringingWatchdogTimer: DispatchSourceTimer?
    private let ringingWatchdogQueue = DispatchQueue(label: "ht.alarmo.ring-coordinator.watchdog")
    private var deferredBridgeStopWorkItem: DispatchWorkItem?
    private var ringingBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var ringingUIPresentationWorkItem: DispatchWorkItem?
    
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
            // If audio was interrupted during lock->unlock transition, force it
            // back immediately while keeping the same ringing session/UI.
            reassertRingingAudio(reason: "duplicate-start-\(source)")
            ensureRingingUIPresentation(afterAudioMaxWait: 0.1)
            if ringingWatchdogTimer == nil {
                startRingingWatchdog()
            }
            return true
        }
        
        guard let alarm = alarmStore?.alarm(by: id) else {
             print("[AlarmRingCoordinator] ❌ Alarm not found in store: \(alarmId)")
             return false
        }

        NotificationManager.shared.clearCompletedAlarmFlow(alarmId: alarm.id.uuidString)

        // Determine whether coordinator should claim bridge ownership for this alarm.
        let bridgeSurfaceIdToStop: String? = {
            guard let bridgeSurfaceId = AlarmBackgroundAudioBridge.shared.currentAlarmID else {
                return nil
            }
            let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: bridgeSurfaceId)
            if mappedSource == alarmId ||
                AlarmBackgroundAudioBridge.shared.currentSourceAlarmID == alarmId ||
                bridgeSurfaceId == alarmId {
                return bridgeSurfaceId
            }
            return nil
        }()

        deferredBridgeStopWorkItem?.cancel()
        deferredBridgeStopWorkItem = nil

        Task {
            await AlarmManagerFacade.shared.markAlarmFired(id: alarm.id)
        }

        // Once user engages with the ring flow, clear one-shot/snooze follow-up notifications.
        scheduler.cancelRuntimeRingNotifications(for: alarm)

        print("[AlarmRingCoordinator] 🔔 START RINGING: \(alarm.name) (Source: \(source)) wallpaperId=\(alarm.wallpaperId) sound=\(alarm.soundName)")
        
        activeAlarm = alarm
        isRingingUIVisible = false
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
        
        // Hold a background task throughout ringing so the watchdog can keep
        // recovering audio even if the coordinator's player is silent at the
        // exact moment the app backgrounds.
        beginRingingBackgroundTask()

        // Clear any stale fallback notification chain from older app versions —
        // we no longer schedule new ones (AlarmKit's persistent surface is the
        // single source of truth for ringing audio + UI).
        NotificationManager.shared.cancelAlarmRingingFallbackChain(alarmId: alarm.id.uuidString)

        // INSTANT audio — no fade. A fade-in (even 400ms) creates a
        // near-silent window after unlock; if the user re-locks during that
        // window, iOS suspends the app while no audio is playing, and the
        // alarm goes silent permanently. Full volume from the first sample.
        soundPlayer.playLooping(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
        ensureRingingUIPresentation(afterAudioMaxWait: 0.1)
        if let bridgeSurfaceIdToStop {
            // Always defer the bridge stop, even if not currently active. The bridge
            // is our most reliable safety net (50ms watchdog + audio-background
            // capability). Killing it during unlock/lock churn — or during any other
            // transient app state — leaves only the coordinator's player, which can
            // briefly fail when AVAudioSession.setActive throws during transitions.
            //
            // 8s is generous enough to cover unlock → 2-4s pause → relock test cases
            // and any quick double-tap-of-lock-button churn. Bridge is stopped
            // for real only via stopRingingInternal (user pressed Stop/Snooze) or
            // when the coordinator confirms it's been continuously active.
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.deferredBridgeStopWorkItem = nil
                guard self.isRinging, UIApplication.shared.applicationState == .active else { return }
                AlarmBackgroundAudioBridge.shared.stop(alarmId: bridgeSurfaceIdToStop)
            }
            deferredBridgeStopWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: workItem)
        }
        startRingingWatchdog()
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

    func reassertRingingAudio(reason: String = "manual") {
        guard isRinging, !isPreviewMode, let alarm = activeAlarm else { return }
        print("[AlarmRingCoordinator] 🔁 Reasserting ringing audio (\(reason)) for \(alarm.id)")
        // Non-destructive: only resumes/respawns when the player isn't already playing.
        // Calling stop+start (playLooping) during scene transitions causes a guaranteed
        // silence gap; if AVAudioSession.setActive throws during the transition, the
        // player can fail to restart at all.
        soundPlayer.reassertLoopingPlayback(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        }
    }

    func startPreview(alarm: Alarm) {
        print("[AlarmRingCoordinator] 👁️ START PREVIEW: \(alarm.name) wallpaperId=\(alarm.wallpaperId) sound=\(alarm.soundName)")
        activeAlarm = alarm
        isPreviewMode = true
        isRinging = true
        isRingingUIVisible = true
        
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
        deferredBridgeStopWorkItem?.cancel()
        deferredBridgeStopWorkItem = nil
        ringingUIPresentationWorkItem?.cancel()
        ringingUIPresentationWorkItem = nil
        stopRingingWatchdog()
        let bridgeSurfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID
        let bridgeSourceAlarmId = AlarmBackgroundAudioBridge.shared.currentSourceAlarmID
        let mappedBridgeSourceAlarmId = bridgeSurfaceAlarmId.map {
            AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0)
        }
        AlarmBackgroundAudioBridge.shared.stop()
        soundPlayer.stop()
        hapticsPlayer.stop()
        
        if let alarm = activeAlarm {
            // Consume any remaining runtime/follow-up notifications immediately
            // so ring banners do not keep reappearing after Stop/Snooze actions.
            scheduler.cancelRuntimeRingNotifications(for: alarm)
            // Cancel the fallback ring notification chain — the user has
            // explicitly dismissed via Stop/Snooze, so no more retrigger
            // notifications should fire.
            NotificationManager.shared.cancelAlarmRingingFallbackChain(alarmId: alarm.id.uuidString)

            NotificationManager.shared.markAlarmFlowCompleted(alarmId: alarm.id.uuidString)
            if let bridgeSurfaceAlarmId {
                NotificationManager.shared.markAlarmFlowCompleted(alarmId: bridgeSurfaceAlarmId)
            }
            if let bridgeSourceAlarmId {
                NotificationManager.shared.markAlarmFlowCompleted(alarmId: bridgeSourceAlarmId)
            }
            if let mappedBridgeSourceAlarmId {
                NotificationManager.shared.markAlarmFlowCompleted(alarmId: mappedBridgeSourceAlarmId)
            }
            NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: alarm.id.uuidString)
            if let bridgeSurfaceAlarmId {
                NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: bridgeSurfaceAlarmId)
            }
            if let bridgeSourceAlarmId {
                NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: bridgeSourceAlarmId)
            }
            if let mappedBridgeSourceAlarmId {
                NotificationManager.shared.cancelAlarmKitUnlockPrompt(alarmId: mappedBridgeSourceAlarmId)
            }
            NotificationManager.shared.cancelAllAlarmKitUnlockPrompts()
            // Cleanup again after a short delay to absorb any in-flight loop
            // callback that may race with Stop/Snooze.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationManager.shared.cancelAllAlarmKitUnlockPrompts()
            }
            AlarmCustomUIHandoffStore.clear()
            NotificationManager.shared.dismissLinkedAlarmKitSurfaces(sourceAlarmId: alarm.id.uuidString)
            // Cancel the backup AlarmKit chain — user has explicitly stopped,
            // so no more "alarm rings every 30s" should happen.
            if #available(iOS 26.0, *) {
                NotificationManager.shared.cancelAllBackupAlarmKitChains()
            }
            // Belt-and-suspenders: also nuke EVERY currently-alerting AlarmKit
            // alarm. Catches zombie alarms whose handoff mapping was lost so
            // dismissLinkedAlarmKitSurfaces (which matches by sourceAlarmId)
            // would otherwise miss them.
            NotificationManager.shared.nukeAllAlertingAlarmKitSurfaces()

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

        isRinging = false
        isRingingUIVisible = false
        endRingingBackgroundTask()
        UserDefaults.standard.removeObject(forKey: "last_ringing_alarm_id")
        tamperService.end()
        
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

    func ensureLockPromptLoopAfterUnexpectedViewDismiss() {
        guard isRinging, !isPreviewMode, let alarm = activeAlarm else { return }
        NotificationManager.shared.startAlarmKitUnlockPromptLoop(
            sourceAlarmId: alarm.id.uuidString,
            surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? alarm.id.uuidString,
            alarmName: alarm.name
        )
        NotificationManager.shared.ensureAlarmKitSurfaceForLockedLoopIfNeeded(
            sourceAlarmId: alarm.id.uuidString
        )
    }

    func cancelDeferredBridgeStop(reason: String = "manual") {
        guard deferredBridgeStopWorkItem != nil else { return }
        deferredBridgeStopWorkItem?.cancel()
        deferredBridgeStopWorkItem = nil
        print("[AlarmRingCoordinator] Cancelled deferred bridge stop (\(reason))")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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

    // MARK: - Ringing Watchdog

    private func startRingingWatchdog() {
        stopRingingWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: ringingWatchdogQueue)
        // Tight 50ms tick so a lock/unlock churn or silent-cut cannot open a
        // perceptible gap before we re-assert the session and resume playback.
        // (Matches AlarmBackgroundAudioBridge's watchdog cadence.)
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05, leeway: .milliseconds(15))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.ringingWatchdogTick()
            }
        }
        ringingWatchdogTimer = timer
        timer.resume()
    }

    private func stopRingingWatchdog() {
        ringingWatchdogTimer?.setEventHandler {}
        ringingWatchdogTimer?.cancel()
        ringingWatchdogTimer = nil
    }

    private func ensureRingingUIPresentation(afterAudioMaxWait maxWait: TimeInterval) {
        ringingUIPresentationWorkItem?.cancel()
        ringingUIPresentationWorkItem = nil
        let deadline = Date().addingTimeInterval(maxWait)
        continueRingingUIPresentation(until: deadline)
    }

    private func continueRingingUIPresentation(until deadline: Date) {
        guard isRinging else { return }
        if soundPlayer.isCurrentlyPlaying || Date() >= deadline {
            isRingingUIVisible = true
            ringingUIPresentationWorkItem = nil
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.continueRingingUIPresentation(until: deadline)
        }
        ringingUIPresentationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: workItem)
    }

    private func ringingWatchdogTick() {
        guard isRinging, !isPreviewMode, let alarm = activeAlarm else { return }
        let coordinatorAudible = soundPlayer.isCurrentlyPlaying
        let bridgeAudible = AlarmBackgroundAudioBridge.shared.isAudiblyPlaying
        if coordinatorAudible || bridgeAudible { return }

        print("[AlarmRingCoordinator] ⚠️ Watchdog: NO audible audio (coord=\(coordinatorAudible), bridge=\(bridgeAudible)) — emergency recovery")
        // Re-assert session before restarting playback in case it was deactivated
        // by a phone call or system interruption while the app was in background.
        try? AudioRouteManager.configureAlarmSession()
        soundPlayer.reassertLoopingPlayback(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
        if alarm.vibrateEnabled {
            hapticsPlayer.startRepeating()
        }

        // Belt-and-suspenders: also re-arm the lock-screen path. If the device
        // is locked when audio failed, we need AlarmKit's system surface back to
        // guarantee the user hears something even if our app is suspended next.
        if UIApplication.shared.applicationState != .active {
            let surfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID ?? alarm.id.uuidString
            NotificationManager.shared.enforceLockedRingingState(
                sourceAlarmId: alarm.id.uuidString,
                surfaceAlarmId: surfaceAlarmId
            )
        }
    }

    // MARK: - Background Task

    /// Hold a background task for the entire ringing duration. Without this, if
    /// the coordinator's player goes silent at the exact moment the user locks
    /// the phone (e.g. during AlarmKit's session release), iOS can suspend the
    /// app before the watchdog reasserts audio — and the alarm goes silent until
    /// the user opens the app. The bridge has its own background task; this is
    /// the coordinator's belt-and-suspenders so the watchdog stays alive.
    private func beginRingingBackgroundTask() {
        if ringingBackgroundTaskID != .invalid { return }
        ringingBackgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "alarmo.ringCoordinator.ringing") { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.isRinging else {
                    self.endRingingBackgroundTask()
                    return
                }
                // Re-request to keep the watchdog alive across iOS reclaim cycles.
                let oldTask = self.ringingBackgroundTaskID
                self.ringingBackgroundTaskID = .invalid
                if oldTask != .invalid {
                    UIApplication.shared.endBackgroundTask(oldTask)
                }
                self.beginRingingBackgroundTask()
            }
        }
    }

    private func endRingingBackgroundTask() {
        guard ringingBackgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(ringingBackgroundTaskID)
        ringingBackgroundTaskID = .invalid
    }
}

enum RingSource {
    case notification
    case foregroundTimer
}
