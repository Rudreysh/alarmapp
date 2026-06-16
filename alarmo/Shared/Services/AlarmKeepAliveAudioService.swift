import Foundation
import AVFoundation
import UIKit
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Bounded silent-audio keep-alive.
///
/// iOS suspends backgrounded apps; for a far-future (e.g. overnight) alarm the app is
/// suspended by fire time, so the AlarmKit observation (`alarmUpdates`) is frozen and
/// the AppEngine can't take over — the first morning alarm rings AlarmKit-only. This
/// service plays a looping SILENT `.caf` so the process stays alive and is running
/// when the alarm fires.
///
/// App Store hygiene / battery bounding — the keep-alive runs only when it's useful:
///   • App is NOT foreground-active (a live app needs no keep-alive).
///   • An enabled alarm fires within `maxLookaheadHours`.
///   • No alarm is currently ringing (the alarm engine owns audio + keeps us alive).
///
/// Session policy: `.playback` with **`.mixWithOthers`**, always. This matches the
/// app's default session (`AlarmAppDelegate`) and — critically — is NOT interrupted by
/// AlarmKit when the alarm fires. An EXCLUSIVE session would be interrupted by AlarmKit's
/// alert, and the engine misreads that interruption as a user suppression → a premature
/// parallel AppEngine takeover while AlarmKit is still ringing (DUAL SOUND). Mixing also
/// never cuts the user's bedtime music. Volume is 0 — nothing audible is ever produced.
///
/// Hardened against the three things that silently kill a background audio app:
/// interruptions (calls/Siri), route changes, and media-services resets — all
/// re-assert playback. Start is retried with backoff.
///
/// Best-effort, NOT a guarantee: force-quit or extreme memory pressure can still
/// terminate the app, in which case AlarmKit remains the never-silent floor.
@MainActor
final class AlarmKeepAliveAudioService {
    static let shared = AlarmKeepAliveAudioService()

    private var player: AVAudioPlayer?
    private var isRunning = false
    private var observersInstalled = false
    private var retryWorkItems: [DispatchWorkItem] = []
    /// Bounds battery: only keep alive when an alarm is within this window.
    private let maxLookaheadHours: TimeInterval = 24
    private let retryBackoff: [TimeInterval] = [0.5, 1.0, 2.0]

    private init() {}

    /// Central decision point. Call on scene-phase changes, on launch, after
    /// (re)scheduling alarms, and when an alarm session ends. Idempotent. Also acts
    /// as a health check: if it should be running but the player stopped, it restarts.
    func evaluate(reason: String) {
        installObserversIfNeeded()
        if shouldRun() {
            if isRunning, player?.isPlaying == true {
                return // healthy
            }
            if isRunning {
                DiagnosticsLog.shared.log("keep-alive player not progressing — restarting reason=\(reason)", category: "KeepAlive")
                isRunning = false
                player = nil
            }
            start(reason: reason, attempt: 0)
        } else {
            stop(reason: reason)
        }
    }

    /// Stop the keep-alive SYNCHRONOUSLY before the alarm engine starts playing, so
    /// the silent loop never coexists with the alarm audio. Call at ring start.
    func pauseForAlarmRing(reason: String) {
        cancelRetries()
        stop(reason: "alarm-ring-\(reason)")
    }

    private func shouldRun() -> Bool {
        if UIApplication.shared.applicationState == .active { return false }
        if AlarmAudioStateController.shared.isAlarmRinging { return false }
        return hasPendingAlarmWithinWindow()
    }

    private func hasPendingAlarmWithinWindow() -> Bool {
        let now = Date()
        let horizon = now.addingTimeInterval(maxLookaheadHours * 3600)
        for alarm in AlarmStore.shared.alarms where alarm.enabled {
            if let fire = AlarmStore.nextFireDate(for: alarm, from: now),
               fire > now, fire <= horizon {
                return true
            }
        }
        return false
    }

    private func start(reason: String, attempt: Int) {
        guard !isRunning else { return }
        guard let url = silentSoundURL() else {
            DiagnosticsLog.shared.log("cannot start — silent file unavailable reason=\(reason)", category: "KeepAlive")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // ALWAYS .mixWithOthers. An EXCLUSIVE .playback session gets INTERRUPTED by
            // AlarmKit when the alarm fires (AlarmKit grabs audio focus), and the engine's
            // interruption handler misreads that as a user suppression → it starts the
            // AppEngine in PARALLEL while AlarmKit is still ringing = DUAL SOUND. With
            // .mixWithOthers the session is NOT interrupted by AlarmKit, so the keep-alive
            // stays invisible to the ring handoff. This also matches the app's long-standing
            // default session (AlarmAppDelegate) and never cuts the user's bedtime audio.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.0
            p.prepareToPlay()
            guard p.play() else {
                throw NSError(domain: "KeepAlive", code: -1, userInfo: [NSLocalizedDescriptionKey: "play() returned false"])
            }
            player = p
            isRunning = true
            DiagnosticsLog.shared.log("▶️ started (mixWithOthers) reason=\(reason)", category: "KeepAlive")
        } catch {
            DiagnosticsLog.shared.log("start failed attempt=\(attempt) error=\(error.localizedDescription) reason=\(reason)", category: "KeepAlive")
            scheduleRetry(reason: reason, nextAttempt: attempt + 1)
        }
    }

    private func scheduleRetry(reason: String, nextAttempt: Int) {
        guard nextAttempt <= retryBackoff.count else {
            DiagnosticsLog.shared.log("start gave up after \(retryBackoff.count) retries reason=\(reason)", category: "KeepAlive")
            return
        }
        let delay = retryBackoff[nextAttempt - 1]
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.shouldRun() { self.start(reason: "\(reason)-retry\(nextAttempt)", attempt: nextAttempt) }
        }
        retryWorkItems.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelRetries() {
        retryWorkItems.forEach { $0.cancel() }
        retryWorkItems.removeAll()
    }

    private func stop(reason: String) {
        cancelRetries()
        guard isRunning else { return }
        player?.stop()
        player = nil
        isRunning = false
        // Do NOT deactivate the shared session — the alarm engine may own it.
        DiagnosticsLog.shared.log("⏹ stopped reason=\(reason)", category: "KeepAlive")
    }

    private func silentSoundURL() -> URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = library
            .appendingPathComponent("Sounds", isDirectory: true)
            .appendingPathComponent("alarmo_silence.caf", isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) { return url }
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            _ = AlarmSchedulerIOS26AlarmKit.ensureSilentAlertSoundStaged()
        }
#endif
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleRouteChange() }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleMediaServicesReset() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { _ in
            DiagnosticsLog.shared.log("⚠️ memory warning received (termination risk while backgrounded)", category: "Memory")
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            isRunning = false
            player = nil
            DiagnosticsLog.shared.log("interruption began — paused", category: "KeepAlive")
        case .ended:
            DiagnosticsLog.shared.log("interruption ended — re-evaluating", category: "KeepAlive")
            evaluate(reason: "interruption-ended")
        @unknown default:
            break
        }
    }

    private func handleRouteChange() {
        guard isRunning, player?.isPlaying != true else { return }
        DiagnosticsLog.shared.log("route change stopped playback — re-asserting", category: "KeepAlive")
        isRunning = false
        player = nil
        evaluate(reason: "route-change")
    }

    private func handleMediaServicesReset() {
        // Media server crashed: the session + player are dead and must be rebuilt.
        DiagnosticsLog.shared.log("media services reset — rebuilding", category: "KeepAlive")
        isRunning = false
        player = nil
        evaluate(reason: "media-services-reset")
    }
}
