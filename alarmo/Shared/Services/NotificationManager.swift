import Foundation
import Combine
import UserNotifications

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private weak var ringCoordinator: AlarmRingCoordinator?
    private weak var alarmStore: AlarmStore?
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
    }

    func configure(ringCoordinator: AlarmRingCoordinator, alarmStore: AlarmStore) {
        self.ringCoordinator = ringCoordinator
        self.alarmStore = alarmStore
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        checkStatus()
    }
    
    func checkStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            self.checkStatus()
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try? await center.requestAuthorization(options: options)
            logSettings()
            return granted ?? false
        @unknown default:
            return false
        }
    }

    private func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: AlarmNotificationCategory.snooze,
            title: "Snooze",
            options: [.foreground]
        )
        let stop = UNNotificationAction(
            identifier: AlarmNotificationCategory.stop,
            title: "Stop",
            options: [.destructive, .foreground]
        )
        let category = UNNotificationCategory(
            identifier: AlarmNotificationCategory.alarmRing,
            actions: [snooze, stop],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func logSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("[NotificationManager] authorizationStatus: \(settings.authorizationStatus.rawValue)")
            print("[NotificationManager] soundSetting: \(settings.soundSetting.rawValue)")
            print("[NotificationManager] alertSetting: \(settings.alertSetting.rawValue)")
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handle(notification: notification)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        if action == AlarmNotificationCategory.stop {
            ringCoordinator?.stopRinging()
        } else if action == AlarmNotificationCategory.snooze {
            ringCoordinator?.snooze()
        } else {
            handle(notification: response.notification)
        }
        completionHandler()
    }

    private func handle(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        if let alarmId = userInfo["alarmId"] as? String {
            ringCoordinator?.startRinging(alarmId: alarmId, source: .notification)
        }
    }
}

enum AlarmNotificationCategory {
    static let alarmRing = "ALARM_RING"
    static let snooze = "SNOOZE"
    static let stop = "STOP"
}
