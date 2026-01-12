import SwiftUI

@main
struct AlarmoApp: App {
    @UIApplicationDelegateAdaptor(AlarmAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
