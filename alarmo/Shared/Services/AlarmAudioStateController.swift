import Foundation

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
    static let postSlideMinimumOutputVolume: Float = 0.25
    static let preAlarmMinimumOutputVolume: Float = 0.25
    static let mpVolumeFloorAttemptDelay: TimeInterval = 0.15
    static let mpVolumeFloorVerificationDelay: TimeInterval = 0.35

    private(set) var phase: AlarmAudioPhase = .stopped
    private(set) var audibleOwner: AlarmAudibleOwner = .none
    private(set) var currentAlarmId: String?
    private(set) var currentAlarmRunId: UUID?
    private(set) var selectedSoundName: String?
    private(set) var selectedSoundURL: URL?

    private(set) var alarmKitAlertingReceivedAt: Date?
    private(set) var appEnginePreparedAt: Date?
    private(set) var appEngineFadeInStartedAt: Date?
    private(set) var appEnginePrimaryConfirmedAt: Date?
    private(set) var phaseEnteredAt: Date?
    private(set) var lastPhaseTransitionReason: String = "init"
    private(set) var terminalActionRecorded: Bool = false

    private var takeoverWorkItem: DispatchWorkItem?
    private var takeoverScheduled: Bool = false
    private var takeoverScheduledAt: Date?

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

    func timeInCurrentPhase() -> TimeInterval {
        guard let enteredAt = phaseEnteredAt else { return 0 }
        return Date().timeIntervalSince(enteredAt)
    }

    func transitionAudioPhase(to newPhase: AlarmAudioPhase, reason: String) {
        let oldPhase = phase
        guard let allowed = allowedTransitions[oldPhase], allowed.contains(newPhase) else {
            log("⚠️ INVALID transition \(oldPhase.rawValue) → \(newPhase.rawValue) reason=\(reason)")
            return
        }
        phase = newPhase
        phaseEnteredAt = Date()
        lastPhaseTransitionReason = reason

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
    }

    func canStartAudibleAppAudio(reason: String) -> Bool {
        let hasActiveSession = currentAlarmId != nil && currentAlarmRunId != nil
        let allowed = (phase == .appEngineFadingIn || phase == .appEnginePrimary)
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

        takeoverScheduled = false
        takeoverScheduledAt = nil
        currentAlarmId = alarmId
        currentAlarmRunId = UUID()
        selectedSoundName = soundName
        selectedSoundURL = nil
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
        log("[StateController] Engine primary — background tasks ending, AlarmKit surface PRESERVED for slide-to-stop")
    }

    func recordFallback(reason: String) {
        transitionAudioPhase(to: .alarmKitFallback, reason: reason)
        if let alarmId = currentAlarmId {
            NotificationManager.shared.scheduleHardwareButtonRespawnIfNeeded(
                sourceAlarmId: alarmId,
                alarmName: nil,
                reason: "[AlarmAudio] App engine failed; AlarmKit fallback audible sound enabled"
            )
        }
    }

    func recordStopped(reason: String) {
        takeoverScheduled = false
        takeoverScheduledAt = nil
        terminalActionRecorded = true
        takeoverWorkItem?.cancel()
        takeoverWorkItem = nil
        transitionAudioPhase(to: .stopped, reason: reason)
        currentAlarmId = nil
        currentAlarmRunId = nil
        selectedSoundName = nil
        selectedSoundURL = nil
    }

    func handleAlarmKitAlerting(alarmId: String, soundName: String, reason: String) {
        if phase == .appEnginePreparing || phase == .appEngineFadingIn || phase == .appEnginePrimary {
            log("[StateController] AlarmKit alerting after engine already started — dismissing surface only")
            NotificationManager.shared.dismissLinkedAlarmKitSurfaces(sourceAlarmId: alarmId)
            return
        }

        if phase == .alarmKitSettling || phase == .appEnginePreparing {
            // Keep AlarmKit surface behavior unchanged, but ensure AppEngine
            // audible takeover is actually armed. In some locked-screen paths
            // we can re-enter here with no live takeover work item.
            if let runId = currentAlarmRunId {
                if !takeoverScheduled {
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

        guard let runId = currentAlarmRunId else {
            log("[StateController] handleAlarmKitAlerting: no runId after session begin — aborting")
            return
        }
        log("[StateController] handleAlarmKitAlerting: using runId=\(runId.uuidString)")
        if #available(iOS 26.0, *) {
            selectedSoundURL = AlarmSchedulerIOS26AlarmKit().resolvedSoundURL(for: soundName)
        } else {
            selectedSoundURL = nil
        }

        AlarmContinuousAudioEngine.shared.prepareSilently(
            soundName: soundName,
            alarmId: alarmId,
            alarmRunId: runId
        )

        scheduleDelayedTakeover(
            alarmRunId: runId,
            delay: Self.alarmKitSettleDelay
        )
    }

    /// Called when foreground timer detects due alarm before AlarmKit alerting.
    /// Creates/reuses session and schedules takeover with the same runId.
    func handleForegroundTimerAlarm(alarmId: String, soundName: String) {
        log("[StateController] handleForegroundTimerAlarm: alarmId=\(alarmId)")

        guard phase == .stopped else {
            log("[StateController] Foreground timer ignored — phase is \(phase.rawValue)")
            return
        }

        if currentAlarmId == alarmId && currentAlarmRunId != nil {
            log("[StateController] Foreground timer: session already exists for \(alarmId)")
            return
        }

        beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: "foreground-timer")
        guard let runId = currentAlarmRunId else { return }
        log("[StateController] handleForegroundTimerAlarm: runId=\(runId.uuidString)")

        AlarmContinuousAudioEngine.shared.prepareSilently(
            soundName: soundName,
            alarmId: alarmId,
            alarmRunId: runId
        )

        scheduleDelayedTakeover(
            alarmRunId: runId,
            delay: Self.alarmKitSettleDelay
        )
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
        log("[StateController] Takeover proceeding — calling startFadeIn")
        AlarmContinuousAudioEngine.shared.startFadeIn(
            alarmRunId: alarmRunId,
            fadeInDuration: Self.appEngineFadeInDuration,
            targetVolume: Self.appEngineFinalTargetVolume
        )
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

    /// Called when app becomes active. If takeover is pending and still in a
    /// settling phase, trigger immediate or remaining-delay takeover.
    func handleAppBecameActive() {
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

        if elapsed >= Self.alarmKitSettleDelay {
            log("[StateController] handleAppBecameActive: settle delay elapsed — triggering immediate takeover")
            requestAppEngineTakeoverIfAllowed(
                alarmRunId: runId,
                reason: "foreground-activation-fallback-elapsed-\(String(format: "%.2f", elapsed))s"
            )
        } else {
            let remaining = Self.alarmKitSettleDelay - elapsed
            log("[StateController] handleAppBecameActive: \(String(format: "%.2f", remaining))s remaining — scheduling residual takeover")
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.requestAppEngineTakeoverIfAllowed(
                    alarmRunId: runId,
                    reason: "foreground-activation-residual-\(String(format: "%.2f", remaining))s"
                )
            }
        }
    }

    // MARK: - Phase-Aware Health Queries

    /// Returns true when silence (no audible app audio) is expected.
    /// Watchdogs must NOT treat silence as failure when this returns true.
    func isSilenceExpected() -> Bool {
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling, .appEnginePreparing:
            return true
        case .appEngineFadingIn, .appEnginePrimary, .alarmKitFallback:
            return false
        case .stopped:
            return true
        }
    }

    /// Returns true when AlarmKit backup/respawn scheduling is appropriate.
    /// Returns false during settling — respawning during settling causes crash loop.
    func shouldAllowAlarmKitRespawn() -> Bool {
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling, .appEnginePreparing:
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
    /// Returns false during phases where engine is intentionally not playing yet.
    func isEngineUnhealthinessAFailure() -> Bool {
        switch phase {
        case .waitingForAlarmKit, .alarmKitSettling, .appEnginePreparing:
            return false
        case .appEngineFadingIn, .appEnginePrimary:
            return true
        case .alarmKitFallback:
            // In fallback, engine failure must trigger AlarmKit audible recovery.
            return true
        case .stopped:
            return false
        }
    }

    private func log(_ message: String) {
        print("[AlarmAudio] \(message)")
    }
}

extension Notification.Name {
    static let alarmEngineBecamePrimary = Notification.Name("AlarmEngineBecamePrimary")
}
