import AppIntents
import Foundation

@available(iOS 16.0, *)
struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        // Broadcast to the main app using Darwin Notifications
        let notificationName = CFNotificationName("ht.alarmo.togglePlayback" as CFString)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
        
        return .result()
    }
}
