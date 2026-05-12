import Foundation
import Combine
import UserNotifications
import UIKit
import AVFoundation

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
    private let alarmKitUnlockPromptNotificationsEnabled = true

    private enum AlarmKitUnlockPrompt {
        static let singleIdentifier = "alarmo-alarmkit-unlock-single"
        static let identifierPrefix = "alarmo-alarmkit-unlock-"
        static let loopIdentifierPrefix = "alarmo-alarmkit-unlock-loop-"
        static let loopImmediateIdentifierPrefix = "alarmo-alarmkit-unlock-loop-immediate-"
        static let legacyUserInfoAlarmIDKey = "alarmKitHandoffAlarmId"
        static let userInfoSourceAlarmIDKey = "alarmKitHandoffSourceAlarmId"
        static let userInfoSurfaceAlarmIDKey = "alarmKitHandoffSurfaceAlarmId"
    }

    private enum AlarmAuthenticationPrompt {
        static let identifierPrefix = "alarmo.post-slide-control."
        static let legacyIdentifierPrefix = "alarm-auth-prompt-"
        static let userInfoSourceAlarmIDKey = "alarmAuthPromptSourceAlarmId"
        static let userInfoSurfaceAlarmIDKey = "alarmAuthPromptSurfaceAlarmId"

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    private enum CustomUIHandoffFallback {
        static let identifierPrefix = "alarmo-custom-ui-handoff-fallback-"
    }

    private struct AlarmStartRetryState {
        var firstAttemptAt: Date
        var attempts: Int
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
    private var alarmStartRetryStates: [String: AlarmStartRetryState] = [:]
    private var lastRespawnScheduledAt: [String: Date] = [:]
    private var pendingAlarmKitDismissalTasks: [String: Task<Void, Never>] = [:]
    private var lastPostSlideNotificationAt: [String: Date] = [:]
    private let postSlideNotificationDuplicateWindow: TimeInterval = 1.0
    /// For each source alarm ID, the UUID of the currently-scheduled backup
    /// AlarmKit alarm that will fire 30s after the original. Cleared when
    /// the backup fires (then a new one is scheduled) OR when the user
    /// presses Stop in-app (then the chain ends).
    private var pendingBackupAlarmIds: [String: UUID] = [:]
    /// The most recently-alerting AlarmKit alarm UUID for each source. Used
    /// to dismiss the previous alarm before a new backup fires so only ONE
    /// banner is ever visible at a time.
    private var lastFiredAlarmIdsBySource: [String: UUID] = [:]
    /// Delays (in seconds) to try when scheduling each backup. We try the
    /// shortest first; if AlarmKit silently rejects it (some iOS builds reject
    /// schedules under a certain threshold), we fall back to longer delays.
    /// Worst-case gap of silence between AlarmKit fires.
    private static let backupAlarmDelays: [TimeInterval] = [2.0, 3.0, 5.0]
    private enum AlarmFlowPhase {
        case idle
        case ringingLocked
        case ringingUnlocked
        case completed
    }
    private var alarmFlowPhaseBySource: [String: AlarmFlowPhase] = [:]
    
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
        // Clean up stale ring-fallback notifications from a previous session
        // that may have been killed without going through stopRinging.
        cancelAllAlarmRingingFallbackChains()
        checkStatus()
        drainPendingAlarmStarts()
        startAlarmKitObservation()
    }

    func isCustomAlarmUIVisibleInForeground() -> Bool {
        UIApplication.shared.applicationState == .active && (ringCoordinator?.isRingingUIVisible == true)
    }

    private func appStateTag() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private func logAlarmTrace(
        event: String,
        sourceAlarmId: String? = nil,
        surfaceAlarmId: String? = nil,
        extra: String = ""
    ) {
        let controller = AlarmAudioStateController.shared
        let engine = AlarmContinuousAudioEngine.shared
        let bridge = AlarmBackgroundAudioBridge.shared
        let output = AVAudioSession.sharedInstance().outputVolume
        print(
            "🚨 [ALARMTRACE] EVENT=\(event.uppercased()) APP_STATE=\(appStateTag().uppercased()) " +
            "PHASE=\(controller.phase.rawValue.uppercased()) OWNER=\(controller.audibleOwner.rawValue.uppercased()) " +
            "SRC=\(sourceAlarmId ?? "nil") SURFACE=\(surfaceAlarmId ?? "nil") " +
            "RC_RINGING=\(ringCoordinator?.isRinging == true) RC_UI_VISIBLE=\(ringCoordinator?.isRingingUIVisible == true) " +
            "ENGINE_ACTIVE=\(engine.isEngineActive) ENGINE_HEALTHY=\(engine.cachedIsHealthy) " +
            "ENGINE_VOL=\(String(format: "%.2f", engine.currentPlayerVolume)) OUTPUT_VOL=\(String(format: "%.2f", output)) " +
            "BRIDGE_PLAYING=\(bridge.isPlaying) BRIDGE_SURFACE=\(bridge.currentAlarmID ?? "nil") BRIDGE_SOURCE=\(bridge.currentSourceAlarmID ?? "nil") " +
            "\(extra)"
        )
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

        let unlockToStopOrSnooze = UNNotificationAction(
            identifier: AppNotificationAction.alarmAuthPromptUnlock,
            title: "Unlock to Stop or Snooze",
            options: [.authenticationRequired, .foreground]
        )
        let alarmAuthPromptCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmAuthPrompt,
            actions: [unlockToStopOrSnooze],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Alarm is ringing — authenticate to stop",
            categorySummaryFormat: "%u more alarm alerts",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        let postSlideStopAlarmAction = UNNotificationAction(
            identifier: AppNotificationAction.alarmPostSlideStopAlarm,
            title: "Stop Alarm",
            // Notification action color is system-controlled. `.destructive` is
            // used only to request a red system action style.
            options: [.authenticationRequired, .foreground, .destructive]
        )
        let postSlideControlCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmPostSlideControl,
            actions: [postSlideStopAlarmAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
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
            alarmAuthPromptCategory,
            postSlideControlCategory,
            planCategory,
            focusCategory,
            countdownCategory
        ])
        print("[PostSlideNotification] registered category \(AppNotificationCategory.alarmPostSlideControl)")
    }

    func scheduleAlarmKitUnlockPrompt(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil,
        fireDate: Date? = nil
    ) {
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Unlock prompt suppressed — app is active")
            return
        }
        logAlarmTrace(
            event: "schedule-unlock-prompt",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            extra: "alarmName=\(alarmName ?? "nil") fireDate=\(fireDate?.description ?? "nil")"
        )
        guard alarmKitUnlockPromptNotificationsEnabled else { return }
        // Only emit unlock prompts while an alarm flow is actively ringing
        // either in-app or through the lock-screen bridge.
        let ringIsActive = (ringCoordinator?.isRinging == true) || AlarmBackgroundAudioBridge.shared.isPlaying
        if !ringIsActive { return }
        if completedAlarmFlowIds.contains(sourceAlarmId) { return }
        if issuedAlarmKitUnlockPromptSourceIds.contains(sourceAlarmId) { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        let isUnlockedState = UIApplication.shared.isProtectedDataAvailable
        let copy = alarmKitUnlockPromptCopy(isUnlockedState: isUnlockedState)
        content.title = copy.title
        content.subtitle = ""
        content.body = copy.body
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
        if isUnlockedState {
            print("[UnlockedAlarmNotification] title=\"\(content.title)\" body=\"\(content.body)\"")
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
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Unlock prompt loop suppressed — app is active")
            return
        }
        logAlarmTrace(
            event: "start-unlock-prompt-loop",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            extra: "alarmName=\(alarmName ?? "nil")"
        )
        // No loop notifications. Keep a single unlock prompt only.
        scheduleAlarmKitUnlockPrompt(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName
        )
    }

    func scheduleAlarmAuthenticationPrompt(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) {
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Auth prompt suppressed — app is active, UI handles interaction")
            return
        }
        logAlarmTrace(
            event: "schedule-auth-prompt",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            extra: "alarmName=\(alarmName ?? "nil")"
        )
        let now = Date()
        if let last = lastPostSlideNotificationAt[sourceAlarmId],
           now.timeIntervalSince(last) < postSlideNotificationDuplicateWindow {
            print("[PostSlideNotification] skipped duplicate for alarmId=\(sourceAlarmId)")
            return
        }
        lastPostSlideNotificationAt[sourceAlarmId] = now
        let center = UNUserNotificationCenter.current()
        cancelAlarmAuthenticationPrompt(sourceAlarmId: sourceAlarmId)

        let content = UNMutableNotificationContent()
        content.title = "⏰ Alarm is ringing"
        content.body = "Tap to stop alarm"
        content.categoryIdentifier = AppNotificationCategory.alarmPostSlideControl
        content.threadIdentifier = "alarmo.post-slide-control"
        content.sound = nil
        content.userInfo = [
            AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey: sourceAlarmId,
            AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey: surfaceAlarmId ?? sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }

        let identifier = AlarmAuthenticationPrompt.identifier(for: sourceAlarmId)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        print("[PostSlideNotification] scheduling Alarmy-style card alarmId=\(sourceAlarmId) title=\"\(content.title)\" body=\"\(content.body)\" action=\"Stop Alarm\"")
        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule auth prompt for \(sourceAlarmId): \(error)")
            }
        }
    }

    func cancelAlarmAuthenticationPrompt(sourceAlarmId: String) {
        let stableIdentifier = AlarmAuthenticationPrompt.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [stableIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [stableIdentifier])
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix("\(AlarmAuthenticationPrompt.legacyIdentifierPrefix)\(sourceAlarmId)-")
                }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .map(\.request.identifier)
                .filter {
                    $0.hasPrefix("\(AlarmAuthenticationPrompt.legacyIdentifierPrefix)\(sourceAlarmId)-")
                }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    func cancelAllAlarmAuthenticationPrompts() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(AlarmAuthenticationPrompt.identifierPrefix) ||
                    $0.hasPrefix(AlarmAuthenticationPrompt.legacyIdentifierPrefix)
                }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .map(\.request.identifier)
                .filter {
                    $0.hasPrefix(AlarmAuthenticationPrompt.identifierPrefix) ||
                    $0.hasPrefix(AlarmAuthenticationPrompt.legacyIdentifierPrefix)
                }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    func scheduleCustomUIHandoffFallbackNotification(sourceAlarmId: String, alarmName: String? = nil) {
        let center = UNUserNotificationCenter.current()
        cancelCustomUIHandoffFallbackNotification(sourceAlarmId: sourceAlarmId)
        let content = UNMutableNotificationContent()
        let label = resolvedAlarmLabel(sourceAlarmId: sourceAlarmId, alarmName: alarmName)
        content.title = "\(label) is ringing — tap to open"
        content.body = ""
        content.sound = nil
        content.categoryIdentifier = AppNotificationCategory.alarmKitUnlock
        content.threadIdentifier = "alarmo.alarmkit.handoff-fallback"
        content.userInfo = [
            AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey: sourceAlarmId,
            AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey: sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }
        let identifier = Self.customUIHandoffFallbackIdentifier(alarmId: sourceAlarmId)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed handoff fallback notification for \(sourceAlarmId): \(error)")
            }
        }
    }

    func cancelCustomUIHandoffFallbackNotification(sourceAlarmId: String) {
        let identifier = Self.customUIHandoffFallbackIdentifier(alarmId: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Alarm Ringing Fallback Chain
    //
    // CRITICAL: this is the only mechanism that survives full app suspension.
    // When an alarm fires, we schedule a chain of local notifications with
    // sound at increasing intervals. iOS plays these notifications even when
    // our app is suspended (no DispatchSource timer, no AVAudioPlayer can run
    // when suspended). If anything in our app's audio pipeline fails — bridge
    // interrupted, coordinator's player nil, AlarmKit's surface gone — the
    // fallback chain still fires from the system level and the user is woken.
    //
    // The chain is cancelled the moment the user explicitly dismisses via
    // Stop/Snooze in the in-app UI. So if everything works normally, the user
    // dismisses within seconds and these notifications never actually fire.

    private static let alarmRingingFallbackPrefix = "alarmo-ring-fallback-"
    private let alarmRingingFallbackOffsets: [TimeInterval] = [
        8, 18, 30, 45, 60, 90, 120, 180, 240, 300
    ]

    /// Schedule the fallback notification chain for an alarm. Safe to call
    /// repeatedly — re-scheduling cancels the previous chain first.
    func scheduleAlarmRingingFallbackChain(alarmId: String, soundName: String, alarmName: String) {
        cancelAlarmRingingFallbackChain(alarmId: alarmId)

        let center = UNUserNotificationCenter.current()
        let resolvedSound = resolveAlarmRingingSound(soundName: soundName)
        let displayTitle = alarmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Alarm"
            : alarmName

        for (index, offset) in alarmRingingFallbackOffsets.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = displayTitle
            content.body = ""
            content.categoryIdentifier = AppNotificationCategory.alarmRing
            content.threadIdentifier = "alarmo.alarm-ring-fallback.\(alarmId)"
            content.userInfo = ["alarmId": alarmId, "alarmoFallbackIndex": index]
            content.sound = resolvedSound
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: offset, repeats: false)
            let identifier = "\(Self.alarmRingingFallbackPrefix)\(alarmId)-\(index)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    print("[NotificationManager] ❌ Failed to schedule fallback chain entry \(index) for \(alarmId): \(error)")
                }
            }
        }
        print("[NotificationManager] ⏰ Scheduled \(alarmRingingFallbackOffsets.count) fallback ring notifications for alarm \(alarmId)")
    }

    /// Cancel the fallback notification chain. Called on Stop/Snooze.
    func cancelAlarmRingingFallbackChain(alarmId: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = (0..<alarmRingingFallbackOffsets.count).map {
            "\(Self.alarmRingingFallbackPrefix)\(alarmId)-\($0)"
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        // Also remove ANY stragglers with the matching prefix (e.g. if offsets
        // changed between app versions).
        center.getPendingNotificationRequests { requests in
            let stale = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("\(Self.alarmRingingFallbackPrefix)\(alarmId)") }
            if !stale.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
        }
        center.getDeliveredNotifications { delivered in
            let stale = delivered
                .map(\.request.identifier)
                .filter { $0.hasPrefix("\(Self.alarmRingingFallbackPrefix)\(alarmId)") }
            if !stale.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: stale)
            }
        }
    }

    /// Cancel ALL fallback chains across ALL alarms. Used on app launch /
    /// dirty-shutdown recovery to clean up any leftover notifications from a
    /// previous ring that didn't get explicitly cancelled.
    func cancelAllAlarmRingingFallbackChains() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.alarmRingingFallbackPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered
                .map(\.request.identifier)
                .filter { $0.hasPrefix(Self.alarmRingingFallbackPrefix) }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    private func resolveAlarmRingingSound(soundName: String) -> UNNotificationSound {
        // Try the user's chosen alarm sound first. If we have critical alert
        // entitlement, use criticalSoundNamed to bypass silent mode + DND.
        // Sound files must already be staged into Library/Sounds by the
        // legacy alarm scheduler before reaching here.
        let trimmed = soundName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != "default" {
            for ext in ["caf", "wav", "aiff"] {
                let candidateName = "\(sanitizedSoundFileBase(from: trimmed)).\(ext)"
                if soundFileExistsInLibrary(named: candidateName) {
                    if EntitlementInspector.hasCriticalAlertsAccess {
                        return UNNotificationSound.criticalSoundNamed(
                            UNNotificationSoundName(candidateName),
                            withAudioVolume: 1.0
                        )
                    }
                    return UNNotificationSound(named: UNNotificationSoundName(candidateName))
                }
            }
        }
        if EntitlementInspector.hasCriticalAlertsAccess {
            return UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        }
        return .default
    }

    private func sanitizedSoundFileBase(from raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_-."))
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "_-."))
        return cleaned.isEmpty ? "alarm" : cleaned
    }

    private func soundFileExistsInLibrary(named fileName: String) -> Bool {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return false
        }
        let url = library.appendingPathComponent("Sounds", isDirectory: true).appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Cancel any in-flight AlarmKit dismissals. Call from scenePhase inactive
    /// to ensure a fast user re-lock cannot trigger a stale dismissal that
    /// silences the lock-screen alarm surface.
    func cancelPendingAlarmKitDismissals(reason: String = "manual") {
        guard !pendingAlarmKitDismissalTasks.isEmpty else { return }
        for (_, task) in pendingAlarmKitDismissalTasks {
            task.cancel()
        }
        let count = pendingAlarmKitDismissalTasks.count
        pendingAlarmKitDismissalTasks.removeAll()
        print("[NotificationManager] Cancelled \(count) pending AlarmKit dismissal(s) (\(reason))")
    }

    func cancelAlarmKitUnlockPrompt(alarmId: String) {
        let identifier = Self.alarmKitUnlockPromptIdentifier(alarmId: alarmId)
        let loopIdentifier = Self.alarmKitUnlockPromptLoopIdentifier(alarmId: alarmId)
        let loopImmediateIdentifier = Self.alarmKitUnlockPromptLoopImmediateIdentifier(alarmId: alarmId)
        let customUIFallbackIdentifier = Self.customUIHandoffFallbackIdentifier(alarmId: alarmId)
        issuedAlarmKitUnlockPromptSourceIds.remove(alarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier, loopIdentifier, loopImmediateIdentifier, customUIFallbackIdentifier, AlarmKitUnlockPrompt.singleIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier, loopIdentifier, loopImmediateIdentifier, customUIFallbackIdentifier, AlarmKitUnlockPrompt.singleIdentifier])
        // Intentionally do NOT cancel AlarmAuthenticationPrompt here.
        // Post-slide control card is a distinct notification flow and should
        // remain visible when unlock prompts are pruned.
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
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopImmediateIdentifierPrefix) ||
                    $0.hasPrefix(CustomUIHandoffFallback.identifierPrefix)
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
                    $0.hasPrefix(AlarmKitUnlockPrompt.loopImmediateIdentifierPrefix) ||
                    $0.hasPrefix(CustomUIHandoffFallback.identifierPrefix)
                }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
        // Keep post-slide control cards independent from unlock-prompt cleanup.
    }

    func markAlarmFlowCompleted(alarmId: String) {
        completedAlarmFlowIds.insert(alarmId)
        completedAlarmFlowAt[alarmId] = Date()
        issuedAlarmKitUnlockPromptSourceIds.remove(alarmId)
        alarmFlowPhaseBySource[alarmId] = .completed
        cancelAlarmAuthenticationPrompt(sourceAlarmId: alarmId)
        cancelCustomUIHandoffFallbackNotification(sourceAlarmId: alarmId)
    }

    // MARK: - Backup AlarmKit Chain (Alarmy-style)
    //
    // This is the GUARANTEED audio continuity mechanism. When an AlarmKit
    // alarm fires, we schedule ONE backup alarm 30 seconds in the future.
    // If the user dismisses the alarm in-app, we cancel the backup and the
    // chain ends. If the user does NOT dismiss (e.g. they unlock+lock fast,
    // and our app gets suspended), the backup fires after 30 seconds and
    // creates a new AlarmKit alerting state — slide-to-stop UI returns,
    // sound plays again. When the backup fires, we schedule a new backup,
    // continuing the chain. This loops indefinitely until the user opens
    // the app and presses Stop/Snooze.

    /// Ensure a backup AlarmKit alarm is scheduled for the given source.
    /// Idempotent — if one is already pending, no-op. Tries multiple delays
    /// (shortest first) so we get the fastest possible re-fire while still
    /// being accepted by AlarmKit.
    @available(iOS 26.0, *)
    @MainActor
    func ensureBackupAlarmKitChain(sourceAlarmId: String) async {
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() else {
            print("[Backup] Chain suppressed by phase \(AlarmAudioStateController.shared.phase.rawValue) — shouldAllowAlarmKitRespawn=false")
            return
        }
        guard !(UIApplication.shared.applicationState == .active &&
                AlarmAudioStateController.shared.phase == .appEnginePrimary) else {
            print("[Backup] Chain suppressed — app active + engine primary, no backup surface needed")
            return
        }

        let precheckEngineAppearsHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.cachedIsHealthy
        let precheckEngineLiveHealthy = precheckEngineAppearsHealthy &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if !precheckEngineLiveHealthy && !AlarmAudioStateController.shared.isEngineUnhealthinessAFailure() {
            print("[Backup] Engine not healthy but not a failure in phase \(AlarmAudioStateController.shared.phase.rawValue) — skipping backup")
            return
        }

        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        if pendingBackupAlarmIds[sourceAlarmId] != nil { return }
        guard let sourceUUID = UUID(uuidString: sourceAlarmId) else { return }
        guard let originalAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else { return }
        let engineAppearsHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.cachedIsHealthy
        let engineLiveHealthy = engineAppearsHealthy &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if engineLiveHealthy {
            print("[Backup] Skipping backup chain — engine is active and healthy (would cause session conflict)")
            return
        }
        print("[Backup] Engine not healthy — scheduling backup AlarmKit chain")

        let helper = AlarmSchedulerIOS26AlarmKit()
        let title = originalAlarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Alarm"
            : originalAlarm.name

        var lastError: Error?
        for delay in Self.backupAlarmDelays {
            let backupUUID = UUID()
            do {
                _ = try await helper.scheduleWithFallbackSound(
                    manager: AlarmManager.shared,
                    id: backupUUID,
                    originalAlarmID: sourceUUID,
                    title: title,
                    schedule: .fixed(Date().addingTimeInterval(delay)),
                    snoozeEnabled: false,
                    snoozeInterval: nil,
                    preferredSoundName: originalAlarm.soundName
                )
                AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: backupUUID)
                pendingBackupAlarmIds[sourceAlarmId] = backupUUID
                print("[NotificationManager] 🔁 Scheduled backup AlarmKit alarm \(backupUUID.uuidString) for source=\(sourceAlarmId) at +\(delay)s")
                return
            } catch {
                lastError = error
                print("[NotificationManager] backup at +\(delay)s rejected: \(error)")
            }
        }
        print("[NotificationManager] ❌ ALL backup AlarmKit schedule attempts failed: \(lastError?.localizedDescription ?? "unknown")")
    }

    /// Cancel the currently-pending backup alarm for a source. Called when
    /// the backup fires (so the next one can be scheduled) OR when the user
    /// presses Stop/Snooze in-app (chain ends).
    @available(iOS 26.0, *)
    func cancelPendingBackupAlarm(sourceAlarmId: String) {
        guard let backupId = pendingBackupAlarmIds.removeValue(forKey: sourceAlarmId) else { return }
        do {
            try AlarmManager.shared.cancel(id: backupId)
            print("[NotificationManager] 🛑 Cancelled backup AlarmKit alarm \(backupId.uuidString)")
        } catch {
            print("[NotificationManager] Cancel of backup \(backupId.uuidString) failed: \(error)")
        }
    }

    /// Cancel ALL backup chains (both the one for sourceAlarmId and any
    /// stragglers). Called from stopRingingInternal — comprehensive cleanup.
    @available(iOS 26.0, *)
    func cancelAllBackupAlarmKitChains() {
        for (_, backupId) in pendingBackupAlarmIds {
            try? AlarmManager.shared.cancel(id: backupId)
        }
        pendingBackupAlarmIds.removeAll()
        lastFiredAlarmIdsBySource.removeAll()
    }

    /// Check whether the given alarm UUID is one of our pending backups.
    /// Used in processAlarmKitAlertingAlarm to detect when a backup fires
    /// so we can schedule the next link in the chain.
    func isBackupAlarmKitAlarm(_ alarmId: UUID) -> (sourceAlarmId: String, backupId: UUID)? {
        for (source, backup) in pendingBackupAlarmIds where backup == alarmId {
            return (source, backup)
        }
        return nil
    }

    /// Aggressively kill EVERY AlarmKit alarm currently in the .alerting
    /// state. Used by stopRingingInternal so the user pressing Stop in-app
    /// nukes any zombie alarms created by previous respawn rounds even if
    /// their handoff mapping was lost. Iterates a few times with short
    /// delays to catch any alarm that respawns between passes.
    func nukeAllAlertingAlarmKitSurfaces() {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            // Three passes: covers the natural race where a zombie respawn
            // fires between our query and our cancel.
            for pass in 0..<3 {
                do {
                    let alarms = try AlarmManager.shared.alarms
                    var killed = 0
                    for alarm in alarms where alarm.state == .alerting {
                        try? AlarmManager.shared.stop(id: alarm.id)
                        try? AlarmManager.shared.cancel(id: alarm.id)
                        killed += 1
                    }
                    if pass == 0 || killed > 0 {
                        print("[NotificationManager] 🛑 nukeAllAlertingAlarmKitSurfaces pass \(pass): killed \(killed)")
                    }
                    if killed == 0 && pass > 0 { break }
                } catch {
                    print("[NotificationManager] nukeAllAlertingAlarmKitSurfaces fetch failed: \(error)")
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
#endif
    }

    func clearCompletedAlarmFlow(alarmId: String) {
        completedAlarmFlowIds.remove(alarmId)
        completedAlarmFlowAt.removeValue(forKey: alarmId)
        if alarmFlowPhaseBySource[alarmId] == .completed {
            alarmFlowPhaseBySource[alarmId] = .idle
        }
    }

    private func setAlarmFlowPhase(_ phase: AlarmFlowPhase, for sourceAlarmId: String) {
        alarmFlowPhaseBySource[sourceAlarmId] = phase
    }

    private func alarmFlowPhase(for sourceAlarmId: String) -> AlarmFlowPhase {
        alarmFlowPhaseBySource[sourceAlarmId] ?? .idle
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
                if UIApplication.shared.applicationState != .active {
                    break
                }
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

    private static func customUIHandoffFallbackIdentifier(alarmId: String) -> String {
        "\(CustomUIHandoffFallback.identifierPrefix)\(alarmId)"
    }

    private func resolvedAlarmLabel(sourceAlarmId: String, alarmName: String?) -> String {
        let trimmedProvided = alarmName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedProvided.isEmpty {
            return trimmedProvided
        }
        if let uuid = UUID(uuidString: sourceAlarmId),
           let stored = (alarmStore ?? AlarmStore.shared).alarm(by: uuid)?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        return "Alarm"
    }

    private func makeAlarmKitUnlockPromptContent(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let isUnlockedState = UIApplication.shared.isProtectedDataAvailable
        let copy = alarmKitUnlockPromptCopy(isUnlockedState: isUnlockedState)
        content.title = copy.title
        content.subtitle = ""
        content.body = copy.body
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
        if isUnlockedState {
            print("[UnlockedAlarmNotification] title=\"\(content.title)\" body=\"\(content.body)\"")
        }
        return content
    }

    private func alarmKitUnlockPromptCopy(isUnlockedState: Bool) -> (title: String, body: String) {
        if isUnlockedState {
            // iOS controls notification typography for standard banners; we
            // cannot directly increase font size. We increase prominence by
            // keeping the key message concise in the title with a leading emoji.
            return ("⏰ Alarm is ringing", "Tap to stop alarm")
        }
        return ("Alarm is ringing — unlock your phone to Stop or Snooze", "")
    }

    private func shouldContinueAlarmKitUnlockPromptLoop(for sourceAlarmId: String) -> Bool {
        if completedAlarmFlowIds.contains(sourceAlarmId) { return false }
        if alarmFlowPhase(for: sourceAlarmId) == .completed { return false }
        let phase = alarmFlowPhase(for: sourceAlarmId)
        if phase == .ringingLocked || phase == .ringingUnlocked { return true }
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

        if action == AppNotificationAction.alarmPostSlideStopAlarm ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmPostSlideControl {
            print("[PostSlideNotification] action received \(AppNotificationAction.alarmPostSlideStopAlarm)")
            print("[PostSlideNotification] routing to existing custom alarm UI handoff")
            handleAlarmAuthenticationPromptAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmStopCardAction ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmStopCard {
            let userInfo = response.notification.request.content.userInfo
            let sourceAlarmId = (userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String)
                ?? (userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String)
                ?? response.notification.request.identifier
            handleNotificationStopAction(alarmId: sourceAlarmId)
        } else if action == AppNotificationAction.alarmAuthPromptUnlock ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmAuthPrompt {
            handleAlarmAuthenticationPromptAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmKitUnlockDismiss ||
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

    func handleNotificationStopAction(alarmId: String) {
        print("[NotificationManager] Stop action from notification card — alarmId: \(alarmId)")
        guard AlarmAudioStateController.shared.phase != .stopped else { return }

        // Prefer existing stop flow first.
        if ringCoordinator?.isRinging == true {
            ringCoordinator?.stopRinging()
        } else {
            AlarmContinuousAudioEngine.shared.stop(reason: "notification-stop-action")
            AlarmAudioStateController.shared.recordStopped(reason: "notification-stop-action")
        }

        // Defensive cleanup for any active AlarmKit surfaces.
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                do {
                    let alarms = try AlarmManager.shared.alarms
                    for alarm in alarms where alarm.state == .alerting {
                        try? AlarmManager.shared.cancel(id: alarm.id)
                    }
                } catch {
                    print("[NotificationManager] Stop action cleanup failed: \(error)")
                }
            }
        }
#endif
    }

    private func handle(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        if let alarmId = userInfo["alarmId"] as? String {
            // If the user already explicitly dismissed via Stop/Snooze, don't
            // re-start the ring just because a stale fallback notification got
            // tapped from the tray. Also prune any leftover fallback chain.
            if isAlarmFlowSuppressed(alarmId) {
                cancelAlarmRingingFallbackChain(alarmId: alarmId)
                return
            }
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
        } else if let sourceAlarmId = userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String {
            let surfaceAlarmId = userInfo[AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey] as? String
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

    private func handleAlarmAuthenticationPromptAction(notification: UNNotification) {
        guard let sourceAlarmId = notification.request.content.userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String else {
            return
        }
        let surfaceAlarmId = notification.request.content.userInfo[AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey] as? String
        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
    }

    private func requestCustomUIHandoff(sourceAlarmId: String, surfaceAlarmId: String? = nil) {
        logAlarmTrace(
            event: "request-custom-ui-handoff",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId
        )
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

    /// Respawn AlarmKit's alerting surface — but ONLY if there isn't one
    /// already alerting AND we haven't respawned recently (3-second throttle).
    /// This is the one place we programmatically respawn now; called from
    /// scenePhase inactive when the user re-locks during an active ring.
    /// Prevents the multiple-banner cascade by being strictly one-shot.
    func ensureAlarmKitSurfaceForLockedLoopIfNeeded(sourceAlarmId: String, force: Bool = false) {
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Locked loop surface suppressed — app is active")
            return
        }
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() else {
            print("[NotificationManager] Locked loop surface suppressed — phase \(AlarmAudioStateController.shared.phase.rawValue) not eligible for AlarmKit respawn")
            return
        }
        let phase = AlarmAudioStateController.shared.phase
        if phase == .appEnginePrimary || phase == .appEngineFadingIn {
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                let outputVolume = AVAudioSession.sharedInstance().outputVolume
                print("[NotificationManager] Locked loop surface suppressed — phase=\(phase.rawValue), engine playing, outputVolume=\(String(format: "%.2f", outputVolume))")
                return
            }
            print("[NotificationManager] Locked loop surface recovery allowed — phase=\(phase.rawValue) but engine not playing")
            AlarmAudioStateController.shared.recordFallback(reason: "locked-loop-engine-not-playing-recovery")
        }
        logAlarmTrace(
            event: "ensure-locked-loop-surface-if-needed-entry",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID,
            extra: "force=\(force)"
        )
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        let lockedLoopOutputVolume = AVAudioSession.sharedInstance().outputVolume
        if AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying() &&
            lockedLoopOutputVolume > 0.01 {
            print("[Respawn] Engine active and healthy — skipping AlarmKit respawn")
            scheduleAlarmAuthenticationPrompt(
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? sourceAlarmId,
                alarmName: (ringCoordinator?.activeAlarm?.name)
            )
            return
        } else if lockedLoopOutputVolume <= 0.01 {
            print("[Respawn] Engine playing but muted outputVolume=\(String(format: "%.2f", lockedLoopOutputVolume)) — continuing with AlarmKit respawn recovery")
        }
        // Strict 3-second throttle. The previous "force=true bypasses throttle"
        // was the source of the multiple-banner cascade — every scene
        // transition fired a new respawn within milliseconds.
        let now = Date()
        if let last = lastLockedSurfaceEnsureAt[sourceAlarmId],
           now.timeIntervalSince(last) < 3.0 {
            return
        }
        if lockedSurfaceEnsureInFlight.contains(sourceAlarmId) { return }
        lastLockedSurfaceEnsureAt[sourceAlarmId] = now
        lockedSurfaceEnsureInFlight.insert(sourceAlarmId)

        Task { @MainActor in
            defer { lockedSurfaceEnsureInFlight.remove(sourceAlarmId) }
            // Only respawn if NO AlarmKit alarm is currently alerting for our
            // source. If one is alerting, leave it alone — that's the surface
            // the user is supposed to interact with.
            do {
                let alarms = try AlarmManager.shared.alarms
                let alreadyAlerting = alarms.contains { alarm in
                    let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alarm.id.uuidString)
                    return (mappedSource == sourceAlarmId || alarm.id.uuidString == sourceAlarmId) && alarm.state == .alerting
                }
                if alreadyAlerting { return }
            } catch {
                print("[NotificationManager] inspect-before-respawn failed: \(error)")
            }

            let surfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID ?? sourceAlarmId
            let intent = StopAlarmIntent(
                alarmID: surfaceAlarmId,
                originalAlarmID: sourceAlarmId,
                suppressUnlockPrompt: true
            )
            do {
                _ = try await intent.perform()
                self.setAlarmFlowPhase(.ringingLocked, for: sourceAlarmId)
                print("[NotificationManager] 🔁 Single-shot respawn (lock transition) for \(sourceAlarmId)")
            } catch {
                print("[NotificationManager] Lock-transition respawn failed: \(error)")
            }
        }
#endif
        _ = force
    }

    func scheduleHardwareButtonRespawnIfNeeded(
        sourceAlarmId: String,
        alarmName: String?,
        reason: String
    ) {
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Side button respawn suppressed — app is active, engine primary")
            return
        }
        let phase = AlarmAudioStateController.shared.phase
        if phase == .appEnginePrimary || phase == .appEngineFadingIn {
            let outputVolume = AVAudioSession.sharedInstance().outputVolume
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() && outputVolume > 0.01 {
                print("[NotificationManager] Side button respawn suppressed — phase=\(phase.rawValue), engine playing, outputVolume=\(String(format: "%.2f", outputVolume))")
                return
            }
            print("[NotificationManager] Side button respawn recovery allowed — phase=\(phase.rawValue), enginePlaying=\(AlarmContinuousAudioEngine.shared.confirmStillPlaying()) outputVolume=\(String(format: "%.2f", outputVolume))")
            AlarmAudioStateController.shared.recordFallback(reason: "hardware-button-engine-not-playing-recovery")
        } else if !AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() {
            print("[NotificationManager] Side button respawn suppressed — phase \(phase.rawValue) not eligible for AlarmKit respawn")
            return
        }
        logAlarmTrace(
            event: "schedule-hardware-button-respawn-if-needed-entry",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID,
            extra: "reason=\(reason) alarmName=\(alarmName ?? "nil")"
        )
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        let now = Date()
        if let last = lastRespawnScheduledAt[sourceAlarmId],
           now.timeIntervalSince(last) < 3.0 {
            return
        }
        lastRespawnScheduledAt[sourceAlarmId] = now

        scheduleAlarmAuthenticationPrompt(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? sourceAlarmId,
            alarmName: alarmName
        )

        Task { @MainActor in
            guard let sourceUUID = UUID(uuidString: sourceAlarmId) else { return }
            do {
                let alarms = try AlarmManager.shared.alarms
                for alarm in alarms where alarm.state == .alerting {
                    let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alarm.id.uuidString)
                    guard mappedSource == sourceAlarmId || alarm.id.uuidString == sourceAlarmId else { continue }
                    try? AlarmManager.shared.stop(id: alarm.id)
                    try? AlarmManager.shared.cancel(id: alarm.id)
                }
            } catch {
                print("[NotificationManager] inspect-before-hardware-respawn failed: \(error)")
            }

            let helper = AlarmSchedulerIOS26AlarmKit()
            let sourceAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID)
            let title = resolvedAlarmLabel(sourceAlarmId: sourceAlarmId, alarmName: alarmName)
            let delayLadder: [TimeInterval] = [2.0, 2.2, 2.4, 2.6]
            let snoozeInterval = sourceAlarm.flatMap { helper.resolvedSnoozeInterval(for: $0) }
            let snoozeEnabled = snoozeInterval != nil

            for delay in delayLadder {
                let newUUID = UUID()
                do {
                    _ = try await helper.scheduleWithFallbackSound(
                        manager: AlarmManager.shared,
                        id: newUUID,
                        originalAlarmID: sourceUUID,
                        title: title,
                        schedule: .fixed(Date().addingTimeInterval(delay)),
                        snoozeEnabled: snoozeEnabled,
                        snoozeInterval: snoozeInterval,
                        preferredSoundName: sourceAlarm?.soundName
                    )
                    AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: newUUID)
                    print("[NotificationManager] \(reason) — respawning AlarmKit in 2s (source=\(sourceAlarmId), delay=\(delay))")
                    return
                } catch {
                    print("[NotificationManager] Hardware respawn attempt +\(delay)s failed for \(sourceAlarmId): \(error)")
                }
            }
        }
#endif
    }

    func enforceLockedRingingState(sourceAlarmId: String, surfaceAlarmId: String? = nil) {
        logAlarmTrace(
            event: "enforce-locked-ringing-state-entry",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId
        )
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        setAlarmFlowPhase(.ringingLocked, for: sourceAlarmId)
        AlarmBackgroundAudioBridge.shared.reinforceLockedLoopNow(
            surfaceAlarmId: surfaceAlarmId,
            sourceAlarmId: sourceAlarmId,
            reason: "scene-transition-lock"
        )
#endif
    }

