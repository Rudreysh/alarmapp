import Foundation
import Combine
import UserNotifications
import UIKit

#if canImport(AlarmKit)
import AlarmKit
#endif

struct AlarmDeliveryStatus {
    let notificationsAuthorized: Bool
    let soundEnabled: Bool
    let alertEnabled: Bool
    let lockScreenEnabled: Bool
    let timeSensitiveEnabled: Bool
    let scheduledDeliveryEnabled: Bool
    let criticalEnabled: Bool

    var canRingAudibly: Bool {
        notificationsAuthorized && soundEnabled
    }

    var canShowOnLockScreenImmediately: Bool {
        notificationsAuthorized
        && alertEnabled
        && lockScreenEnabled
        && (!scheduledDeliveryEnabled || timeSensitiveEnabled)
    }
}

final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private enum AlarmKitUnlockPrompt {
        static let identifierPrefix = "alarmo-alarmkit-unlock-"
        static let userInfoAlarmIDKey = "alarmKitHandoffAlarmId"
    }

    private weak var ringCoordinator: AlarmRingCoordinator?
    private weak var alarmStore: AlarmStore?
    private let alarmScheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    private let alarmRecoveryLookbackSeconds: TimeInterval = 7 * 60
    private let pendingAlarmStartKey = "alarmo.pendingNotificationAlarmStarts"
    private var pendingAlarmStarts: Set<String> = []
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        pendingAlarmStarts = loadPendingAlarmStarts()
    }

    func configure(ringCoordinator: AlarmRingCoordinator, alarmStore: AlarmStore) {
        self.ringCoordinator = ringCoordinator
        self.alarmStore = alarmStore
        AlarmBackgroundAudioBridge.shared.configure(alarmStore: alarmStore)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        checkStatus()
        drainPendingAlarmStarts()
        startAlarmKitObservation()
    }

    /// Observe AlarmKit alarm state changes on iOS 26+.
    ///
    /// **Sound continuity strategy:**
    /// When an alarm enters `.alerting`, we ALWAYS start the app-owned
    /// background audio bridge immediately – regardless of app state.
    /// This means Alarmo's own AVAudioPlayer is looping the alarm sound
    /// *in parallel* with the system AlarmKit alert sound.
    ///
    /// When the user swipes "Stop" on the lock-screen AlarmKit UI:
    /// - AlarmKit stops its own system-managed sound
    /// - Alarmo's background audio bridge **continues** because it is
    ///   an independent AVAudioPlayer in `.playback` mode with the
    ///   `audio` background capability
    /// - The sound therefore never stops from the user's perspective
    ///
    /// After the user unlocks:
    /// - The `StopAlarmIntent` or unlock-prompt action triggers a
    ///   custom-UI handoff
    /// - `AppRootView.handlePendingCustomAlarmUIHandoff()` presents the
    ///   in-app `AlarmRingingView` which takes over audio
    /// - Only then is the bridge audio stopped
    private func startAlarmKitObservation() {
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                let manager = AlarmManager.shared
                for await alarms in manager.alarmUpdates {
                    for alarm in alarms {
                        if alarm.state == .alerting {
                            let alarmId = alarm.id.uuidString
                            print("[NotificationManager] 🔔 AlarmKit alarm alerting: \(alarmId)")

                            // ALWAYS start the background audio bridge so Alarmo's
                            // own sound is playing before the user interacts with
                            // the AlarmKit stop slider. This is the key to
                            // seamless sound continuity.
                            AlarmBackgroundAudioBridge.shared.start(alarmId: alarmId)

                            if UIApplication.shared.applicationState == .active {
                                // App is already in the foreground — show the
                                // in-app ringing UI directly and dismiss the
                                // system AlarmKit surface.
                                startOrQueueAlarm(alarmId: alarmId)
                                cancelAlarmKitUnlockPrompt(alarmId: alarmId)
                                // Hand off from bridge to coordinator audio
                                AlarmBackgroundAudioBridge.shared.handoffToForeground(alarmId: alarmId)
                                do {
                                    try manager.stop(id: alarm.id)
                                    print("[NotificationManager] Dismissed foreground AlarmKit surface: \(alarmId)")
                                } catch {
                                    print("[NotificationManager] Failed to dismiss foreground AlarmKit surface \(alarmId): \(error)")
                                }
                            } else {
                                // App is backgrounded/locked — keep bridge audio
                                // running and prepare for post-unlock handoff.
                                AlarmCustomUIHandoffStore.request(alarmID: alarm.id)
                                scheduleAlarmKitUnlockPrompt(alarmId: alarmId)
                            }
                            await AlarmManagerFacade.shared.markAlarmFired(id: alarm.id)
                        }
                    }
                }
            }
        }
