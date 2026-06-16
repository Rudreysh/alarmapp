import AVFoundation
import Foundation
import UIKit

/// While AppEngine owns alarm audio, watches for media-volume drops and attempts
/// best-effort restoration via MPVolumeView. Falls back to AlarmKit recovery if reset fails.
@MainActor
final class AppEngineVolumeResetMonitor {
    static let shared = AppEngineVolumeResetMonitor()

    struct AlarmVolumeSnapshot {
        let sourceAlarmId: String
        let runId: String
        let originalOutputVolume: Float
        let targetOutputVolume: Float
        let capturedAt: Date
    }

    static let safeAlarmFloor: Float = 0.85
    static let resetFloor: Float = 0.70
    static let criticalFloor: Float = 0.10

    private var observation: NSKeyValueObservation?
    private var pollTimer: Timer?
    private var retryTask: Task<Void, Never>?

    private var isArmed = false
    private var snapshot: AlarmVolumeSnapshot?

    private init() {}

    func syncWithCurrentState(reason: String) {
        let state = AlarmAudioStateController.shared
        guard shouldMonitor(state: state) else {
            if isArmed {
                disarm(reason: "sync-not-monitoring-\(reason)")
            }
            return
        }
        guard let alarmId = state.currentAlarmId,
              let runId = state.currentAlarmRunId else {
            return
        }
        let runKey = runId.uuidString
        if isArmed,
           snapshot?.sourceAlarmId == alarmId,
           snapshot?.runId == runKey {
            checkAndResetNow(reason: "sync-\(reason)")
            return
        }
        arm(sourceAlarmId: alarmId, runId: runKey, reason: reason)
    }

    func arm(sourceAlarmId: String, runId: String, reason: String) {
        if isArmed {
            if snapshot?.runId == runId {
                checkAndResetNow(reason: "rearm-\(reason)")
                return
            }
            disarm(reason: "rearm-new-run")
        }

        SystemOutputVolumeFloorManager.shared.prepareVolumeViewIfNeeded()

        let session = AVAudioSession.sharedInstance()
        let original = session.outputVolume
        let target = max(original, Self.safeAlarmFloor)
        snapshot = AlarmVolumeSnapshot(
            sourceAlarmId: sourceAlarmId,
            runId: runId,
            originalOutputVolume: original,
            targetOutputVolume: target,
            capturedAt: Date()
        )
        isArmed = true

        print(
            "[VolumeReset] armed source=\(sourceAlarmId) run=\(runId) " +
            "original=\(String(format: "%.2f", original)) " +
            "target=\(String(format: "%.2f", target)) reason=\(reason)"
        )

        startKVO()
        startPolling()
        checkAndResetNow(reason: "arm")
    }

    func disarm(reason: String) {
        guard isArmed else { return }
        isArmed = false
        snapshot = nil

        observation?.invalidate()
        observation = nil
        stopPolling()
        retryTask?.cancel()
        retryTask = nil

        print("[VolumeReset] disarmed reason=\(reason)")
    }

    func checkAndResetNow(reason: String) {
        guard isArmed, let snapshot else { return }
        let volume = AVAudioSession.sharedInstance().outputVolume
        if volume < Self.resetFloor {
            handleVolumeDrop(volume, reason: reason)
        }
    }

    private func shouldMonitor(state: AlarmAudioStateController) -> Bool {
        guard state.isAlarmRinging else { return false }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return false }
        guard state.appEngineConfirmedPlaying() else { return false }
        switch state.phase {
        case .appEngineFadingIn, .appEnginePrimary, .alarmKitFallback:
            return true
        default:
            return false
        }
    }

    private func startKVO() {
        observation?.invalidate()
        observation = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new]
        ) { [weak self] session, change in
            guard let self else { return }
            Task { @MainActor in
                guard self.isArmed else { return }
                let volume = change.newValue ?? session.outputVolume
                print("[VolumeReset] observed outputVolume=\(String(format: "%.2f", volume))")
                if volume < Self.resetFloor {
                    self.handleVolumeDrop(volume, reason: "kvo")
                }
            }
        }
        print("[VolumeReset] KVO started")
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndResetNow(reason: "poll")
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func handleVolumeDrop(_ volume: Float, reason: String) {
        guard isArmed, let snap = snapshot else { return }

        if volume <= Self.criticalFloor {
            print("[VolumeReset] CRITICAL outputVolume=\(String(format: "%.2f", volume)) reason=\(reason)")
        } else {
            print(
                "[VolumeReset] low outputVolume=\(String(format: "%.2f", volume)) " +
                "floor=\(String(format: "%.2f", Self.resetFloor)) reason=\(reason)"
            )
        }

        SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
            snap.targetOutputVolume,
            reason: "restore-after-drop-\(reason)",
            allowBackground: true
        )
        scheduleRetrySequence(reason: reason)
    }

    private func scheduleRetrySequence(reason: String) {
        retryTask?.cancel()
        guard let snap = snapshot else { return }
        let target = snap.targetOutputVolume

        retryTask = Task { [weak self] in
            let delays: [UInt64] = [200_000_000, 500_000_000, 1_000_000_000, 1_500_000_000]
            for delay in delays {
                try? await Task.sleep(nanoseconds: delay)
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.isArmed else { return }
                    let current = AVAudioSession.sharedInstance().outputVolume
                    if current >= Self.resetFloor {
                        print("[VolumeReset] confirmed outputVolume=\(String(format: "%.2f", current)) reason=\(reason)")
                        self.retryTask?.cancel()
                        self.retryTask = nil
                        return
                    }
                    print(
                        "[VolumeReset] retry current=\(String(format: "%.2f", current)) " +
                        "target=\(String(format: "%.2f", target)) reason=\(reason)"
                    )
                    SystemOutputVolumeFloorManager.shared.setSystemVolumeBestEffort(
                        target,
                        reason: "retry-\(reason)",
                        allowBackground: true
                    )
                }
            }

            await MainActor.run {
                guard let self, self.isArmed else { return }
                let current = AVAudioSession.sharedInstance().outputVolume
                if current < Self.resetFloor {
                    print(
                        "[VolumeReset] failed-to-restore outputVolume=\(String(format: "%.2f", current)) " +
                        "floor=\(String(format: "%.2f", Self.resetFloor))"
                    )
                    self.notifyVolumeResetFailed(currentVolume: current)
                }
            }
        }
    }

    private func notifyVolumeResetFailed(currentVolume: Float) {
        guard let snap = snapshot else { return }
        NotificationCenter.default.post(
            name: .alarmoAppEngineVolumeResetFailed,
            object: nil,
            userInfo: [
                "sourceAlarmId": snap.sourceAlarmId,
                "runId": snap.runId,
                "currentVolume": currentVolume,
                "targetVolume": snap.targetOutputVolume
            ]
        )
    }
}

extension Notification.Name {
    static let alarmoAppEngineVolumeResetFailed = Notification.Name("alarmoAppEngineVolumeResetFailed")
}
