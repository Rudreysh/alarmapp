import Foundation
import UserNotifications

protocol NotificationPermissionService {
    func isAuthorized() async -> Bool
    func requestAuthorization() async -> Bool
}

struct SystemNotificationPermissionService: NotificationPermissionService {
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
            return granted
        } catch {
            return false
        }
    }
}
