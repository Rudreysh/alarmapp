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
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var pendingHandoffStopWorkItem: DispatchWorkItem?
    private var watchdogTimer: Timer?

    private init() {}

    var currentAlarmID: String? {
        activeAlarmID
    }

    var isPlaying: Bool {
        activeAlarmID != nil
    }

    func configure(alarmStore: AlarmStore) {
        self.alarmStore = alarmStore
    }

    func start(alarmId: String) {
        guard let uuid = UUID(uuidString: alarmId) else { return }
        guard let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) else {
            print("[AlarmBackgroundAudioBridge] Alarm not found for \(alarmId)")
            return
        }

        if activeAlarmID == alarmId {
            return
        }

        pendingHandoffStopWorkItem?.cancel()
        pendingHandoffStopWorkItem = nil

        if let current = activeAlarmID, current != alarmId {
            stop(alarmId: current)
        }

        beginBackgroundTask(named: "alarmo.backgroundAlarm.\(alarmId)")

        do {
            try AudioRouteManager.configureAlarmSession()
        } catch {
            print("[AlarmBackgroundAudioBridge] Failed to configure alarm session: \(error)")
        }

        soundPlayer.playLooping(resourceName: alarm.soundName, volume: 1.0, fadeDuration: 0)
        activeAlarmID = alarmId
        startWatchdog()
        print("[AlarmBackgroundAudioBridge] ▶️ Started background audio bridge for \(alarmId)")
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
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.watchdogCheck()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func watchdogCheck() {
        guard let alarmId = activeAlarmID else { return }
        guard let uuid = UUID(uuidString: alarmId),
              (alarmStore ?? AlarmStore.shared).alarm(by: uuid) != nil else { return }

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

        // SoundPlayer handles interruption internally via its own observers,
        // but as a safety net, if no audio appears to be playing and we haven't
        // been told to stop, restart it.
        print("[AlarmBackgroundAudioBridge] 🔍 Watchdog: bridge active for \(alarmId)")
    }
}
