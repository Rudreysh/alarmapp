import Foundation
import UserNotifications

protocol NotificationPermissionService {
    func isAuthorized() async -> Bool
    func requestAuthorization() async -> Bool
}

struct SystemNotificationPermissionService: NotificationPermissionService {
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }
}
