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
    private let minimumAttemptInterval: TimeInterval = 10.0

    private init() {}

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
        guard let slider = view.subviews.compactMap({ $0 as? UISlider }).first else {
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

    private func ensureMountedVolumeView() -> MPVolumeView {
        if let volumeView {
            return volumeView
        }

        let view = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        view.alpha = 0.001

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        keyWindow?.addSubview(view)
        volumeView = view
        print("[VolumeFloor] mounted hidden MPVolumeView")
        return view
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
