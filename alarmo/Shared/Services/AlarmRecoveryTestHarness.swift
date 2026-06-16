import Foundation
import UIKit

#if DEBUG
/// Debug-only harness for repeatable dead-audio recovery verification in the
/// simulator. Launch with: `--run-alarm-recovery-test`
///
/// The simulator cannot exercise real hardware side-button or AlarmKit ringer
/// audio. This harness simulates the lifecycle/dead-audio state machine and
/// verifies that recovery is scheduled when invariant conditions are met.
enum AlarmRecoveryTestHarness {
    static let launchArgument = "--run-alarm-recovery-test"
    static let loopCountKey = "--alarm-recovery-loop-count"
    static let fireTestAlarmKey = "--fire-test-alarm-in"
    static let skipOnboardingKey = "--skip-onboarding"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains(skipOnboardingKey)
    }

    static var fireTestAlarmInSeconds: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: fireTestAlarmKey), idx + 1 < args.count,
              let n = Int(args[idx + 1]), n > 0 else { return nil }
        return min(n, 300)
    }

    static var loopCount: Int {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: loopCountKey), idx + 1 < args.count,
              let n = Int(args[idx + 1]), n > 0 else { return 10 }
        return min(n, 50)
    }

    /// Runs one simulated side-button suppression cycle and logs pass/fail.
    @MainActor
    static func runIteration(_ iteration: Int, notificationManager: NotificationManager) {
        let sourceId = UUID().uuidString
        print("[RecoveryTest] iteration=\(iteration) START source=\(sourceId)")

        AlarmAuthHandoffStore.markRingingStarted(sourceAlarmId: sourceId)
        AlarmAudioStateController.shared.beginAlarmSession(
            alarmId: sourceId,
            soundName: "cockpitalert",
            reason: "recovery-test"
        )
        AlarmAudioStateController.shared.recordAppEnginePrepared()

        let isRisk = DeadAudioRiskEvaluator.isDeadAudioRisk(
            phase: .appEnginePreparing,
            appInactive: true,
            enginePlaying: false,
            finalStop: false,
            alarmStateRinging: true
        )
        print("[RecoveryTest] iteration=\(iteration) deadAudioRisk=\(isRisk)")
        XCTAssertHarness(isRisk, "expected dead-audio risk in simulated state")

        notificationManager.recordHardwareSuppressionEvent(sourceAlarmId: sourceId)
        notificationManager.detectAndRecoverDeadAudioState(
            sourceAlarmId: sourceId,
            reason: "recovery-test-side-button-or-lock-suppression"
        )

        print("[RecoveryTest] iteration=\(iteration) END source=\(sourceId)")
    }

    /// Schedules a quick alarm N seconds from now for manual simulator testing.
    @MainActor
    static func scheduleSimulatorTestAlarm(alarmStore: AlarmStore, secondsFromNow: Int) {
        UserDefaults.standard.set(true, forKey: "alarmo.onboarding.completed")
        UserDefaults.standard.set(false, forKey: "alarmo.onboarding.forceShowNextLaunch")
        let fire = Date().addingTimeInterval(TimeInterval(secondsFromNow))
        let cal = Calendar.current
        let id = UUID()
        let alarm = Alarm(
            id: id,
            type: .quick,
            name: "Simulator Side-Button Test",
            emoji: "⏰",
            hour: cal.component(.hour, from: fire),
            minute: cal.component(.minute, from: fire),
            second: cal.component(.second, from: fire),
            isDaily: false,
            repeatMask: 0,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "cockpitalert",
            soundVolume: 1.0,
            vibrateEnabled: true,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: 5,
            snoozeCount: 0,
            wallpaperId: "default",
            createdAt: Date()
        )
        alarmStore.add(alarm)
        AlarmManagerFacade.shared.schedule(alarm: alarm)
        print("[SimTestAlarm] scheduled id=\(id.uuidString) fireIn=\(secondsFromNow)s at \(alarm.timeStringPrecision)")
        print("[SimTestAlarm] when alarm rings, press side button (Cmd+Shift+H) or lock simulator, then wait for recovery logs")
    }

    @MainActor
    static func runLoop(notificationManager: NotificationManager) {
        let count = loopCount
        print("[RecoveryTest] starting loop count=\(count)")
        for i in 1...count {
            runIteration(i, notificationManager: notificationManager)
        }
        print("[RecoveryTest] loop complete count=\(count)")
    }

    private static func XCTAssertHarness(_ condition: Bool, _ message: String) {
        if condition {
            print("[RecoveryTest] PASS \(message)")
        } else {
            print("[RecoveryTest] FAIL \(message)")
        }
    }
}
#endif