#endif
    }
    
    func checkStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        let options = authorizationOptions()
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
            let options = authorizationOptions()
            let granted = try? await center.requestAuthorization(options: options)
            logSettings()
            return granted ?? false
        @unknown default:
            return false
        }
    }

    func currentAlarmDeliveryStatus() async -> AlarmDeliveryStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral)
        let soundEnabled = settings.soundSetting == .enabled
        let alertEnabled = settings.alertSetting == .enabled
        let lockScreenEnabled: Bool
        if #available(iOS 14.0, *) {
            lockScreenEnabled = settings.lockScreenSetting == .enabled
        } else {
            lockScreenEnabled = true
        }
        let timeSensitiveEnabled: Bool
        if #available(iOS 15.0, *) {
            timeSensitiveEnabled = settings.timeSensitiveSetting == .enabled
        } else {
            timeSensitiveEnabled = true
        }
        let scheduledDeliveryEnabled: Bool
        if #available(iOS 15.0, *) {
            scheduledDeliveryEnabled = settings.scheduledDeliverySetting == .enabled
        } else {
            scheduledDeliveryEnabled = false
        }
        let criticalEnabled: Bool
        if #available(iOS 12.0, *) {
            criticalEnabled = settings.criticalAlertSetting == .enabled
        } else {
            criticalEnabled = false
        }
        return AlarmDeliveryStatus(
            notificationsAuthorized: authorized,
            soundEnabled: soundEnabled,
            alertEnabled: alertEnabled,
            lockScreenEnabled: lockScreenEnabled,
            timeSensitiveEnabled: timeSensitiveEnabled,
            scheduledDeliveryEnabled: scheduledDeliveryEnabled,
            criticalEnabled: criticalEnabled
        )
    }

    private func authorizationOptions() -> UNAuthorizationOptions {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]
        if EntitlementInspector.hasCriticalAlertsAccess {
            options.insert(.criticalAlert)
        }
        return options
    }

    /// If the app is opened manually while alarm notifications are still actively re-alerting,
    /// recover the ringing session and show the in-app Snooze/Stop UI.
    func recoverAlarmFromDeliveredNotificationsIfNeeded() {
        // On the AlarmKit path, the system alarm surface is primary. We should not
        // resurrect the app's legacy notification-based ringing overlay.
        if AlarmManagerFacade.shared.selectedPath == .alarmKit { return }

        guard ringCoordinator?.isRinging != true else { return }
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] delivered in
            guard let self else { return }

            let now = Date()
            let latestAlarmId = delivered
                .filter { $0.request.content.categoryIdentifier == AppNotificationCategory.alarmRing }
                .compactMap { notification -> (String, Date)? in
                    guard let alarmId = notification.request.content.userInfo["alarmId"] as? String else { return nil }
                    return (alarmId, notification.date)
                }
                .filter { now.timeIntervalSince($0.1) <= self.alarmRecoveryLookbackSeconds }
                .sorted { $0.1 > $1.1 }
                .first?
                .0

            guard let alarmId = latestAlarmId else { return }
            self.startOrQueueAlarm(alarmId: alarmId)
        }
    }

    private func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: AppNotificationAction.alarmSnooze,
            title: "Snooze",
            options: []
        )
        let stop = UNNotificationAction(
            identifier: AppNotificationAction.alarmStop,
            title: "Stop",
            options: [.destructive]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmRing,
            actions: [snooze, stop],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let unlockDismiss = UNNotificationAction(
            identifier: AppNotificationAction.alarmKitUnlockDismiss,
            title: "Unlock Alarmo",
            options: [.authenticationRequired, .foreground]
        )
        let alarmKitUnlockCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmKitUnlock,
            actions: [unlockDismiss],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Unlock to stop or snooze the alarm in Alarmo.",
            categorySummaryFormat: "%u more alarm alerts",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        let markDone = UNNotificationAction(
            identifier: AppNotificationAction.planMarkDone,
            title: "Mark Done",
            options: [.foreground]
        )
        let remind10 = UNNotificationAction(
            identifier: AppNotificationAction.planRemindIn10,
            title: "Remind in 10m",
            options: []
        )
        let planCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.planReminder,
            actions: [markDone, remind10],
            intentIdentifiers: [],
            options: []
        )

        let startFocus = UNNotificationAction(
            identifier: AppNotificationAction.focusStartNow,
            title: "Start Focus",
            options: [.foreground]
        )
        let skipBreak = UNNotificationAction(
            identifier: AppNotificationAction.focusSkipBreak,
            title: "Skip Break",
            options: [.foreground]
        )
        let focusCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.focusSession,
            actions: [startFocus, skipBreak],
            intentIdentifiers: [],
            options: []
        )

        let addMinute = UNNotificationAction(
            identifier: AppNotificationAction.countdownAddMinute,
            title: "+1 Minute",
            options: []
        )
        let stopCountdown = UNNotificationAction(
            identifier: AppNotificationAction.countdownStop,
            title: "Stop",
            options: [.foreground]
        )
        let countdownCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.countdown,
            actions: [addMinute, stopCountdown],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            alarmCategory,
            alarmKitUnlockCategory,
            planCategory,
            focusCategory,
            countdownCategory
        ])
    }

    func scheduleAlarmKitUnlockPrompt(alarmId: String, alarmName: String? = nil, fireDate: Date? = nil) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        let resolvedAlarmName = alarmName ?? UUID(uuidString: alarmId).flatMap { id in
            (alarmStore ?? AlarmStore.shared).alarm(by: id)?.name
        }
        let title = resolvedAlarmName?.trimmingCharacters(in: .whitespacesAndNewlines)

        content.title = "Unlock to Stop or Snooze Alarm"
        if let title, !title.isEmpty {
            content.subtitle = "\(title) is still ringing"
        } else {
            content.subtitle = "Alarm is still ringing"
        }
        content.body = "Tap this alert to unlock your iPhone.\nThen stop or snooze the alarm in Alarmo."
        content.categoryIdentifier = AppNotificationCategory.alarmKitUnlock
        content.threadIdentifier = "alarmo.alarmkit.unlock"
        content.summaryArgument = "Unlock alarm alert"
        content.summaryArgumentCount = 1
        content.userInfo = [AlarmKitUnlockPrompt.userInfoAlarmIDKey: alarmId]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }

        let identifier = Self.alarmKitUnlockPromptIdentifier(alarmId: alarmId)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        let trigger: UNNotificationTrigger?
        if let fireDate, fireDate.timeIntervalSinceNow > 1 {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = nil
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule AlarmKit unlock prompt for \(alarmId): \(error)")
            }
        }
    }

    func cancelAlarmKitUnlockPrompt(alarmId: String) {
        let identifier = Self.alarmKitUnlockPromptIdentifier(alarmId: alarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private static func alarmKitUnlockPromptIdentifier(alarmId: String) -> String {
        "\(AlarmKitUnlockPrompt.identifierPrefix)\(alarmId)"
    }

    func logSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("[NotificationManager] authorizationStatus: \(settings.authorizationStatus.rawValue)")
            print("[NotificationManager] soundSetting: \(settings.soundSetting.rawValue)")
            print("[NotificationManager] alertSetting: \(settings.alertSetting.rawValue)")
            if #available(iOS 15.0, *) {
                print("[NotificationManager] timeSensitiveSetting: \(settings.timeSensitiveSetting.rawValue)")
            }
            if #available(iOS 12.0, *) {
                print("[NotificationManager] criticalAlertSetting: \(settings.criticalAlertSetting.rawValue)")
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo["alarmId"] != nil {
            // Ensure audio session is configured to override silent switch BEFORE starting playback.
            try? AudioRouteManager.configureAlarmSession()

            // Foreground alarm notifications should immediately transition to the in-app ringing UI.
            handle(notification: notification)
            if ringCoordinator?.isRinging == true {
                completionHandler([])
            } else {
                completionHandler([.banner, .list, .sound])
            }
            return
        }
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier

        // If user tapped the alarm notification from lock screen, configure audio immediately
        if response.notification.request.content.userInfo["alarmId"] != nil {
            try? AudioRouteManager.configureAlarmSession()
        }

        if action == AppNotificationAction.alarmKitUnlockDismiss ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmKitUnlock {
            handleAlarmKitUnlockPromptAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmStop {
            handleAlarmStopAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmSnooze {
            handleAlarmSnoozeAction(notification: response.notification)
        } else if action == AppNotificationAction.planMarkDone {
            NotificationCenter.default.post(
                name: .planNotificationMarkDoneRequested,
                object: nil,
                userInfo: response.notification.request.content.userInfo
            )
        } else if action == AppNotificationAction.planRemindIn10 {
            handlePlanRemindIn10(response: response.notification)
        } else if action == AppNotificationAction.focusStartNow {
            NotificationCenter.default.post(name: .focusStartRequestedFromNotification, object: nil)
        } else if action == AppNotificationAction.focusSkipBreak {
            NotificationCenter.default.post(name: .focusSkipBreakRequestedFromNotification, object: nil)
        } else if action == AppNotificationAction.countdownAddMinute {
            NotificationCenter.default.post(name: .countdownAddMinuteRequestedFromNotification, object: nil)
        } else if action == AppNotificationAction.countdownStop {
            NotificationCenter.default.post(name: .countdownStopRequestedFromNotification, object: nil)
        } else {
            handle(notification: response.notification)
        }
        completionHandler()
    }

    private func handle(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        if let alarmId = userInfo["alarmId"] as? String {
            startOrQueueAlarm(alarmId: alarmId)
        } else if let alarmId = userInfo[AlarmKitUnlockPrompt.userInfoAlarmIDKey] as? String {
            requestCustomUIHandoff(alarmId: alarmId)
        }
    }

    private func handleAlarmKitUnlockPromptAction(notification: UNNotification) {
        guard let alarmId = notification.request.content.userInfo[AlarmKitUnlockPrompt.userInfoAlarmIDKey] as? String else {
            return
        }
        requestCustomUIHandoff(alarmId: alarmId)
    }

    private func requestCustomUIHandoff(alarmId: String) {
        guard let uuid = UUID(uuidString: alarmId) else { return }
        AlarmCustomUIHandoffStore.request(alarmID: uuid)
        NotificationCenter.default.post(
            name: .alarmKitCustomUIHandoffRequested,
            object: nil,
            userInfo: ["alarmId": alarmId]
        )
    }

    private func handleAlarmStopAction(notification: UNNotification) {
        if ringCoordinator?.isRinging == true {
            ringCoordinator?.stopRinging()
            return
        }

        guard let alarm = alarmFromNotification(notification) else { return }
        alarmScheduler.cancelRuntimeRingNotifications(for: alarm)

        // Mirror ring-coordinator behavior for lock-screen stop actions.
        let store = alarmStore ?? AlarmStore.shared
        if alarm.type == .quick {
            store.remove(id: alarm.id)
        } else if alarm.repeatMask == 0 && !alarm.isDaily {
            store.toggleEnabled(id: alarm.id, enabled: false)
        }
    }

    private func handleAlarmSnoozeAction(notification: UNNotification) {
        if ringCoordinator?.isRinging == true {
            ringCoordinator?.snooze()
            return
        }

        guard let alarm = alarmFromNotification(notification) else { return }
        alarmScheduler.cancelRuntimeRingNotifications(for: alarm)
        let totalSeconds = resolvedSnoozeSeconds(for: alarm)
        alarmScheduler.scheduleSnooze(alarm: alarm, totalSeconds: totalSeconds)
    }

    private func alarmFromNotification(_ notification: UNNotification) -> Alarm? {
        guard let alarmIdString = notification.request.content.userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: alarmIdString) else {
            return nil
        }
        let store = alarmStore ?? AlarmStore.shared
        return store.alarm(by: alarmId)
    }

    private func resolvedSnoozeSeconds(for alarm: Alarm) -> Int {
        let minutes = max(0, alarm.snoozeMinutes)
        let seconds = max(0, alarm.snoozeSeconds)
        if seconds > 0 {
            return max(1, minutes * 60 + seconds)
        }
        if minutes > 0 {
            return max(1, minutes * 60)
        }
        return 300
    }

    private func handlePlanRemindIn10(response: UNNotification) {
        let userInfo = response.request.content.userInfo
        guard let scenarioRaw = userInfo["scenario"] as? String,
              let scenario = AppNotificationScenario(rawValue: scenarioRaw) else { return }

        let itemName = userInfo["itemName"] as? String
        let context = AppNotificationContext(itemName: itemName)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        NotificationOrchestrator.shared.schedule(
            identifier: "\(response.request.identifier)-snooze10-\(UUID().uuidString)",
            scenario: scenario,
            trigger: trigger,
            context: context,
            categoryIdentifier: AppNotificationCategory.planReminder,
            userInfo: userInfo,
            sound: .default
        )
    }

    private func startOrQueueAlarm(alarmId: String) {
        if ringCoordinator == nil {
            pendingAlarmStarts.insert(alarmId)
            persistPendingAlarmStarts()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.ringCoordinator?.startRinging(alarmId: alarmId, source: .notification)
            self.pendingAlarmStarts.remove(alarmId)
            self.persistPendingAlarmStarts()
        }
    }

    private func drainPendingAlarmStarts() {
        guard !pendingAlarmStarts.isEmpty else { return }
        let ids = Array(pendingAlarmStarts)
        for id in ids {
            startOrQueueAlarm(alarmId: id)
        }
    }

    private func persistPendingAlarmStarts() {
        UserDefaults.standard.set(Array(pendingAlarmStarts), forKey: pendingAlarmStartKey)
    }

    private func loadPendingAlarmStarts() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: pendingAlarmStartKey) ?? []
        return Set(values)
    }
}

