import SwiftUI
import SwiftData

@main
struct AlarmoApp: App {
    @UIApplicationDelegateAdaptor(AlarmAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [PlanItem.self, CompletionLog.self])
    }
}
