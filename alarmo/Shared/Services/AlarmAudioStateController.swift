import Foundation
import UIKit
import AVFoundation

enum AlarmAudioPhase: String {
    case waitingForAlarmKit
    case alarmKitSettling
    case appEnginePreparing
    case appEngineFadingIn
    case appEnginePrimary
    case alarmKitFallback
    case stopped
}

enum AlarmAudibleOwner: String {
    case none
    case alarmKit
    case appEngine
}

/// Locked/background AppEngine takeover progression — do not claim ownership until verified.
enum LockedEngineAudibilityState: String {
    case engineNotPlaying
    case engineCandidatePlaying
    case engineVerifiedAudible
}

final class AlarmAudioStateController {
    static let shared = AlarmAudioStateController()

    static let alarmKitSettleDelay: TimeInterval = 3.0
    static let postInterruptionGraceDelay: TimeInterval = 0.4
    static let appEngineProgressCheckDelay: TimeInterval = 0.5
    static let appEngineFadeInDuration: TimeInterval = 8.0
    static let appEngineInitialVolume: Float = 0.15
    static let appEngineFirstFadeTargetVolume: Float = 0.2
    static let appEngineFinalTargetVolume: Float = 1.0
    static let postSlideMinimumVolume: Float = 0.30
    static let postSlideRampDuration: TimeInterval = 2.5
    static let postSlideTargetVolume: Float = 1.0
    static let postSlideMinimumOutputVolume: Float = 0.70
    static let preAlarmMinimumOutputVolume: Float = 0.70
    /// Target system **media** volume when AppEngine replaces AlarmKit ringer audio.
    /// AlarmKit uses the ringer domain (full loudness); AppEngine uses media volume ×
    /// player volume — raise media to 100% on handoff so perceived level stays close.
    static let alarmKitHandoffMediaVolumeTarget: Float = 1.0
    /// AppEngine player volume while AlarmKit owns audible output (app not yet active).
    static let alarmKitPrimaryStandbyVolume: Float = 0.0
    static let mpVolumeFloorAttemptDelay: TimeInterval = 0.15
    static let mpVolumeFloorVerificationDelay: TimeInterval = 0.35

    private(set) var phase: AlarmAudioPhase = .stopped
    private(set) var audibleOwner: AlarmAudibleOwner = .none
    private(set) var currentAlarmId: String?
    private(set) var currentAlarmRunId: UUID?
    private(set) var selectedSoundName: String?
    private(set) var selectedSoundURL: URL?
    private(set) var selectedSoundVolume: Float = 1.0

    private(set) var alarmKitAlertingReceivedAt: Date?
    private(set) var appEnginePreparedAt: Date?
    private(set) var appEngineFadeInStartedAt: Date?
    private(set) var appEnginePrimaryConfirmedAt: Date?
    private(set) var lastPhaseTransitionReason: String = "init"
    private(set) var terminalActionRecorded: Bool = false

    private var takeoverWorkItem: DispatchWorkItem?
    private var takeoverScheduled: Bool = false
    private var takeoverScheduledAt: Date?

    // MARK: - Hardware / volume suppression tracking
    private(set) var lastSceneInactiveAt: Date?
    private(set) var lastSceneBackgroundAt: Date?
    private(set) var lastHardwareSuppressionCheckAt: Date?
    private(set) var hardwareRecoveryPending: Bool = false
    private(set) var lastHardwareRecoveryScheduledAt: Date?
    private(set) var lastKnownOutputVolume: Float = -1
    private(set) var lowVolumeWarningActive: Bool = false
    /// Set when the no-UI engine was proven unable to be audible while locked
    /// (e.g. media volume at/near zero, where `.playback` is physically silent).
    /// While set, locked takeover/recovery skips the engine and leaves AlarmKit
    /// (ringer domain, with UI) as the audible owner — the only thing that can be
    /// heard at volume 0. Cleared when the app becomes active, the alarm stops, or
    /// media volume rises back above the floor.
    private(set) var engineInaudibleWhileLockedProven: Bool = false

    /// Set when a LIVE AlarmKit `.alerting` surface is intentionally the audible
    /// owner while the app is inactive/background/locked. While set, the dead-audio
    /// detector, bridge watchdog, and recovery scheduler must NOT dismiss/recreate
    /// the AlarmKit surface or treat AppEngine silence / low media outputVolume as
    /// proof the alarm is silent (AlarmKit is ringer-domain and cannot be probed
    /// via the media domain). Cleared when the app becomes active or the alarm stops.
    private(set) var alarmKitPrimaryLocked: Bool = false

    /// Set on the first foreground/unlock during a ring session. After this,
    /// AlarmKit lock-screen UI must never respawn — AppEngine sound (+ custom
    /// notification) is sufficient for the remainder of the run.
    private(set) var userHasUnlockedDuringThisAlarmRun: Bool = false

    private(set) var lockedEngineAudibilityState: LockedEngineAudibilityState = .engineNotPlaying
    private var lockedEngineVerificationWorkItem: DispatchWorkItem?
    private var lastForbiddenAudioStateRecoveryAt: Date?

    /// Set after side-button, interruption, or failed candidate verify while ringing.
    /// While true, internal AlarmKit `.alerting` records must NOT suppress recovery.
    private var alarmKitSurfaceSuppressionRiskBySource: [String: String] = [:]

    /// Sliding window of recent audible-owner changes within the current run.
    /// Used by the oscillation detector to freeze ownership to AlarmKit when
    /// the system is rapidly flipping between AlarmKit ↔ AppEngine — the
    /// signature of "sound comes and goes / UI flickers" loops.
    private var ownerFlipTimestamps: [Date] = []
    static let ownerFlipWindow: TimeInterval = 10.0
    static let ownerFlipFreezeThreshold: Int = 2

    static let lowOutputVolumeThreshold: Float = 0.15
    /// Minimum system output volume while Awayk is foreground during a ring.
    static let foregroundVolumeFloorStandard: Float = 0.90
    /// Used when media volume has been crushed near zero — fight back harder.
    static let foregroundVolumeFloorAggressive: Float = 1.0

    private let allowedTransitions: [AlarmAudioPhase: Set<AlarmAudioPhase>] = [
        .waitingForAlarmKit: [.alarmKitSettling, .appEnginePreparing, .stopped],
        .alarmKitSettling: [.appEnginePreparing, .appEngineFadingIn, .appEnginePrimary, .alarmKitFallback, .stopped],
        .appEnginePreparing: [.appEngineFadingIn, .alarmKitFallback, .stopped],
        .appEngineFadingIn: [.appEnginePrimary, .alarmKitFallback, .stopped],
        .appEnginePrimary: [.alarmKitFallback, .stopped],
        .alarmKitFallback: [.appEnginePreparing, .appEngineFadingIn, .appEnginePrimary, .stopped],
        .stopped: [.waitingForAlarmKit, .alarmKitSettling]
    ]

    private init() {}

    var isAlarmRinging: Bool {
        phase != .stopped && currentAlarmId != nil && !terminalActionRecorded
    }

    func transitionAudioPhase(to newPhase: AlarmAudioPhase, reason: String) {
        let oldPhase = phase
        guard let allowed = allowedTransitions[oldPhase], allowed.contains(newPhase) else {
            log("⚠️ INVALID transition \(oldPhase.rawValue) → \(newPhase.rawValue) reason=\(reason)")
            return
        }
        phase = newPhase
        lastPhaseTransitionReason = reason
        DiagnosticsLog.shared.log("audio phase \(oldPhase.rawValue) → \(newPhase.rawValue) reason=\(reason)", category: "Takeover")

        let priorOwner = audibleOwner
        switch newPhase {
        case .waitingForAlarmKit, .appEnginePreparing:
            audibleOwner = .none
        case .alarmKitSettling, .alarmKitFallback:
            audibleOwner = .alarmKit
        case .appEngineFadingIn, .appEnginePrimary:
            audibleOwner = .appEngine
        case .stopped:
            audibleOwner = .none
        }
        log("Phase \(oldPhase.rawValue) → \(newPhase.rawValue) owner=\(audibleOwner.rawValue) reason=\(reason) alarmId=\(currentAlarmId ?? "nil") runId=\(currentAlarmRunId?.uuidString ?? "nil")")

        // OSCILLATION GUARD: track AlarmKit ↔ AppEngine flips. Repeated flips
        // within a short window are the fingerprint of a runaway "engine
        // takeover ↔ AlarmKit fallback" loop where neither side is actually
        // audible. Once tripped, freeze ownership to AlarmKit and prove the
        // engine inaudible so future locked takeovers are skipped until the
        // user unlocks or media volume rises.
        if newPhase != .stopped {
            let isFlip =
                (priorOwner == .alarmKit && audibleOwner == .appEngine) ||
                (priorOwner == .appEngine && audibleOwner == .alarmKit)
            if isFlip {
                let now = Date()
                ownerFlipTimestamps.append(now)
                let windowStart = now.addingTimeInterval(-Self.ownerFlipWindow)
                ownerFlipTimestamps.removeAll { $0 < windowStart }
                if ownerFlipTimestamps.count > Self.ownerFlipFreezeThreshold,
                   !engineInaudibleWhileLockedProven {
                    log("[OscillationGuard] owner flip loop detected (\(ownerFlipTimestamps.count) flips ≤ \(Int(Self.ownerFlipWindow))s) — freezing owner=AlarmKit reason=\(reason)")
                    markEngineInaudibleWhileLocked()
                    if let alarmId = currentAlarmId {
                        NotificationManager.shared.preArmAudibleAlarmKitRecovery(
                            sourceAlarmId: alarmId,
                            reason: "oscillation-guard-\(reason)",
                            delay: 4.0
                        )
                    }
                }
            }
        } else {
            ownerFlipTimestamps.removeAll()
        }

        evaluateForbiddenAudioStateIfNeeded(reason: "phase-\(reason)")

        // Keep-alive lifecycle. The silent keep-alive must stay alive (keeping the app
        // unsuspended in background) from alarm fire until AppEngine actually OWNS audio
        // — only then is it safe to release it. While AlarmKit owns the ring
        // (waitingForAlarmKit/alarmKitSettling/alarmKitFallback) and while AppEngine is
        // only PREPARING (prepareSilently does not play), the keep-alive is the sole
        // thing preventing iOS from suspending the process before the background
        // takeover can run. evaluate() honours shouldRun(): it keeps/(re)starts the
        // keep-alive during those phases and stops it on appEngineFadingIn/Primary and
        // on stopped. Skipped in foreground (the live app needs no keep-alive).
        if UIApplication.shared.applicationState != .active {
            AlarmKeepAliveAudioService.shared.evaluate(reason: "phase-\(newPhase.rawValue)")
        }
    }