enum AppNotificationCategory {
    static let alarmRing = "ALARM_RING"
    static let alarmKitUnlock = "ALARMKIT_UNLOCK"
    static let planReminder = "PLAN_REMINDER"
    static let focusSession = "FOCUS_SESSION"
    static let countdown = "COUNTDOWN"
}

enum AppNotificationAction {
    static let alarmSnooze = "ALARM_SNOOZE"
    static let alarmStop = "ALARM_STOP"
    static let alarmKitUnlockDismiss = "ALARMKIT_UNLOCK_DISMISS"
    static let planMarkDone = "PLAN_MARK_DONE"
    static let planRemindIn10 = "PLAN_REMIND_IN_10"
    static let focusStartNow = "FOCUS_START_NOW"
    static let focusSkipBreak = "FOCUS_SKIP_BREAK"
    static let countdownAddMinute = "COUNTDOWN_ADD_MINUTE"
    static let countdownStop = "COUNTDOWN_STOP"
}

extension Notification.Name {
    static let planNotificationMarkDoneRequested = Notification.Name("alarmo.plan.notification.markDoneRequested")
    static let focusStartRequestedFromNotification = Notification.Name("alarmo.focus.notification.startRequested")
    static let focusSkipBreakRequestedFromNotification = Notification.Name("alarmo.focus.notification.skipBreakRequested")
    static let countdownAddMinuteRequestedFromNotification = Notification.Name("alarmo.countdown.notification.addMinuteRequested")
    static let countdownStopRequestedFromNotification = Notification.Name("alarmo.countdown.notification.stopRequested")
}

enum AlarmNotificationCategory {
    static let alarmRing = AppNotificationCategory.alarmRing
    static let snooze = AppNotificationAction.alarmSnooze
    static let stop = AppNotificationAction.alarmStop
}
