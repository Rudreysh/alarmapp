import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class SystemOutputVolumeFloorManager {
    static let shared = SystemOutputVolumeFloorManager()

    private var volumeView: MPVolumeView?
    private var lastFloorAttemptAt: [String: Date] = [:]
    private var lastRequestedMinimum: [String: Float] = [:]
    private var activeAttemptInProgress: Set<String> = []
    private var floorRetryWorkItems: [DispatchWorkItem] = []
    private let minimumAttemptInterval: TimeInterval = 1.5
    /// Retry offsets after a volume-down press. Hardware volume HUD briefly sets
    /// the app to `.inactive`; iOS may also apply several DOWN steps in sequence.
    private let floorRetryDelays: [TimeInterval] = [0.05, 0.15, 0.30]

    private init() {}

    /// Foreground for volume enforcement: `.active` or `.inactive` (volume HUD).
    /// `.inactive` is NOT background — blocking here was why volume stayed low.
    private var isForegroundForVolumeEnforcement: Bool {
        switch UIApplication.shared.applicationState {
        case .active, .inactive: return true
        case .background: return false
        @unknown default: return false
        }
    }

    func attemptRaiseOutputVolumeFloor(
        minimumVolume: Float,
        reason: String,
        completion: ((Float) -> Void)? = nil
    ) {
        let state = AlarmAudioStateController.shared
        let runKey = state.currentAlarmRunId?.uuidString ?? state.currentAlarmId ?? "global"
        let phase = state.phase
        let session = AVAudioSession.sharedInstance()
        let currentOutput = session.outputVolume
        let routeTypes = session.currentRoute.outputs.map(\.portType)
        let routeText = routeTypes.map(\.rawValue).joined(separator: ",")

        guard AlarmFeatureFlags.experimentalMPVolumeOutputFloor else {
            print("[VolumeFloor] skipped reason=feature-flag-disabled output=\(String(format: "%.2f", currentOutput))")
            if currentOutput < minimumVolume {
                postLowVolumeHint()
            }
            completion?(currentOutput)
            return
        }

        guard isForegroundForVolumeEnforcement else {
            print("[VolumeFloor] skipped reason=app-background state=\(UIApplication.shared.applicationState.rawValue)")
            completion?(currentOutput)
            return
        }

        guard phase != .stopped, state.isAlarmRinging else {
            print("[VolumeFloor] skipped reason=alarm-not-ringing phase=\(phase.rawValue)")
            completion?(currentOutput)
            return
        }

        guard !activeAttemptInProgress.contains(runKey) else {
            print("[VolumeFloor] skipped reason=attempt-in-progress runId=\(runKey)")
            completion?(currentOutput)
            return
        }

        if let last = lastFloorAttemptAt[runKey],
           Date().timeIntervalSince(last) < minimumAttemptInterval {
            print("[VolumeFloor] skipped reason=rate-limited runId=\(runKey)")
            completion?(currentOutput)
            return
        }

        guard routeTypes.contains(.builtInSpeaker) else {
            print("[VolumeFloor] skipped reason=route-not-speaker route=\(routeText) detail=headphone-safety")
            postLowVolumeHint()
            completion?(currentOutput)
            return
        }

        guard currentOutput < minimumVolume else {
            print("[VolumeFloor] skipped reason=already-above-floor output=\(String(format: "%.2f", currentOutput)) targetFloor=\(String(format: "%.2f", minimumVolume))")
            completion?(currentOutput)
            return
        }

        print("[VolumeFloor] attempting reason=\(reason) currentOutput=\(String(format: "%.2f", currentOutput)) targetFloor=\(String(format: "%.2f", minimumVolume)) route=\(routeText) phase=\(phase.rawValue)")

        lastFloorAttemptAt[runKey] = Date()
        lastRequestedMinimum[runKey] = minimumVolume
        activeAttemptInProgress.insert(runKey)

        let view = ensureMountedVolumeView()
        guard let slider = findVolumeSlider(in: view) else {
            print("[VolumeFloor] skipped reason=slider-not-found")
            activeAttemptInProgress.remove(runKey)
            postLowVolumeHint()
            completion?(currentOutput)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + AlarmAudioStateController.mpVolumeFloorAttemptDelay) { [weak self] in
            guard let self else { return }
            slider.setValue(minimumVolume, animated: false)
            slider.sendActions(for: .valueChanged)
            print("[VolumeFloor] slider set target=\(String(format: "%.2f", minimumVolume))")

            DispatchQueue.main.asyncAfter(deadline: .now() + AlarmAudioStateController.mpVolumeFloorVerificationDelay) {
                let after = AVAudioSession.sharedInstance().outputVolume
                let accepted = after >= (minimumVolume - 0.01)
                print("[VolumeFloor] result before=\(String(format: "%.2f", currentOutput)) after=\(String(format: "%.2f", after)) accepted=\(accepted)")
                self.activeAttemptInProgress.remove(runKey)
                if !accepted {
                    self.postLowVolumeHint()
                }
                completion?(after)
            }
        }
    }

    /// Mount the hidden MPVolumeView early while a key window exists.
    func prepareVolumeViewIfNeeded() {
        _ = ensureMountedVolumeView()
    }

    /// Best-effort system media volume set — may work in background during an active ring.
    func setSystemVolumeBestEffort(
        _ value: Float,
        reason: String,
        allowBackground: Bool = true
    ) {
        guard AlarmFeatureFlags.experimentalMPVolumeOutputFloor else {
            print("[VolumeReset] skipped reason=feature-flag-disabled detail=\(reason)")
            return
        }
        let appState = UIApplication.shared.applicationState
        if !allowBackground && !isForegroundForVolumeEnforcement {
            print("[VolumeReset] skipped reason=app-background state=\(appState.rawValue) detail=\(reason)")
            return
        }
        let session = AVAudioSession.sharedInstance()
        let routeTypes = session.currentRoute.outputs.map(\.portType)
        guard routeTypes.contains(.builtInSpeaker) else {
            print("[VolumeReset] skipped reason=route-not-speaker detail=\(reason)")
            return
        }
        let clamped = min(max(value, 0), 1)
        let view = ensureMountedVolumeView()
        guard let slider = findVolumeSlider(in: view) else {
            print("[VolumeReset] failed reason=slider-not-found detail=\(reason)")
            return
        }
        print("[VolumeReset] setting slider value=\(String(format: "%.2f", clamped)) reason=\(reason) appState=\(appState.rawValue)")
        slider.setValue(clamped, animated: false)
        slider.sendActions(for: .valueChanged)
        slider.sendActions(for: .touchUpInside)
    }

    private func findVolumeSlider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider { return slider }
        for subview in view.subviews {
            if let slider = findVolumeSlider(in: subview) { return slider }
        }
        return nil
    }

    private func ensureMountedVolumeView() -> MPVolumeView {
        if let volumeView {
            return volumeView
        }

        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 40, height: 40))
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        view.alpha = 0.01
        view.isUserInteractionEnabled = false

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        keyWindow?.addSubview(view)
        keyWindow?.layoutIfNeeded()
        volumeView = view
        print("[VolumeFloor] mounted hidden MPVolumeView")
        return view
    }

    /// Raises system output volume to `minimumVolume` immediately, bypassing rate limiting.
    /// Use this for real-time volume-button enforcement (user is actively pressing volume-down
    /// while the alarm is ringing). The regular `attemptRaiseOutputVolumeFloor` is rate-limited
    /// to once per 1.5s and is not suitable for per-button-press response.
    ///
    /// Retries at short offsets because the volume HUD leaves the app `.inactive` and iOS may
    /// still be applying sequential hardware DOWN steps when we first fight back.
    func enforceFloorImmediately(minimumVolume: Float, reason: String = "immediate") {
        cancelPendingFloorRetries()
        enforceFloorOnce(minimumVolume: minimumVolume, reason: reason)
        for delay in floorRetryDelays {
            let work = DispatchWorkItem { [weak self] in
                self?.enforceFloorOnce(
                    minimumVolume: minimumVolume,
                    reason: "\(reason)-retry-\(Int(delay * 1000))ms"
                )
            }
            floorRetryWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func cancelPendingFloorRetries() {
        floorRetryWorkItems.forEach { $0.cancel() }
        floorRetryWorkItems.removeAll()
    }

    private func enforceFloorOnce(minimumVolume: Float, reason: String) {
        guard AlarmFeatureFlags.experimentalMPVolumeOutputFloor else { return }
        guard isForegroundForVolumeEnforcement else {
            print("[VolumeFloor] skipped reason=app-background state=\(UIApplication.shared.applicationState.rawValue) detail=\(reason)")
            return
        }
        let state = AlarmAudioStateController.shared
        guard state.phase != .stopped, state.isAlarmRinging else {
            print("[VolumeFloor] skipped reason=alarm-not-ringing detail=\(reason)")
            return
        }
        let session = AVAudioSession.sharedInstance()
        let currentOutput = session.outputVolume
        guard currentOutput + 0.01 < minimumVolume else { return }
        let routeTypes = session.currentRoute.outputs.map(\.portType)
        guard routeTypes.contains(.builtInSpeaker) else {
            print("[VolumeFloor] skipped reason=route-not-speaker detail=\(reason)")
            return
        }
        let view = ensureMountedVolumeView()
        guard let slider = findVolumeSlider(in: view) else {
            print("[VolumeFloor] skipped reason=slider-not-found detail=\(reason)")
            return
        }
        slider.setValue(minimumVolume, animated: false)
        slider.sendActions(for: .valueChanged)
        print("[VolumeFloor] enforce reason=\(reason) appState=\(UIApplication.shared.applicationState.rawValue) \(String(format: "%.2f", currentOutput)) → \(String(format: "%.2f", minimumVolume))")
    }

    private func postLowVolumeHint() {
        NotificationCenter.default.post(
            name: .alarmVolumeFloorHint,
            object: nil,
            userInfo: ["message": "Increase iPhone volume for louder alarm."]
        )
    }
}

extension Notification.Name {
    static let alarmVolumeFloorHint = Notification.Name("alarmVolumeFloorHint")
}
