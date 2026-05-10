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

    static let alarmKitSettleDelay: TimeInterval = 4.5
    static let postInterruptionGraceDelay: TimeInterval = 0.4
    static let appEngineProgressCheckDelay: TimeInterval = 0.5
    static let appEngineFadeInDuration: TimeInterval = 8.0
    static let appEngineInitialVolume: Float = 0.0
    static let appEngineFirstFadeTargetVolume: Float = 0.2
    static let appEngineFinalTargetVolume: Float = 1.0

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
    private(set) var lastPhaseTransitionReason: String = "init"
    private(set) var terminalActionRecorded: Bool = false

    private var takeoverWorkItem: DispatchWorkItem?

    private let allowedTransitions: [AlarmAudioPhase: Set<AlarmAudioPhase>] = [
        .waitingForAlarmKit: [.alarmKitSettling, .stopped],
        .alarmKitSettling: [.appEnginePreparing, .alarmKitFallback, .stopped],
        .appEnginePreparing: [.appEngineFadingIn, .alarmKitFallback, .stopped],
        .appEngineFadingIn: [.appEnginePrimary, .alarmKitFallback, .stopped],
        .appEnginePrimary: [.alarmKitFallback, .stopped],
        .alarmKitFallback: [.appEnginePreparing, .stopped],
        .stopped: [.waitingForAlarmKit]
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
        currentAlarmId = alarmId
        currentAlarmRunId = UUID()
        selectedSoundName = soundName
        selectedSoundURL = nil
        terminalActionRecorded = false
        alarmKitAlertingReceivedAt = nil
        appEnginePreparedAt = nil
        appEngineFadeInStartedAt = nil
        appEnginePrimaryConfirmedAt = nil
        transitionAudioPhase(to: .waitingForAlarmKit, reason: reason)
        log("Session begun alarmId=\(alarmId) runId=\(currentAlarmRunId!.uuidString)")
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
        if let alarmId = currentAlarmId {
            log("Engine primary — dismissing current AlarmKit surfaces for \(alarmId)")
            NotificationManager.shared.dismissLinkedAlarmKitSurfaces(sourceAlarmId: alarmId)
        }
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
        if phase == .stopped || currentAlarmId != alarmId {
            beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: reason)
        }
        if phase == .waitingForAlarmKit {
            recordAlarmKitAlerting()
        }
        guard let runId = currentAlarmRunId else { return }
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
        scheduleDelayedTakeover(alarmRunId: runId, delay: Self.alarmKitSettleDelay)
    }

    func scheduleEarlyTakeoverAfterInterruptionEnd() {
        guard let runId = currentAlarmRunId else { return }
        scheduleDelayedTakeover(alarmRunId: runId, delay: Self.postInterruptionGraceDelay)
    }

    func requestAppEngineTakeoverIfAllowed(alarmRunId: UUID, reason: String) {
        guard currentAlarmRunId == alarmRunId else {
            log("Takeover ignored — runId mismatch")
            return
        }
        guard !terminalActionRecorded else {
            log("Takeover ignored — terminal action recorded")
            return
        }
        guard phase == .alarmKitSettling || phase == .appEnginePreparing else {
            log("Takeover ignored — phase=\(phase.rawValue)")
            return
        }
        guard AlarmContinuousAudioEngine.shared.currentAlarmRunId == alarmRunId else {
            log("Takeover ignored — engine not prepared for runId")
            return
        }
        log("Takeover proceeding reason=\(reason)")
        AlarmContinuousAudioEngine.shared.startFadeIn(
            alarmRunId: alarmRunId,
            fadeInDuration: Self.appEngineFadeInDuration,
            targetVolume: Self.appEngineFinalTargetVolume
        )
    }

    private func scheduleDelayedTakeover(alarmRunId: UUID, delay: TimeInterval) {
        takeoverWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.requestAppEngineTakeoverIfAllowed(alarmRunId: alarmRunId, reason: "delay-\(String(format: "%.2f", delay))s")
        }
        takeoverWorkItem = work
        log("Takeover scheduled in \(String(format: "%.2f", delay))s runId=\(alarmRunId.uuidString)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func log(_ message: String) {
        print("[AlarmAudio] \(message)")
    }
}
