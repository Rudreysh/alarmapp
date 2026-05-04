import Foundation
import UIKit
import AVFoundation

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

    private let soundPlayer = SoundPlayer()
    private weak var alarmStore: AlarmStore?
    private var activeAlarmID: String?
    private var activeSourceAlarmID: String?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var pendingHandoffStopWorkItem: DispatchWorkItem?
    private var watchdogTimer: DispatchSourceTimer?
    private let watchdogQueue = DispatchQueue(label: "ht.alarmo.background-audio-bridge.watchdog")
    private var lastLockedRefreshAt: Date?
    private let lockedRefreshCooldown: TimeInterval = 1.5

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
    }

    var currentAlarmID: String? {
        activeAlarmID
    }

    var currentSourceAlarmID: String? {
        activeSourceAlarmID
    }

    var isPlaying: Bool {
        activeAlarmID != nil
    }

    var isAudiblyPlaying: Bool {
        soundPlayer.isCurrentlyPlaying
    }

    func configure(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
    }

    func start(surfaceAlarmId: String, sourceAlarmId: String? = nil) {
        let resolvedSourceAlarmId = sourceAlarmId
            ?? AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        guard let uuid = UUID(uuidString: resolvedSourceAlarmId) else { return }
        guard let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) else {
            print("[AlarmBackgroundAudioBridge] Alarm not found for source=\(resolvedSourceAlarmId), surface=\(surfaceAlarmId)")
            return
        }

        if activeAlarmID == surfaceAlarmId {
            return
        }

        pendingHandoffStopWorkItem?.cancel()
        pendingHandoffStopWorkItem = nil

        if let current = activeAlarmID, current != surfaceAlarmId {
            stop(alarmId: current)
        }

        beginBackgroundTask(named: "alarmo.backgroundAlarm.\(surfaceAlarmId)")

        do {
            try AudioRouteManager.configureAlarmSession()
        } catch {
            print("[AlarmBackgroundAudioBridge] Failed to configure alarm session: \(error)")
        }

        soundPlayer.playLooping(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
        activeAlarmID = surfaceAlarmId
        activeSourceAlarmID = resolvedSourceAlarmId
        startWatchdog()
        print("[AlarmBackgroundAudioBridge] ▶️ Started background audio bridge for surface=\(surfaceAlarmId), source=\(resolvedSourceAlarmId)")
    }

    func handoffToForeground(alarmId: String, stopDelay: TimeInterval = 0.35) {
        guard activeAlarmID == alarmId else { return }

        pendingHandoffStopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.stop(alarmId: alarmId)
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

        soundPlayer.stop()
        activeAlarmID = nil
        activeSourceAlarmID = nil
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
              let sourceAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) else { return }

        // If the audio session was interrupted (e.g. by AlarmKit stopping),
        // re-configure and restart playback.
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback {
            do {
                try AudioRouteManager.configureAlarmSession()
                print("[AlarmBackgroundAudioBridge] ⚠️ Watchdog: re-configured audio session")
            } catch {
                print("[AlarmBackgroundAudioBridge] ⚠️ Watchdog: failed to re-configure session: \(error)")
            }
        }
        if !soundPlayer.isCurrentlyPlaying {
            print("[AlarmBackgroundAudioBridge] ⚠️ Watchdog: detected silent bridge, restarting audio")
            soundPlayer.playLooping(resourceName: sourceAlarm.soundName, volume: 1.0, fadeDuration: 0)
            triggerImmediateLockedRefresh(reason: "watchdog-restart")
        }

        // SoundPlayer handles interruption internally via its own observers,
        // but as a safety net, if no audio appears to be playing and we haven't
        // been told to stop, restart it.
        print("[AlarmBackgroundAudioBridge] 🔍 Watchdog: bridge active for surface=\(alarmId), source=\(sourceAlarmId)")
    }

    private func triggerImmediateLockedRefresh(reason: String) {
        guard UIApplication.shared.applicationState != .active else { return }
        let now = Date()
        if let last = lastLockedRefreshAt, now.timeIntervalSince(last) < lockedRefreshCooldown {
            return
        }
        lastLockedRefreshAt = now
        guard let sourceAlarmId = activeSourceAlarmID ?? activeAlarmID else { return }
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
        let resolvedSurface = surfaceAlarmId ?? activeAlarmID
        let resolvedSource = sourceAlarmId
            ?? activeSourceAlarmID
            ?? resolvedSurface.map { AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0) }
        guard let resolvedSurface, let resolvedSource else { return }

        if activeAlarmID == nil {
            start(surfaceAlarmId: resolvedSurface, sourceAlarmId: resolvedSource)
        }
        triggerImmediateLockedRefresh(reason: reason)
    }
}