    func canStartAudibleAppAudio(reason: String) -> Bool {
        let hasActiveSession = currentAlarmId != nil && currentAlarmRunId != nil
        let foregroundPreparingBypass: Bool = {
            guard hasActiveSession else { return false }
            guard phase == .appEnginePreparing else { return false }
            guard !terminalActionRecorded else { return false }
            guard UIApplication.shared.applicationState == .active else { return false }
            guard AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging else { return false }
            guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return false }
            log("[AudioOwner] appEnginePreparing bypassed because app is active and alarm is ringing")
            log("[AudioOwner] AppEngine audible takeover allowed in foreground")
            return true
        }()
        let allowed = ((phase == .appEngineFadingIn || phase == .appEnginePrimary) || foregroundPreparingBypass)
            && hasActiveSession
            && !terminalActionRecorded
        if !allowed {
            log("⛔ Audible app audio BLOCKED phase=\(phase.rawValue) reason=\(reason)")
        }
        return allowed
    }

    func beginAlarmSession(alarmId: String, soundName: String, reason: String) {
        if currentAlarmId == alarmId,
           currentAlarmRunId != nil,
           phase != .stopped {
            log("[StateController] beginAlarmSession: already tracking alarmId=\(alarmId) runId=\(currentAlarmRunId!.uuidString) — skipping reset (reason=\(reason))")
            return
        }

        // A genuinely new ring session — establish clean persisted ringing state.
        // CRITICAL: this clears any stale `finalStopOrSnoozePressed` left by the
        // previous Stop on a repeating alarm, which would otherwise block every
        // recovery path and leave the alarm audibly dead.
        AlarmAuthHandoffStore.markRingingStarted(sourceAlarmId: alarmId)
        clearEngineInaudibleWhileLocked(reason: "new-ring-session")
        clearAlarmKitPrimaryLocked(reason: "new-ring-session")
        userHasUnlockedDuringThisAlarmRun = false
        ownerFlipTimestamps.removeAll()
        resetLockedEngineAudibilityState(reason: "new-ring-session")
        clearAlarmKitSurfaceSuppressionRisk(sourceAlarmId: alarmId, reason: "new-ring-session")
        NotificationManager.shared.clearSuppressionRecoveryStateForNewRing(sourceAlarmId: alarmId)

        takeoverScheduled = false
        takeoverScheduledAt = nil
        currentAlarmId = alarmId
        currentAlarmRunId = UUID()
        selectedSoundName = soundName
        selectedSoundURL = nil
        selectedSoundVolume = 1.0
        if let uuid = UUID(uuidString: alarmId),
           let alarm = AlarmStore.shared.alarm(by: uuid),
           alarm.soundVolume > 0, alarm.soundVolume <= 1.0 {
            selectedSoundVolume = alarm.soundVolume
        }
        terminalActionRecorded = false
        alarmKitAlertingReceivedAt = nil
        appEnginePreparedAt = nil
        appEngineFadeInStartedAt = nil
        appEnginePrimaryConfirmedAt = nil
        log("[StateController] beginAlarmSession: new session alarmId=\(alarmId) runId=\(currentAlarmRunId!.uuidString) reason=\(reason)")
        transitionAudioPhase(to: .waitingForAlarmKit, reason: reason)
    }

    func recordAlarmKitAlerting() {
        alarmKitAlertingReceivedAt = Date()
        transitionAudioPhase(to: .alarmKitSettling, reason: "alarmkit-alerting")
    }

    func recordAppEnginePrepared() {
        appEnginePreparedAt = Date()
        transitionAudioPhase(to: .appEnginePreparing, reason: "engine-prepared-silently")
        if UIApplication.shared.applicationState == .active {
            evaluateForbiddenAudioStateIfNeeded(reason: "engine-prepared-silently")
        } else if let alarmId = currentAlarmId,
                  NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
            evaluateForbiddenAudioStateIfNeeded(reason: "engine-prepared-silently")
        } else {
            log("[ForbiddenAudioState] skipped after silent prepare — AlarmKit still owns locked/background alert")
        }
    }

    func recordFadeInStarted() {
        appEngineFadeInStartedAt = Date()
        transitionAudioPhase(to: .appEngineFadingIn, reason: "fade-in-started")
    }

    func recordEnginePrimary() {
        appEnginePrimaryConfirmedAt = Date()
        transitionAudioPhase(to: .appEnginePrimary, reason: "engine-primary-confirmed")
        NotificationCenter.default.post(
            name: .alarmEngineBecamePrimary,
            object: nil
        )
        log("[StateController] Engine primary — AppEngine owns sound; AlarmKit UI suppressed after unlock")
        AppEngineVolumeResetMonitor.shared.syncWithCurrentState(reason: "engine-primary")
    }

    /// AlarmKit lock-screen UI is allowed only before the user unlocks AND while
    /// AlarmKit (not AppEngine) is the audible owner.
    func shouldAllowAlarmKitLockScreenUI() -> Bool {
        if userHasUnlockedDuringThisAlarmRun {
            return false
        }
        switch audibleOwner {
        case .appEngine:
            return false
        case .alarmKit:
            return true
        case .none:
            switch phase {
            case .waitingForAlarmKit, .alarmKitSettling, .alarmKitFallback:
                return isAlarmKitPrimaryLockedActive()
            default:
                return false
            }
        }
    }

    /// Call when the user unlocks / app becomes foreground during an active ring.
    func markUserUnlockedDuringAlarmRun(reason: String) {
        guard currentAlarmId != nil, isAlarmRinging else { return }
        guard !userHasUnlockedDuringThisAlarmRun else { return }
        userHasUnlockedDuringThisAlarmRun = true
        clearAlarmKitPrimaryLocked(reason: "user-unlocked-\(reason)")
        log("[AlarmKitUI] user unlocked — suppressing AlarmKit UI for remainder of run reason=\(reason)")
        if let alarmId = currentAlarmId {
            NotificationManager.shared.dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: alarmId,
                reason: reason
            )
        }
    }

    func recordFallback(reason: String) {
        transitionAudioPhase(to: .alarmKitFallback, reason: reason)
        guard let alarmId = currentAlarmId else { return }
        if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
            log("[LockedNoUI] recordFallback → engine-only recovery (no AlarmKit UI) reason=\(reason)")
            NotificationManager.shared.attemptLockedNoUIEngineRecovery(
                sourceAlarmId: alarmId,
                reason: "fallback-\(reason)"
            )
            return
        }
        NotificationManager.shared.scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: alarmId,
            reason: reason,
            delay: 1.0
        )
    }

    func recordStopped(reason: String) {
        AppEngineVolumeResetMonitor.shared.disarm(reason: "stopped-\(reason)")
        takeoverScheduled = false
        takeoverScheduledAt = nil
        terminalActionRecorded = true
        takeoverWorkItem?.cancel()
        takeoverWorkItem = nil
        clearHardwareRecoveryState()
        clearEngineInaudibleWhileLocked(reason: "stopped")
        clearAlarmKitPrimaryLocked(reason: "stopped")
        userHasUnlockedDuringThisAlarmRun = false
        resetLockedEngineAudibilityState(reason: "stopped")
        if let alarmId = currentAlarmId {
            clearAlarmKitSurfaceSuppressionRisk(sourceAlarmId: alarmId, reason: "stopped")
        }
        transitionAudioPhase(to: .stopped, reason: reason)
        currentAlarmId = nil
        currentAlarmRunId = nil
        selectedSoundName = nil
        selectedSoundURL = nil
    }

    // MARK: - Hardware suppression

    func appEngineConfirmedPlaying() -> Bool {
        AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.cachedIsHealthy &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
    }

    /// Fast single-sample check — NOT sufficient for AlarmKit dismissal decisions.
    /// Use `isAppEngineActuallyAudible(reason:) async` before dismissing AlarmKit surfaces.
    func isAppEngineQuickAudible(reason: String) -> Bool {
        guard passesAudibilitySessionGuards(reason: reason) else { return false }
        let engine = AlarmContinuousAudioEngine.shared
        let sample = engine.captureAudibilitySample()
        let meter = engine.recentMeterIsAudible()
        let appInactive = UIApplication.shared.applicationState != .active
        let meterOK: Bool = {
            if let meter { return meter }
            // Background/locked: unknown meter is not proof of audibility.
            return !appInactive
        }()
        let audible = sample.isPlaying
            && sample.hasPlayer
            && sample.outputVolume > Self.lowOutputVolumeThreshold
            && sample.hasValidRoute
            && sample.sessionIsActive
            && sample.categoryIsPlayback
            && !sample.isInterrupted
            && meterOK
        let meterText = meter.map { $0 ? "audible" : "silent" } ?? "unknown"
        log(
            "[Audibility] quick reason=\(reason) playing=\(sample.isPlaying) " +
            "output=\(String(format: "%.2f", sample.outputVolume)) " +
            "route=\(sample.hasValidRoute ? "valid" : "invalid") meter=\(meterText) audible=\(audible)"
        )
        return audible
    }

    func engineMeterSummaryForLogs() -> String {
        let engine = AlarmContinuousAudioEngine.shared
        guard let meter = engine.recentMeterIsAudible() else { return "meter=unknown" }
        return meter ? "meter=audible" : "meter=silent"
    }

    // MARK: - AlarmKit surface suppression risk

    func markAlarmKitSurfaceSuppressionRisk(sourceAlarmId: String, reason: String) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging
        guard ringing else { return }
        let runId = currentAlarmRunId?.uuidString ?? AlarmAuthHandoffStore.activeRingingAlarmId()
        alarmKitSurfaceSuppressionRiskBySource[sourceAlarmId] = runId
        log("[AlarmKitSuppressionRisk] set=true source=\(sourceAlarmId) runId=\(runId ?? "nil") reason=\(reason)")
    }

    func isAlarmKitSurfaceSuppressionRisk(sourceAlarmId: String) -> Bool {
        guard let pinnedRunId = alarmKitSurfaceSuppressionRiskBySource[sourceAlarmId] else {
            return false
        }
        if let current = currentAlarmRunId?.uuidString, pinnedRunId != current {
            return false
        }
        return true
    }

    func clearAlarmKitSurfaceSuppressionRisk(sourceAlarmId: String, reason: String) {
        if alarmKitSurfaceSuppressionRiskBySource.removeValue(forKey: sourceAlarmId) != nil {
            log("[AlarmKitSuppressionRisk] cleared source=\(sourceAlarmId) reason=\(reason)")
        }
    }

    func markLockedEngineCandidateFailed(sourceAlarmId: String, reason: String) {
        if lockedEngineAudibilityState == .engineCandidatePlaying {
            log("[LockedNoUI] candidate failed — resetting to engineNotPlaying reason=\(reason)")
            resetLockedEngineAudibilityState(reason: reason)
        }
        if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            markAlarmKitSurfaceSuppressionRisk(sourceAlarmId: sourceAlarmId, reason: reason)
        } else {
            log("[LockedNoUI] candidate failure did not imply suppression takeover source=\(sourceAlarmId) reason=\(reason)")
        }
    }

    /// Strict two-sample verification — required before dismissing AlarmKit.
    func isAppEngineActuallyAudible(reason: String) async -> Bool {
        guard passesAudibilitySessionGuards(reason: reason) else { return false }
        guard let alarmId = currentAlarmId, let runId = currentAlarmRunId else {
            log("[EngineVerify] FAIL reason=no-active-session request=\(reason)")
            return false
        }
        let engine = AlarmContinuousAudioEngine.shared
        guard engine.currentAlarmRunId == runId else {
            log("[EngineVerify] FAIL reason=run-id-mismatch request=\(reason)")
            return false
        }
        guard engine.captureAudibilitySample().alarmId == alarmId else {
            log("[EngineVerify] FAIL reason=alarm-id-mismatch request=\(reason)")
            return false
        }
        return await engine.verifyAudibilityWithProgression(reason: reason)
    }

    private func passesAudibilitySessionGuards(reason: String) -> Bool {
        if terminalActionRecorded {
            log("[EngineVerify] FAIL reason=terminal-action-recorded request=\(reason)")
            return false
        }
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            log("[EngineVerify] FAIL reason=final-stop-or-snooze request=\(reason)")
            return false
        }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging
        if !ringing {
            log("[EngineVerify] FAIL reason=alarm-not-ringing request=\(reason)")
            return false
        }
        return true
    }

    func recordPossibleHardwareSuppression(reason: String, scenePhase: String? = nil) {
        let now = Date()
        if scenePhase == "inactive" {
            lastSceneInactiveAt = now
        } else if scenePhase == "background" {
            lastSceneBackgroundAt = now
        } else {
            lastSceneInactiveAt = now
        }
        lastHardwareSuppressionCheckAt = now
        log("[HardwareRecovery] possible side-button/lock suppression detected reason=\(reason) alarmId=\(currentAlarmId ?? "nil")")
        if let alarmId = currentAlarmId ?? AlarmAuthHandoffStore.activeRingingAlarmId(),
           !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed(),
           AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging {
            markAlarmKitSurfaceSuppressionRisk(sourceAlarmId: alarmId, reason: reason)
        }
    }

    func markHardwareRecoveryPending(_ pending: Bool) {
        hardwareRecoveryPending = pending
        if pending {
            lastHardwareRecoveryScheduledAt = Date()
        }
    }

    func clearHardwareRecoveryState() {
        hardwareRecoveryPending = false
        lastHardwareRecoveryScheduledAt = nil
        lowVolumeWarningActive = false
    }

    func markEngineInaudibleWhileLocked() {
        if !engineInaudibleWhileLockedProven {
            engineInaudibleWhileLockedProven = true
            log("[LockedAudible] engine PROVEN inaudible while locked — AlarmKit (with UI) owns audio until volume rises / unlock")
        }
    }

    /// Declares a live AlarmKit alerting surface the intentional audible owner while
    /// the app is not active. Idempotent. Pins owner=alarmKit and suppresses the
    /// destructive "silent AlarmKit" recovery storm.
    func markAlarmKitPrimaryLocked(reason: String) {
        if !alarmKitPrimaryLocked {
            alarmKitPrimaryLocked = true
            log("[AlarmAudio] → alarmKitPrimaryLocked owner=alarmKit reason=\(reason)")
        }
        switch phase {
        case .alarmKitSettling, .appEnginePreparing, .appEngineFadingIn, .appEnginePrimary:
            transitionAudioPhase(to: .alarmKitFallback, reason: "alarmkit-primary-locked-\(reason)")
        default:
            // alarmKitFallback already implies owner=alarmKit; waitingForAlarmKit/stopped left as-is.
            break
        }
    }

    func clearAlarmKitPrimaryLocked(reason: String) {
        if alarmKitPrimaryLocked {
            alarmKitPrimaryLocked = false
            log("[AlarmAudio] cleared alarmKitPrimaryLocked reason=\(reason)")
        }
    }

    /// True when AlarmKit is the intentional locked/background owner — callers must
    /// not run engine takeover, dead-audio recovery, or surface dismissal.
    func isAlarmKitPrimaryLockedActive() -> Bool {
        alarmKitPrimaryLocked && UIApplication.shared.applicationState != .active
    }

    func clearEngineInaudibleWhileLocked(reason: String) {
        if engineInaudibleWhileLockedProven {
            engineInaudibleWhileLockedProven = false
            log("[LockedAudible] cleared engine-inaudible flag reason=\(reason) — no-UI engine may take over again")
        }
    }

    /// Hands audio ownership to AlarmKit (with UI) when the no-UI engine cannot be
    /// heard while locked (media volume at/near zero). Called by the audible
    /// verification failure path so the alarm is never left silent.
    func recordLockedEngineInaudible(reason: String) {
        // Only LATCH "proven inaudible while locked" (which blocks every future
        // locked engine takeover until unlock / volume rise) when the engine truly
        // cannot be heard — i.e. media volume is at/near zero, where `.playback` is
        // physically silent. A TRANSIENT session-activation failure (the side-button
        // interruption that just suppressed AlarmKit) clears within ~1s; latching the
        // engine off for it strands the alarm in AlarmKit-fallback with no sound for
        // the rest of the run (the overnight "side button → silence" bug). In that
        // case we still fall back to AlarmKit (never silent) but keep the engine
        // eligible so the next retry — or the keep-alive session-recovered re-drive —
        // can take over.
        let transientSession = AlarmContinuousAudioEngine.shared.lastAudibleRecoveryFailedSessionActivation
        let outputVolume = AVAudioSession.sharedInstance().outputVolume
        let genuinelyLowVolume = outputVolume <= Self.lowOutputVolumeThreshold
        if genuinelyLowVolume || !transientSession {
            markEngineInaudibleWhileLocked()
        } else {
            log("[LockedAudible] NOT latching inaudible — transient session-activation failure output=\(String(format: "%.2f", outputVolume)) reason=\(reason)")
        }
        switch phase {
        case .alarmKitSettling, .appEnginePreparing, .appEngineFadingIn, .appEnginePrimary:
            transitionAudioPhase(to: .alarmKitFallback, reason: "engine-inaudible-locked-\(reason)")
        case .waitingForAlarmKit, .alarmKitFallback, .stopped:
            break
        }
    }

    /// Target system output volume while the alarm UI is foreground.
    /// Respects the user's configured alarm volume but never below 90%;
    /// bumps to 100% when media volume has been pressed near zero.
    func resolvedForegroundVolumeFloor() -> Float {
        let configured = max(0.01, min(1.0, selectedSoundVolume))
        let output = lastKnownOutputVolume >= 0
            ? lastKnownOutputVolume
            : AVAudioSession.sharedInstance().outputVolume
        let policyFloor = output <= Self.lowOutputVolumeThreshold
            ? Self.foregroundVolumeFloorAggressive
            : Self.foregroundVolumeFloorStandard
        return max(configured, policyFloor)
    }

    /// After AlarmKit suppression, AppEngine plays in the media domain. Keep player at
    /// max immediately; raise system media volume only once playback is stable — calling
    /// MPVolumeView during `setActive`/`play()` in background interrupts the session.
    func enforceAlarmKitHandoffVolumeParity(reason: String, applyMediaFloor: Bool = true) {
        guard isAlarmRinging else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let target = Self.alarmKitHandoffMediaVolumeTarget
        let output = AVAudioSession.sharedInstance().outputVolume
        let appState = UIApplication.shared.applicationState
        log(
            "[Volume] AlarmKit→AppEngine handoff parity target=\(String(format: "%.2f", target)) " +
            "currentMedia=\(String(format: "%.2f", output)) configuredAlarm=\(String(format: "%.2f", selectedSoundVolume)) " +
            "appState=\(appState.rawValue) reason=\(reason)"
        )
        AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(reason: "handoff-parity-\(reason)")

        guard applyMediaFloor else { return }
        // MPVolumeView in background (no key window) can interrupt AVAudioPlayer right after
        // startAudibleRecovery — defer until foreground or verified playback.
        guard appState == .active || appState == .inactive else {
            log("[Volume] handoff media floor deferred — app background; player kept at max reason=\(reason)")
            return
        }
        guard output + 0.01 < target else { return }
        SystemOutputVolumeFloorManager.shared.enforceFloorImmediately(
            minimumVolume: target,
            reason: "alarmkit-handoff-\(reason)"
        )
    }

    /// Called after locked engine verification passes — safe point to raise media volume.
    func enforceAlarmKitHandoffVolumeParityAfterVerified(reason: String) {
        enforceAlarmKitHandoffVolumeParity(reason: reason, applyMediaFloor: true)
        if !AlarmContinuousAudioEngine.shared.confirmStillPlaying(),
           let runId = currentAlarmRunId {
            log("[Volume] handoff parity reassert — engine stalled after media floor reason=\(reason)")
            _ = AlarmContinuousAudioEngine.shared.startAudibleRecovery(alarmRunId: runId, reason: "handoff-parity-reassert-\(reason)")
        }
    }

    /// While foreground, keep player at max and raise system volume to the policy floor.
    func enforceForegroundVolumeControl(reason: String) {
        guard isAlarmRinging else { return }
        let appState = UIApplication.shared.applicationState
        guard appState == .active || appState == .inactive else { return }
        let floor = resolvedForegroundVolumeFloor()
        if phase == .appEngineFadingIn || phase == .appEnginePrimary {
            AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(reason: "foreground-volume-\(reason)")
        }
        let enforce = {
            SystemOutputVolumeFloorManager.shared.enforceFloorImmediately(
                minimumVolume: floor,
                reason: "foreground-control-\(reason)"
            )
        }
        if Thread.isMainThread {
            enforce()
        } else {
            DispatchQueue.main.async(execute: enforce)
        }
        log("[Volume] foreground volume control floor=\(String(format: "%.2f", floor)) reason=\(reason)")
    }

    func handleOutputVolumeChange(
        oldVolume: Float,
        newVolume: Float,
        sourceAlarmId: String?
    ) {
        lastKnownOutputVolume = newVolume
        if appEngineConfirmedPlaying() {
            AppEngineVolumeResetMonitor.shared.syncWithCurrentState(reason: "output-volume-change")
        }
        // If the user turned the volume back up, the no-UI engine can be audible
        // again — allow it to reclaim from AlarmKit on the next trigger.
        if newVolume > Self.lowOutputVolumeThreshold {
            clearEngineInaudibleWhileLocked(reason: "volume-rose")
        }
        let resolvedSource = sourceAlarmId ?? currentAlarmId
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()
        print("[Volume] outputVolume changed old=\(String(format: "%.2f", oldVolume)) new=\(String(format: "%.2f", newVolume)) source=\(resolvedSource ?? "nil")")

        let alarmStillActive = isAlarmRinging
            || AlarmAuthHandoffStore.shouldRestoreOnAppOpen()
        guard alarmStillActive, let source = resolvedSource else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }

        // Volume rocker during a locked AlarmKit-owned ring is user/system
        // interaction — start AppEngine immediately so sound does not die.
        if UIApplication.shared.applicationState != .active,
           isAlarmKitPrimaryLockedActive(),
           !appEngineConfirmedPlaying(),
           AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression,
           abs(newVolume - oldVolume) > 0.01 {
            print("[VolumeRecovery] volume button during AlarmKit ring — immediate AppEngine takeover source=\(source)")
            let takeover = {
                _ = NotificationManager.shared.startAppEngineAfterAlarmKitSuppression(
                    sourceAlarmId: source,
                    reason: "volume-suppression-\(String(format: "%.2f", newVolume))"
                )
            }
            if Thread.isMainThread {
                takeover()
            } else {
                DispatchQueue.main.async(execute: takeover)
            }
            return
        }

        let configuredTarget = max(0.01, min(1.0, selectedSoundVolume))
        let foregroundFloor = resolvedForegroundVolumeFloor()
        // Foreground: never let media volume sit below 90% (100% when crushed).
        if newVolume + 0.01 < foregroundFloor {
            lowVolumeWarningActive = true
            print("[Volume] low output volume while alarm ringing source=\(source)")

            let appState = UIApplication.shared.applicationState
            let appForeground = appState == .active || appState == .inactive
            let backgroundUnlockedOwnership = NotificationManager.shared.shouldAllowBackgroundUnlockedAppEngineOwnership(
                sourceAlarmId: source
            )
            if appEngineConfirmedPlaying() {
                AppEngineVolumeResetMonitor.shared.checkAndResetNow(reason: "volume-down-\(String(format: "%.2f", newVolume))")
            }
            if appForeground {
                let floor = foregroundFloor
                if phase == .appEngineFadingIn || phase == .appEnginePrimary || phase == .alarmKitFallback {
                    AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(reason: "low-system-volume-foreground")
                    print("[Volume] AppEngine player volume kept at 1.0")
                }
                let enforce = {
                    SystemOutputVolumeFloorManager.shared.enforceFloorImmediately(
                        minimumVolume: floor,
                        reason: "volume-down-\(String(format: "%.2f", newVolume))"
                    )
                }
                if Thread.isMainThread {
                    enforce()
                } else {
                    DispatchQueue.main.async(execute: enforce)
                }
                print("[Volume] volume down detected; restoring system floor to \(String(format: "%.2f", floor)) appState=\(appState.rawValue)")
                NotificationCenter.default.post(
                    name: .alarmVolumeFloorHint,
                    object: nil,
                    userInfo: ["message": "iPhone volume is low. Turn volume up for louder alarm."]
                )
            } else if backgroundUnlockedOwnership && appEngineConfirmedPlaying() {
                let floor = max(configuredTarget, foregroundFloor)
                AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(
                    reason: "low-system-volume-background-unlocked"
                )
                let restore = {
                    SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
                        floor,
                        reason: "background-unlocked-volume-down-\(String(format: "%.2f", newVolume))",
                        allowBackground: true
                    )
                }
                if Thread.isMainThread {
                    restore()
                } else {
                    DispatchQueue.main.async(execute: restore)
                }
                print("[Volume] background unlocked volume down detected; restoring system floor to \(String(format: "%.2f", floor)) appState=\(appState.rawValue)")
            } else if !appEngineConfirmedPlaying() {
                if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
                    print("[VolumeRecovery] volume drop during AlarmKit ring — attempting AppEngine takeover source=\(source)")
                    let takeover = {
                        _ = NotificationManager.shared.startAppEngineAfterAlarmKitSuppression(
                            sourceAlarmId: source,
                            reason: "volume-suppression-\(String(format: "%.2f", newVolume))"
                        )
                    }
                    if Thread.isMainThread {
                        takeover()
                    } else {
                        DispatchQueue.main.async(execute: takeover)
                    }
                    return
                }
                if isAlarmKitPrimaryLockedActive()
                    || NotificationManager.shared.hasLiveAlarmKitSurface(
                        sourceAlarmId: source,
                        reason: "volume-suppression-low-output"
                    ) {
                    print("[VolumeRecovery] output low; AppEngine disabled, AlarmKit owner preserved source=\(source)")
                    NotificationManager.shared.scheduleAlarmRecoveryOpenAppNotification(
                        sourceAlarmId: source,
                        reason: "volume-suppression-low-output"
                    )
                } else {
                    print("[VolumeRecovery] no live AlarmKit surface; scheduling one last-resort AlarmKit recovery source=\(source)")
                    NotificationManager.shared.scheduleAudibleAlarmKitRecoveryIfNeeded(
                        sourceAlarmId: source,
                        reason: "volume-suppression-low-output",
                        delay: 1.0
                    )
                }
            }
        } else if newVolume + 0.01 >= foregroundFloor {
            lowVolumeWarningActive = false
        }
    }

    /// Prepare AVAudioPlayer + warm AVAudioSession while AlarmKit still owns sound.
    /// Does not start playback or arm the delayed foreground takeover.
    func prewarmEngineForInstantHandoff(alarmId: String, soundName: String, reason: String) {
        if phase == .stopped {
            beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: "prewarm-\(reason)")
        }
        if phase == .waitingForAlarmKit {
            recordAlarmKitAlerting()
        }
        guard let runId = currentAlarmRunId else {
            log("[StateController] prewarmEngineForInstantHandoff: no runId alarmId=\(alarmId)")
            return
        }
        if #available(iOS 26.0, *) {
            // Converge on the EXACT file AlarmKit plays (the staged file), so AppEngine
            // never diverges onto the full untrimmed original. Fall back to the resolved
            // source only if staging fails.
            let scheduler = AlarmSchedulerIOS26AlarmKit()
            selectedSoundURL = scheduler.stagedSoundURL(for: soundName) ?? scheduler.resolvedSoundURL(for: soundName)
        }
        AlarmContinuousAudioEngine.shared.prewarmForInstantHandoff(
            soundName: soundName,
            alarmId: alarmId,
            alarmRunId: runId
        )
        log("[StateController] prewarmEngineForInstantHandoff complete alarmId=\(alarmId) phase=\(phase.rawValue) reason=\(reason)")
    }

    func handleAlarmKitAlerting(alarmId: String, soundName: String, reason: String) {
        // Ensure the silent keep-alive is running so the app stays alive (unsuspended)
        // through the AlarmKit ring until AppEngine takes over. It is stopped again the
        // moment AppEngine owns audio (see transitionAudioPhase).
        AlarmKeepAliveAudioService.shared.ensureAliveForAlarmRing(reason: "alarmkit-alerting")
        let appActive = UIApplication.shared.applicationState == .active
        DiagnosticsLog.shared.log(
            "AlarmKit alerting alarmId=\(alarmId) sound=\(soundName) appActive=\(appActive) phase=\(phase.rawValue) reason=\(reason)",
            category: "Alarm"
        )
        let shouldPreserveAlarmKitOwner = NotificationManager.shared.shouldPreserveAlarmKitPrimaryOwner(
            sourceAlarmId: alarmId
        )

        // PROCESS-ALIVE ANCHOR (reliability fix). The instant the ring starts while
        // backgrounded/locked, acquire a UIApplication background-task assertion so the
        // process keeps ~30s of GUARANTEED execution — self-renewing while the ring is
        // live. Without this, the ONLY thing keeping the app alive at ring time is the
        // silent keep-alive AVAudioPlayer, whose play() reliably FAILS for ~5s while
        // AlarmKit holds the audio hardware. During that unanchored gap, pressing the
        // side button stops AlarmKit and iOS suspends the process before the
        // `alarmUpdates` observation can drive the AppEngine takeover — so the alarm
        // goes silent until the app is reopened (the morning "AppEngine never played"
        // bug). The bridge's passive-standby path (preserve-owner + engine inactive)
        // only PREWARMS the engine SILENTLY and acquires the assertion — it starts no
        // audible audio, so there is no dual sound.
        if !appActive, shouldPreserveAlarmKitOwner {
            let surfaceForAnchor = AlarmAuthHandoffStore.surfaceAlarmId()
                ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
                ?? alarmId
            AlarmBackgroundAudioBridge.shared.start(
                surfaceAlarmId: surfaceForAnchor,
                sourceAlarmId: alarmId
            )
        }

        if phase == .alarmKitFallback {
            if appActive,
               let runId = currentAlarmRunId {
                if AlarmContinuousAudioEngine.shared.currentAlarmRunId != runId {
                    AlarmContinuousAudioEngine.shared.prepareSilently(
                        soundName: soundName,
                        alarmId: alarmId,
                        alarmRunId: runId
                    )
                }
                startForegroundAppEngineImmediately(
                    alarmRunId: runId,
                    reason: "alarmkit-fallback-active"
                )
                return
            }
            log("[StateController] AlarmKit alerting — alarmKitFallback active, preserving AlarmKit owner (reason=\(reason))")
            return
        }

        if phase == .appEngineFadingIn || phase == .appEnginePrimary {
            log("[StateController] AlarmKit alerting — engine already primary, dismissing AlarmKit UI")
            NotificationManager.shared.dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: alarmId,
                reason: "engine-primary-alerting"
            )
            return
        }

        if phase == .alarmKitSettling || phase == .appEnginePreparing {
	            if shouldPreserveAlarmKitOwner {
	                takeoverScheduled = false
	                takeoverScheduledAt = nil
	                takeoverWorkItem?.cancel()
	                takeoverWorkItem = nil
	                markAlarmKitPrimaryLocked(reason: "preserve-alarmkit-owner-\(reason)")
	                log("[StateController] AlarmKit alerting — background primary owner preserved; AppEngine idle until explicit handoff (reason=\(reason))")
	                return
	            }
            if let runId = currentAlarmRunId {
                if appActive {
                    if AlarmContinuousAudioEngine.shared.currentAlarmRunId != runId {
                        AlarmContinuousAudioEngine.shared.prepareSilently(
                            soundName: soundName,
                            alarmId: alarmId,
                            alarmRunId: runId
                        )
                    }
                    startForegroundAppEngineImmediately(
                        alarmRunId: runId,
                        reason: "alarmkit-alerting-active"
                    )
                } else if !takeoverScheduled {
                    log("[StateController] AlarmKit alerting — phase \(phase.rawValue) with no takeover scheduled, re-arming takeover")
                    scheduleDelayedTakeover(
                        alarmRunId: runId,
                        delay: Self.alarmKitSettleDelay
                    )
                } else {
                    log("[StateController] AlarmKit alerting — already in \(phase.rawValue), takeover scheduled at \(takeoverScheduledAt?.description ?? "unknown"), keeping existing takeover")
                }
            } else {
                log("[StateController] AlarmKit alerting — phase \(phase.rawValue) but runId missing, ignoring")
            }
            return
        }

        log("[StateController] AlarmKit alerting — setting up session. currentPhase=\(phase.rawValue)")

        if phase == .stopped {
            beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: reason)
        }

        if phase == .waitingForAlarmKit {
            recordAlarmKitAlerting()
        }

	        if shouldPreserveAlarmKitOwner {
	            takeoverScheduled = false
	            takeoverScheduledAt = nil
	            takeoverWorkItem?.cancel()
	            takeoverWorkItem = nil
	            markAlarmKitPrimaryLocked(reason: "preserve-alarmkit-owner-\(reason)")
	            log("[StateController] AlarmKit alerting — preserving AlarmKit owner; AppEngine idle until explicit handoff (reason=\(reason))")
	            return
	        }

        guard let runId = currentAlarmRunId else {
            log("[StateController] handleAlarmKitAlerting: no runId after session begin — aborting")
            return
        }
        log("[StateController] handleAlarmKitAlerting: using runId=\(runId.uuidString)")
        if #available(iOS 26.0, *) {
            // Converge on the EXACT file AlarmKit plays (the staged file), so AppEngine
            // never diverges onto the full untrimmed original. Fall back to the resolved
            // source only if staging fails.
            let scheduler = AlarmSchedulerIOS26AlarmKit()
            selectedSoundURL = scheduler.stagedSoundURL(for: soundName) ?? scheduler.resolvedSoundURL(for: soundName)
        } else {
            selectedSoundURL = nil
        }

        AlarmContinuousAudioEngine.shared.prepareSilently(
            soundName: soundName,
            alarmId: alarmId,
            alarmRunId: runId
        )

        if appActive {
            startForegroundAppEngineImmediately(
                alarmRunId: runId,
                reason: "alarmkit-alerting-active"
            )
        } else {
            scheduleDelayedTakeover(
                alarmRunId: runId,
                delay: Self.alarmKitSettleDelay
            )
        }
    }

    /// Called when foreground timer detects due alarm before AlarmKit alerting.
    /// Creates/reuses session and immediately hands foreground audio to AppEngine.
    func handleForegroundTimerAlarm(alarmId: String, soundName: String) {
        log("[StateController] handleForegroundTimerAlarm: alarmId=\(alarmId)")
        beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: "foreground-timer")
        guard let runId = currentAlarmRunId else { return }
        log("[StateController] handleForegroundTimerAlarm: runId=\(runId.uuidString)")

        AlarmContinuousAudioEngine.shared.prepareSilently(
            soundName: soundName,
            alarmId: alarmId,
            alarmRunId: runId
        )

        startForegroundAppEngineImmediately(
            alarmRunId: runId,
            reason: "foreground-timer"
        )
    }

    func startForegroundAppEngineImmediately(alarmRunId: UUID, reason: String) {
        log("[StateController] startForegroundAppEngineImmediately ENTRY phase=\(phase.rawValue) currentRunId=\(currentAlarmRunId?.uuidString ?? "nil") requestedRunId=\(alarmRunId.uuidString) reason=\(reason)")
        guard UIApplication.shared.applicationState == .active else {
            log("[StateController] foreground immediate start blocked — app not active reason=\(reason)")
            return
        }
        guard currentAlarmRunId == alarmRunId else {
            log("[StateController] foreground immediate start blocked — runId mismatch")
            return
        }
        guard !terminalActionRecorded else {
            log("[StateController] foreground immediate start blocked — terminal action recorded")
            return
        }
        guard currentAlarmId != nil else {
            log("[StateController] foreground immediate start blocked — no active alarm")
            return
        }
        guard AlarmContinuousAudioEngine.shared.currentAlarmRunId == alarmRunId else {
            log("[StateController] foreground immediate start blocked — engine not prepared for runId")
            return
        }

        takeoverScheduled = false
        takeoverScheduledAt = nil
        takeoverWorkItem?.cancel()
        takeoverWorkItem = nil
        clearAlarmKitPrimaryLocked(reason: "foreground-immediate-\(reason)")
        userHasUnlockedDuringThisAlarmRun = true

        switch phase {
        case .alarmKitSettling, .appEnginePreparing:
            AlarmContinuousAudioEngine.shared.startFadeIn(
                alarmRunId: alarmRunId,
                fadeInDuration: 0,
                targetVolume: Self.appEngineFinalTargetVolume
            )
            enforceForegroundVolumeControl(reason: "foreground-immediate-\(reason)")
        case .appEngineFadingIn, .appEnginePrimary:
            AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(reason: "foreground-immediate-\(reason)")
            enforceForegroundVolumeControl(reason: "foreground-immediate-\(reason)")
        default:
            log("[StateController] foreground immediate start blocked — phase \(phase.rawValue) not eligible")
        }
    }

    func scheduleEarlyTakeoverAfterInterruptionEnd() {
        guard let runId = currentAlarmRunId else { return }
        scheduleDelayedTakeover(alarmRunId: runId, delay: Self.postInterruptionGraceDelay)
    }

    func requestAppEngineTakeoverIfAllowed(alarmRunId: UUID, reason: String) {
        log("[StateController] requestAppEngineTakeoverIfAllowed ENTRY — phase=\(phase.rawValue) currentRunId=\(currentAlarmRunId?.uuidString ?? "nil") requestedRunId=\(alarmRunId.uuidString) reason=\(reason)")
        guard currentAlarmRunId == alarmRunId else {
            log("[StateController] Takeover blocked — runId mismatch: current=\(currentAlarmRunId?.uuidString ?? "nil") requested=\(alarmRunId.uuidString)")
            return
        }
        guard !terminalActionRecorded else {
            log("[StateController] Takeover blocked — terminal action recorded")
            return
        }
        guard phase == .alarmKitSettling || phase == .appEnginePreparing else {
            log("[StateController] Takeover blocked — phase \(phase.rawValue) not eligible")
            return
        }
        guard currentAlarmId != nil else {
            log("[StateController] Takeover blocked — no active alarm")
            return
        }
        guard AlarmContinuousAudioEngine.shared.currentAlarmRunId == alarmRunId else {
            log("[StateController] Takeover blocked — engine not prepared for runId")
            return
        }
        // While the app is NOT active (backgrounded/locked), the user requires the
        // alarm to keep ringing with NO AlarmKit UI. Take over via the no-UI engine
        // when media volume is high enough for `.playback` to actually be audible —
        // once playing, `.playback` audio survives the screen-lock + side button,
        // and the 50ms watchdog restarts it after volume-button interruptions, so
        // the sound keeps retriggering until the user unlocks. At/near zero media
        // volume `.playback` is physically silent, so AlarmKit (ringer domain, with
        // its system UI) must remain the audible owner — there is no public API to
        // be heard at volume 0 without a system surface.
        if UIApplication.shared.applicationState != .active {
            if let alarmId = currentAlarmId,
               NotificationManager.shared.shouldPreserveAlarmKitPrimaryOwner(sourceAlarmId: alarmId) {
                log("[AudioOwner] AppEngine takeover blocked — preserving AlarmKit owner until explicit suppression")
                return
            }
            if let alarmId = currentAlarmId,
               NotificationManager.shared.shouldAllowBackgroundUnlockedAppEngineOwnership(sourceAlarmId: alarmId) {
                log("[AudioOwner] AppEngine audible takeover allowed in background-unlocked state")
                AlarmContinuousAudioEngine.shared.ensurePlayerVolumeAtMaximum(
                    reason: "background-unlocked-takeover-\(reason)"
                )
                startAppEngineFadeIn(alarmRunId: alarmRunId, reason: "background-unlocked-\(reason)")
                let targetFloor = resolvedForegroundVolumeFloor()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
                        targetFloor,
                        reason: "background-unlocked-takeover-\(reason)",
                        allowBackground: true
                    )
                }
                return
            }
            let output = AVAudioSession.sharedInstance().outputVolume
            // Volume-floor-ignoring takeover: after a suppression signal, ALWAYS
            // attempt the no-UI engine regardless of current media volume — the
            // engine ramps up and we best-effort raise system output, with the
            // no-UI watchdog re-alerting AlarmKit if it never becomes audible.
            // Otherwise (flag off) only take over when media volume is already
            // high enough to be audible (>= configured alarm volume). Use >= so
            // configured alarm volumes at exactly the floor (e.g. 0.15) still pass.
            let mediaVolumeAudible = output + 0.001 >= max(0.01, selectedSoundVolume)
                && !engineInaudibleWhileLockedProven
            let shouldAttemptTakeover = AlarmFeatureFlags.appEngineTakeoverIgnoresVolumeFloor
                || mediaVolumeAudible
            if AlarmFeatureFlags.appEngineTakeoverIgnoresVolumeFloor, !mediaVolumeAudible {
                // Monitoring: measure how often we force a takeover at low/zero media
                // volume (where audibility depends on the best-effort system-volume
                // raise, which iOS may reject in the background).
                log("[AudioOwner] floor-ignoring takeover forced at low volume output=\(String(format: "%.2f", output)) configured=\(String(format: "%.2f", selectedSoundVolume)) provenInaudible=\(engineInaudibleWhileLockedProven)")
            }
            if shouldAttemptTakeover,
               tryEngineAudibleWhileLocked(reason: "takeover-while-locked") {
                if let alarmId = currentAlarmId {
                    // AlarmKit's lock-screen surface was dismissed, so give the user a
                    // tappable way back to the in-app Stop/Snooze UI.
                    NotificationManager.shared.scheduleRecoveryPromptNotification(sourceAlarmId: alarmId)
                    NotificationManager.shared.armEngineAudibleVerification(
                        sourceAlarmId: alarmId,
                        reason: "takeover-while-locked"
                    )
                }
                return
            }
            log("[AudioOwner] AppEngine takeover deferred — AlarmKit audible owner while inactive (output=\(String(format: "%.2f", output)) provenInaudible=\(engineInaudibleWhileLockedProven) phase=\(phase.rawValue))")
            // CRITICAL: when locked takeover is deferred (low output volume,
            // engine proven inaudible, etc.) we cannot leave the alarm silent.
            // Route to audible AlarmKit recovery so the system surface restores
            // the ringer-domain audio. This handles the "side button → backgrounded
            // → engine never started" silence gap observed in device logs.
            if let alarmId = currentAlarmId,
               !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
                if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
                    log("[LockedNoUI] takeover deferred → locked no-UI engine recovery output=\(String(format: "%.2f", output))")
                    NotificationManager.shared.attemptLockedNoUIEngineRecovery(
                        sourceAlarmId: alarmId,
                        reason: "takeover-deferred-while-locked"
                    )
                } else {
                    NotificationManager.shared.detectAndRecoverDeadAudioState(
                        sourceAlarmId: alarmId,
                        reason: "takeover-deferred-while-locked-output-\(String(format: "%.2f", output))"
                    )
                }
            }
            return
        }
        log("[AudioOwner] AppEngine audible takeover allowed in foreground")
        log("[AudioOwner] App active; AppEngine takeover allowed (phase=\(phase.rawValue))")
        startAppEngineFadeIn(alarmRunId: alarmRunId, reason: reason)
        // Raise system output volume to the user's configured level now that
        // the engine is starting. selectedSoundVolume was set in beginAlarmSession.
        let floorVolume = selectedSoundVolume
        _ = floorVolume
    }

    /// Attempts to make the app-owned engine the AUDIBLE, **no-UI** audio source
    /// while the phone is locked. Used when AlarmKit's audible surface was lost via
    /// slide-to-stop / side-button and we want the alarm to keep ringing WITHOUT
    /// re-showing the AlarmKit system UI.
    ///
    /// This intentionally bypasses the normal `applicationState == .active`
    /// requirement enforced by `requestAppEngineTakeoverIfAllowed`. That guard
    /// exists to prevent the engine and an *audible* AlarmKit surface from playing
    /// at once (dual sound). Here the AlarmKit surface has already been dismissed,
    /// so there is no dual-sound risk and the engine is safe to take over locked.
    ///
    /// Returns `true` only if the engine is now confirmed playing. The caller must
    /// fall back to an audible AlarmKit re-alert when this returns `false`, so the
    /// alarm is never left silent.
    /// Re-establishes a live engine session after side-button / slide-to-stop without
    /// resetting auth-handoff or final-stop flags.
    func ensureLockedRecoverySession(alarmId: String, soundName: String, reason: String) {
        log("[LockedNoUI] ensureLockedRecoverySession alarmId=\(alarmId) phase=\(phase.rawValue) reason=\(reason)")
        if currentAlarmId != alarmId {
            currentAlarmId = alarmId
            currentAlarmRunId = UUID()
            selectedSoundName = soundName
            terminalActionRecorded = false
            if let uuid = UUID(uuidString: alarmId),
               let alarm = AlarmStore.shared.alarm(by: uuid),
               alarm.soundVolume > 0, alarm.soundVolume <= 1.0 {
                selectedSoundVolume = alarm.soundVolume
            } else {
                selectedSoundVolume = 1.0
            }
        } else if currentAlarmRunId == nil {
            currentAlarmRunId = UUID()
        }
        if phase == .stopped || phase == .waitingForAlarmKit {
            transitionAudioPhase(to: .appEnginePreparing, reason: "locked-recovery-\(reason)")
        }
        guard let runId = currentAlarmRunId else { return }
        if AlarmContinuousAudioEngine.shared.currentAlarmRunId != runId {
            AlarmContinuousAudioEngine.shared.prepareSilently(
                soundName: soundName,
                alarmId: alarmId,
                alarmRunId: runId
            )
        }
    }

    @discardableResult
    func tryEngineAudibleWhileLocked(reason: String) -> Bool {
        guard !terminalActionRecorded,
              !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            log("[LockedAudible] skipped — terminal/final-stop reason=\(reason)")
            return false
        }
        var alarmId = currentAlarmId
        var runId = currentAlarmRunId
        if alarmId == nil, let persisted = AlarmAuthHandoffStore.activeRingingAlarmId() {
            alarmId = persisted
        }
        guard let resolvedAlarmId = alarmId else {
            log("[LockedAudible] skipped — no active session reason=\(reason)")
            return false
        }
        let appActiveNow = UIApplication.shared.applicationState == .active
        let suppressionTakeoverAllowed = NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: resolvedAlarmId)
            || NotificationManager.shared.isHardwareSuppressionReason(reason)
        if !appActiveNow, !suppressionTakeoverAllowed {
            log("[LockedAudible] skipped — waiting for explicit suppression before locked takeover reason=\(reason)")
            return false
        }
        if phase == .stopped || phase == .waitingForAlarmKit || runId == nil {
            if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: resolvedAlarmId) {
                let sound: String = {
                    if let s = selectedSoundName, !s.isEmpty { return s }
                    guard let uuid = UUID(uuidString: resolvedAlarmId),
                          let alarm = AlarmStore.shared.alarm(by: uuid) else { return "" }
                    return alarm.soundName
                }()
                guard !sound.isEmpty else {
                    log("[LockedAudible] skipped — cannot resolve sound for locked recovery reason=\(reason)")
                    return false
                }
                ensureLockedRecoverySession(alarmId: resolvedAlarmId, soundName: sound, reason: reason)
                runId = currentAlarmRunId
            } else {
                log("[LockedAudible] skipped — phase \(phase.rawValue) ineligible reason=\(reason)")
                return false
            }
        }
        guard let runId else {
            log("[LockedAudible] skipped — no runId after session ensure reason=\(reason)")
            return false
        }
        let ignoreVolumeFloor = AlarmFeatureFlags.appEngineTakeoverIgnoresVolumeFloor
        if !ignoreVolumeFloor {
            guard !engineInaudibleWhileLockedProven else {
                log("[LockedAudible] skipped — engine proven inaudible while locked (volume too low) reason=\(reason)")
                return false
            }
        } else {
            log("[LockedAudible] volume-floor ignored — always attempting playback reason=\(reason)")
        }

        // CRITICAL (floor mode only): refuse to take over while locked if media
        // volume is at or below the audibility floor. The `.playback` engine
        // follows media volume; if we transition to appEnginePrimary at output=0.00
        // the user hears nothing AND we just dismissed the only audible source
        // (AlarmKit). When `appEngineTakeoverIgnoresVolumeFloor` is on, we skip this
        // and let the engine play + ramp anyway (AlarmKit UI stays until verified,
        // and the no-UI watchdog re-alerts AlarmKit if the engine is never audible).
        if !ignoreVolumeFloor, !appActiveNow {
            let outputVolumeNow = AVAudioSession.sharedInstance().outputVolume
            if outputVolumeNow <= Self.lowOutputVolumeThreshold {
                log("[LockedAudible] BLOCKED takeover — outputVolume=\(String(format: "%.2f", outputVolumeNow)) ≤ threshold reason=\(reason)")
                markEngineInaudibleWhileLocked()
                switch phase {
                case .alarmKitSettling, .appEnginePreparing, .appEngineFadingIn, .appEnginePrimary:
                    transitionAudioPhase(to: .alarmKitFallback, reason: "engine-blocked-low-output-\(reason)")
                default:
                    break
                }
                return false
            }
        }

        let engine = AlarmContinuousAudioEngine.shared
        // Ensure a player is prepared for this run (the engine may be cold if the
        // app was launched fresh for the Stop intent).
        if engine.currentAlarmRunId != runId {
            let soundName = selectedSoundName ?? ""
            guard !soundName.isEmpty else {
                log("[LockedAudible] skipped — engine not prepared and no known sound reason=\(reason)")
                return false
            }
            engine.prepareSilently(soundName: soundName, alarmId: resolvedAlarmId, alarmRunId: runId)
        }

        // Try to make the engine audible FIRST. Only promote the phase if it
        // actually starts playing — otherwise leave state untouched so the caller
        // can fall back to an audible AlarmKit re-alert.
        // In volume-floor-ignoring mode, start near the current (possibly low)
        // media volume and ramp gently to full over a few seconds instead of the
        // fast 0.3s restore (the user asked for a soft 2–5s ramp).
        let engineStarted: Bool = ignoreVolumeFloor
            ? engine.startAudibleRecovery(
                alarmRunId: runId,
                rampDuration: Self.postSlideRampDuration,
                startFloor: Self.appEngineInitialVolume,
                reason: reason
              )
            : engine.startAudibleRecovery(alarmRunId: runId, reason: reason)
        guard engineStarted else {
            log("[LockedAudible] ❌ engine could not start playing — AlarmKit re-alert needed reason=\(reason)")
            return false
        }

        if ignoreVolumeFloor {
            // player.volume is RELATIVE to system output volume; ramping the player
            // to full is inaudible at system-output 0. Best-effort raise the system
            // media volume to FULL so the ramp is actually heard. Background
            // MPVolumeView changes are unreliable, so retry across the ramp window
            // (spaced, AFTER playback is stable — calling it during setActive/play
            // interrupts the session). Still best-effort: if iOS rejects every
            // attempt, verification fails and AlarmKit re-alerts (never silent).
            let raiseTarget = resolvedForegroundVolumeFloor()
            SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
                raiseTarget,
                reason: "locked-takeover-volume-raise-\(reason)",
                allowBackground: true
            )
            for offset in [0.6, 1.4, 2.4] {
                DispatchQueue.main.asyncAfter(deadline: .now() + offset) {
                    let controller = AlarmAudioStateController.shared
                    guard controller.isAlarmRinging,
                          !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
                    SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
                        raiseTarget,
                        reason: "locked-takeover-volume-raise-retry-\(reason)",
                        allowBackground: true
                    )
                }
            }
        } else {
            // Re-check output volume AFTER play(): the system may still report 0
            // even when isPlaying==true. If so, we are inaudible — abort the
            // ownership change before we dismiss AlarmKit.
            let outputAfterPlay = AVAudioSession.sharedInstance().outputVolume
            if !appActiveNow && outputAfterPlay <= Self.lowOutputVolumeThreshold {
                log("[LockedAudible] BLOCKED post-play — engine running but outputVolume=\(String(format: "%.2f", outputAfterPlay)) ≤ threshold reason=\(reason)")
                markEngineInaudibleWhileLocked()
                switch phase {
                case .alarmKitSettling, .appEnginePreparing, .appEngineFadingIn, .appEnginePrimary:
                    transitionAudioPhase(to: .alarmKitFallback, reason: "engine-inaudible-post-play-\(reason)")
                default:
                    break
                }
                return false
            }
        }

        // Candidate only — keep AlarmKit/recovery alive until strict verification passes.
        markLockedEngineCandidate(reason: reason)
        markAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: resolvedAlarmId,
            reason: "locked-engine-candidate-started-\(reason)"
        )
        if AlarmContinuousAudioEngine.shared.recentMeterIsAudible() == false {
            markAlarmKitSurfaceSuppressionRisk(
                sourceAlarmId: resolvedAlarmId,
                reason: "locked-candidate-meter-silent-\(reason)"
            )
        }
        log("[LockedNoUI] engine candidate started source=\(resolvedAlarmId) reason=\(reason) phase=\(phase.rawValue)")
        log("[LockedNoUI] keeping AlarmKit recovery armed until verified source=\(resolvedAlarmId)")
        NotificationManager.shared.beginLockedEngineCandidateVerification(
            sourceAlarmId: resolvedAlarmId,
            reason: reason
        )
        return true
    }

    func markLockedEngineCandidate(reason: String) {
        lockedEngineAudibilityState = .engineCandidatePlaying
        log("[LockedNoUI] state=engineCandidatePlaying reason=\(reason)")
    }

    func resetLockedEngineAudibilityState(reason: String) {
        lockedEngineVerificationWorkItem?.cancel()
        lockedEngineVerificationWorkItem = nil
        if lockedEngineAudibilityState != .engineNotPlaying {
            log("[LockedNoUI] state=engineNotPlaying reason=\(reason)")
        }
        lockedEngineAudibilityState = .engineNotPlaying
    }

    /// Called after strict async verification while locked — promotes AppEngine to owner.
    @MainActor
    func confirmLockedEngineVerified(sourceAlarmId: String, reason: String) async {
        guard lockedEngineAudibilityState == .engineCandidatePlaying
            || lockedEngineAudibilityState == .engineVerifiedAudible else {
            return
        }
        guard await isAppEngineActuallyAudible(reason: "locked-verify-\(reason)") else {
            log("[LockedNoUI] verification failed — staying candidate source=\(sourceAlarmId) reason=\(reason)")
            markLockedEngineCandidateFailed(sourceAlarmId: sourceAlarmId, reason: "locked-verify-failed-\(reason)")
            NotificationManager.shared.evaluateNoAudibleOwnerRecoveryIfNeeded(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-candidate-verify-failed-\(reason)"
            )
            return
        }

        clearAlarmKitSurfaceSuppressionRisk(sourceAlarmId: sourceAlarmId, reason: "locked-engine-verified")
        lockedEngineAudibilityState = .engineVerifiedAudible
        log("[LockedNoUI] engine verified audible while locked source=\(sourceAlarmId) reason=\(reason)")
        enforceAlarmKitHandoffVolumeParityAfterVerified(reason: reason)

        switch phase {
        case .alarmKitSettling, .appEnginePreparing, .alarmKitFallback:
            transitionAudioPhase(to: .appEngineFadingIn, reason: "locked-verified-\(reason)")
            transitionAudioPhase(to: .appEnginePrimary, reason: "locked-verified-confirmed-\(reason)")
        case .appEngineFadingIn:
            transitionAudioPhase(to: .appEnginePrimary, reason: "locked-verified-confirmed-\(reason)")
        case .appEnginePrimary, .waitingForAlarmKit, .stopped:
            break
        }

        AppEngineVolumeResetMonitor.shared.syncWithCurrentState(reason: "locked-verified-\(reason)")

        if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            NotificationManager.shared.dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-verified-no-ui-\(reason)"
            )
        } else if shouldAllowAlarmKitLockScreenUI() {
            NotificationManager.shared.ensureSilentAlarmKitUIShell(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-verified-\(reason)"
            )
        } else {
            NotificationManager.shared.dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-verified-\(reason)"
            )
        }
        NotificationManager.shared.markLockedNoUIAudibleConfirmed(
            sourceAlarmId: sourceAlarmId,
            reason: "locked-verified-\(reason)"
        )
        log("[LockedNoUI] cancelling AlarmKit recovery source=\(sourceAlarmId) reason=\(reason)")
        _ = await NotificationManager.shared.verifyAndCancelPreArmedRecoveryIfEngineAudible(
            sourceAlarmId: sourceAlarmId,
            reason: "locked-verified-\(reason)"
        )
    }

    func isForbiddenSilentAudioState(
        sourceAlarmId: String,
        alarmKitAlerting: Bool,
        recoveryPending: Bool
    ) -> Bool {
        let appInactive = UIApplication.shared.applicationState != .active
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging
        let engineAudible = isAppEngineQuickAudible(reason: "forbidden-state-check")
            || lockedEngineAudibilityState == .engineVerifiedAudible
        return ForbiddenAudioStateEvaluator.isForbiddenSilentState(
            phase: phase,
            appInactive: appInactive,
            alarmStateRinging: ringing,
            finalStop: AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() || terminalActionRecorded,
            engineActuallyAudible: engineAudible,
            alarmKitAlerting: alarmKitAlerting,
            recoveryPending: recoveryPending
        )
    }

    func evaluateForbiddenAudioStateIfNeeded(reason: String) {
        guard let sourceAlarmId = currentAlarmId ?? AlarmAuthHandoffStore.activeRingingAlarmId() else {
            return
        }
        if UIApplication.shared.applicationState != .active,
           !NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId),
           NotificationManager.shared.hasAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId) {
            log("[ForbiddenAudioState] skipped — AlarmKit owns initial locked/background alert source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        Task { @MainActor in
            let alarmKitSurface = NotificationManager.shared.currentAlarmSurfaceStatus(
                sourceAlarmId: sourceAlarmId,
                reason: "forbidden-state-\(reason)"
            )
            let alarmKitAlerting = alarmKitSurface.trustedAsAudible
            let recoveryPending = hardwareRecoveryPending
                || AlarmAuthHandoffStore.isAuthRecoveryPending()
                || NotificationManager.shared.hasPreArmedRecovery(sourceAlarmId: sourceAlarmId)
                || NotificationManager.shared.hasPendingAuthRecoverySurface(sourceAlarmId: sourceAlarmId)
            guard isForbiddenSilentAudioState(
                sourceAlarmId: sourceAlarmId,
                alarmKitAlerting: alarmKitAlerting,
                recoveryPending: recoveryPending
            ) else {
                return
            }
            let throttleInterval: TimeInterval = 5.0
            if let last = lastForbiddenAudioStateRecoveryAt,
               Date().timeIntervalSince(last) < throttleInterval {
                return
            }
            lastForbiddenAudioStateRecoveryAt = Date()
            let appState = UIApplication.shared.applicationState
            let engineAudible = isAppEngineQuickAudible(reason: "forbidden-state-\(reason)")
            let appStateLabel: String = {
                switch appState {
                case .active: return "active"
                case .inactive: return "inactive"
                case .background: return "background"
                @unknown default: return "unknown(\(appState.rawValue))"
                }
            }()
            log(
                "[ForbiddenAudioState] detected phase=\(phase.rawValue) " +
                "appState=\(appStateLabel) engineAudible=\(engineAudible) " +
                "alarmKitAlerting=\(alarmKitAlerting) recoveryPending=\(recoveryPending) " +
                "source=\(sourceAlarmId) reason=\(reason)"
            )
            NotificationManager.shared.scheduleForbiddenAudioStateRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: reason
            )
        }
    }

    private func scheduleDelayedTakeover(alarmRunId: UUID, delay: TimeInterval) {
        if takeoverScheduled {
            if takeoverWorkItem != nil {
                log("[StateController] Takeover already scheduled at \(takeoverScheduledAt.map { String(describing: $0) } ?? "unknown") — not rescheduling")
                return
            }
            // Stale marker recovery: scheduled flag remained true but no live work item exists.
            log("[StateController] Takeover schedule marker was stale — re-arming delayed takeover")
            takeoverScheduled = false
            takeoverScheduledAt = nil
        }

        takeoverScheduled = true
        takeoverScheduledAt = Date()

        log("[StateController] Takeover scheduled in \(delay)s for runId: \(alarmRunId)")
        takeoverWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.takeoverWorkItem = nil
            self.takeoverScheduled = false
            self.requestAppEngineTakeoverIfAllowed(
                alarmRunId: alarmRunId,
                reason: "settle-delay-\(String(format: "%.2f", delay))s"
            )
        }
        takeoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func startAppEngineFadeIn(alarmRunId: UUID, reason: String) {
        log("[StateController] Takeover proceeding — calling startFadeIn reason=\(reason)")
        var fadeInDuration = Self.appEngineFadeInDuration
        if let alarmIdStr = currentAlarmId,
           let uuid = UUID(uuidString: alarmIdStr),
           let alarm = AlarmStore.shared.alarm(by: uuid),
           alarm.gentleWakeUpSeconds > 0 {
            fadeInDuration = TimeInterval(alarm.gentleWakeUpSeconds)
        }
        AlarmContinuousAudioEngine.shared.startFadeIn(
            alarmRunId: alarmRunId,
            fadeInDuration: fadeInDuration,
            targetVolume: Self.appEngineFinalTargetVolume
        )
    }

    /// Called when app becomes active. If takeover is pending and still in a
    /// settling phase, trigger immediate or remaining-delay takeover.
    func handleAppBecameActive() {
        guard UIApplication.shared.applicationState == .active else {
            log("[StateController] handleAppBecameActive deferred — app not yet active (state=\(UIApplication.shared.applicationState.rawValue))")
            return
        }
        if isAlarmRinging {
            markUserUnlockedDuringAlarmRun(reason: "app-became-active")
        }
        // Foreground gives the engine full control (incl. the system volume floor),
        // so any "inaudible while locked" verdict no longer applies.
        clearEngineInaudibleWhileLocked(reason: "app-active")
        clearAlarmKitPrimaryLocked(reason: "app-active")
        if let alarmId = currentAlarmId {
            clearAlarmKitSurfaceSuppressionRisk(sourceAlarmId: alarmId, reason: "app-active-pending-verify")
            if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
                enforceAlarmKitHandoffVolumeParity(reason: "app-became-active")
            }
        }
        if let alarmId = currentAlarmId {
            NotificationManager.shared.stopAlarmKitRealertLoop(sourceAlarmId: alarmId, reason: "app-active")
        }

	        if phase == .alarmKitFallback, let runId = currentAlarmRunId {
	            log("[AudioOwner] app active — allowing AppEngine takeover from alarmKitFallback")
	            let resolvedSoundName: String = {
	                if let selectedSoundName, !selectedSoundName.isEmpty {
	                    return selectedSoundName
	                }
	                guard let alarmId = currentAlarmId,
	                      let uuid = UUID(uuidString: alarmId),
	                      let alarm = AlarmStore.shared.alarm(by: uuid) else { return "" }
	                return alarm.soundName
	            }()
	            if AlarmContinuousAudioEngine.shared.currentAlarmRunId != runId,
	               let alarmId = currentAlarmId,
	               !resolvedSoundName.isEmpty {
	                AlarmContinuousAudioEngine.shared.prepareSilently(
	                    soundName: resolvedSoundName,
	                    alarmId: alarmId,
	                    alarmRunId: runId
	                )
	            }
	            if phase == .alarmKitFallback {
	                transitionAudioPhase(to: .appEnginePreparing, reason: "foreground-from-alarmkit-fallback")
	            }
	            takeoverScheduled = true
	            takeoverScheduledAt = Date().addingTimeInterval(-Self.alarmKitSettleDelay)
	            startForegroundAppEngineImmediately(
	                alarmRunId: runId,
	                reason: "foreground-from-alarmkit-fallback"
	            )
            let capturedAlarmId = currentAlarmId
            let capturedRunId = runId
            Task { @MainActor in
                guard let capturedAlarmId,
                      await self.isAppEngineActuallyAudible(reason: "foreground-takeover-verified") else {
                    return
                }
                self.clearAlarmKitSurfaceSuppressionRisk(
                    sourceAlarmId: capturedAlarmId,
                    reason: "foreground-takeover-verified"
                )
                self.log("[AudioOwner] AppEngine verified; cancelling recovery notification and AlarmKit fallback source=\(capturedAlarmId)")
                NotificationManager.shared.cancelRecoveryPromptNotification(sourceAlarmId: capturedAlarmId)
                NotificationManager.shared.cancelPreArmedAlarmKitRecovery(
                    sourceAlarmId: capturedAlarmId,
                    runId: capturedRunId.uuidString,
                    reason: "app-active-engine-verified"
                )
            }
            return
        }

        guard let runId = currentAlarmRunId,
              phase == .alarmKitSettling || phase == .appEnginePreparing else {
            return
        }

        let elapsed = takeoverScheduledAt.map { Date().timeIntervalSince($0) } ?? 0
        log("[StateController] handleAppBecameActive: phase=\(phase.rawValue) elapsed=\(String(format: "%.2f", elapsed))s takeoverScheduled=\(takeoverScheduled)")

        guard takeoverScheduled else {
            log("[StateController] handleAppBecameActive: no takeover scheduled — attempting immediate re-arm")
            requestAppEngineTakeoverIfAllowed(
                alarmRunId: runId,
                reason: "foreground-activation-no-schedule-rearm"
            )
            return
        }

        if elapsed < Self.alarmKitSettleDelay {
            let remaining = Self.alarmKitSettleDelay - elapsed
            log("[StateController] handleAppBecameActive: skipping remaining settle delay (\(String(format: "%.2f", remaining))s) — forcing immediate foreground takeover")
        } else {
            log("[StateController] handleAppBecameActive: settle delay elapsed — triggering immediate takeover")
        }
        requestAppEngineTakeoverIfAllowed(
            alarmRunId: runId,
            reason: "foreground-activation-immediate"
        )
    }

    // MARK: - Phase-Aware Health Queries

    /// Returns true when silence (no audible app audio) is expected.
    /// Watchdogs must NOT treat silence as failure when this returns true.
    func isSilenceExpected() -> Bool {
        // Locked engine candidate — verification in flight; keep watchdog active.
        if lockedEngineAudibilityState == .engineCandidatePlaying { return false }
        // AlarmKit is the intentional locked/background owner — AppEngine silence is
        // expected, so the bridge watchdog must relax and not churn recovery.
        if isAlarmKitPrimaryLockedActive() { return true }
        // After side-button / slide-to-stop, silence is NEVER acceptable — the
        // bridge watchdog and recovery paths must keep trying engine or AlarmKit.
        if isDeadAudioRisk() { return false }
        if let alarmId = currentAlarmId,
           NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
            return false
        }
        if let alarmId = currentAlarmId ?? AlarmAuthHandoffStore.activeRingingAlarmId(),
           !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed(),
           UIApplication.shared.applicationState != .active,
           !AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            // AlarmKit may have been suppressed by side-button while the app
            // engine was still silently preparing — treat this as recoverable.
            switch phase {
            case .alarmKitSettling, .appEnginePreparing, .waitingForAlarmKit:
                return false
            default:
                break
            }
        }
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling:
            return true
        case .appEnginePreparing:
            // Silent prepare while locked/background is a silence-risk window.
            return UIApplication.shared.applicationState == .active
        case .appEngineFadingIn, .appEnginePrimary:
            return false
        case .alarmKitFallback:
            if UIApplication.shared.applicationState != .active,
               let alarmId = currentAlarmId ?? AlarmAuthHandoffStore.activeRingingAlarmId(),
               NotificationManager.shared.hasAudibleAlarmKitAlertingSurface(
                   sourceAlarmId: alarmId,
                   reason: "silence-expected-alarmkit-fallback"
               ) {
                return true
            }
            return false
        case .stopped:
            return true
        }
    }

    /// Returns true when AlarmKit backup/respawn scheduling is appropriate.
    /// Returns false during settling — respawning during settling causes crash loop.
    func shouldAllowAlarmKitRespawn() -> Bool {
        // A live AlarmKit alerting surface is already the locked/background owner —
        // it is ringing on its own. Respawning backup surfaces on top of it just
        // creates a new surface every ~2s, each dismissing the prior, which is the
        // screen-blink / surface-churn loop. Suppress respawn entirely here.
        if isAlarmKitPrimaryLockedActive() {
            log("[RespawnPolicy] suppressed — AlarmKit primary surface is live (locked owner)")
            return false
        }
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling:
            return false
        case .appEnginePreparing:
            // Normally the engine is about to take over, so respawn is suppressed.
            // But if the engine is NOT actually playing while the app is inactive
            // and the alarm is still ringing, this is the DEAD-AUDIO state (AlarmKit
            // suppressed by side button, engine never started) — allow AlarmKit
            // recovery so the alarm is never left silent.
            let appInactive = UIApplication.shared.applicationState != .active
            let enginePlaying = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
            let finalStop = AlarmAuthHandoffStore.isFinalStopOrSnoozePressed()
            if appInactive && !enginePlaying && !finalStop {
                if let alarmId = currentAlarmId,
                   NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: alarmId) {
                    log("[LockedNoUI] RespawnPolicy DENY AlarmKit — locked no-UI session active source=\(alarmId)")
                    return false
                }
                log("[RespawnPolicy] allow recovery: appEnginePreparing + engine not playing + app inactive")
                if let alarmId = currentAlarmId {
                    NotificationManager.shared.emitDeadAudioProbe(
                        sourceAlarmId: alarmId,
                        reason: "respawn-policy-preparing"
                    )
                }
                return true
            }
            return false
        case .appEngineFadingIn, .appEnginePrimary:
            return false
        case .alarmKitFallback:
            return true
        case .stopped:
            return false
        }
    }

    /// Returns true when engine being "not healthy" is a genuine failure.
    /// Returns false during phases where engine is intentionally not playing yet,
    /// UNLESS `isDeadAudioRisk()` is true (background + ringing + engine silent).
    func isEngineUnhealthinessAFailure() -> Bool {
        if isDeadAudioRisk() { return true }
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling, .appEnginePreparing:
            return false
        case .appEngineFadingIn, .appEnginePrimary:
            return true
        case .alarmKitFallback:
            return true
        case .stopped:
            return false
        }
    }

    /// True when the alarm should be ringing but nothing is audibly playing while
    /// the app is backgrounded/locked. This is the exact dead-audio state from device
    /// logs: appEnginePreparing + owner=none + engineActive + !enginePlaying.
    func isDeadAudioRisk() -> Bool {
        // When a live AlarmKit alerting surface is the intentional locked/background
        // owner, the AppEngine being silent is EXPECTED — AlarmKit (ringer domain)
        // is producing the sound. Treating this as dead audio is exactly what caused
        // the dismiss/recreate storm. It is not a risk.
        if isAlarmKitPrimaryLockedActive() { return false }
        return DeadAudioRiskEvaluator.isDeadAudioRisk(
            phase: phase,
            appInactive: UIApplication.shared.applicationState != .active,
            enginePlaying: AlarmContinuousAudioEngine.shared.confirmStillPlaying(),
            finalStop: AlarmAuthHandoffStore.isFinalStopOrSnoozePressed(),
            alarmStateRinging: AlarmAuthHandoffStore.alarmState() == .ringing || isAlarmRinging
        )
    }

    /// Side-button / lock path: try no-UI engine immediately, then route to the
    /// centralized dead-audio detector if the engine cannot start.
    func attemptImmediateLockedRecovery(sourceAlarmId: String, reason: String) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard UIApplication.shared.applicationState != .active else { return }
        let output = AVAudioSession.sharedInstance().outputVolume
        let engineAudible = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
            && output > Self.lowOutputVolumeThreshold
        if engineAudible {
            log("[LockedRecovery] engine already audible — no immediate action source=\(sourceAlarmId) output=\(String(format: "%.2f", output))")
            return
        }
        if engineAudible == false, AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            log("[LockedRecovery] engine reports playing but output=\(String(format: "%.2f", output)) — continuing recovery source=\(sourceAlarmId)")
        }

        // SHORT-CIRCUIT: once the engine has been proven inaudible while locked
        // there is no point re-attempting tryEngineAudibleWhileLocked or
        // attemptLockedNoUIEngineRecovery — they both fall through to AlarmKit
        // recovery, which is what we want directly. Calling them again only
        // burns cycles, grows reason strings, and risks the
        // reassert↔locked-no-ui recursion. Pre-arm an audible AlarmKit
        // recovery and let it ring.
        if engineInaudibleWhileLockedProven {
            log("[LockedRecovery] engine proven inaudible while locked — keeping AlarmKit owner, pre-arming recovery source=\(sourceAlarmId) reason=\(reason)")
            NotificationManager.shared.preArmAudibleAlarmKitRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: "immediate-locked-engine-proven-inaudible-\(reason)",
                delay: 4.0
            )
            return
        }

        NotificationManager.shared.emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "immediate-\(reason)")
        if tryEngineAudibleWhileLocked(reason: reason) {
            log("[LockedRecovery] immediate no-UI engine started source=\(sourceAlarmId) reason=\(reason)")
            NotificationManager.shared.scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
            NotificationManager.shared.armEngineAudibleVerification(sourceAlarmId: sourceAlarmId, reason: reason)
            NotificationManager.shared.startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            return
        }
        if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            log("[LockedNoUI] immediate engine failed — orchestrating locked no-UI recovery source=\(sourceAlarmId) reason=\(reason)")
            NotificationManager.shared.attemptLockedNoUIEngineRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: reason
            )
            return
        }
        if isDeadAudioRisk() {
            print("[DeadAudio] appEnginePreparing + background + engine not playing is recoverable failure source=\(sourceAlarmId)")
        }
        NotificationManager.shared.detectAndRecoverDeadAudioState(
            sourceAlarmId: sourceAlarmId,
            reason: reason
        )
    }

    private func log(_ message: String) {
        print("[AlarmAudio] \(message)")
    }
}

extension Notification.Name {
    static let alarmEngineBecamePrimary = Notification.Name("AlarmEngineBecamePrimary")
}
