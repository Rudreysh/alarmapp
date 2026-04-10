import UIKit

final class AlarmAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = NotificationManager.shared

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
