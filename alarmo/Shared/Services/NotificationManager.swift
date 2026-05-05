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
    // Disabled by request: do not show "Alarm is ringing — unlock your phone..."
    // notifications; rely on AlarmKit surface only.
    private let alarmKitUnlockPromptNotificationsEnabled = false

    private enum AlarmKitUnlockPrompt {
        static let singleIdentifier = "alarmo-alarmkit-unlock-single"
        static let identifierPrefix = "alarmo-alarmkit-unlock-"
        static let loopIdentifierPrefix = "alarmo-alarmkit-unlock-loop-"
        static let loopImmediateIdentifierPrefix = "alarmo-alarmkit-unlock-loop-immediate-"
        static let legacyUserInfoAlarmIDKey = "alarmKitHandoffAlarmId"
        static let userInfoSourceAlarmIDKey = "alarmKitHandoffSourceAlarmId"
        static let userInfoSurfaceAlarmIDKey = "alarmKitHandoffSurfaceAlarmId"
    }

    private weak var ringCoordinator: AlarmRingCoordinator?
    private weak var alarmStore: AlarmStore?
    private let alarmScheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    private let alarmRecoveryLookbackSeconds: TimeInterval = 7 * 60
    private let pendingAlarmStartKey = "alarmo.pendingNotificationAlarmStarts"
    // Keep a visible gap between lock-screen reappearances to avoid
    // notification-center/card flooding and allow user interaction time.
    private let lockedSurfaceEnsureInterval: TimeInterval = 1.0
    // After explicit Stop/Snooze, ignore stale AlarmKit alert callbacks briefly
    // so in-flight updates cannot resurrect ringing UI/audio.
    private let alarmFlowCompletionSuppressionWindow: TimeInterval = 12.0
    private var pendingAlarmStarts: Set<String> = []
    private var lastLockedSurfaceEnsureAt: [String: Date] = [:]
    private var pendingLockedSurfaceReassertWorkItems: [String: DispatchWorkItem] = [:]
    private var lockedSurfaceEnsureInFlight: Set<String> = []
    private var completedAlarmFlowIds: Set<String> = []
    private var completedAlarmFlowAt: [String: Date] = [:]
    private var issuedAlarmKitUnlockPromptSourceIds: Set<String> = []
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        pendingAlarmStarts = loadPendingAlarmStarts()
        if !alarmKitUnlockPromptNotificationsEnabled {
            cancelAllAlarmKitUnlockPrompts()
        }
    }

    func configure(ringCoordinator: AlarmRingCoordinator, alarmStore: AlarmStore) {
        self.ringCoordinator = ringCoordinator
        self.alarmStore = alarmStore
        AlarmBackgroundAudioBridge.shared.configure(alarmStore: alarmStore)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        if !alarmKitUnlockPromptNotificationsEnabled {
            cancelAllAlarmKitUnlockPrompts()
        }
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
                        await processAlarmKitAlarmUpdate(alarm)
                    }
                }
            }
        }
