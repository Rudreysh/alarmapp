import Foundation
import UIKit
import AVFoundation

@inline(__always)
private func swiftlog(_ message: String) {
    print(message)
}

/// Plays the alarm sound using an app-owned AVAudioPlayer while the phone is
/// locked, providing seamless audio continuity when AlarmKit stops its own
/// system-managed sound after the user swipes "Stop".
///
/// ## How it works
///
/// 1. When `AlarmManager.alarmUpdates` reports `.alerting`, the bridge is
///    started immediately — BEFORE the user interacts with the lock-screen UI.
/// 2. The bridge configures an AVAudioSession with `.playback` category (which
///    bypasses the silent switch) and begins looping the alarm sound.
/// 3. Because the app declares the `audio` background mode, the audio session
///    keeps running even when the app is in the background or the screen is
///    locked.
/// 4. When AlarmKit stops the system alarm sound (user swipes stop), the
///    bridge audio continues uninterrupted.
/// 5. After unlock, `AppRootView.handlePendingCustomAlarmUIHandoff()` presents
///    the custom `AlarmRingingView` and calls `handoffToForeground(alarmId:)`
///    which stops the bridge after a short overlap so the coordinator audio
///    takes over seamlessly.
@MainActor
final class AlarmBackgroundAudioBridge {
    static let shared = AlarmBackgroundAudioBridge()
    private static let outputVolumeDidChangeNotification = Notification.Name("AVSystemController_SystemVolumeDidChangeNotification")

    private weak var alarmStore: AlarmStore?
    private var activeAlarmID: String?
    private var activeSourceAlarmID: String?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var pendingHandoffStopWorkItem: DispatchWorkItem?
    private var watchdogTimer: DispatchSourceTimer?
    private let watchdogQueue = DispatchQueue(label: "ht.alarmo.background-audio-bridge.watchdog")
    private var lastLockedRefreshAt: Date?
    private let lockedRefreshCooldown: TimeInterval = 0.5
    private var silentBridgeSince: Date?
    private var lastAudibleAt: Date?
    private var consecutiveWatchdogFailures: Int = 0
    private var lastWatchdogRecoveryAttemptAt: Date = .distantPast
    private var watchdogRecoveryInProgress: Bool = false
    private var lastObservedOutputVolume: Float = -1