#if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func processAlarmKitAlarmUpdate(_ alarm: AlarmKit.Alarm) async {
        let surfaceAlarmId = alarm.id.uuidString
        let sourceAlarmId = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)

        if alarm.state == .alerting {
            cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
            await processAlarmKitAlertingAlarm(alarm)
            return
        }

        // Alarm transitioned out of .alerting. We do NOT programmatically
        // respawn AlarmKit — earlier rounds of that approach created multiple
        // overlapping AlarmKit surfaces (each with its own fallback sound when
        // the user's selected sound couldn't be staged as CAF) and the user
        // saw a chaotic stack of banners with mismatched audio.
        //
        // If the user explicitly pressed Stop/Snooze in-app, suppression is
        // active and we just clean up. Otherwise we let AlarmKit's natural
        // alerting state stand — sound continuity is provided by the bridge's
        // AVAudioPlayer (.playback category bypasses silent mode and uses the
        // user's actual selected sound).
        cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
        _ = sourceAlarmId
        _ = surfaceAlarmId
    }

    @available(iOS 26.0, *)
    private func scheduleLockedSurfaceReassert(
        sourceAlarmId: String,
        surfaceAlarmId: String,
        stateDescription: String
    ) {
        // INTENTIONALLY A NO-OP. Programmatic AlarmKit respawn was creating
        // a cascade of overlapping alarm surfaces. AlarmKit's natural state
        // stands; bridge audio is the continuity mechanism instead.
        _ = sourceAlarmId
        _ = surfaceAlarmId
        _ = stateDescription
    }

    private func cancelPendingLockedSurfaceReassert(for sourceAlarmId: String) {
        pendingLockedSurfaceReassertWorkItems[sourceAlarmId]?.cancel()
        pendingLockedSurfaceReassertWorkItems.removeValue(forKey: sourceAlarmId)
    }

    @available(iOS 26.0, *)
    private func processAlarmKitAlertingAlarm(_ alarm: AlarmKit.Alarm) async {
        let surfaceAlarmId = alarm.id.uuidString
        let sourceAlarmId = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        let phase = AlarmAudioStateController.shared.phase
        let appIsActive = UIApplication.shared.applicationState == .active
        if appIsActive && (phase == .appEnginePrimary || phase == .appEngineFadingIn) {
            print("[NotificationManager] AlarmKit surface auto-dismissed — app active phase=\(phase.rawValue) surface=\(surfaceAlarmId)")
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
            return
        }
        logAlarmTrace(
            event: "process-alerting-entry",
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId
        )
        let outputVolume = AVAudioSession.sharedInstance().outputVolume
        let engineAppearsHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.cachedIsHealthy &&
            outputVolume > 0.01
        let engineLiveHealthy = engineAppearsHealthy &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if engineAppearsHealthy && !engineLiveHealthy {
            print("[AlarmKit] Engine cached healthy but not playing live — continuing with recovery start path")
        } else if outputVolume <= 0.01 {
            print("[AlarmKit] Engine path muted (outputVolume=\(String(format: "%.2f", outputVolume))) — allowing AlarmKit recovery path")
        }
        if engineLiveHealthy {
            logAlarmTrace(
                event: "process-alerting-engine-live-healthy",
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: surfaceAlarmId,
                extra: "keeping-surface-alive=true"
            )
            // Keep AlarmKit surface alive when engine is already healthy.
            // Aggressive stop/cancel here can cut audio ownership at the wrong time.
            AlarmBackgroundAudioBridge.shared.start(
                surfaceAlarmId: surfaceAlarmId,
                sourceAlarmId: sourceAlarmId
            )
            if UIApplication.shared.applicationState != .active {
                startAlarmKitUnlockPromptLoop(
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId,
                    alarmName: nil
                )
            }
            return
        }
        let sourceAlarm: Alarm? = {
            guard let uuid = UUID(uuidString: sourceAlarmId) else { return nil }
            return (alarmStore ?? AlarmStore.shared).alarm(by: uuid)
        }()
        print("[NotificationManager] 🔔 AlarmKit alarm alerting: surface=\(surfaceAlarmId), source=\(sourceAlarmId)")
        setAlarmFlowPhase(
            UIApplication.shared.applicationState == .active ? .ringingUnlocked : .ringingLocked,
            for: sourceAlarmId
        )

        // If user already pressed Stop/Snooze, ignore stale or in-flight
        // AlarmKit callbacks and tear down the surface instead of resurrecting UI.
        if isAlarmFlowSuppressed(sourceAlarmId) || isAlarmFlowSuppressed(surfaceAlarmId) {
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
            setAlarmFlowPhase(.completed, for: sourceAlarmId)
            return
        }

        if let sourceAlarm {
            print("[NotificationManager] AlarmKit alerting — deferring engine audible start via state machine. sound=\(sourceAlarm.soundName)")
            AlarmAudioStateController.shared.handleAlarmKitAlerting(
                alarmId: sourceAlarm.id.uuidString,
                soundName: sourceAlarm.soundName,
                reason: "alarmkit-alerting"
            )
        } else {
            print("[AlarmKit→Engine] Source alarm model missing for \(sourceAlarmId); engine start skipped")
        }

        // Always arm bridge audio on alerting updates so quick foreground/
        // background churn never leaves the alarm without an active audio owner.
        AlarmBackgroundAudioBridge.shared.start(
            surfaceAlarmId: surfaceAlarmId,
            sourceAlarmId: sourceAlarmId
        )

        // Dismiss the PREVIOUSLY-fired alarm for this source so banners
        // don't stack. Only one AlarmKit alarm should be alerting at a time
        // for any given source — the most recent backup or the original.
        if let priorAlertingId = lastFiredAlarmIdsBySource[sourceAlarmId],
           priorAlertingId != alarm.id {
            try? AlarmManager.shared.stop(id: priorAlertingId)
            try? AlarmManager.shared.cancel(id: priorAlertingId)
            print("[NotificationManager] 🧹 Dismissed prior alerting alarm \(priorAlertingId.uuidString) to prevent banner stacking")
        }
        lastFiredAlarmIdsBySource[sourceAlarmId] = alarm.id

        // Mark the backup slot empty if this was a backup that fired.
        if let (chainSource, _) = isBackupAlarmKitAlarm(alarm.id) {
            pendingBackupAlarmIds.removeValue(forKey: chainSource)
        }

        // BACKUP ALARM CHAIN: only fire backups when app is NOT in foreground.
        // In foreground, the bridge audio is reliable and we don't want
        // AlarmKit banners stacking up on the user's screen. When the user
        // backgrounds/locks, the scenePhase handler kicks off the chain.
        if UIApplication.shared.applicationState != .active {
            await ensureBackupAlarmKitChain(sourceAlarmId: sourceAlarmId)
        } else {
            // Foreground: dismiss this alarm immediately so no banner shows
            // over the in-app UI. Bridge keeps audio going.
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
            lastFiredAlarmIdsBySource.removeValue(forKey: sourceAlarmId)
            print("[NotificationManager] 🧹 Foreground — dismissed alerting alarm \(alarm.id.uuidString) to avoid banner")
        }

        if UIApplication.shared.applicationState == .active {
            setAlarmFlowPhase(.ringingUnlocked, for: sourceAlarmId)
            // App is already in the foreground — show the
            // in-app ringing UI directly and dismiss the
            // system AlarmKit surface.
            let didStartCustomRing = startAlarmImmediatelyIfPossible(alarmId: sourceAlarmId)
            if didStartCustomRing {
                logAlarmTrace(
                    event: "process-alerting-foreground-custom-ring-started",
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId,
                    extra: "alarmkit-surface-preserved=true"
                )
                scheduleAlarmKitUnlockPrompt(
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId
                )
                // INTENTIONALLY do NOT dismiss the AlarmKit surface here.
                //
                // Strategy (matches Alarmy): AlarmKit stays alerting throughout
                // the user's session. Its slide-to-stop is the persistent
                // system-level banner. Audio bypasses silent mode reliably
                // because it's AlarmKit's audio (we don't have critical-alert
                // entitlement so our own notifications can't bypass silent
                // mode). When the user finally presses Stop/Snooze in the
                // in-app UI, `stopRingingInternal` dismisses AlarmKit.
                //
                // If the user presses slide-to-stop on AlarmKit's lock-screen
                // surface, our StopAlarmIntent zombie-respawns the alarm —
                // forcing the user to fully unlock and dismiss in-app.
                _ = surfaceAlarmId  // referenced only for log clarity
            } else {
                logAlarmTrace(
                    event: "process-alerting-foreground-custom-ring-failed",
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId
                )
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
            setAlarmFlowPhase(.ringingLocked, for: sourceAlarmId)
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
                self.alarmStartRetryStates.removeValue(forKey: alarmId)
                self.cancelCustomUIHandoffFallbackNotification(sourceAlarmId: alarmId)
            } else {
                let now = Date()
                var retryState = self.alarmStartRetryStates[alarmId]
                    ?? AlarmStartRetryState(firstAttemptAt: now, attempts: 0)
                if now.timeIntervalSince(retryState.firstAttemptAt) >= 5.0 {
                    self.alarmStartRetryStates.removeValue(forKey: alarmId)
                    self.pendingAlarmStarts.remove(alarmId)
                    self.persistPendingAlarmStarts()
                    self.scheduleCustomUIHandoffFallbackNotification(sourceAlarmId: alarmId)
                    return
                }
                retryState.attempts += 1
                self.alarmStartRetryStates[alarmId] = retryState

                self.pendingAlarmStarts.insert(alarmId)
                self.persistPendingAlarmStarts()
                let retryDelay: TimeInterval
                switch retryState.attempts {
                case 1:
                    retryDelay = 0.1
                case 2:
                    retryDelay = 0.2
                case 3:
                    retryDelay = 0.3
                default:
                    retryDelay = 0.6
                }
                let retryAlarmId = alarmId
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
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
            alarmStartRetryStates.removeValue(forKey: alarmId)
            cancelCustomUIHandoffFallbackNotification(sourceAlarmId: alarmId)
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
    static let alarmAuthPrompt = "ALARM_AUTH_PROMPT"
    static let alarmPostSlideControl = "ALARM_POST_SLIDE_CONTROL"
    // Legacy category retained for backward compatibility with already-delivered notifications.
    static let alarmStopCard = "ALARM_STOP_CATEGORY"
    static let planReminder = "PLAN_REMINDER"
    static let focusSession = "FOCUS_SESSION"
    static let countdown = "COUNTDOWN"
}

enum AppNotificationAction {
    static let alarmSnooze = "ALARM_SNOOZE"
    static let alarmStop = "ALARM_STOP"
    static let alarmPostSlideStopAlarm = "ALARM_POST_SLIDE_STOP_ALARM"
    // Legacy action retained for backward compatibility with already-delivered notifications.
    static let alarmStopCardAction = "ALARM_STOP_ACTION"
    static let alarmKitUnlockDismiss = "ALARMKIT_UNLOCK_DISMISS"
    static let alarmAuthPromptUnlock = "ALARM_AUTH_PROMPT_UNLOCK"
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
