import Foundation
import AVFoundation
import UIKit

/// Probes whether the in-app AppEngine can actually own the alarm sound, by
/// sampling real audibility over the first few seconds of a ring.
///
/// Design principle (Alarmy-like): pre-arm the AlarmKit/basic fallback FIRST,
/// then run this probe. Cancel the fallback ONLY after the probe proves the
/// AppEngine is actually audible. Never assume "started == working".
///
/// A PASS requires at least two consecutive successful samples, each requiring:
///   - app process alive, runId matches, not final-stopped, state == ringing
///   - AVAudioSession category == .playback and session active
///   - engine playing, currentTime advancing, outputVolume above floor
///   - a valid audible route, and (if a fresh meter exists) non-silent signal
@MainActor
final class AppSoundCapabilityProbe {
    static let shared = AppSoundCapabilityProbe()

    private struct ActiveRun {
        let sourceAlarmId: String
        let runId: String
        var lastCurrentTime: TimeInterval
        var consecutivePasses: Int
        var sampleIndex: Int
        var workItems: [DispatchWorkItem]
    }

    private var active: ActiveRun?
    private let sampleOffsets: [TimeInterval] = [0.25, 0.75, 1.5, 3.0, 4.0]
    private let requiredConsecutivePasses = 2

    private init() {}

    /// Begins a probe for the given alarm run. `onPass` fires once when the engine
    /// is proven audible; `onFail` fires once if all samples elapse without a pass.
    func evaluate(
        sourceAlarmId: String,
        runId: String,
        reason: String,
        onPass: @escaping () -> Void,
        onFail: @escaping (_ reason: String) -> Void
    ) {
        cancel(reason: "superseded-by-\(reason)")
        print("[AppSoundProbe] started source=\(sourceAlarmId) runId=\(runId) reason=\(reason)")

        var run = ActiveRun(
            sourceAlarmId: sourceAlarmId,
            runId: runId,
            lastCurrentTime: AlarmContinuousAudioEngine.shared.currentTime,
            consecutivePasses: 0,
            sampleIndex: 0,
            workItems: []
        )

        for offset in sampleOffsets {
            let work = DispatchWorkItem { [weak self] in
                self?.takeSample(
                    sourceAlarmId: sourceAlarmId,
                    runId: runId,
                    onPass: onPass,
                    onFail: onFail
                )
            }
            run.workItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + offset, execute: work)
        }
        active = run
    }

    func cancel(reason: String) {
        guard let run = active else { return }
        run.workItems.forEach { $0.cancel() }
        active = nil
        print("[AppSoundProbe] cancelled runId=\(run.runId) reason=\(reason)")
    }

    private func takeSample(
        sourceAlarmId: String,
        runId: String,
        onPass: @escaping () -> Void,
        onFail: @escaping (_ reason: String) -> Void
    ) {
        guard var run = active, run.runId == runId else { return }
        run.sampleIndex += 1
        let isLastSample = run.sampleIndex >= sampleOffsets.count

        // Hard aborts that end the probe immediately.
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            active = nil
            print("[AppSoundProbe] FAIL — final stop/snooze source=\(sourceAlarmId)")
            onFail("final-stop")
            return
        }
        let stateRinging = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
        guard stateRinging else {
            active = nil
            print("[AppSoundProbe] FAIL — alarm no longer ringing source=\(sourceAlarmId)")
            onFail("not-ringing")
            return
        }
        guard AlarmAudioStateController.shared.currentAlarmRunId?.uuidString == runId
            || AlarmContinuousAudioEngine.shared.currentAlarmRunId?.uuidString == runId else {
            active = nil
            print("[AppSoundProbe] FAIL — runId mismatch source=\(sourceAlarmId)")
            onFail("run-id-mismatch")
            return
        }

        let engine = AlarmContinuousAudioEngine.shared
        let session = AVAudioSession.sharedInstance()
        let categoryOK = session.category == .playback
        let playing = engine.isEngineActive && engine.confirmStillPlaying()
        let currentTime = engine.currentTime
        let advancing = currentTime > run.lastCurrentTime + 0.001
        let output = session.outputVolume
        let outputOK = output > AlarmAudioStateController.lowOutputVolumeThreshold
        let routeOK = engine.hasValidAudibleRoute
        let meter = engine.recentMeterIsAudible()
        let meterOK = meter ?? true
        run.lastCurrentTime = currentTime

        // Sample 1 cannot prove advancing (no prior sample), so it only needs the
        // static conditions; advancing is required from sample 2 onward.
        let needsAdvancing = run.sampleIndex > 1
        let samplePass = categoryOK && playing && outputOK && routeOK && meterOK
            && (!needsAdvancing || advancing)

        if samplePass {
            run.consecutivePasses += 1
        } else {
            run.consecutivePasses = 0
        }

        let meterText = meter.map { $0 ? "audible" : "silent" } ?? "unknown"
        print("[AppSoundProbe] sample source=\(sourceAlarmId) idx=\(run.sampleIndex) playing=\(playing) advancing=\(advancing) output=\(String(format: "%.2f", output)) route=\(routeOK ? "valid" : "invalid") meter=\(meterText) pass=\(samplePass) streak=\(run.consecutivePasses)")

        if run.consecutivePasses >= requiredConsecutivePasses {
            run.workItems.forEach { $0.cancel() }
            active = nil
            print("[AppSoundProbe] PASS — AppEngine can own sound source=\(sourceAlarmId)")
            onPass()
            return
        }

        if isLastSample {
            active = nil
            print("[AppSoundProbe] FAIL — AppEngine not reliable source=\(sourceAlarmId) reason=insufficient-audible-samples")
            onFail("insufficient-audible-samples")
            return
        }

        active = run
    }
}