    // Backoff schedule: attempt 1 = 0.5s wait, 2 = 1s, 3 = 2s, 4+ = 5s max
    private func watchdogBackoffInterval() -> TimeInterval {
        switch consecutiveWatchdogFailures {
        case 0:      return 0.0
        case 1:      return 0.5
        case 2:      return 1.0
        case 3:      return 2.0
        default:     return 5.0
        }
    }

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in }
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { _ in }
        NotificationCenter.default.addObserver(
            forName: Self.outputVolumeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOutputVolumeDidChange()
        }
    }

    var currentAlarmID: String? {
        activeAlarmID
    }

    var currentSourceAlarmID: String? {
        activeSourceAlarmID
    }

    var isPlaying: Bool {
        guard activeAlarmID != nil || activeSourceAlarmID != nil else { return false }
        return watchdogTimer != nil
            || backgroundTaskID != .invalid
            || pendingHandoffStopWorkItem != nil
            || AlarmContinuousAudioEngine.shared.isEngineActive
    }

    var isAudiblyPlaying: Bool {
        AlarmContinuousAudioEngine.shared.cachedIsHealthy
    }

    /// Returns true only when playback has been observed recently by the
    /// watchdog/start paths. This avoids decisions based on a stale one-shot
    /// `isPlaying` read during lock/unlock races.
    func hasRecentAudiblePlayback(within interval: TimeInterval) -> Bool {
        guard let lastAudibleAt else { return false }
        return Date().timeIntervalSince(lastAudibleAt) <= interval
    }

    func configure(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
    }

    /// Volume to pass when re-entering the engine. If the engine is already
    /// active we preserve its current target so recovery/restart paths don't
    /// silently bump volume back to 1.0 and create a perceptible loudness jump
    /// after a side-button or interruption event. First-time starts use 1.0.
    private func engineStartVolume() -> Float {
        AlarmContinuousAudioEngine.shared.isEngineActive
            ? AlarmContinuousAudioEngine.shared.targetVolume
            : 1.0
    }

    private func startOrPrepareEngine(soundName: String, alarmId: String, reason: String) {
        let controller = AlarmAudioStateController.shared
        if controller.currentAlarmId != alarmId || controller.currentAlarmRunId == nil {
            controller.beginAlarmSession(alarmId: alarmId, soundName: soundName, reason: "bridge-\(reason)")
        }
        if NotificationManager.shared.shouldPreserveAlarmKitPrimaryOwner(sourceAlarmId: alarmId) {
            controller.markAlarmKitPrimaryLocked(reason: "bridge-preserve-primary-owner-\(reason)")
            swiftlog("[Bridge] preserving AlarmKit primary owner; engine prewarm suppressed reason=\(reason)")
            return
        }
        if controller.phase == .alarmKitSettling || controller.phase == .appEnginePreparing || controller.phase == .alarmKitFallback {
            if UIApplication.shared.applicationState != .active {
                swiftlog("[AudioOwner] Bridge started near-silent because AlarmKit is primary (owner=\(controller.audibleOwner.rawValue) phase=\(controller.phase.rawValue))")
            }
            if let runId = controller.currentAlarmRunId {
                AlarmContinuousAudioEngine.shared.prepareSilently(
                    soundName: soundName,
                    alarmId: alarmId,
                    alarmRunId: runId
                )
                swiftlog("[Bridge] delegated to prepareSilently — phase=\(controller.phase.rawValue)")
            }
            return
        }
        if controller.phase == .appEnginePrimary {
            swiftlog("[Bridge] skipped because AppEngine is primary")
            return
        }
        if controller.canStartAudibleAppAudio(reason: "bridge-\(reason)") {
            AlarmContinuousAudioEngine.shared.start(
                soundName: soundName,
                alarmId: alarmId,
                volume: engineStartVolume()
            )
        } else {
            swiftlog("[Bridge] audible start blocked by phase=\(controller.phase.rawValue)")
        }
    }

    func start(surfaceAlarmId: String, sourceAlarmId: String? = nil) {
        let resolvedSourceAlarmId = sourceAlarmId
            ?? AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        guard let uuid = UUID(uuidString: resolvedSourceAlarmId) else { return }
        guard let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) else {
            print("[AlarmBackgroundAudioBridge] Alarm not found for source=\(resolvedSourceAlarmId), surface=\(surfaceAlarmId)")
            return
        }

        if NotificationManager.shared.shouldPreserveAlarmKitPrimaryOwner(sourceAlarmId: resolvedSourceAlarmId),
           !AlarmContinuousAudioEngine.shared.isEngineActive {
            activeAlarmID = surfaceAlarmId
            activeSourceAlarmID = resolvedSourceAlarmId
            AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "bridge-passive-standby")
            AlarmAudioStateController.shared.prewarmEngineForInstantHandoff(
                alarmId: resolvedSourceAlarmId,
                soundName: alarm.soundName,
                reason: "bridge-passive-standby"
            )
            beginBackgroundTaskIfNeeded(named: "alarmo.backgroundAlarm.standby.\(surfaceAlarmId)")
            if watchdogTimer == nil {
                startWatchdog()
            }
            swiftlog("[Bridge] passive standby — AlarmKit owns sound; engine prewarmed source=\(resolvedSourceAlarmId)")
            return
        }

        if AlarmContinuousAudioEngine.shared.isEngineActive {
            swiftlog("[Bridge] Engine already active — bridge skipping audio, managing AlarmKit surfaces only")
            activeAlarmID = surfaceAlarmId
            activeSourceAlarmID = resolvedSourceAlarmId
            beginBackgroundTaskIfNeeded(named: "alarmo.backgroundAlarm.\(surfaceAlarmId)")
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                lastAudibleAt = Date()
            }
            if watchdogTimer == nil {
                startWatchdog()
            }
            return
        }

        swiftlog("[Bridge] Engine not active — starting engine from bridge as fallback")

        if activeAlarmID == surfaceAlarmId {
            startOrPrepareEngine(soundName: alarm.soundName, alarmId: resolvedSourceAlarmId, reason: "bridge-active-same-surface")
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                lastAudibleAt = Date()
            }
            if watchdogTimer == nil {
                startWatchdog()
            }
            return
        }

        // AlarmKit lock-loop respawns surfaces with new UUIDs for the SAME
        // logical alarm. Rebinding the surface id without restarting player
        // avoids audible "restart from beginning" artifacts.
        if activeSourceAlarmID == resolvedSourceAlarmId {
            activeAlarmID = surfaceAlarmId
            beginBackgroundTaskIfNeeded(named: "alarmo.backgroundAlarm.\(surfaceAlarmId)")
            startOrPrepareEngine(soundName: alarm.soundName, alarmId: resolvedSourceAlarmId, reason: "bridge-rebind")
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                lastAudibleAt = Date()
            }
            if watchdogTimer == nil {
                startWatchdog()
            }
            print("[AlarmBackgroundAudioBridge] 🔄 Rebound bridge to new surface=\(surfaceAlarmId), source=\(resolvedSourceAlarmId)")
            return
        }

        pendingHandoffStopWorkItem?.cancel()
        pendingHandoffStopWorkItem = nil

        if let current = activeAlarmID, current != surfaceAlarmId {
            print("[Engine] Stop call removed from AlarmBackgroundAudioBridge.start(surface-switch) — engine continues")
            _ = current
        }

        beginBackgroundTask(named: "alarmo.backgroundAlarm.\(surfaceAlarmId)")
        startOrPrepareEngine(soundName: alarm.soundName, alarmId: resolvedSourceAlarmId, reason: "bridge-fallback-start")
        if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            lastAudibleAt = Date()
        }
        activeAlarmID = surfaceAlarmId
        activeSourceAlarmID = resolvedSourceAlarmId
        startWatchdog()
        print("[AlarmBackgroundAudioBridge] ▶️ Started background audio bridge for surface=\(surfaceAlarmId), source=\(resolvedSourceAlarmId)")
    }

    func handoffToForeground(alarmId: String, stopDelay: TimeInterval = 0.175) {
        guard activeAlarmID == alarmId else { return }

        pendingHandoffStopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            print("[Engine] Stop call removed from AlarmBackgroundAudioBridge.handoffToForeground — engine continues")
        }
        pendingHandoffStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay, execute: workItem)
    }

    func stop(alarmId: String? = nil) {
        guard alarmId == nil || activeAlarmID == alarmId else { return }

        pendingHandoffStopWorkItem?.cancel()
        pendingHandoffStopWorkItem = nil
        stopWatchdog()

        if activeAlarmID != nil {
            print("[AlarmBackgroundAudioBridge] ⏹️ Stopping background audio bridge for \(activeAlarmID ?? "unknown")")
        }

        print("[Engine] Stop call removed from AlarmBackgroundAudioBridge.stop — engine continues")
        activeAlarmID = nil
        activeSourceAlarmID = nil
        lastAudibleAt = nil
        silentBridgeSince = nil
        consecutiveWatchdogFailures = 0
        lastWatchdogRecoveryAttemptAt = .distantPast
        watchdogRecoveryInProgress = false
        endBackgroundTask()
    }

    // MARK: - Background Task

    private func beginBackgroundTask(named name: String) {
        endBackgroundTask()

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            Task { @MainActor in
                // Background task expiring — the OS is reclaiming execution time.
                // Re-request if we still have an active alarm (the audio session
                // should keep us alive via the `audio` background mode, but this
                // is a safety net).
                guard let self, self.activeAlarmID != nil else {
                    self?.endBackgroundTask()
                    return
                }
                print("[AlarmBackgroundAudioBridge] ⚠️ Background task expiring, re-requesting")
                self.endBackgroundTask()
                self.beginBackgroundTask(named: name)
            }
        }
    }

    private func beginBackgroundTaskIfNeeded(named name: String) {
        guard backgroundTaskID == .invalid else { return }
        beginBackgroundTask(named: name)
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // MARK: - Watchdog

    /// A periodic check that the audio is still playing. If the system
    /// interrupted the session (e.g. during AlarmKit stop transition),
    /// we re-activate and restart playback.
    private func startWatchdog() {
        stopWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: watchdogQueue)
        // Tight 50ms tick so a side-button or AlarmKit silent-cut can't open
        // a perceptible gap before we reactivate the session and respawn the
        // surface.
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05, leeway: .milliseconds(15))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.watchdogCheck()
            }
        }
        watchdogTimer = timer
        timer.resume()
    }

    private func stopWatchdog() {
        watchdogTimer?.setEventHandler {}
        watchdogTimer?.cancel()
        watchdogTimer = nil
    }

    private func watchdogCheck() {
        guard let alarmId = activeAlarmID else { return }
        let sourceAlarmId = activeSourceAlarmID ?? AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alarmId)
        guard let uuid = UUID(uuidString: sourceAlarmId),
              let sourceAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) else {
            // Mapping or model can be transiently unavailable during rapid
            // lock/unlock + surface-respawn churn. In that case force a locked
            // refresh so AlarmKit surface/audio can recover instead of stalling.
            triggerImmediateLockedRefresh(reason: "watchdog-missing-source")
            return
        }

        // During known interruption windows, avoid triggering aggressive
        // respawn/recovery churn; let engine interruption retries settle first.
        if AlarmContinuousAudioEngine.shared.isInInterruptionRecoveryWindow {
            silentBridgeSince = nil
            watchdogRecoveryInProgress = false
            return
        }

        if AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging {
            AlarmAudioStateController.shared.evaluateForbiddenAudioStateIfNeeded(reason: "bridge-watchdog")
        }

        let engineHealthy = AlarmContinuousAudioEngine.shared.cachedIsHealthy
        let alarmKitOwnsLockedAudio = AlarmAudioStateController.shared.isAlarmKitPrimaryLockedActive()
            || (NotificationManager.shared.shouldPreserveAlarmKitPrimaryOwner(sourceAlarmId: sourceAlarmId)
                && NotificationManager.shared.currentAlarmSurfaceStatus(
                    sourceAlarmId: sourceAlarmId,
                    reason: "bridge-watchdog"
                ).trustedAsAudible)
        if alarmKitOwnsLockedAudio {
            let enginePlaying = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
            if !enginePlaying {
                // During the initial locked AlarmKit-owned ring the engine is
                // intentionally silent (prewarmed only). Take over only after a
                // real suppression signal or once AlarmKit is no longer alerting.
                let explicitSuppression = NotificationManager.shared.hasExplicitHardwareSuppression(
                    sourceAlarmId: sourceAlarmId
                )
                let alarmKitStillAlerting = NotificationManager.shared.hasAlarmKitAlertingSurface(
                    sourceAlarmId: sourceAlarmId
                )
                if explicitSuppression || !alarmKitStillAlerting {
                    swiftlog(
                        "[Bridge] post-suppression handoff — engine silent " +
                        "source=\(sourceAlarmId) explicit=\(explicitSuppression) " +
                        "alarmKitAlerting=\(alarmKitStillAlerting)"
                    )
                    _ = NotificationManager.shared.startAppEngineAfterAlarmKitSuppression(
                        sourceAlarmId: sourceAlarmId,
                        surfaceAlarmId: alarmId,
                        reason: "bridge-watchdog-post-suppression"
                    )
                } else {
                    LogThrottler.log(
                        "[Bridge] AppEngine silence expected because AlarmKit owns locked audio",
                        key: "bridge.watchdog.alarmkit-primary.\(sourceAlarmId)",
                        interval: 5.0,
                        sink: swiftlog
                    )
                }
            } else {
                LogThrottler.log(
                    "[Bridge] AppEngine playing while AlarmKit primary",
                    key: "bridge.watchdog.alarmkit-playing.\(sourceAlarmId)",
                    interval: 5.0,
                    sink: swiftlog
                )
            }
            consecutiveWatchdogFailures = 0
            lastWatchdogRecoveryAttemptAt = .distantPast
            watchdogRecoveryInProgress = false
            silentBridgeSince = nil
            return
        }
        if AlarmAudioStateController.shared.isSilenceExpected() {
            consecutiveWatchdogFailures = 0
            lastWatchdogRecoveryAttemptAt = .distantPast
            watchdogRecoveryInProgress = false
            silentBridgeSince = nil
            return
        }
        if !engineHealthy {
            let now = Date()
            if silentBridgeSince == nil {
                silentBridgeSince = now
            }

            consecutiveWatchdogFailures += 1
            let backoff = watchdogBackoffInterval()
            let timeSinceLast = Date().timeIntervalSince(lastWatchdogRecoveryAttemptAt)
            guard timeSinceLast >= backoff else {
                let remaining = max(0, backoff - timeSinceLast)
                LogThrottler.log(
                    "[Bridge] Watchdog: silence detected (failure \(consecutiveWatchdogFailures)) — backoff \(String(format: "%.1f", remaining))s remaining",
                    key: "bridge.watchdog.backoff.\(sourceAlarmId)",
                    interval: 2.0
                )
                return
            }

            guard !watchdogRecoveryInProgress else {
                LogThrottler.log(
                    "[Bridge] Watchdog: recovery in progress — skipping this tick",
                    key: "bridge.watchdog.recovery-in-progress.\(sourceAlarmId)",
                    interval: 2.0
                )
                return
            }

            lastWatchdogRecoveryAttemptAt = Date()
            watchdogRecoveryInProgress = true
            print("[Bridge] Watchdog: silence — failure \(consecutiveWatchdogFailures), attempting recovery")
            startOrPrepareEngine(soundName: sourceAlarm.soundName, alarmId: sourceAlarmId, reason: "bridge-watchdog-recovery")

            // A side/volume button can create a very brief interruption. Avoid
            // aggressively respawning the AlarmKit surface unless silence
            // persists for a sustained period.
            if let silentSince = silentBridgeSince,
               now.timeIntervalSince(silentSince) >= 0.25 {
                guard !AlarmAudioStateController.shared.isSilenceExpected() else {
                    swiftlog("[Bridge] Locked refresh suppressed — silence expected in phase \(AlarmAudioStateController.shared.phase.rawValue)")
                    return
                }
                triggerImmediateLockedRefresh(reason: "watchdog-persistent-silence")
                silentBridgeSince = now
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.watchdogRecoveryInProgress = false
            }
        } else {
            silentBridgeSince = nil
            lastAudibleAt = Date()
            consecutiveWatchdogFailures = 0
            lastWatchdogRecoveryAttemptAt = .distantPast
            watchdogRecoveryInProgress = false
        }

        // SoundPlayer handles interruption internally via its own observers,
        // but as a safety net, if no audio appears to be playing and we haven't
        // been told to stop, restart it.
        LogThrottler.log(
            "[AlarmBackgroundAudioBridge] 🔍 Watchdog: bridge active for surface=\(alarmId), source=\(sourceAlarmId)",
            key: "bridge.watchdog.active.\(sourceAlarmId)",
            interval: 5.0
        )
    }

    func resetWatchdogBackoff() {
        consecutiveWatchdogFailures = 0
        lastWatchdogRecoveryAttemptAt = .distantPast
        watchdogRecoveryInProgress = false
        LogThrottler.log(
            "[Bridge] Watchdog backoff reset",
            key: "bridge.watchdog.backoff-reset",
            interval: 3.0,
            sink: swiftlog
        )
    }

    private func triggerImmediateLockedRefresh(reason: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let now = Date()
        if let last = lastLockedRefreshAt, now.timeIntervalSince(last) < lockedRefreshCooldown {
            return
        }
        lastLockedRefreshAt = now
        guard let sourceAlarmId = activeSourceAlarmID ?? activeAlarmID else { return }
        if NotificationManager.shared.shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            print("[LockedNoUI] bridge locked refresh → engine only (no AlarmKit UI) reason=\(reason) source=\(sourceAlarmId)")
            NotificationManager.shared.attemptLockedNoUIEngineRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: "bridge-\(reason)"
            )
            return
        }
        NotificationManager.shared.ensureAlarmKitSurfaceForLockedLoopIfNeeded(
            sourceAlarmId: sourceAlarmId,
            force: true
        )
        print("[AlarmBackgroundAudioBridge] 🔁 Locked refresh requested (\(reason)) for source=\(sourceAlarmId)")
    }

    func reinforceLockedLoopNow(
        surfaceAlarmId: String? = nil,
        sourceAlarmId: String? = nil,
        reason: String = "manual"
    ) {
        let phase = AlarmAudioStateController.shared.phase
        guard phase == .appEnginePrimary || phase == .alarmKitFallback else {
            print("[Bridge] Locked refresh suppressed — phase \(phase.rawValue) (engine not primary)")
            return
        }
        let resolvedSurface = surfaceAlarmId ?? activeAlarmID
        let resolvedSource = sourceAlarmId
            ?? activeSourceAlarmID
            ?? resolvedSurface.map { AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0) }
        guard let resolvedSurface, let resolvedSource else { return }

        if AlarmContinuousAudioEngine.shared.isEngineActive &&
            (AlarmContinuousAudioEngine.shared.cachedIsHealthy ||
             AlarmContinuousAudioEngine.shared.isInInterruptionRecoveryWindow) {
            print("[Bridge] \(reason): engine healthy/recovering — skip locked-loop audio reset")
            return
        }

        if activeAlarmID == nil {
            start(surfaceAlarmId: resolvedSurface, sourceAlarmId: resolvedSource)
            triggerImmediateLockedRefresh(reason: reason)
            return
        }

        // If a bridge session exists but side/volume interaction left it silent,
        // immediately re-assert audio and refresh the AlarmKit lock surface.
        if !AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            if let uuid = UUID(uuidString: resolvedSource),
               let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) {
                startOrPrepareEngine(soundName: alarm.soundName, alarmId: resolvedSource, reason: "bridge-reinforce")
                if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                    lastAudibleAt = Date()
                }
            }
            triggerImmediateLockedRefresh(reason: "\(reason)-silent-bridge")
        }
    }

    private func handleOutputVolumeDidChange() {
        guard activeAlarmID != nil || activeSourceAlarmID != nil else { return }
        let output = AVAudioSession.sharedInstance().outputVolume
        let oldOutput = lastObservedOutputVolume >= 0 ? lastObservedOutputVolume : output
        lastObservedOutputVolume = output

        let sourceAlarmId = activeSourceAlarmID
            ?? activeAlarmID.map { AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0) }
            ?? AlarmCustomUIHandoffStore.pendingRequest()?.sourceAlarmID
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()

        AlarmAudioStateController.shared.handleOutputVolumeChange(
            oldVolume: oldOutput,
            newVolume: output,
            sourceAlarmId: sourceAlarmId
        )
    }
}
