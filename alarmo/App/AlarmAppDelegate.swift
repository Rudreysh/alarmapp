import UIKit
import AVFoundation

final class AlarmAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = NotificationManager.shared
        DiagnosticsLog.shared.log("app launched", category: "Lifecycle")
        AppExitDiagnostics.shared.start()

        // Pre-configure audio session to .playback so alarm sounds override the silent switch.
        // This must be done early so the session is ready before any notification triggers playback.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("[AlarmAppDelegate] ✅ Audio session pre-configured for alarm playback")
        } catch {
            print("[AlarmAppDelegate] ⚠️ Failed to pre-configure audio session: \(error)")
        }

#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            _ = AlarmSchedulerIOS26AlarmKit.ensureSilentAlertSoundStaged()
        }
#endif

        // CRITICAL (first-alarm cold-launch fix): when AlarmKit fires while the app is
        // terminated/suspended, iOS cold-launches us in the BACKGROUND and runs this
        // method — but SwiftUI's onAppear (where the AlarmKit observation, alerting
        // recovery, and keep-alive normally start) does NOT run until the app is
        // foregrounded. That left the first morning alarm with no AppEngine takeover.
        // Engage alarm handling now, independent of the view lifecycle, so the
        // in-progress alert is caught and the process is anchored before the user
        // can silence it via the side button.
        NotificationManager.shared.engageAlarmHandlingAtColdLaunch()

        // AlarmKit authorization is requested from explicit UI flows (onboarding/settings)
        // and before scheduling. Avoid launch-time prompts that can trap onboarding.

        // Initialize Accountability Penalty and reconcile any previous session (e.g. force close)
        // Replaced by call in AppRootView using correctly injected dependencies

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // If the user explicitly swipes up to kill the app while it's active or finishing tasks,
        // applicationWillTerminate is fired. In this case, we wipe the onboarding recovery step
        // to ensure the app starts fresh.
        // Note: iOS Privacy-switch kills do not trigger this, keeping those safe!
        UserDefaults.standard.removeObject(forKey: "alarmo.onboarding.recoveryStepRaw")

        print("[Lifecycle] applicationWillTerminate fired")
        // Best-effort force-quit warning only. Do not rely on this for correctness —
        // iOS often does not call willTerminate on swipe-up force-quit. AlarmKit
        // remains the reliable wake-up fallback.
        NotificationManager.shared.scheduleBestEffortForceQuitWarningOnTerminate(
            alarms: AlarmStore.shared.alarms
        )
    }
}