#endif
    }

    func recoverAlarmKitAlertingIfNeeded() {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                do {
                    let alarms = try AlarmManager.shared.alarms
                    for alarm in alarms where alarm.state == .alerting {
                        await processAlarmKitAlertingAlarm(alarm)
                    }
                } catch {
                    print("[NotificationManager] Failed AlarmKit alert recovery fetch: \(error)")
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
            title: "Dismiss",
            options: [.authenticationRequired, .foreground]
        )
        let alarmKitUnlockCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmKitUnlock,
            actions: [unlockDismiss],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Alarm is ringing — unlock your phone to Stop or Snooze",
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

    func scheduleAlarmKitUnlockPrompt(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil,
        fireDate: Date? = nil
    ) {
        guard alarmKitUnlockPromptNotificationsEnabled else { return }
        // Only emit unlock prompts while an alarm flow is actively ringing
        // either in-app or through the lock-screen bridge.
        let ringIsActive = (ringCoordinator?.isRinging == true) || AlarmBackgroundAudioBridge.shared.isPlaying
        if !ringIsActive { return }
        if completedAlarmFlowIds.contains(sourceAlarmId) { return }
        if issuedAlarmKitUnlockPromptSourceIds.contains(sourceAlarmId) { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Alarm is ringing — unlock your phone to Stop or Snooze"
        content.subtitle = ""
        content.body = ""
        content.categoryIdentifier = AppNotificationCategory.alarmKitUnlock
        content.threadIdentifier = "alarmo.alarmkit.unlock"
        content.summaryArgument = "Unlock alarm alert"
        content.summaryArgumentCount = 1
        content.userInfo = [
            AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey: sourceAlarmId,
            AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey: surfaceAlarmId ?? sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }

        let identifier = AlarmKitUnlockPrompt.singleIdentifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        let trigger: UNNotificationTrigger?
        if let fireDate, fireDate.timeIntervalSinceNow > 1 {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule AlarmKit unlock prompt for \(sourceAlarmId): \(error)")
            }
        }
        issuedAlarmKitUnlockPromptSourceIds.insert(sourceAlarmId)
    }

    func startAlarmKitUnlockPromptLoop(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) {
        // No loop notifications. Keep a single unlock prompt only.
        scheduleAlarmKitUnlockPrompt(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName
        )
    }

    func cancelAlarmKitUnlockPrompt(alarmId: String) {
        let identifier = Self.alarmKitUnlockPromptIdentifier(alarmId: alarmId)
        let loopIdentifier = Self.alarmKitUnlockPromptLoopIdentifier(alarmId: alarmId)
        let loopImmediateIdentifier = Self.alarmKitUnlockPromptLoopImmediateIdentifier(alarmId: alarmId)
        issuedAlarmKitUnlockPromptSourceIds.remove(alarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier, loopIdentifier, loopImmediateIdentifier, AlarmKitUnlockPrompt.singleIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier, loopIdentifier, loopImmediateIdentifier, AlarmKitUnlockPrompt.singleIdentifier])
    }

    func cancelAllAlarmKitUnlockPrompts() {
        issuedAlarmKitUnlockPromptSourceIds.removeAll()
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0 == AlarmKitUnlockPrompt.singleIdentifier ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.identifierPrefix) ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopIdentifierPrefix) ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopImmediateIdentifierPrefix)
                }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .map { $0.request.identifier }
                .filter {
                    $0 == AlarmKitUnlockPrompt.singleIdentifier ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.identifierPrefix) ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopIdentifierPrefix) ||
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopImmediateIdentifierPrefix)
                }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    func markAlarmFlowCompleted(alarmId: String) {
        completedAlarmFlowIds.insert(alarmId)
        completedAlarmFlowAt[alarmId] = Date()
        issuedAlarmKitUnlockPromptSourceIds.remove(alarmId)
    }

    func clearCompletedAlarmFlow(alarmId: String) {
        completedAlarmFlowIds.remove(alarmId)
        completedAlarmFlowAt.removeValue(forKey: alarmId)
    }

    private func isAlarmFlowSuppressed(_ alarmId: String) -> Bool {
        guard let completedAt = completedAlarmFlowAt[alarmId] else {
            completedAlarmFlowIds.remove(alarmId)
            return false
        }
        if Date().timeIntervalSince(completedAt) <= alarmFlowCompletionSuppressionWindow {
            return true
        }
        completedAlarmFlowAt.removeValue(forKey: alarmId)
        completedAlarmFlowIds.remove(alarmId)
        return false
    }

    func dismissLinkedAlarmKitSurfaces(sourceAlarmId: String) {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            await dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: sourceAlarmId)
        }
