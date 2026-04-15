import AppIntents
import Foundation

@available(iOS 16.0, *)
struct TogglePomoRunStateIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Play or Pause Focus"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let notificationName = CFNotificationName("ht.alarmo.toggleRunState" as CFString)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, notificationName, nil, nil, true)
        
        return .result()
    }
}
