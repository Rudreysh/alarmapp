import UIKit

final class AlarmAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Accountability Shield and reconcile any previous session (e.g. force close)
        // Replaced by call in AppRootView using correctly injected dependencies

        return true
    }
}