#endif
    }

    func dismissLinkedAlarmKitSurfacesAggressively(
        sourceAlarmId: String,
        attempts: Int = 8,
        interval: TimeInterval = 0.2
    ) {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        let totalAttempts = max(1, attempts)

        Task { @MainActor in
            for pass in 0..<totalAttempts {
                await dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: sourceAlarmId)
                if pass < totalAttempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
#endif
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    @MainActor
    private func dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: String) async {
        do {
            let alarms = try AlarmManager.shared.alarms
            for alarm in alarms {
                let surfaceId = alarm.id.uuidString
                let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
                guard mappedSource == sourceAlarmId || surfaceId == sourceAlarmId else { continue }
                try? AlarmManager.shared.stop(id: alarm.id)
                try? AlarmManager.shared.cancel(id: alarm.id)
            }
        } catch {
            print("[NotificationManager] Failed dismissLinkedAlarmKitSurfaces for \(sourceAlarmId): \(error)")
        }
    }
#endif

    private static func alarmKitUnlockPromptIdentifier(alarmId: String) -> String {
        "\(AlarmKitUnlockPrompt.identifierPrefix)\(alarmId)"
    }

    private static func alarmKitUnlockPromptLoopIdentifier(alarmId: String) -> String {
        "\(AlarmKitUnlockPrompt.loopIdentifierPrefix)\(alarmId)"
    }

    private static func alarmKitUnlockPromptLoopImmediateIdentifier(alarmId: String) -> String {
        "\(AlarmKitUnlockPrompt.loopImmediateIdentifierPrefix)\(alarmId)"
    }

    private func makeAlarmKitUnlockPromptContent(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Alarm is ringing — unlock your phone to Stop or Snooze"
        content.subtitle = ""
        content.body = ""
        content.categoryIdentifier = AppNotificationCategory.alarmKitUnlock
        content.threadIdentifier = "alarmo.alarmkit.unlock"
        content.summaryArgument = "Unlock alarm alert"
        content.summaryArgumentCount = 1
        content.userInfo = [
            AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey: sourceAlarmId,
            AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey: surfaceAlarmId ?? sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }
        return content
    }

    private func shouldContinueAlarmKitUnlockPromptLoop(for sourceAlarmId: String) -> Bool {
        if completedAlarmFlowIds.contains(sourceAlarmId) { return false }
        if (ringCoordinator?.isRinging == true) || AlarmBackgroundAudioBridge.shared.isPlaying {
            return true
        }
        if let pending = AlarmCustomUIHandoffStore.pendingRequest() {
            return pending.sourceAlarmID == sourceAlarmId || pending.surfaceAlarmID == sourceAlarmId
        }
        return false
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
            // If user tapped an alarm notification from lock/home screen,
            // force custom ringing UI handoff and consume remaining runtime
            // follow-up notifications for this alarm.
            requestCustomUIHandoff(sourceAlarmId: alarmId, surfaceAlarmId: alarmId)
            if let uuid = UUID(uuidString: alarmId),
               let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) {
                alarmScheduler.cancelRuntimeRingNotifications(for: alarm)
            }
            startOrQueueAlarm(alarmId: alarmId)
        } else if let sourceAlarmId = userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String {
            let surfaceAlarmId = userInfo[AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey] as? String
            requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        } else if let legacyAlarmId = userInfo[AlarmKitUnlockPrompt.legacyUserInfoAlarmIDKey] as? String {
            requestCustomUIHandoff(sourceAlarmId: legacyAlarmId, surfaceAlarmId: legacyAlarmId)
        }
    }

    private func handleAlarmKitUnlockPromptAction(notification: UNNotification) {
        guard alarmKitUnlockPromptNotificationsEnabled else { return }
        guard let sourceAlarmId = notification.request.content.userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String else {
            return
        }
        let surfaceAlarmId = notification.request.content.userInfo[AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey] as? String
        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
    }

    private func requestCustomUIHandoff(sourceAlarmId: String, surfaceAlarmId: String? = nil) {
        guard let sourceUUID = UUID(uuidString: sourceAlarmId) else { return }
        let surfaceUUID = surfaceAlarmId.flatMap(UUID.init(uuidString:))
        AlarmCustomUIHandoffStore.request(
            alarmID: sourceUUID,
            surfaceAlarmID: surfaceUUID
        )
        NotificationCenter.default.post(
            name: .alarmKitCustomUIHandoffRequested,
            object: nil,
            userInfo: [
                "alarmId": sourceAlarmId,
                "surfaceAlarmId": surfaceAlarmId ?? sourceAlarmId
            ]
        )
    }

    func ensureAlarmKitSurfaceForLockedLoopIfNeeded(sourceAlarmId: String, force: Bool = false) {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        guard UIApplication.shared.applicationState != .active else { return }
        // Never resurrect surfaces when there is no active ringing session.
        // This prevents stale lock-loop callbacks from re-triggering after
        // Stop/Snooze already completed.
        if !force {
            let ringIsActive = (ringCoordinator?.isRinging == true) || AlarmBackgroundAudioBridge.shared.isPlaying
            guard ringIsActive else { return }
        }
        // The user has explicitly completed this alarm — never resurrect it.
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }

        let now = Date()
        let effectiveEnsureInterval = force ? max(0.5, lockedSurfaceEnsureInterval) : lockedSurfaceEnsureInterval
        if let last = lastLockedSurfaceEnsureAt[sourceAlarmId],
           now.timeIntervalSince(last) < effectiveEnsureInterval {
            return
        }
        if lockedSurfaceEnsureInFlight.contains(sourceAlarmId) {
            return
        }
        lastLockedSurfaceEnsureAt[sourceAlarmId] = now
        lockedSurfaceEnsureInFlight.insert(sourceAlarmId)

        Task { @MainActor in
            defer { lockedSurfaceEnsureInFlight.remove(sourceAlarmId) }
            do {
                let alarms = try AlarmManager.shared.alarms
                let alreadyAlerting = alarms.contains { alarm in
                    let surfaceId = alarm.id.uuidString
                    let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
                    return mappedSource == sourceAlarmId && alarm.state == .alerting
                }
                // Never mutate an actively alerting AlarmKit surface from this
                // recovery path. Doing so causes lock-screen UI flicker and
                // ring/stop/ring oscillation.
                if alreadyAlerting { return }
            } catch {
                print("[NotificationManager] Failed to inspect AlarmKit alarms before locked ensure: \(error)")
            }

            let surfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID ?? sourceAlarmId
            let intent = StopAlarmIntent(
                alarmID: surfaceAlarmId,
                originalAlarmID: sourceAlarmId,
                suppressUnlockPrompt: true
            )
            do {
                _ = try await intent.perform()
                print("[NotificationManager] 🔁 Ensured locked AlarmKit surface for source=\(sourceAlarmId)")
            } catch {
                print("[NotificationManager] Failed ensuring locked AlarmKit surface for \(sourceAlarmId): \(error)")
            }
        }
