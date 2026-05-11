import UIKit
import AVFoundation

final class AlarmAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = NotificationManager.shared

        // Keep launch path non-blocking on physical devices.
        // Full session activation is done by alarm engine right before playback.
        DispatchQueue.global(qos: .utility).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                print("[AlarmAppDelegate] ✅ Audio session category pre-configured")
            } catch {
                print("[AlarmAppDelegate] ⚠️ Failed to pre-configure audio category: \(error)")
            }

#if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
                _ = AlarmSchedulerIOS26AlarmKit.ensureSilentAlertSoundStaged()
            }
#endif
        }

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
        UserDefaults.standard.set(true, forKey: "alarmo.onboarding.forceShowNextLaunch")
    }
}