#endif
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func processAlarmKitAlarmUpdate(_ alarm: AlarmKit.Alarm) async {
        let surfaceAlarmId = alarm.id.uuidString
        let sourceAlarmId = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        let isBackgroundOrLocked = UIApplication.shared.applicationState != .active

        if alarm.state == .alerting {
            cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
            await processAlarmKitAlertingAlarm(alarm)
            return
        }

        // If the system surface was interrupted (for example hardware button
        // interaction) while we are still in locked/background alarm flow,
        // force the lock surface to reappear and keep bridge audio alive.
        if isBackgroundOrLocked, shouldContinueAlarmKitUnlockPromptLoop(for: sourceAlarmId) {
            // Side/volume button interactions can emit short non-alerting states.
            // Debounce reassertion so transient state flips do not cut and restart
            // alarm audio/UI.
            if AlarmBackgroundAudioBridge.shared.isAudiblyPlaying {
                cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
                return
            }
            scheduleLockedSurfaceReassert(
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: surfaceAlarmId,
                stateDescription: String(describing: alarm.state)
            )
        } else {
            cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
        }
    }

    @available(iOS 26.0, *)
    private func scheduleLockedSurfaceReassert(
        sourceAlarmId: String,
        surfaceAlarmId: String,
        stateDescription: String
    ) {
        cancelPendingLockedSurfaceReassert(for: sourceAlarmId)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingLockedSurfaceReassertWorkItems.removeValue(forKey: sourceAlarmId)

            guard UIApplication.shared.applicationState != .active else { return }
            guard self.shouldContinueAlarmKitUnlockPromptLoop(for: sourceAlarmId) else { return }
            guard !AlarmBackgroundAudioBridge.shared.isAudiblyPlaying else { return }

            AlarmBackgroundAudioBridge.shared.reinforceLockedLoopNow(
                surfaceAlarmId: surfaceAlarmId,
                sourceAlarmId: sourceAlarmId,
                reason: "alarm-update-non-alerting-\(stateDescription)"
            )
            self.ensureAlarmKitSurfaceForLockedLoopIfNeeded(sourceAlarmId: sourceAlarmId)
            self.startAlarmKitUnlockPromptLoop(
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: surfaceAlarmId,
                alarmName: nil
            )
        }

        pendingLockedSurfaceReassertWorkItems[sourceAlarmId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func cancelPendingLockedSurfaceReassert(for sourceAlarmId: String) {
        pendingLockedSurfaceReassertWorkItems[sourceAlarmId]?.cancel()
        pendingLockedSurfaceReassertWorkItems.removeValue(forKey: sourceAlarmId)
    }

    @available(iOS 26.0, *)
    private func processAlarmKitAlertingAlarm(_ alarm: AlarmKit.Alarm) async {
        let surfaceAlarmId = alarm.id.uuidString
        let sourceAlarmId = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        print("[NotificationManager] 🔔 AlarmKit alarm alerting: surface=\(surfaceAlarmId), source=\(sourceAlarmId)")

        // If user already pressed Stop/Snooze, ignore stale or in-flight
        // AlarmKit callbacks and tear down the surface instead of resurrecting UI.
        if isAlarmFlowSuppressed(sourceAlarmId) || isAlarmFlowSuppressed(surfaceAlarmId) {
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
            return
        }

        // ALWAYS start the background audio bridge so Alarmo's
        // own sound is playing before the user interacts with
        // the AlarmKit stop slider. This is the key to
        // seamless sound continuity.
        AlarmBackgroundAudioBridge.shared.start(
            surfaceAlarmId: surfaceAlarmId,
            sourceAlarmId: sourceAlarmId
        )

        if UIApplication.shared.applicationState == .active {
            // App is already in the foreground — show the
            // in-app ringing UI directly and dismiss the
            // system AlarmKit surface.
            let didStartCustomRing = startAlarmImmediatelyIfPossible(alarmId: sourceAlarmId)
            if didStartCustomRing {
                scheduleAlarmKitUnlockPrompt(
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId
                )
                dismissLinkedAlarmKitSurfacesAggressively(sourceAlarmId: sourceAlarmId)
                // Hand off from bridge to coordinator audio
                AlarmBackgroundAudioBridge.shared.handoffToForeground(alarmId: surfaceAlarmId)
                do {
                    try AlarmManager.shared.stop(id: alarm.id)
                    print("[NotificationManager] Dismissed foreground AlarmKit surface: \(surfaceAlarmId)")
                } catch {
                    print("[NotificationManager] Failed to dismiss foreground AlarmKit surface \(surfaceAlarmId): \(error)")
                }
            } else {
                // Keep sound alive and retry through the standard handoff path.
                if let sourceUUID = UUID(uuidString: sourceAlarmId) {
                    AlarmCustomUIHandoffStore.request(
                        alarmID: sourceUUID,
                        surfaceAlarmID: alarm.id
                    )
                }
                scheduleAlarmKitUnlockPrompt(
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId
                )
            }
        } else {
            // App is backgrounded/locked — keep bridge audio
            // running and prepare for post-unlock handoff.
            if let sourceUUID = UUID(uuidString: sourceAlarmId) {
                AlarmCustomUIHandoffStore.request(
                    alarmID: sourceUUID,
                    surfaceAlarmID: alarm.id
                )
            }
        }
        await AlarmManagerFacade.shared.markAlarmFired(id: alarm.id)
    }
#endif

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
            let didStart = self.ringCoordinator?.startRinging(alarmId: alarmId, source: .notification) == true
            if didStart {
                self.pendingAlarmStarts.remove(alarmId)
                self.persistPendingAlarmStarts()
            } else {
                // Keep ring request pending and retry so unlock flow can recover
                // from transient handoff races without going silent.
                self.pendingAlarmStarts.insert(alarmId)
                self.persistPendingAlarmStarts()
                let retryAlarmId = alarmId
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.startOrQueueAlarm(alarmId: retryAlarmId)
                }
            }
        }
    }

    @MainActor
    private func startAlarmImmediatelyIfPossible(alarmId: String) -> Bool {
        guard let ringCoordinator else {
            pendingAlarmStarts.insert(alarmId)
            persistPendingAlarmStarts()
            return false
        }
        let didStart = ringCoordinator.startRinging(alarmId: alarmId, source: .notification)
        if didStart {
            pendingAlarmStarts.remove(alarmId)
            persistPendingAlarmStarts()
        }
        return didStart
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
