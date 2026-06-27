import Foundation
import Combine
import UserNotifications
import UIKit
import AVFoundation

#if canImport(AlarmKit)
import AlarmKit
#endif

enum NotificationPermissionResult {
    case granted
    case denied
    case notDetermined
}

/// Tags a notification's intent so the tap handler can decide whether it is
/// allowed to start alarm audio. Informational/reopen warnings (scheduled
/// BEFORE the alarm is due) must only open the app — never ring.
enum AlarmNotificationKind {
    static let userInfoKey = "alarmoNotificationKind"
    /// Open the app only. Never starts audio or the ringing UI.
    static let openAppOnly = "open_app_only"
    /// A real "alarm is due/ringing" notification — allowed to start audio.
    static let alarmDue = "alarm_due"
    /// A recovery prompt for an alarm that is already ringing — allowed to ring.
    static let alarmRecovery = "alarm_recovery"
}

/// Classifies app lifecycle events so we can distinguish normal lock/background
/// (no warning) from switcher force-quit risk (keep the pre-armed fuse).
enum AlarmLifecycleState: String {
    case normalLock = "NORMAL_LOCK"
    /// Side-button lock / protected data unavailable — never schedule close warnings.
    case normalDeviceLock = "NORMAL_DEVICE_LOCK"
    case normalBackground = "NORMAL_BACKGROUND"
    case futureAlarmOnly = "FUTURE_ALARM_ONLY"
    case activeRingingBackground = "ACTIVE_RINGING_BACKGROUND"
    /// App switcher / inactive while phone is still unlocked — force-quit fuse stays armed.
    case staleAppRisk = "USER_FORCE_QUIT_RISK"
}

/// Persists leave/active markers so the next cold start can infer whether the
/// previous session ended while backgrounded (force-quit, memory kill, or crash).
private enum AlarmAppLifecycleSession {
    static let wasBackgroundedKey = "alarmo.lifecycle.wasBackgroundedWithoutCleanExit"
    static let lastBackgroundAtKey = "alarmo.lifecycle.lastBackgroundAt"
    static let lastActiveAtKey = "alarmo.lifecycle.lastActiveAt"
    static let lastLeaveStateKey = "alarmo.lifecycle.lastLeaveState"
    static let lastKnownLifecycleReasonKey = "alarmo.lifecycle.lastKnownLifecycleReason"
    static let futureAlarmExistsAtBackgroundKey = "alarmo.lifecycle.futureAlarmExistsAtBackground"
    static let deviceLockSignalAtKey = "alarmo.lifecycle.deviceLockSignalAt"
    /// Window after protectedDataWillBecomeUnavailable to classify leave as device lock.
    static let deviceLockAssociationWindow: TimeInterval = 3.0

    static func markCleanForegroundEntry(reason: String) {
        UserDefaults.standard.set(false, forKey: wasBackgroundedKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastActiveAtKey)
        clearDeviceLockSignal()
        print("[Lifecycle] state=APP_ACTIVE reason=\(reason)")
    }

    static func markProtectedDataWillBecomeUnavailable() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: deviceLockSignalAtKey)
        print("[Lifecycle] protectedDataWillBecomeUnavailable likelyDeviceLock=true")
    }

    static func markProtectedDataDidBecomeAvailable() {
        clearDeviceLockSignal()
        print("[Lifecycle] protectedDataDidBecomeAvailable")
    }

    static func clearDeviceLockSignal() {
        UserDefaults.standard.removeObject(forKey: deviceLockSignalAtKey)
    }

    static func isDeviceLockLikely() -> Bool {
        if !UIApplication.shared.isProtectedDataAvailable { return true }
        let ts = UserDefaults.standard.double(forKey: deviceLockSignalAtKey)
        guard ts > 0 else { return false }
        return Date().timeIntervalSince(Date(timeIntervalSince1970: ts)) <= deviceLockAssociationWindow
    }

    static func recordNormalBackgroundSnapshot(
        alarms: [Alarm],
        reason: String,
        lifecycle: AlarmLifecycleState
    ) {
        UserDefaults.standard.set(reason, forKey: lastKnownLifecycleReasonKey)
        let hasFuture = alarms.contains { alarm in
            guard alarm.enabled else { return false }
            guard let fire = AlarmStore.nextFireDate(for: alarm, from: Date()) else { return false }
            return fire > Date()
        }
        UserDefaults.standard.set(hasFuture, forKey: futureAlarmExistsAtBackgroundKey)
        if lifecycle == .normalBackground {
            UserDefaults.standard.set(true, forKey: wasBackgroundedKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackgroundAtKey)
        }
    }

    static func recordLeave(state: AlarmLifecycleState, reason: String) {
        UserDefaults.standard.set(state.rawValue, forKey: lastLeaveStateKey)
        UserDefaults.standard.set(reason, forKey: lastKnownLifecycleReasonKey)
        switch state {
        case .normalBackground:
            UserDefaults.standard.set(true, forKey: wasBackgroundedKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastBackgroundAtKey)
            print("[LifecycleClassifier] state=NORMAL_BACKGROUND reason=\(reason)")
            print("[Lifecycle] state=APP_BACKGROUNDED reason=\(reason)")
            print("[ForceQuitWarning] no immediate warning for normal background")
        case .normalDeviceLock, .normalLock:
            print("[LifecycleClassifier] state=NORMAL_DEVICE_LOCK reason=\(reason)")
            print("[Lifecycle] state=APP_INACTIVE reason=\(reason) deviceLocked=true")
            print("[ForceQuitWarning] skipped because device lock detected")
        case .staleAppRisk:
            print("[Lifecycle] state=USER_FORCE_QUIT_RISK reason=\(reason) policy=keep-standby-fuse")
        case .activeRingingBackground:
            print("[Lifecycle] state=ACTIVE_RINGING_BACKGROUND reason=\(reason) policy=cancel-leave-warnings")
        case .futureAlarmOnly:
            break
        }
    }

    static func logColdStartInferenceIfNeeded() {
        guard UserDefaults.standard.bool(forKey: wasBackgroundedKey) else { return }
        let lastLeave = UserDefaults.standard.string(forKey: lastLeaveStateKey) ?? "unknown"
        let lastBgTs = UserDefaults.standard.double(forKey: lastBackgroundAtKey)
        let lastBgLabel: String = {
            guard lastBgTs > 0 else { return "nil" }
            return Date(timeIntervalSince1970: lastBgTs).description
        }()
        print("[Lifecycle] state=APP_TERMINATED_OR_COLD_START previousLeave=\(lastLeave) lastBackgroundAt=\(lastBgLabel)")
        print("[Lifecycle] note=previous session ended after backgrounding; may be force-quit, memory pressure, or crash")
    }
}

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
    /// "Alarm is still ringing — Unlock to open Alarmo" recovery banner.
    /// Disabled: confusing when the app is already open or the phone is unlocked.
    private let alarmRecoveryOpenAppNotificationEnabled = false

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
    /// Guards `startAlarmKitObservation()` against double-subscription — it can now
    /// be started at cold launch (AppDelegate) AND from `configure` (onAppear).
    private var alarmKitObservationStarted = false
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
    private var uiShellEnsureInFlight: Set<String> = []
    private var lastUIShellEnsureAt: [String: Date] = [:]
    private var lastAppEngineRingingControlAt: [String: Date] = [:]
    private var appEngineRingingControlInFlight: Set<String> = []
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
    /// Per-surface throttle for AlarmKit `.alerting` callbacks. AlarmKit can deliver
    /// repeated alerting updates for the same surface; reprocessing the full recovery
    /// setup each time causes the surface-churn / screen-blink storm.
    private var lastProcessedAlertingSurfaceAt: [String: Date] = [:]
    private static let alertingDedupeWindow: TimeInterval = 1.0
    /// Cooldown between scheduling NEW AlarmKit recovery surfaces (not notification prompts).
    private static let alarmKitRecoverySurfaceCooldown: TimeInterval = 20.0
    private static let recoveryNotificationCooldown: TimeInterval = 20.0
    /// Window during which a delivered custom recovery notification is considered present.
    private static let recoveryNotificationActiveWindow: TimeInterval = 600.0
    private var alarmKitRecoverySurfaceCountBySource: [String: Int] = [:]
    private var lastAlarmKitRecoverySurfaceAt: [String: Date] = [:]
    private var lastRecoveryNotificationScheduledAt: [String: Date] = [:]
    private var lastBasicSoundWarningDeliveredAtBySource: [String: Date] = [:]
    private let basicSoundWarningMinimumInterval: TimeInterval = 20
    private var lastArmedAlarmCloseWarningSourceId: String?
    private var appEngineVolumeResetFailedObserver: NSObjectProtocol?
    /// Controlled AlarmKit re-alert loop after Slide-to-Stop while locked.
    private var realertLoopWorkItems: [String: DispatchWorkItem] = [:]
    private var realertLoopTickCountBySource: [String: Int] = [:]
    private var realertLoopScheduleInFlight: Set<String> = []
    private static let realertLoopFirstDelay: TimeInterval = 1.5
    private static let realertLoopSecondDelay: TimeInterval = 5.0
    private static let realertLoopSubsequentDelay: TimeInterval = 10.0
    private static let realertLoopMinScheduleInterval: TimeInterval = 5.0
    /// System-owned first strike when AlarmKit ringer sound is gone (slide-to-stop, etc.).
    private static let respawnWhenSoundGonePreArmDelay: TimeInterval = 1.0
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
    private var authHandoffTimeoutWorkItems: [String: DispatchWorkItem] = [:]
    private var hardwareSuppressionCheckWorkItems: [String: DispatchWorkItem] = [:]
    private var engineAudibleVerificationWorkItems: [String: DispatchWorkItem] = [:]
    private var lastAuthRecoveryScheduledAt: [String: Date] = [:]
    private var pendingAuthRecoverySurfaceIds: [String: UUID] = [:]
    /// Counts side-button / lock suppressions per source. After the first
    /// suppression, subsequent recoveries prefer the no-UI engine path only.
    private var hardwareSuppressionCountBySource: [String: Int] = [:]
    /// Explicit AlarmKit-audio suppression signals. Generic lifecycle/dead-audio
    /// checks must not promote AppEngine unless one of these signals was seen.
    private var explicitAlarmKitSuppressionSourceIds: Set<String> = []
    /// Re-checks every 2s while locked; forces a fresh audible AlarmKit surface
    /// if nothing is audibly playing for 5s (side-button / slide-to-stop / auth cancel).
    private var alarmKitAudibleWatchdogWorkItems: [String: DispatchWorkItem] = [:]
    private var lastConfirmedAudibleAtBySource: [String: Date] = [:]
    private var alarmKitWatchdogStartedAtBySource: [String: Date] = [:]
    /// Consecutive failed locked no-UI engine attempts per source. Reset when
    /// the engine is confirmed audible. Used to escalate to an audible AlarmKit
    /// re-alert if the engine cannot become audible (Phase 4 + 5: alarm must
    /// never stay silent).
    private var lockedNoUIFailureCountBySource: [String: Int] = [:]
    /// True when the watchdog has already escalated to an audible AlarmKit
    /// re-alert in this session (so we don't spam reschedules every tick).
    /// Cleared when the engine is confirmed audible again or final stop fires.
    private var lockedNoUIEscalatedBySource: Set<String> = []
    private let authHandoffTimeoutInterval: TimeInterval = 5.0
    private let authRecoveryMinimumInterval: TimeInterval = 10.0
    private let hardwareRecoveryMinimumInterval: TimeInterval = 10.0
    private let alarmKitAudibleWatchdogInterval: TimeInterval = 2.0
    private let alarmKitAudibleMaxSilence: TimeInterval = 5.0
    /// Number of consecutive locked-no-UI engine failures that triggers the
    /// audible AlarmKit escalation (alongside the silence timeout).
    private let lockedNoUIEscalationFailureThreshold: Int = 1

    // MARK: - Pre-armed AlarmKit recovery state
    //
    // The "pre-armed" recovery is a system-owned audible AlarmKit alarm
    // scheduled BEFORE the app is at risk of being suspended (e.g. immediately
    // when the side button is pressed or slide-to-stop is invoked). Because the
    // system schedules the alarm, it fires even if iOS suspends our process.
    //
    // It is cancelled ONLY after the app proves the engine is audible OR the
    // user issues a real Stop/Snooze in the in-app full-screen UI.
    private struct PreArmedRecovery {
        let sourceAlarmId: String
        let runId: String
        let surfaceUUID: UUID
        let reason: String
        let fireDate: Date
        let scheduledAt: Date
    }
    private var preArmedRecoveryBySource: [String: PreArmedRecovery] = [:]
    private var preArmedRecoveryInFlight: Set<String> = []
    /// Sources where AlarmKit is intentionally dismissed to schedule audible recovery.
    private var replacingWithAudibleAlarmKitRecoverySourceIds: Set<String> = []
    private static let preArmedRecoveryDefaultDelay: TimeInterval = 4.0
    private static let preArmedRecoverySlideToStopDelay: TimeInterval = 8.0
    private static let preArmedRecoveryDuplicateWindow: TimeInterval = 1.5

    private func currentRunId(for sourceAlarmId: String) -> String {
        if AlarmAudioStateController.shared.currentAlarmId == sourceAlarmId,
           let runId = AlarmAudioStateController.shared.currentAlarmRunId {
            return runId.uuidString
        }
        // Fall back to a stable per-source key so cancellation paths still work
        // when the audio state controller has not yet observed the session.
        return "session-\(sourceAlarmId)"
    }
    private static let authRecoveryDelays: [TimeInterval] = [1.0, 1.2, 1.4]

    private enum RecoveryOpenAppNotification {
        static let identifierPrefix = "alarmo.recovery.openApp."
        static let userInfoSourceAlarmIDKey = "recoveryOpenAppSourceAlarmId"
        static let userInfoRunIdKey = "recoveryOpenAppRunId"

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    private enum RecoveryPrompt {
        static let identifierPrefix = "alarmo.recoveryPrompt."

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    /// Rich lock-screen notification shown while AppEngine owns alarm audio.
    /// Replaces the silent AlarmKit UI shell — Stop/Snooze actions open the
    /// custom full-screen AlarmRingingView (they do not stop/snooze directly).
    private enum AppEngineRingingControlNotification {
        static let identifierPrefix = "alarmo.appEngineRingingControl."
        static let userInfoSourceAlarmIDKey = "alarmId"
        static let userInfoHandoffOnlyKey = "appEngineRingingHandoffOnly"

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    /// "Open Alarmo again" / basic-sound-only reminders — disabled. Users keep
    /// ForceQuitWarning ("Alarmo was closed") and AppEngine control notifications only.
    private let openAlarmoAgainNotificationsEnabled = false

    private enum ForegroundSoundReminder {
        static let identifierPrefix = "alarmo.foregroundSoundReminder."
        static let userInfoSourceAlarmIDKey = "foregroundSoundReminderSourceAlarmId"
        static let userInfoSurfaceAlarmIDKey = "foregroundSoundReminderSurfaceAlarmId"

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    /// Pre-armed warning that fires ~1.5s ahead unless cancelled on each foreground heartbeat.
    /// Survives swipe-up force-quit when `willResignActive` does not finish scheduling.
    private enum SwipeAwayWarningStandby {
        static let identifierPrefix = "alarmo.swipeAwayWarning."
        static let fireDelay: TimeInterval = 1.5

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    /// Standby warning for an armed (upcoming) alarm. Re-armed while app is foreground
    /// so force-close still surfaces a notification shortly after process death.
    private enum ArmedAlarmCloseWarningStandby {
        static let standbyIdentifierPrefix = "alarmo.armedAlarmCloseWarning.standby."
        static let immediateIdentifierPrefix = "alarmo.armedAlarmCloseWarning.immediate."
        static let fireDelay: TimeInterval = 1.5
        static let userInfoAlarmIDKey = "armedAlarmCloseWarningSourceAlarmId"

        static func standbyIdentifier(for sourceAlarmId: String) -> String {
            "\(standbyIdentifierPrefix)\(sourceAlarmId)"
        }

        static func immediateIdentifier(for sourceAlarmId: String) -> String {
            "\(immediateIdentifierPrefix)\(sourceAlarmId)"
        }

        static func isArmedCloseWarningIdentifier(_ id: String) -> Bool {
            id.hasPrefix(standbyIdentifierPrefix) || id.hasPrefix(immediateIdentifierPrefix)
        }
    }

    /// Pre-armed "Open Alarmo again" warning, scheduled AHEAD of the fire time so
    /// it still fires when the app is force-closed (the app can't run code to
    /// cancel it). While the app is alive and the AppEngine is verified, we cancel
    /// it. This is the Alarmy-style force-close fallback notification.
    private enum ForceClosedWarning {
        static let identifierPrefix = "alarmo.forceClosedWarning."
        static let userInfoSourceAlarmIDKey = "forceClosedWarningSourceAlarmId"
        /// Seconds after the alarm fire time at which the warning surfaces. Small
        /// so a still-alive app has a brief window to cancel it after firing.
        static let postFireDelay: TimeInterval = 8

        static func identifier(for sourceAlarmId: String) -> String {
            "\(identifierPrefix)\(sourceAlarmId)"
        }
    }

    /// "Open Alarmo to keep your full wake-up flow active" warning — scheduled
    /// while the app is still alive (background/inactive) so it survives a
    /// swipe-up force-close. Cancelled the moment the user opens the app again.
    enum AppClosedWarning {
        static let identifier = "alarmo.appClosedWarning"
        /// Delay after true background entry before the absence warning fires.
        /// Survives swipe-up force-close (UNNotificationRequest is system-owned).
        /// Cancelled if the user returns to the app before this elapses.
        /// Secondary absence fuse (primary is armed-close standby at ~1.5s).
        static let scheduleDelay: TimeInterval = 15
        /// Shorter delay used for debug/test scheduling so a force-close can be
        /// exercised quickly.
        static let debugScheduleDelay: TimeInterval = 10
        /// Minimum interval between two "app closed" warnings. Anti-spam for
        /// users who background the app frequently throughout the day.
        static let throttleInterval: TimeInterval = 8 * 60 * 60
        /// Only schedule this warning if the next enabled alarm fires within
        /// this window. Far-future alarms rely on the pre-alarm readiness
        /// reminder instead.
        static let nextAlarmWindow: TimeInterval = 24 * 60 * 60
        static let userInfoNextAlarmIdKey = "appClosedWarningNextAlarmId"
        static let userInfoScheduledAtKey = "appClosedWarningScheduledAt"

        static let lastShownAtDefaultsKey = "alarmo.appClosedWarning.lastShownAt"
        static let lastKnownAppOpenAtDefaultsKey = "alarmo.appClosedWarning.lastKnownAppOpenAt"
        static let debugBypassThrottleDefaultsKey = "debugBypassAppClosedWarningThrottle"
        static let debugLaunchArgument = "--debug-app-closed-warning"
    }

    /// Best-effort warning scheduled from `applicationWillTerminate` only.
    /// Do not rely on this for correctness — iOS may not call willTerminate on
    /// force-quit. AlarmKit remains the reliable wake-up fallback.
    enum ForceQuitWarning {
        static let identifier = "alarmo.forceQuitWarning.bestEffort"
        static let scheduleDelay: TimeInterval = 1.0
        static let userInfoNextAlarmIdKey = "forceQuitWarningNextAlarmId"
        static let educationShownDefaultsKey = "alarmo.forceQuitWarning.educationShown"
    }

    /// Pre-alarm readiness reminders are disabled — a 10–15 min-before-fire
    /// nudge wakes users who are already asleep (e.g. 4:45 AM for a 5 AM alarm).
    private let preAlarmReadinessRemindersEnabled = false

    /// Legacy pre-alarm readiness reminder identifiers (scheduling disabled).
    private enum PreAlarmReadinessReminder {
        static let identifierPrefix = "alarmo.preAlarmReadiness."
        /// Default lead time before the alarm fire date (10–15 min window).
        static let leadTime: TimeInterval = 12 * 60
        /// Shorter lead for alarms that are soon but not imminent.
        static let shortLeadTime: TimeInterval = 5 * 60
        /// Minimum lead for very near alarms.
        static let imminentLeadTime: TimeInterval = 3 * 60
        /// Only schedule if the alarm is at least this far away.
        static let minAdvanceForScheduling: TimeInterval = 5 * 60
        /// Use short lead when alarm is within this many seconds.
        static let shortLeadThreshold: TimeInterval = 30 * 60
        /// When the app is opened within this window of an alarm and looks
        /// healthy, the readiness reminder is cancelled.
        static let healthCheckWindow: TimeInterval = 15 * 60
        static let userInfoSourceAlarmIDKey = "preAlarmReadinessSourceAlarmId"
        static let userInfoFireAtKey = "preAlarmReadinessFireAt"

        static func identifier(for alarmId: String) -> String {
            "\(identifierPrefix)\(alarmId)"
        }

        /// True when `id` is one of our pre-alarm readiness identifiers.
        static func isReadinessIdentifier(_ id: String) -> Bool {
            id.hasPrefix(identifierPrefix)
        }
    }
    
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
        // Store-aware cleanup of stale AlarmKit→custom-UI handoff state, now that
        // AlarmStore is available. Runs before recovery/observation so a stale
        // pending request cannot ghost-start a ring via handlePendingCustomAlarmUIHandoff.
        let runtimeIsActive =
            ringCoordinator.isRinging ||
            AlarmBackgroundAudioBridge.shared.currentAlarmID != nil ||
            AlarmContinuousAudioEngine.shared.isEngineActive ||
            AlarmAudioStateController.shared.phase != .stopped
        let appIsForeground = UIApplication.shared.applicationState != .background
        AlarmCustomUIHandoffStore.pruneWithAlarmStore(
            alarmStore,
            runtimeIsActive: runtimeIsActive,
            appIsForeground: appIsForeground
        )
        checkStatus()
        drainPendingAlarmStarts()
        cancelPersistedAlarmKitRespawnArtifactsIfNeeded()
        installAppEngineVolumeResetFailedObserverIfNeeded()
        startAlarmKitObservation()
    }

    private func cancelPersistedAlarmKitRespawnArtifactsIfNeeded() {
        guard AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn else { return }
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        let helper = AlarmSchedulerIOS26AlarmKit()
        helper.cancelAllLockedContinuityGuards(
            manager: AlarmManager.shared,
            reason: "respawn-disabled-startup-cleanup"
        )
#endif
    }

    func isCustomAlarmUIVisibleInForeground() -> Bool {
        let appActive = UIApplication.shared.applicationState == .active
        let uiVisible = ringCoordinator?.isRingingUIVisible == true
        // Defensive: RC_UI_VISIBLE can briefly remain true after a side-button press
        // before the scene phase actually transitions. Recovery decisions must NOT
        // trust UI visibility while the app is backgrounded.
        if uiVisible && !appActive {
            print("[RecoveryCheck] ignoring RC_UI_VISIBLE because app is not active")
        }
        return appActive && uiVisible
    }

    /// Compact diagnostic log emitted before recovery decisions — captures the
    /// invalid "dead audio" state observed in device logs (engine active + not
    /// playing, app backgrounded, finalStop poisoned by previous Stop, etc.).
    func emitDeadAudioProbe(sourceAlarmId: String, reason: String) {
        let phase = AlarmAudioStateController.shared.phase.rawValue
        let appState: String
        switch UIApplication.shared.applicationState {
        case .active: appState = "active"
        case .inactive: appState = "inactive"
        case .background: appState = "background"
        @unknown default: appState = "unknown"
        }
        let finalStop = AlarmAuthHandoffStore.isFinalStopOrSnoozePressed()
        let alarmStateRaw = AlarmAuthHandoffStore.alarmState()?.rawValue ?? "nil"
        let activeRinging = AlarmAuthHandoffStore.activeRingingAlarmId() ?? "nil"
        let engine = AlarmContinuousAudioEngine.shared
        let recoveryPending = AlarmAudioStateController.shared.hardwareRecoveryPending
            || AlarmAuthHandoffStore.isAuthRecoveryPending()
        let rcRinging = ringCoordinator?.isRinging == true
        let rcUIVisible = ringCoordinator?.isRingingUIVisible == true
        print(
            "[DeadAudioProbe] source=\(sourceAlarmId) reason=\(reason) phase=\(phase) appState=\(appState) " +
            "finalStop=\(finalStop) alarmState=\(alarmStateRaw) activeRinging=\(activeRinging) " +
            "engineActive=\(engine.isEngineActive) enginePlaying=\(engine.confirmStillPlaying()) " +
            "recoveryPending=\(recoveryPending) rcRinging=\(rcRinging) rcUIVisible=\(rcUIVisible)"
        )
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
        guard !alarmKitObservationStarted else { return }
        alarmKitObservationStarted = true
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

    /// Engage AlarmKit handling at COLD LAUNCH, from the AppDelegate — independent
    /// of the SwiftUI view lifecycle.
    ///
    /// When AlarmKit fires while the app is terminated/suspended, iOS cold-launches
    /// the process in the BACKGROUND and runs `didFinishLaunching`, but SwiftUI's
    /// `onAppear` (where the observation + alerting recovery + keep-alive normally
    /// start) does NOT run until the app is foregrounded. That left the FIRST morning
    /// alarm with no takeover: by the time the user opened the app (~19s later in the
    /// field logs), they had already silenced AlarmKit, so the alerting was never
    /// observed. Starting the observation + recovery + keep-alive here catches the
    /// in-progress alert immediately and acquires the bridge passive-standby anchor,
    /// keeping the process alive through the side-button press so the takeover fires.
    ///
    /// Safe for normal launches: recovery only acts on an actually-`alerting` alarm,
    /// and the keep-alive only runs when backgrounded with a pending alarm. Uses
    /// `AlarmStore.shared` because the SwiftUI-injected store isn't wired up yet.
    @MainActor
    func engageAlarmHandlingAtColdLaunch() {
        if alarmStore == nil { alarmStore = AlarmStore.shared }
        AlarmBackgroundAudioBridge.shared.configure(alarmStore: AlarmStore.shared)
        startAlarmKitObservation()
        recoverAlarmKitAlertingIfNeeded()
        AlarmKeepAliveAudioService.shared.evaluate(reason: "cold-launch")
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

    /// Single entry point for ensuring notification permission for alarm
    /// features (app-closed warnings, readiness reminders, recovery prompts).
    /// Requests authorization when status is `.notDetermined`. Keeps the
    /// published `authorizationStatus` in sync so the rest of the app can read
    /// a fresh value immediately after.
    @discardableResult
    func ensureNotificationPermissionForAlarmFeatures(reason: String) async -> NotificationPermissionResult {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        print("[NotificationPermission] current status=\(settings.authorizationStatus.rawValue) reason=\(reason)")

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            await MainActor.run { self.authorizationStatus = settings.authorizationStatus }
            print("[NotificationPermission] usable=true status=\(settings.authorizationStatus.rawValue)")
            return .granted
        case .denied:
            await MainActor.run { self.authorizationStatus = .denied }
            print("[NotificationPermission] denied; user must enable in Settings")
            return .denied
        case .notDetermined:
            print("[NotificationPermission] requesting authorization reason=\(reason)")
            let options = authorizationOptions()
            do {
                let granted = try await center.requestAuthorization(options: options)
                print("[NotificationPermission] request result granted=\(granted) error=nil")
                let refreshed = await center.notificationSettings()
                await MainActor.run { self.authorizationStatus = refreshed.authorizationStatus }
                if granted {
                    print("[NotificationPermission] usable=true status=\(refreshed.authorizationStatus.rawValue)")
                    return .granted
                }
                print("[NotificationPermission] denied; user must enable in Settings")
                return .denied
            } catch {
                print("[NotificationPermission] request result granted=false error=\(error)")
                return .denied
            }
        @unknown default:
            return .denied
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

        // AppEngine-primary lock screen: prominent Alarmo notification with
        // pressable Stop / Snooze that foreground the app into AlarmRingingView.
        let appEngineOpenStop = UNNotificationAction(
            identifier: AppNotificationAction.appEngineRingingOpenStop,
            title: "Stop",
            options: [.foreground, .authenticationRequired, .destructive]
        )
        let appEngineOpenSnooze = UNNotificationAction(
            identifier: AppNotificationAction.appEngineRingingOpenSnooze,
            title: "Snooze",
            options: [.foreground, .authenticationRequired]
        )
        let appEngineRingingControlCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.appEngineRingingControl,
            actions: [appEngineOpenStop, appEngineOpenSnooze],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Alarmo alarm is ringing",
            categorySummaryFormat: "%u more Alarmo alarms",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle, .customDismissAction]
        )

        let unlockDismiss = UNNotificationAction(
            identifier: AppNotificationAction.alarmKitUnlockDismiss,
            title: "Stop Alarm",
            options: [.authenticationRequired, .foreground, .destructive]
        )
        let alarmKitUnlockCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmKitUnlock,
            actions: [unlockDismiss],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "⏰ Alarm is ringing",
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

        let openAlarmoForegroundSoundAction = UNNotificationAction(
            identifier: AppNotificationAction.alarmForegroundSoundOpen,
            title: "Open Alarmo",
            options: [.foreground]
        )
        let recoveryOpenAppAction = UNNotificationAction(
            identifier: AppNotificationAction.alarmRecoveryOpenApp,
            title: "Open Alarmo",
            options: [.foreground, .authenticationRequired]
        )
        let recoveryOpenAppCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmRecoveryOpenApp,
            actions: [recoveryOpenAppAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Alarm is still ringing",
            categorySummaryFormat: "%u more alarm alerts",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        let foregroundSoundReminderCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.alarmForegroundSoundReminder,
            actions: [openAlarmoForegroundSoundAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Open Alarmo for full alarm sound",
            categorySummaryFormat: "%u more Alarmo alerts",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        let openAlarmoAction = UNNotificationAction(
            identifier: AppNotificationAction.appOpenReminderOpen,
            title: "Open Alarmo",
            options: [.foreground]
        )
        let appOpenReminderCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.appOpenReminder,
            actions: [openAlarmoAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Open Alarmo to keep your wake-up flow ready",
            categorySummaryFormat: "%u more Alarmo reminders",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        // Pre-alarm readiness: informational only. Tap opens the alarm menu —
        // never starts sound or the full-screen Stop/Snooze UI.
        let preAlarmReadinessAction = UNNotificationAction(
            identifier: AppNotificationAction.preAlarmReadinessOpen,
            title: "Open Alarmo",
            options: [.foreground]
        )
        let preAlarmReadinessCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.preAlarmReadiness,
            actions: [preAlarmReadinessAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Open Alarmo to make sure your wake-up flow is ready",
            categorySummaryFormat: "%u more Alarmo check-ins",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        // "Unlock to Stop" handoff action. Foregrounds the app and requires
        // authentication; maps to the SAME open-to-stop handoff flow as the
        // AlarmKit slide-to-stop intent. This is NOT a final stop — it only
        // opens Alarmo and presents AlarmRingingView.
        let unlockToStopAction = UNNotificationAction(
            identifier: AppNotificationAction.unlockToStop,
            title: "Unlock to Stop",
            options: [.authenticationRequired, .foreground]
        )
        let unlockToStopCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.unlockToStop,
            actions: [unlockToStopAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Alarm is ringing — unlock to stop",
            categorySummaryFormat: "%u more alarm alerts",
            options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )

        let forceQuitOpenAction = UNNotificationAction(
            identifier: AppNotificationAction.forceQuitWarningOpen,
            title: "Open Alarmo",
            options: [.foreground]
        )
        let forceQuitWarningCategory = UNNotificationCategory(
            identifier: AppNotificationCategory.forceQuitWarning,
            actions: [forceQuitOpenAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Open Alarmo for the full wake-up flow",
            categorySummaryFormat: "%u more Alarmo reminders",
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
            appEngineRingingControlCategory,
            alarmKitUnlockCategory,
            alarmAuthPromptCategory,
            recoveryOpenAppCategory,
            postSlideControlCategory,
            foregroundSoundReminderCategory,
            appOpenReminderCategory,
            preAlarmReadinessCategory,
            unlockToStopCategory,
            forceQuitWarningCategory,
            planCategory,
            focusCategory,
            countdownCategory
        ])
        print("[NotificationCategory] registered FORCE_QUIT_WARNING open-only action")
        print("[PostSlideNotification] registered category \(AppNotificationCategory.alarmPostSlideControl)")
        print("[NotificationCategory] registered Unlock-to-Stop action")
        print("[NotificationCategory] registered AppEngine ringing control Stop/Snooze actions")
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
        cancelAlarmAuthenticationPrompt(sourceAlarmId: sourceAlarmId, reason: "replace-with-unlock-prompt")
        let content = makeAlarmKitUnlockPromptContent(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName
        )

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
        if isAppEngineControllingAlarmAudio() {
            print("[NotificationManager] Unlock prompt loop skipped — AppEngine owns audio; using prominent control notification")
            ensureAppEngineRingingControlNotification(
                sourceAlarmId: sourceAlarmId,
                alarmName: alarmName,
                reason: "unlock-loop-engine-primary"
            )
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
        let appState = UIApplication.shared.applicationState
        let phase = AlarmAudioStateController.shared.phase.rawValue
        print("[PostSlideNotification] schedule-request source=\(sourceAlarmId) surface=\(surfaceAlarmId ?? "nil") appState=\(appState.rawValue) phase=\(phase)")
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
            print("[PostSlideNotification] skipped duplicate for alarmId=\(sourceAlarmId) delta=\(String(format: "%.2f", now.timeIntervalSince(last))) window=\(String(format: "%.2f", postSlideNotificationDuplicateWindow))")
            return
        }
        lastPostSlideNotificationAt[sourceAlarmId] = now
        let center = UNUserNotificationCenter.current()
        cancelAlarmAuthenticationPrompt(sourceAlarmId: sourceAlarmId, reason: "pre-schedule-replace")
        cancelAlarmKitUnlockPrompt(alarmId: sourceAlarmId)

        let copy = ringingNotificationCopy(alarmName: alarmName)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.subtitle = copy.subtitle
        content.body = copy.body
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
            // A tiny delay (0.1s) can be swallowed during AlarmKit slide/side
            // transition churn. Use a safer delay so the card is surfaced after
            // the transition settles.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.8, repeats: false)
        )
        print("[PostSlideNotification] scheduling Alarmy-style card alarmId=\(sourceAlarmId) title=\"\(content.title)\" body=\"\(content.body)\" action=\"Stop Alarm\"")
        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule auth prompt for \(sourceAlarmId): \(error)")
                return
            }
            center.getPendingNotificationRequests { requests in
                let found = requests.contains { $0.identifier == identifier }
                print("[PostSlideNotification] add-complete alarmId=\(sourceAlarmId) pendingFound=\(found) pendingCount=\(requests.count)")
            }
            center.getDeliveredNotifications { delivered in
                let found = delivered.contains { $0.request.identifier == identifier }
                print("[PostSlideNotification] add-complete alarmId=\(sourceAlarmId) deliveredFound=\(found) deliveredCount=\(delivered.count)")
            }
        }
    }

    func cancelAlarmAuthenticationPrompt(sourceAlarmId: String, reason: String = "unspecified") {
        let stableIdentifier = AlarmAuthenticationPrompt.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        print("[PostSlideNotification] cancel-request source=\(sourceAlarmId) identifier=\(stableIdentifier) reason=\(reason) appState=\(UIApplication.shared.applicationState.rawValue) phase=\(AlarmAudioStateController.shared.phase.rawValue)")
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
            print("[PostSlideNotification] cancel-complete source=\(sourceAlarmId) reason=\(reason) legacyPendingRemoved=\(ids.count)")
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
            print("[PostSlideNotification] cancel-complete source=\(sourceAlarmId) reason=\(reason) legacyDeliveredRemoved=\(ids.count)")
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
        cancelAppEngineRingingControlNotification(
            sourceAlarmId: alarmId,
            reason: "mark-flow-completed"
        )
        cancelAlarmAuthenticationPrompt(sourceAlarmId: alarmId, reason: "mark-flow-completed")
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
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[Backup] Chain disabled — keeping basic AlarmKit behavior only source=\(sourceAlarmId)")
            return
        }
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI() else {
            print("[Backup] Chain suppressed — AppEngine session after unlock source=\(sourceAlarmId)")
            return
        }
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
        if !precheckEngineLiveHealthy && AlarmAudioStateController.shared.isDeadAudioRisk() {
            print("[Backup] DEAD AUDIO RISK in phase \(AlarmAudioStateController.shared.phase.rawValue) — routing to dead-audio recovery source=\(sourceAlarmId)")
            print("[DeadAudio] appEnginePreparing + background + engine not playing is recoverable failure source=\(sourceAlarmId)")
            emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "backup-dead-audio-risk")
            detectAndRecoverDeadAudioState(
                sourceAlarmId: sourceAlarmId,
                reason: "appEnginePreparing-background-engine-not-playing"
            )
            return
        }
        if !precheckEngineLiveHealthy && !AlarmAudioStateController.shared.isEngineUnhealthinessAFailure() {
            if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
                print("[Backup] Engine silent in locked no-UI session — routing to recovery source=\(sourceAlarmId)")
                detectAndRecoverDeadAudioState(sourceAlarmId: sourceAlarmId, reason: "backup-locked-no-ui-silent")
                return
            }
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

    func markReplacingWithAudibleAlarmKitRecovery(sourceAlarmId: String, reason: String) {
        replacingWithAudibleAlarmKitRecoverySourceIds.insert(sourceAlarmId)
        print("[AlarmKitDismiss] marked replacing-with-recovery source=\(sourceAlarmId) reason=\(reason)")
    }

    func clearReplacingWithAudibleAlarmKitRecovery(sourceAlarmId: String) {
        replacingWithAudibleAlarmKitRecoverySourceIds.remove(sourceAlarmId)
    }

    /// Gate every AlarmKit dismissal — never drop the only audible source before
    /// AppEngine is strictly verified, final stop completes, or recovery replaces it.
    @MainActor
    func canDismissAlarmKit(sourceAlarmId: String, reason: String) async -> Bool {
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            print("[AlarmKitDismiss] allowed reason=final-stop source=\(sourceAlarmId) request=\(reason)")
            return true
        }
        if replacingWithAudibleAlarmKitRecoverySourceIds.contains(sourceAlarmId) {
            print("[AlarmKitDismiss] allowed reason=replacing-with-recovery source=\(sourceAlarmId) request=\(reason)")
            return true
        }
        if await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: reason) {
            print("[AlarmKitDismiss] allowed reason=app-engine-verified source=\(sourceAlarmId) request=\(reason)")
            return true
        }
        print("[AlarmKitDismiss] blocked reason=engine-not-verified source=\(sourceAlarmId) request=\(reason)")
        return false
    }

    @MainActor
    private func canDismissAllAlertingAlarmKitSurfaces(reason: String) async -> Bool {
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            print("[AlarmKitDismiss] allowed reason=final-stop request=\(reason)")
            return true
        }
        if let sourceId = AlarmAuthHandoffStore.activeRingingAlarmId() {
            return await canDismissAlarmKit(sourceAlarmId: sourceId, reason: reason)
        }
        return await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: reason)
    }

    /// Aggressively kill EVERY AlarmKit alarm currently in the .alerting
    /// state. Used by stopRingingInternal so the user pressing Stop in-app
    /// nukes any zombie alarms created by previous respawn rounds even if
    /// their handoff mapping was lost. Iterates a few times with short
    /// delays to catch any alarm that respawns between passes.
    func nukeAllAlertingAlarmKitSurfaces(reason: String = "unspecified") {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            guard await canDismissAllAlertingAlarmKitSurfaces(reason: reason) else { return }
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

    func dismissLinkedAlarmKitSurfaces(sourceAlarmId: String, reason: String = "unspecified") {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            guard await canDismissAlarmKit(sourceAlarmId: sourceAlarmId, reason: reason) else { return }
            await dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: sourceAlarmId)
            print("[AlarmKitDismiss] dismissed linked surfaces source=\(sourceAlarmId) reason=\(reason)")
        }
#endif
    }

    func dismissLinkedAlarmKitSurfacesAggressively(
        sourceAlarmId: String,
        attempts: Int = 8,
        interval: TimeInterval = 0.2,
        reason: String = "aggressive-dismiss"
    ) {
#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }
        let totalAttempts = max(1, attempts)

        Task { @MainActor in
            guard await canDismissAlarmKit(sourceAlarmId: sourceAlarmId, reason: reason) else { return }
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
    private func stopAlarmKitSurfaceIfAllowed(
        alarm: AlarmKit.Alarm,
        sourceAlarmId: String,
        reason: String
    ) async {
        guard await canDismissAlarmKit(sourceAlarmId: sourceAlarmId, reason: reason) else { return }
        try? AlarmManager.shared.stop(id: alarm.id)
        try? AlarmManager.shared.cancel(id: alarm.id)
        print("[AlarmKitDismiss] stopped surface=\(alarm.id.uuidString) source=\(sourceAlarmId) reason=\(reason)")
    }

    @available(iOS 26.0, *)
    @MainActor
    private func dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: String) async {
        do {
            let alarms = try AlarmManager.shared.alarms
            for alarm in alarms {
                let surfaceId = alarm.id.uuidString
                let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
                guard mappedSource == sourceAlarmId || surfaceId == sourceAlarmId else { continue }
                AlarmCustomUIHandoffStore.removeUIShellSurface(surfaceId)
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
        let copy = alarmKitUnlockPromptCopy(isUnlockedState: isUnlockedState, alarmName: alarmName)
        content.title = copy.title
        content.subtitle = copy.subtitle
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

    private func ringingNotificationCopy(alarmName: String?) -> (title: String, subtitle: String, body: String) {
        let trimmedLabel = alarmName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedLabel = trimmedLabel.isEmpty ? "Alarm" : trimmedLabel
        return (
            title: "⏰ \(resolvedLabel)",
            subtitle: "Alarm is ringing",
            body: "Unlock to open Alarmo, then tap Stop or Snooze. The alarm will keep ringing until you stop it in the app."
        )
    }

    private func alarmKitUnlockPromptCopy(isUnlockedState: Bool, alarmName: String?) -> (title: String, subtitle: String, body: String) {
        _ = isUnlockedState
        let copy = ringingNotificationCopy(alarmName: alarmName)
        return (copy.title, copy.subtitle, copy.body)
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
        if notification.request.identifier == AppClosedWarning.identifier
            || ArmedAlarmCloseWarningStandby.isArmedCloseWarningIdentifier(notification.request.identifier) {
            print("[NotificationDelegate] willPresent id=\(notification.request.identifier)")
            print("[NotificationDelegate] presenting banner/sound for informational close warning")
            completionHandler([.banner, .list, .sound])
            return
        }
        if notification.request.content.categoryIdentifier == AppNotificationCategory.appEngineRingingControl {
            print("[NotificationDelegate] willPresent AppEngine ringing control id=\(notification.request.identifier)")
            completionHandler([.banner, .list])
            return
        }
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
        let request = response.notification.request
        let alarmIdForLog = (request.content.userInfo["alarmId"] as? String)
            ?? (request.content.userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String)
            ?? (request.content.userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String)
            ?? request.identifier
        print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_ACTION_RECEIVED ACTION=\(action) CATEGORY=\(request.content.categoryIdentifier) REQUEST_ID=\(request.identifier) ALARM_ID=\(alarmIdForLog) APP_STATE=\(UIApplication.shared.applicationState.rawValue)")

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
        } else if action == AppNotificationAction.alarmForegroundSoundOpen ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmForegroundSoundReminder {
            handleForegroundSoundReminderAction(notification: response.notification)
        } else if action == AppNotificationAction.preAlarmReadinessOpen ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.preAlarmReadiness ||
            PreAlarmReadinessReminder.isReadinessIdentifier(response.notification.request.identifier) {
            handlePreAlarmReadinessTap(notification: response.notification)
        } else if ArmedAlarmCloseWarningStandby.isArmedCloseWarningIdentifier(response.notification.request.identifier) {
            handleArmedCloseWarningTap(notification: response.notification)
        } else if action == AppNotificationAction.forceQuitWarningOpen ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.forceQuitWarning ||
            response.notification.request.identifier == ForceQuitWarning.identifier {
            handleForceQuitWarningTap(notification: response.notification)
        } else if action == AppNotificationAction.appOpenReminderOpen ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.appOpenReminder ||
            response.notification.request.identifier == AppClosedWarning.identifier {
            handleAppOpenReminderTap(notification: response.notification)
        } else if action == AppNotificationAction.unlockToStop ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.unlockToStop {
            handleUnlockToStopAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmKitUnlockDismiss ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmKitUnlock {
            handleAlarmKitUnlockPromptAction(notification: response.notification)
        } else if action == AppNotificationAction.alarmRecoveryOpenApp ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.alarmRecoveryOpenApp {
            let userInfo = response.notification.request.content.userInfo
            let sourceAlarmId = (userInfo[RecoveryOpenAppNotification.userInfoSourceAlarmIDKey] as? String)
                ?? (userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String)
                ?? alarmIdForLog
            print("[RecoveryNotification] tapped source=\(sourceAlarmId) action=open-app")
            handleAlarmKitUnlockPromptAction(notification: response.notification)
        } else if action == AppNotificationAction.appEngineRingingOpenStop ||
            action == AppNotificationAction.appEngineRingingOpenSnooze ||
            response.notification.request.content.categoryIdentifier == AppNotificationCategory.appEngineRingingControl {
            handleAppEngineRingingControlAction(
                notification: response.notification,
                action: action
            )
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
        } else if isInformationalOpenAppNotification(response.notification) {
            handleInformationalOpenAppNotificationTap(notification: response.notification)
        } else {
            handle(notification: response.notification)
        }
        completionHandler()
    }

    func handleNotificationStopAction(alarmId: String) {
        print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_STOP_ACTION_HANDLING ALARM_ID=\(alarmId) PHASE=\(AlarmAudioStateController.shared.phase.rawValue) IS_RINGING=\(ringCoordinator?.isRinging == true)")
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
            print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_TAP_HANDLING ALARM_ID=\(alarmId) REQUEST_ID=\(notification.request.identifier) CATEGORY=\(notification.request.content.categoryIdentifier)")
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
            print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_TAP_ALARMKIT_UNLOCK SOURCE_ID=\(sourceAlarmId) SURFACE_ID=\(surfaceAlarmId ?? "nil")")
            requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        } else if let sourceAlarmId = userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String {
            let surfaceAlarmId = userInfo[AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey] as? String
            print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_TAP_AUTH_PROMPT SOURCE_ID=\(sourceAlarmId) SURFACE_ID=\(surfaceAlarmId ?? "nil")")
            requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        } else if let legacyAlarmId = userInfo[AlarmKitUnlockPrompt.legacyUserInfoAlarmIDKey] as? String {
            print("🧭 [ALARMTRACE_ACTION] EVENT=NOTIFICATION_TAP_LEGACY_ALARMKIT_UNLOCK ALARM_ID=\(legacyAlarmId)")
            requestCustomUIHandoff(sourceAlarmId: legacyAlarmId, surfaceAlarmId: legacyAlarmId)
        }
    }

    private func handleAlarmKitUnlockPromptAction(notification: UNNotification) {
        guard alarmKitUnlockPromptNotificationsEnabled else { return }
        guard let sourceAlarmId = notification.request.content.userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String else {
            return
        }
        let surfaceAlarmId = notification.request.content.userInfo[AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey] as? String
        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_UNLOCK_PROMPT_ACTION SOURCE_ID=\(sourceAlarmId) SURFACE_ID=\(surfaceAlarmId ?? "nil")")
        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
    }

    private func handleAlarmAuthenticationPromptAction(notification: UNNotification) {
        guard let sourceAlarmId = notification.request.content.userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String else {
            return
        }
        let surfaceAlarmId = notification.request.content.userInfo[AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey] as? String
        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARM_AUTH_PROMPT_ACTION SOURCE_ID=\(sourceAlarmId) SURFACE_ID=\(surfaceAlarmId ?? "nil")")
        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
    }

    /// Handles the blue "Unlock to Stop" notification action (and a body tap on
    /// that category). This is a handoff/open action — NOT a final stop. It
    /// persists ringing handoff state via the shared helper, then foregrounds
    /// the app into the custom AlarmRingingView. The real final stop only
    /// happens from Stop/Snooze inside the full-screen UI.
    private func handleUnlockToStopAction(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let sourceAlarmId = (userInfo[AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey] as? String)
            ?? (userInfo[AlarmAuthenticationPrompt.userInfoSourceAlarmIDKey] as? String)
            ?? (userInfo[RecoveryOpenAppNotification.userInfoSourceAlarmIDKey] as? String)
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()
        guard let sourceAlarmId else {
            print("[NotificationAction] received UNLOCK_TO_STOP_ACTION source=nil — no resolvable alarm")
            return
        }
        let surfaceAlarmId = (userInfo[AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey] as? String)
            ?? (userInfo[AlarmAuthenticationPrompt.userInfoSurfaceAlarmIDKey] as? String)
            ?? AlarmAuthHandoffStore.surfaceAlarmId()
            ?? sourceAlarmId

        print("[NotificationAction] received UNLOCK_TO_STOP_ACTION source=\(sourceAlarmId)")
        print("[NotificationRouter] category=ACTIVE_ALARM_HANDOFF -> open ringing UI")
        print("[NotificationTap] ACTIVE_ALARM_HANDOFF tapped source=\(sourceAlarmId)")
        let resolvedRunId = AlarmAudioStateController.shared.currentAlarmRunId?.uuidString
        print("[UnlockToStop] action tapped source=\(sourceAlarmId) runId=\(resolvedRunId ?? "nil")")

        // A tap originating from the recovery prompt is tracked as recoveryPromptTap;
        // anything else is the direct unlock-to-stop notification.
        let isRecoveryPrompt = notification.request.identifier.hasPrefix(RecoveryOpenAppNotification.identifierPrefix)
        let handoffSource: AlarmAuthHandoffStore.HandoffSource = isRecoveryPrompt
            ? .recoveryPromptTap
            : .unlockToStopNotification
        AlarmAuthHandoffStore.persistOpenToStopHandoff(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            runId: resolvedRunId,
            handoffSource: handoffSource,
            reason: isRecoveryPrompt ? "recovery-prompt-tap" : "unlock-to-stop-notification"
        )
        print("[UnlockToStop] persisted handoff state source=\(sourceAlarmId)")

        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
        print("[UnlockToStop] requested foreground app open source=\(sourceAlarmId)")
        print("[UnlockToStop] final stop NOT set source=\(sourceAlarmId)")
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

    func isAppEngineControllingAlarmAudioForNotifications() -> Bool {
        isAppEngineControllingAlarmAudio()
    }

    private func isAppEngineControllingAlarmAudio() -> Bool {
        let phase = AlarmAudioStateController.shared.phase
        if phase == .appEnginePrimary || phase == .appEngineFadingIn { return true }
        if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            if ringCoordinator?.isRinging == true { return true }
            if AlarmAuthHandoffStore.alarmState() == .ringing { return true }
            if AlarmBackgroundAudioBridge.shared.isPlaying { return true }
        }
        return false
    }

    /// Prominent Alarmo lock-screen notification with Stop / Snooze actions that
    /// open the custom AlarmRingingView. Used whenever AppEngine owns audio.
    @MainActor
    func ensureAppEngineRingingControlNotification(
        sourceAlarmId: String,
        alarmName: String? = nil,
        reason: String
    ) {
        let appState = UIApplication.shared.applicationState
        guard appState == .background else {
            print("[AppEngineRingingControl] skipped — app not backgrounded state=\(appState.rawValue) source=\(sourceAlarmId)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard isAppEngineControllingAlarmAudio() else {
            print("[AppEngineRingingControl] skipped — AppEngine not primary source=\(sourceAlarmId)")
            return
        }

        let now = Date()
        if let last = lastAppEngineRingingControlAt[sourceAlarmId],
           now.timeIntervalSince(last) < 2.0 {
            return
        }
        if appEngineRingingControlInFlight.contains(sourceAlarmId) { return }
        lastAppEngineRingingControlAt[sourceAlarmId] = now
        appEngineRingingControlInFlight.insert(sourceAlarmId)

        // No AlarmKit lock-screen UI when AppEngine owns sound.
        dismissLinkedAlarmKitSurfaces(sourceAlarmId: sourceAlarmId, reason: "app-engine-control-\(reason)")
        cancelAlarmKitUnlockPrompt(alarmId: sourceAlarmId)

        let identifier = AppEngineRingingControlNotification.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "⏰ Alarmo Alarm"
        let trimmedName = alarmName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            content.subtitle = trimmedName
        }
        content.body = "Alarm is ringing — tap Stop or Snooze to open Alarmo"
        content.sound = nil
        content.categoryIdentifier = AppNotificationCategory.appEngineRingingControl
        content.threadIdentifier = "alarmo.appEngineRingingControl"
        content.userInfo = [
            AppEngineRingingControlNotification.userInfoSourceAlarmIDKey: sourceAlarmId,
            AppEngineRingingControlNotification.userInfoHandoffOnlyKey: true,
            AlarmNotificationKind.userInfoKey: AlarmNotificationKind.alarmRecovery
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if let attachment = prominentBrandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.25, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { [weak self] error in
            self?.appEngineRingingControlInFlight.remove(sourceAlarmId)
            if let error {
                print("[AppEngineRingingControl] schedule failed source=\(sourceAlarmId) error=\(error)")
            } else {
                print("[AppEngineRingingControl] scheduled prominent control notification source=\(sourceAlarmId) reason=\(reason)")
            }
        }
    }

    func cancelAppEngineRingingControlNotification(sourceAlarmId: String, reason: String) {
        let identifier = AppEngineRingingControlNotification.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        appEngineRingingControlInFlight.remove(sourceAlarmId)
        print("[AppEngineRingingControl] cancelled source=\(sourceAlarmId) reason=\(reason)")
    }

    /// Dismisses AlarmKit lock-screen surfaces once AppEngine is strictly verified,
    /// final stop completed, or an audible recovery surface is replacing AlarmKit.
    func dismissAlarmKitUIForAppEngineOwnedSession(sourceAlarmId: String, reason: String) {
        Task { @MainActor in
            guard await canDismissAlarmKit(sourceAlarmId: sourceAlarmId, reason: reason) else { return }
            print("[AlarmKitUI] suppressing lock-screen UI source=\(sourceAlarmId) reason=\(reason)")
            await dismissLinkedAlarmKitSurfacesOnce(sourceAlarmId: sourceAlarmId)
            cancelAllBackupAlarmKitChains()
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "app-engine-owned-\(reason)")
            if UIApplication.shared.applicationState == .background,
               isAppEngineControllingAlarmAudio() || AlarmAudioStateController.shared.userHasUnlockedDuringThisAlarmRun {
                let alarmName = (alarmStore ?? AlarmStore.shared)
                    .alarm(by: UUID(uuidString: sourceAlarmId) ?? UUID())?
                    .name
                ensureAppEngineRingingControlNotification(
                    sourceAlarmId: sourceAlarmId,
                    alarmName: alarmName,
                    reason: "no-alarmkit-ui-\(reason)"
                )
            }
        }
    }

    /// Shows a **silent** AlarmKit lock-screen surface (slide-to-stop + snooze) only
    /// while the phone is still locked, the user has not unlocked, and AlarmKit owns sound.
    func ensureSilentAlarmKitUIShell(sourceAlarmId: String, reason: String) {
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI() else {
            dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "ui-shell-blocked-\(reason)"
            )
            return
        }
        if isAppEngineControllingAlarmAudio() {
            dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "engine-primary-instead-of-ui-shell-\(reason)"
            )
            return
        }

        guard UIApplication.shared.applicationState != .active else {
            print("[AlarmKitUIShell] skipped — app active source=\(sourceAlarmId)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
            || AlarmBackgroundAudioBridge.shared.isPlaying
        guard ringing else { return }

        let now = Date()
        if let last = lastUIShellEnsureAt[sourceAlarmId],
           now.timeIntervalSince(last) < 2.0 {
            return
        }
        if uiShellEnsureInFlight.contains(sourceAlarmId) { return }
        lastUIShellEnsureAt[sourceAlarmId] = now
        uiShellEnsureInFlight.insert(sourceAlarmId)

#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else {
            uiShellEnsureInFlight.remove(sourceAlarmId)
            return
        }
        guard #available(iOS 26.0, *) else {
            uiShellEnsureInFlight.remove(sourceAlarmId)
            return
        }

        Task { @MainActor in
            defer { self.uiShellEnsureInFlight.remove(sourceAlarmId) }
            do {
                let alarms = try AlarmManager.shared.alarms
                let alreadyHasShell = alarms.contains { alarm in
                    guard alarm.state == .alerting else { return false }
                    let mapped = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alarm.id.uuidString)
                    guard mapped == sourceAlarmId || alarm.id.uuidString == sourceAlarmId else { return false }
                    return AlarmCustomUIHandoffStore.isUIShellSurface(alarm.id.uuidString)
                }
                if alreadyHasShell {
                    print("[AlarmKitUIShell] UI shell already alerting source=\(sourceAlarmId) reason=\(reason)")
                    return
                }
            } catch {
                print("[AlarmKitUIShell] inspect failed source=\(sourceAlarmId): \(error)")
            }

            guard let sourceUUID = UUID(uuidString: sourceAlarmId),
                  let alarm = (self.alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else {
                print("[AlarmKitUIShell] alarm model missing source=\(sourceAlarmId)")
                return
            }

            if self.hasLiveAlarmKitSurface(sourceAlarmId: sourceAlarmId, reason: "ui-shell-\(reason)") {
                print("[AlarmKitUIShell] skipped — live AlarmKit surface exists source=\(sourceAlarmId) reason=\(reason)")
                self.scheduleAlarmRecoveryOpenAppNotification(sourceAlarmId: sourceAlarmId, reason: "ui-shell-live-surface-\(reason)")
                return
            }

            let helper = AlarmSchedulerIOS26AlarmKit()
            let title = alarm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alarm" : alarm.name
            let shellUUID = UUID()
            do {
                try await helper.scheduleUIShellWithFallbackSound(
                    manager: AlarmManager.shared,
                    id: shellUUID,
                    originalAlarmID: sourceUUID,
                    title: title,
                    schedule: .fixed(Date().addingTimeInterval(0.35)),
                    sourceAlarm: alarm
                )
                AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: shellUUID)
                AlarmCustomUIHandoffStore.markUIShellSurface(shellUUID.uuidString)
                AlarmAuthHandoffStore.updateSurfaceAlarmId(shellUUID)
                print("[AlarmKitUIShell] ensured silent UI shell surface=\(shellUUID.uuidString) source=\(sourceAlarmId) reason=\(reason)")
            } catch {
                print("[AlarmKitUIShell] schedule failed source=\(sourceAlarmId) reason=\(reason): \(error)")
            }
        }
#else
        uiShellEnsureInFlight.remove(sourceAlarmId)
#endif
    }

    /// Respawn AlarmKit's alerting surface — but ONLY if there isn't one
    /// already alerting AND we haven't respawned recently (3-second throttle).
    /// This is the one place we programmatically respawn now; called from
    /// scenePhase inactive when the user re-locks during an active ring.
    /// Prevents the multiple-banner cascade by being strictly one-shot.
    func ensureAlarmKitSurfaceForLockedLoopIfNeeded(sourceAlarmId: String, force: Bool = false) {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[AlarmKitRespawn] locked-loop ensure disabled — no replacement surface source=\(sourceAlarmId)")
            return
        }
        guard UIApplication.shared.applicationState != .active else {
            print("[NotificationManager] Locked loop surface suppressed — app is active")
            return
        }
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI() else {
            print("[NotificationManager] Locked loop surface suppressed — AppEngine owns sound or user unlocked")
            dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-loop-ui-suppressed"
            )
            return
        }
        guard AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() else {
            print("[NotificationManager] Locked loop surface suppressed — phase \(AlarmAudioStateController.shared.phase.rawValue) not eligible for AlarmKit respawn")
            return
        }
        let phase = AlarmAudioStateController.shared.phase
        if phase == .appEnginePrimary || phase == .appEngineFadingIn {
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                dismissAlarmKitUIForAppEngineOwnedSession(
                    sourceAlarmId: sourceAlarmId,
                    reason: "locked-loop-engine-primary"
                )
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
            print("[Respawn] Engine active and healthy — no AlarmKit UI (AppEngine owns sound)")
            dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "locked-loop-engine-healthy"
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

    // MARK: - Auth handoff timeout + audible recovery

    func scheduleAuthHandoffTimeout(sourceAlarmId: String) {
        cancelAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
        let work = DispatchWorkItem { [weak self] in
            self?.handleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
        }
        authHandoffTimeoutWorkItems[sourceAlarmId] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + authHandoffTimeoutInterval, execute: work)
        let delaySeconds = Int(authHandoffTimeoutInterval)
        print("[AuthHandoff] auth timeout scheduled +\(delaySeconds)s source=\(sourceAlarmId)")
    }

    func cancelAuthHandoffTimeout(sourceAlarmId: String) {
        authHandoffTimeoutWorkItems[sourceAlarmId]?.cancel()
        authHandoffTimeoutWorkItems.removeValue(forKey: sourceAlarmId)
    }

    func cancelPendingAuthRecovery(sourceAlarmId: String) {
        if let surfaceId = pendingAuthRecoverySurfaceIds.removeValue(forKey: sourceAlarmId) {
#if canImport(AlarmKit)
            if #available(iOS 26.0, *) {
                try? AlarmManager.shared.cancel(id: surfaceId)
            }
#endif
        }
        AlarmAuthHandoffStore.setAuthRecoveryPending(false)
    }

    func handleAuthHandoffTimeout(sourceAlarmId: String) {
        authHandoffTimeoutWorkItems.removeValue(forKey: sourceAlarmId)
        print("[AuthHandoff] auth timeout fired source=\(sourceAlarmId)")
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "auth-timeout")

        guard AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId else {
            print("[AuthHandoff] recovery skipped — active ringing id mismatch source=\(sourceAlarmId)")
            return
        }
        guard AlarmAuthHandoffStore.alarmState() == .ringing else {
            print("[AuthHandoff] recovery skipped — alarm state is not ringing source=\(sourceAlarmId)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[AuthHandoff] skipped recovery because final stop/snooze already pressed source=\(sourceAlarmId)")
            return
        }
        let appActive = UIApplication.shared.applicationState == .active
        let enginePlaying = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if AlarmAuthHandoffStore.isAuthRecoveryPending(), enginePlaying, !appActive {
            print("[AuthHandoff] skipped recovery because recovery pending and engine playing source=\(sourceAlarmId)")
            return
        }
        if AlarmAuthHandoffStore.isAuthRecoveryPending() {
            print("[AuthHandoff] recovery pending but engine silent — continuing auth-timeout recovery source=\(sourceAlarmId)")
            AlarmAuthHandoffStore.setAuthRecoveryPending(false)
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
        }

        let appActiveCheck = appActive
        let engineLiveHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
            AlarmContinuousAudioEngine.shared.cachedIsHealthy &&
            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if appActiveCheck && engineLiveHealthy {
            print("[AuthHandoff] skipped recovery because app active and engine healthy source=\(sourceAlarmId)")
            return
        }

        if AlarmAudioStateController.shared.engineInaudibleWhileLockedProven
            || !isAlarmAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: "auth-timeout") {
            print("[AuthTimeout] no audible owner — orchestrating AlarmKit respawn source=\(sourceAlarmId)")
            orchestrateAlarmKitRespawnWhenSoundGone(
                sourceAlarmId: sourceAlarmId,
                reason: "auth-timeout"
            )
            return
        }

        if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            print("[LockedNoUI] auth timeout → engine-only recovery source=\(sourceAlarmId)")
            attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: "auth-timeout")
            scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
            if AlarmAuthHandoffStore.isWaitingForAuthentication(),
               UIApplication.shared.applicationState != .active {
                scheduleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
            }
            return
        }

        if !appActiveCheck {
            print("[AppOpen] open request failed; alarm remains active source=\(sourceAlarmId)")
            print("[AppOpen] scheduling dead-audio recovery because open failed source=\(sourceAlarmId)")
            print("[AlarmKitRecovery] recovery remains armed because app not active source=\(sourceAlarmId)")
            print("[AuthHandoff] final stop still false after auth timeout source=\(sourceAlarmId)")
        }

        print("[AuthHandoff] app not active or engine not playing; scheduling recovery source=\(sourceAlarmId)")
        detectAndRecoverDeadAudioState(
            sourceAlarmId: sourceAlarmId,
            reason: "auth-timeout-not-unlocked"
        )
        scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
           UIApplication.shared.applicationState != .active {
            scheduleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
        }
    }

    // MARK: - Hardware suppression check + recovery prompt

    func scheduleHardwareSuppressionCheck(
        sourceAlarmId: String,
        delay: TimeInterval = 3.0,
        reason: String = "scene-inactive-or-background"
    ) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        hardwareSuppressionCheckWorkItems[sourceAlarmId]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handleHardwareSuppressionCheck(sourceAlarmId: sourceAlarmId, reason: reason)
        }
        hardwareSuppressionCheckWorkItems[sourceAlarmId] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        print("[HardwareRecovery] scheduled suppression check +\(String(format: "%.1f", delay))s source=\(sourceAlarmId) reason=\(reason)")
    }

    func cancelHardwareSuppressionChecks(sourceAlarmId: String) {
        hardwareSuppressionCheckWorkItems[sourceAlarmId]?.cancel()
        hardwareSuppressionCheckWorkItems.removeValue(forKey: sourceAlarmId)
    }

    func cancelAllHardwareRecoveryState(sourceAlarmId: String) {
        cancelHardwareSuppressionChecks(sourceAlarmId: sourceAlarmId)
        cancelPendingAuthRecovery(sourceAlarmId: sourceAlarmId)
        cancelRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
        cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
        cancelForceClosedWarning(sourceAlarmId: sourceAlarmId, reason: "final-stop")
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmSchedulerIOS26AlarmKit().cancelLockedContinuityGuard(
                manager: AlarmManager.shared,
                sourceAlarmId: sourceAlarmId,
                reason: "final-stop"
            )
        }
#endif
        cancelPreArmedAlarmKitRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "final-stop"
        )
        engineAudibleVerificationWorkItems[sourceAlarmId]?.cancel()
        engineAudibleVerificationWorkItems.removeValue(forKey: sourceAlarmId)
        hardwareSuppressionCountBySource.removeValue(forKey: sourceAlarmId)
        explicitAlarmKitSuppressionSourceIds.remove(sourceAlarmId)
        lockedNoUIFailureCountBySource.removeValue(forKey: sourceAlarmId)
        lockedNoUIEscalatedBySource.remove(sourceAlarmId)
        stopLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
        stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "final-stop")
        AlarmAudioStateController.shared.clearHardwareRecoveryState()
        AlarmAudioStateController.shared.clearAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId,
            reason: "final-stop"
        )
        print("[HardwareRecovery] cleared recovery state after final stop source=\(sourceAlarmId)")
        // Re-evaluate the silent keep-alive now the ring is over: stop it if no alarm
        // remains, or keep it running for the next pending alarm (covers a lock-screen
        // dismissal where no scene-phase change fires).
        Task { @MainActor in
            AlarmKeepAliveAudioService.shared.evaluate(reason: "final-stop")
        }
    }

    // MARK: - AlarmKit respawn when sound is gone

    /// Alerting AlarmKit UI does not always mean ringer audio is playing — side-button
    /// and slide-to-stop can silence the ringer while the surface remains `.alerting`.
    @MainActor
    func shouldForceAlarmKitRespawnDespiteAlertingSurface(
        sourceAlarmId: String,
        reason: String
    ) -> Bool {
        if AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: "force-respawn-\(reason)") {
            return false
        }
        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId {
            print("[AlarmKitRespawn] force respawn — slide-to-stop consumed ringer source=\(sourceAlarmId)")
            return true
        }
        if AlarmAudioStateController.shared.engineInaudibleWhileLockedProven {
            print("[AlarmKitRespawn] force respawn — engine proven inaudible while locked source=\(sourceAlarmId)")
            return true
        }
        let hasAudibleSurface = hasAudibleAlarmKitAlertingSurface(
            sourceAlarmId: sourceAlarmId,
            reason: "force-respawn-check-\(reason)"
        )
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) >= 1 {
            if hasAudibleSurface {
                switch AlarmAudioStateController.shared.phase {
                case .waitingForAlarmKit, .alarmKitSettling, .alarmKitFallback:
                    print("[AlarmKitRespawn] force respawn — hardware suppression while AlarmKit owned source=\(sourceAlarmId)")
                    return true
                default:
                    break
                }
            } else {
                print("[AlarmKitRespawn] force respawn — no audible AlarmKit surface after hardware suppression source=\(sourceAlarmId)")
                return true
            }
        }
        if !hasAudibleSurface,
           AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging {
            if hasCustomControlNotification(sourceAlarmId: sourceAlarmId) {
                print("[AlarmKitRespawn] force respawn — only custom notification, no audible AlarmKit source=\(sourceAlarmId)")
                return true
            }
        }
        return false
    }

    /// True when the AlarmKit ringer domain is likely still producing sound (not just UI).
    @MainActor
    func isAlarmKitRingerLikelyAudibleWhileLocked(sourceAlarmId: String, reason: String) -> Bool {
        guard alarmKitAlertingSurfaceExists(
            sourceAlarmId: sourceAlarmId,
            reason: "ringer-audibility-\(reason)"
        ) else {
            return false
        }
        if AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(sourceAlarmId: sourceAlarmId) {
            return false
        }
        if hasCustomControlNotification(sourceAlarmId: sourceAlarmId) {
            return false
        }
        if shouldForceAlarmKitRespawnDespiteAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason) {
            print("[AlarmKitRespawn] alerting record present but ringer not trusted source=\(sourceAlarmId) reason=\(reason)")
            return false
        }
        return true
    }

    /// True when either an unconsumed AlarmKit ringer or the app engine is actually audible.
    @MainActor
    func isAlarmAudibleWhileLocked(sourceAlarmId: String, reason: String) -> Bool {
        if isAlarmKitRingerLikelyAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: reason) {
            print("[AlarmKitRespawn] audible owner=AlarmKit-ringer source=\(sourceAlarmId) reason=\(reason)")
            return true
        }
        if AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: reason) {
            print("[AlarmKitRespawn] audible owner=AppEngine source=\(sourceAlarmId) reason=\(reason)")
            return true
        }
        print("[AlarmKitRespawn] no audible owner source=\(sourceAlarmId) reason=\(reason)")
        return false
    }

    /// Schedules multiple system-owned recovery surfaces (RecoveryStopAlarmIntent loop).
    /// Survives force-close — iOS delivers these even when the app process is dead.
    @MainActor
    func scheduleSystemOwnedContinuityRecoveries(
        sourceAlarmId: String,
        dismissedSurfaceIds: [String],
        reason: String,
        delays: [TimeInterval] = [1.0, 3.5, 8.0]
    ) async -> Int {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[AlarmKitRespawn] continuity disabled — preserving AlarmKit as single owner source=\(sourceAlarmId) reason=\(reason)")
            return 0
        }
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return 0 }
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return 0 }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return 0 }
        let sessionLive = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAuthHandoffStore.isWaitingForAuthentication()
            || reason.contains("continuity-guard")
        guard sessionLive else {
            print("[AlarmKitRespawn] continuity skipped — no live session source=\(sourceAlarmId) reason=\(reason)")
            return 0
        }
        guard let sourceUUID = UUID(uuidString: sourceAlarmId),
              let originalAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else {
            print("[AlarmKitRespawn] continuity failed — missing model source=\(sourceAlarmId)")
            return 0
        }
        if UIApplication.shared.applicationState == .active,
           await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: "continuity-\(reason)") {
            print("[AlarmKitRespawn] continuity skipped — AppEngine audible in foreground source=\(sourceAlarmId)")
            return 0
        }

        for surfaceId in dismissedSurfaceIds {
            if let dismissedUUID = UUID(uuidString: surfaceId) {
                try? AlarmManager.shared.cancel(id: dismissedUUID)
                AlarmCustomUIHandoffStore.markSurfaceConsumedBySlideToStop(
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceId
                )
            }
        }

        let helper = AlarmSchedulerIOS26AlarmKit()
        let title = resolvedAlarmLabel(sourceAlarmId: sourceAlarmId, alarmName: originalAlarm.name)
        var scheduled = 0
        for delay in delays {
            let newUUID = UUID()
            do {
                _ = try await helper.scheduleRecoveryWithFallbackSound(
                    manager: AlarmManager.shared,
                    id: newUUID,
                    originalAlarmID: sourceUUID,
                    title: title,
                    schedule: .fixed(Date().addingTimeInterval(delay)),
                    preferredSoundName: originalAlarm.soundName,
                    sourceAlarm: originalAlarm
                )
                AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: newUUID)
                recordAlarmKitRecoverySurfaceScheduled(sourceAlarmId: sourceAlarmId)
                pendingAuthRecoverySurfaceIds[sourceAlarmId] = newUUID
                scheduled += 1
                print("[AlarmKitRespawn] continuity scheduled source=\(sourceAlarmId) surface=\(newUUID.uuidString) delay=\(String(format: "%.1f", delay))s reason=\(reason)")
            } catch {
                print("[AlarmKitRespawn] continuity schedule failed source=\(sourceAlarmId) delay=\(delay)s error=\(error.localizedDescription)")
            }
        }
        return scheduled
#else
        _ = sourceAlarmId
        _ = dismissedSurfaceIds
        _ = reason
        _ = delays
        return 0
#endif
    }

    /// Synchronous in-intent AlarmKit respawn (~+1s). More reliable than app timers alone
    /// when slide-to-stop kills the ringer while the app may suspend immediately after.
    @MainActor
    func scheduleImmediateAlarmKitRespawnFromIntent(
        sourceAlarmId: String,
        dismissedSurfaceId: String,
        reason: String
    ) async -> Bool {
        let count = await scheduleSystemOwnedContinuityRecoveries(
            sourceAlarmId: sourceAlarmId,
            dismissedSurfaceIds: [dismissedSurfaceId],
            reason: reason,
            delays: [1.0, 1.2, 3.5, 8.0]
        )
        return count > 0
    }

    /// Schedules AlarmKit recovery when neither AlarmKit ringer nor AppEngine is audible.
    /// Layer A: in-intent or pre-arm (+1s). Layer B: controlled re-alert loop.
    @MainActor
    func orchestrateAlarmKitRespawnWhenSoundGone(
        sourceAlarmId: String,
        reason: String,
        dismissedSurfaceId: String? = nil,
        forceAfterDismissal: Bool = false
    ) {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            if let dismissedSurfaceId {
                print("[AlarmKitRespawn] disabled — not replacing dismissed surface=\(dismissedSurfaceId) source=\(sourceAlarmId) reason=\(reason)")
            } else {
                print("[AlarmKitRespawn] disabled — preserving AlarmKit primary owner source=\(sourceAlarmId) reason=\(reason)")
            }
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "respawn-disabled")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[AlarmKitRespawn] skipped — final stop source=\(sourceAlarmId)")
            return
        }
        let sessionLive = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAuthHandoffStore.isWaitingForAuthentication()
        guard sessionLive else {
            print("[AlarmKitRespawn] skipped — not ringing source=\(sourceAlarmId)")
            return
        }
        if !forceAfterDismissal,
           !shouldForceAlarmKitRespawnDespiteAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason),
           isAlarmAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: reason) {
            print("[AlarmKitRespawn] skipped — sound still present source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: "orchestrate-\(reason)") {
            print("[AlarmKitRespawn] skipped — AppEngine actually audible source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if !AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI() {
            let engineAudible = AlarmAudioStateController.shared.isAppEngineQuickAudible(
                reason: "orchestrate-ui-policy-\(reason)"
            )
            let audibleAlarmKit = hasAudibleAlarmKitAlertingSurface(
                sourceAlarmId: sourceAlarmId,
                reason: "orchestrate-ui-policy-\(reason)"
            )
            if engineAudible || audibleAlarmKit {
                print("[AlarmKitRespawn] no AlarmKit UI preference — engine or AlarmKit already audible source=\(sourceAlarmId)")
                _ = attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: "respawn-ui-suppressed-\(reason)")
                return
            }
            print("[AlarmKitRespawn] bypassing no-UI preference — no audible owner, forcing AlarmKit source=\(sourceAlarmId)")
        }

        let appInactive = UIApplication.shared.applicationState != .active
        let output = AVAudioSession.sharedInstance().outputVolume
        if appInactive, output <= AlarmAudioStateController.lowOutputVolumeThreshold {
            AlarmAudioStateController.shared.markEngineInaudibleWhileLocked()
        }

        if let dismissedSurfaceId {
            print("[AlarmKitRespawn] dismissed surface=\(dismissedSurfaceId) source=\(sourceAlarmId) reason=\(reason)")
        }
        print("[AlarmKitRespawn] arming system recovery source=\(sourceAlarmId) reason=\(reason) force=\(forceAfterDismissal)")

        scheduleAlarmRecoveryOpenAppNotification(
            sourceAlarmId: sourceAlarmId,
            reason: "sound-gone-\(reason)"
        )
        preArmAudibleAlarmKitRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "sound-gone-\(reason)",
            delay: Self.respawnWhenSoundGonePreArmDelay,
            bypassCooldown: true,
            bypassLiveSurfaceCheck: forceAfterDismissal
        )
        scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "sound-gone-\(reason)",
            delay: 1.0,
            allowEngineFirst: false,
            allowAlarmKitFallback: true,
            force: true,
            bypassNoUIPreference: true,
            controlledRealert: true
        )
        startAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    // MARK: - Controlled AlarmKit re-alert loop (post Slide-to-Stop)

    func startAlarmKitRealertLoop(sourceAlarmId: String, reason: String) {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "disabled")
            print("[AlarmKitRealertLoop] disabled source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "restarted")
        realertLoopTickCountBySource[sourceAlarmId] = 0
        print("[AlarmKitRealertLoop] started source=\(sourceAlarmId) reason=\(reason)")
        scheduleAlarmKitRealertLoopTick(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    func stopAlarmKitRealertLoop(sourceAlarmId: String, reason: String) {
        realertLoopWorkItems.removeValue(forKey: sourceAlarmId)?.cancel()
        realertLoopScheduleInFlight.remove(sourceAlarmId)
        print("[AlarmKitRealertLoop] stopped source=\(sourceAlarmId) reason=\(reason)")
    }

    private func scheduleAlarmKitRealertLoopTick(sourceAlarmId: String, reason: String) {
        realertLoopWorkItems[sourceAlarmId]?.cancel()
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "final-stop")
            return
        }
        guard AlarmAuthHandoffStore.alarmState() == .ringing else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "not-ringing")
            return
        }
        guard UIApplication.shared.applicationState != .active else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "app-active")
            return
        }

        let tick = realertLoopTickCountBySource[sourceAlarmId] ?? 0
        let delay: TimeInterval
        switch tick {
        case 0: delay = Self.realertLoopFirstDelay
        case 1: delay = Self.realertLoopSecondDelay
        default: delay = Self.realertLoopSubsequentDelay
        }

        let work = DispatchWorkItem { [weak self] in
            self?.handleAlarmKitRealertLoopTick(sourceAlarmId: sourceAlarmId, reason: reason)
        }
        realertLoopWorkItems[sourceAlarmId] = work
        print("[AlarmKitRealertLoop] scheduling re-alert source=\(sourceAlarmId) delay=\(String(format: "%.1f", delay))s tick=\(tick)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleAlarmKitRealertLoopTick(sourceAlarmId: String, reason: String) {
        realertLoopWorkItems.removeValue(forKey: sourceAlarmId)
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "final-stop")
            return
        }
        guard AlarmAuthHandoffStore.alarmState() == .ringing else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "not-ringing")
            return
        }
        guard UIApplication.shared.applicationState != .active else {
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "app-active")
            return
        }

        if hasValidUnconsumedLiveAlarmKitSurface(sourceAlarmId: sourceAlarmId, reason: "realert-loop-tick") {
            print("[AlarmKitRealertLoop] skipped source=\(sourceAlarmId) reason=valid-live-surface-exists")
            realertLoopTickCountBySource[sourceAlarmId, default: 0] += 1
            scheduleAlarmKitRealertLoopTick(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }

        if realertLoopScheduleInFlight.contains(sourceAlarmId) {
            print("[AlarmKitRealertLoop] skipped source=\(sourceAlarmId) reason=already-pending")
            scheduleAlarmKitRealertLoopTick(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }

        if isAlarmAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: "realert-loop-tick") {
            print("[AlarmKitRealertLoop] skipped source=\(sourceAlarmId) reason=audible-owner-restored")
            stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "audible-owner")
            return
        }

        print("[AlarmKitRealertLoop] firing controlled re-alert source=\(sourceAlarmId) reason=\(reason)")
        scheduleAlarmRecoveryOpenAppNotification(
            sourceAlarmId: sourceAlarmId,
            reason: "slide-to-stop-no-unlock"
        )
        realertLoopScheduleInFlight.insert(sourceAlarmId)
        scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "realert-loop-\(reason)",
            delay: 1.0,
            allowEngineFirst: false,
            allowAlarmKitFallback: true,
            force: true,
            bypassNoUIPreference: true,
            controlledRealert: true
        )
        realertLoopScheduleInFlight.remove(sourceAlarmId)
        realertLoopTickCountBySource[sourceAlarmId, default: 0] += 1
        scheduleAlarmKitRealertLoopTick(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    // MARK: - Locked no-UI audible recovery (same ring session)

    func isDeviceLockLikelyNow() -> Bool {
        AlarmAppLifecycleSession.isDeviceLockLikely()
            || !UIApplication.shared.isProtectedDataAvailable
    }

    func shouldAllowBackgroundUnlockedAppEngineOwnership(sourceAlarmId: String) -> Bool {
        guard UIApplication.shared.applicationState != .active else { return false }
        guard UIApplication.shared.isProtectedDataAvailable else { return false }
        guard !isDeviceLockLikelyNow() else { return false }
        guard !shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) else { return false }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return false }
        return true
    }

    func shouldPreserveAlarmKitPrimaryOwner(sourceAlarmId: String) -> Bool {
        guard UIApplication.shared.applicationState != .active else { return false }
        guard !shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) else { return false }
        guard !shouldAllowBackgroundUnlockedAppEngineOwnership(sourceAlarmId: sourceAlarmId) else { return false }
        return true
    }

    func isHardwareSuppressionReason(_ reason: String) -> Bool {
        let normalized = reason.lowercased()
        // NOTE: "audio-interruption" is deliberately NOT here. An AVAudioSession
        // interruption `.began` fires when AlarmKit GRABS audio to START ringing
        // (also calls/Siri) — never when the user suppresses the alarm (that
        // RELEASES audio → `.ended`). Treating it as an explicit hardware
        // suppression let the AppEngine take over AT RING START, playing in
        // PARALLEL with the still-ringing AlarmKit = DUAL SOUND. Likewise
        // "scene-inactive"/"scene-background"/bare "suppression" are NOT
        // suppression signals — backgrounding during a ring is not the user
        // silencing the alarm. A real suppression always arrives via one of the
        // reasons below (AlarmKit state leaving `.alerting`, a volume/side-button
        // event, etc.).
        return normalized.contains("slide-to-stop")
            || normalized.contains("volume-suppression")
            || normalized.contains("alarmkit-stop-intent")
            || normalized.contains("alarmkit-left-alerting")
            || normalized.contains("side-button")
            || normalized.contains("side_button")
            || normalized.contains("auth-handoff")
            || normalized.contains("unlock-to-stop")
            || normalized.contains("authentication")
    }

    private func isExplicitAlarmKitSuppressionReason(_ reason: String) -> Bool {
        isHardwareSuppressionReason(reason)
    }

    private func shouldAllowAppEngineSuppressionTakeover(sourceAlarmId: String, reason: String) -> Bool {
        if isHardwareSuppressionReason(reason) {
            explicitAlarmKitSuppressionSourceIds.insert(sourceAlarmId)
            return true
        }
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) >= 1 {
            explicitAlarmKitSuppressionSourceIds.insert(sourceAlarmId)
            return true
        }
        if explicitAlarmKitSuppressionSourceIds.contains(sourceAlarmId) {
            return true
        }
        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId {
            explicitAlarmKitSuppressionSourceIds.insert(sourceAlarmId)
            return true
        }
        return false
    }

    /// True once the user has suppressed audio via side-button or slide-to-stop
    /// without completing auth in the current ring session. Recovery must resume
    /// sound through the app engine only — never re-show AlarmKit lock-screen UI.
    func shouldUseLockedNoUIRecovery(sourceAlarmId: String) -> Bool {
        // When the volume-floor-ignoring takeover policy is on, a prior
        // "proven inaudible" verdict must NOT disable the no-UI engine path:
        // the user wants the engine to keep attempting playback and ramp up
        // regardless of current media volume. AlarmKit is still re-alerted by
        // the no-UI watchdog if the engine never becomes audible.
        if AlarmAudioStateController.shared.engineInaudibleWhileLockedProven,
           !AlarmFeatureFlags.appEngineTakeoverIgnoresVolumeFloor {
            print("[LockedNoUI] disabled — engine proven inaudible while locked; using AlarmKit re-alert loop source=\(sourceAlarmId)")
            return false
        }
        if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
            let suppressed = explicitAlarmKitSuppressionSourceIds.contains(sourceAlarmId)
                || (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) >= 1
                || (AlarmAuthHandoffStore.isWaitingForAuthentication()
                    && AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId)
            if suppressed {
                return true
            }
            if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
                print("[LockedNoUI] waiting for suppression before AppEngine takeover source=\(sourceAlarmId)")
                return false
            }
        } else if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[LockedNoUI] disabled by feature flag — AlarmKit remains primary owner source=\(sourceAlarmId)")
            return false
        }
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) >= 1 {
            switch AlarmAudioStateController.shared.phase {
            case .waitingForAlarmKit, .alarmKitSettling, .alarmKitFallback:
                print("[LockedNoUI] disabled — AlarmKit owned ringer; side-button needs AlarmKit respawn source=\(sourceAlarmId)")
                return false
            default:
                break
            }
            return true
        }
        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId {
            return true
        }
        return false
    }

    func preferNoUIRecoveryOnly(sourceAlarmId: String) -> Bool {
        shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId)
    }

    /// AlarmKit was likely silenced by user/system interaction. Do not respawn
    /// AlarmKit; start the app engine and promote it only after strict audibility verification.
    @discardableResult
    func startAppEngineAfterAlarmKitSuppression(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        reason: String
    ) -> Bool {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[SuppressionTakeover] skipped final stop source=\(sourceAlarmId) reason=\(reason)")
            return false
        }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
            || AlarmBackgroundAudioBridge.shared.isPlaying
            || isAlarmKitAlreadyAlerting(for: sourceAlarmId)
        guard ringing else {
            print("[SuppressionTakeover] skipped not ringing source=\(sourceAlarmId) reason=\(reason)")
            return false
        }
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) == 0,
           isHardwareSuppressionReason(reason) {
            recordHardwareSuppressionEvent(sourceAlarmId: sourceAlarmId)
        }
        guard shouldAllowAppEngineSuppressionTakeover(sourceAlarmId: sourceAlarmId, reason: reason) else {
            print("[SuppressionTakeover] skipped weak signal source=\(sourceAlarmId) reason=\(reason)")
            return false
        }

        print("[SuppressionTakeover] AppEngine takeover requested source=\(sourceAlarmId) surface=\(surfaceAlarmId ?? "nil") reason=\(reason)")
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) == 0 {
            recordHardwareSuppressionEvent(sourceAlarmId: sourceAlarmId)
        }
        AlarmAudioStateController.shared.markAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId,
            reason: reason
        )
        AlarmAudioStateController.shared.clearAlarmKitPrimaryLocked(reason: "suppression-\(reason)")
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "suppression-\(reason)")

        if ringCoordinator?.isRinging != true {
            _ = startAlarmImmediatelyIfPossible(alarmId: sourceAlarmId)
        }

        let resolvedSurface = surfaceAlarmId
            ?? AlarmAuthHandoffStore.surfaceAlarmId()
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? sourceAlarmId
        AlarmBackgroundAudioBridge.shared.start(
            surfaceAlarmId: resolvedSurface,
            sourceAlarmId: sourceAlarmId
        )

        if UIApplication.shared.applicationState == .active {
            ringCoordinator?.reassertRingingAudio(reason: "suppression-\(reason)")
            AlarmAudioStateController.shared.enforceAlarmKitHandoffVolumeParity(reason: "suppression-\(reason)")
            AlarmAudioStateController.shared.enforceForegroundVolumeControl(reason: "suppression-\(reason)")
            return AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        }

        let started = attemptLockedNoUIEngineRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "suppression-\(reason)"
        )
        armEngineAudibleVerification(sourceAlarmId: sourceAlarmId, reason: "suppression-\(reason)")
        startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
        scheduleSuppressionTakeoverRetries(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: resolvedSurface,
            reason: reason
        )
        return started
    }

    private func scheduleSuppressionTakeoverRetries(
        sourceAlarmId: String,
        surfaceAlarmId: String?,
        reason: String
    ) {
        let delays: [TimeInterval] = [0.25, 0.75, 1.5, 2.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
                guard UIApplication.shared.applicationState != .active else { return }
                guard !AlarmAudioStateController.shared.appEngineConfirmedPlaying() else { return }
                print("[SuppressionTakeover] retry +\(String(format: "%.2f", delay))s source=\(sourceAlarmId) reason=\(reason)")
                _ = self.attemptLockedNoUIEngineRecovery(
                    sourceAlarmId: sourceAlarmId,
                    reason: "retry-\(reason)"
                )
                self.armEngineAudibleVerification(
                    sourceAlarmId: sourceAlarmId,
                    reason: "retry-\(reason)"
                )
                _ = surfaceAlarmId
            }
        }
    }

    /// Central orchestrator: restart alarm sound via app engine while locked and
    /// ensure a silent AlarmKit UI shell (slide-to-stop + snooze) is visible.
    @discardableResult
    func attemptLockedNoUIEngineRecovery(sourceAlarmId: String, reason: String) -> Bool {
        print("[LockedNoUI] attempt START source=\(sourceAlarmId) reason=\(reason) appState=\(UIApplication.shared.applicationState.rawValue) phase=\(AlarmAudioStateController.shared.phase.rawValue)")
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "locked-no-ui-\(reason)")

        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[LockedNoUI] attempt ABORT finalStop=true source=\(sourceAlarmId)")
            return false
        }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
            || AlarmBackgroundAudioBridge.shared.isPlaying
            || isAlarmKitAlreadyAlerting(for: sourceAlarmId)
        guard ringing else {
            print("[LockedNoUI] attempt ABORT not ringing source=\(sourceAlarmId)")
            return false
        }
        guard UIApplication.shared.applicationState != .active else {
            print("[LockedNoUI] attempt DEFER app active — in-app UI owns audio source=\(sourceAlarmId)")
            return AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        }
        if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression,
           !shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId),
           !isHardwareSuppressionReason(reason) {
            print("[LockedNoUI] attempt SKIP waiting for explicit AlarmKit suppression source=\(sourceAlarmId) reason=\(reason)")
            return false
        }

        guard let sourceUUID = UUID(uuidString: sourceAlarmId),
              let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else {
            print("[LockedNoUI] attempt ABORT alarm model missing source=\(sourceAlarmId)")
            return false
        }

        // Keep bridge + coordinator alive so background audio mode stays entitled.
        let surfaceId = AlarmAuthHandoffStore.surfaceAlarmId()
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? sourceAlarmId
        AlarmBackgroundAudioBridge.shared.start(
            surfaceAlarmId: surfaceId,
            sourceAlarmId: sourceAlarmId
        )
        // INTENTIONAL: do NOT call ringCoordinator.reassertRingingAudio() here.
        // reassertRingingAudio() routes blocked-phase calls through
        // attemptImmediateLockedRecovery → attemptLockedNoUIEngineRecovery,
        // which is THIS function. That created an infinite recursion loop with
        // an exponentially growing reason string (e.g.
        // "coordinator-reassert-locked-no-ui-coordinator-reassert-locked-no-ui-…").
        // The bridge has been started above; the engine takeover is attempted
        // below; AlarmKit recovery is escalated on failure. No reassert needed.

        AlarmAudioStateController.shared.ensureLockedRecoverySession(
            alarmId: sourceAlarmId,
            soundName: alarm.soundName,
            reason: reason
        )

        // CRITICAL: do NOT dismiss AlarmKit before the engine is confirmed
        // playing. iOS kills AlarmKit ringer audio on side-button / screen-off;
        // if we dismiss the surface before the engine is audible, the alarm goes
        // permanently silent. Dismiss only after engine takeover succeeds
        // (tryEngineAudibleWhileLocked handles that on success).

        if isLockedNoUIEngineAudible(sourceAlarmId: sourceAlarmId) {
            if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
                dismissAlarmKitUIForAppEngineOwnedSession(sourceAlarmId: sourceAlarmId, reason: "already-playing-\(reason)")
            } else if AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI() {
                ensureSilentAlarmKitUIShell(sourceAlarmId: sourceAlarmId, reason: "already-playing-\(reason)")
            } else {
                dismissAlarmKitUIForAppEngineOwnedSession(sourceAlarmId: sourceAlarmId, reason: "already-playing-\(reason)")
            }
            markLockedNoUIAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: "already-playing-\(reason)")
            print("[LockedNoUI] attempt OK engine already audible source=\(sourceAlarmId)")
            startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            lockedNoUIFailureCountBySource[sourceAlarmId] = 0
            lockedNoUIEscalatedBySource.remove(sourceAlarmId)
            return true
        }

        let engineStarted = AlarmAudioStateController.shared.tryEngineAudibleWhileLocked(
            reason: "locked-no-ui-\(reason)"
        )
        if engineStarted {
            // Candidate started — AlarmKit/recovery stay armed until strict verify.
            startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            lockedNoUIFailureCountBySource[sourceAlarmId] = 0
            lockedNoUIEscalatedBySource.remove(sourceAlarmId)
            print("[LockedNoUI] attempt OK engine candidate armed source=\(sourceAlarmId) reason=\(reason)")
            return true
        }

        // Engine could not take over — do not create another AlarmKit surface on
        // the no-respawn policy. Short suppression retries will keep trying.
        // NOTE: with appEngineTakeoverIgnoresVolumeFloor on, an inaudible-but-
        // PLAYING engine returns `true` above and is handled by verification, so
        // reaching here means the engine genuinely could not start (play() failed
        // — missing file / session error / cold runId), which is rarely transient.
        let failureCount = (lockedNoUIFailureCountBySource[sourceAlarmId] ?? 0) + 1
        lockedNoUIFailureCountBySource[sourceAlarmId] = failureCount
        print("[LockedNoUI] attempt FAILED engine not audible source=\(sourceAlarmId) reason=\(reason) failureCount=\(failureCount)")
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            // Fast fallback: don't wait the full ~5s watchdog window for an outright
            // engine-start failure — re-alert audible AlarmKit promptly so a sleeping
            // user isn't left silent after the button press. One-shot guarded by
            // `lockedNoUIEscalatedBySource`, so it cannot spam surfaces, and if the
            // engine recovers on a later retry it still supersedes AlarmKit after
            // strict verification.
            if AlarmFeatureFlags.appEngineTakeoverIgnoresVolumeFloor {
                let reference = lastConfirmedAudibleAtBySource[sourceAlarmId]
                    ?? alarmKitWatchdogStartedAtBySource[sourceAlarmId]
                    ?? Date()
                print("[LockedNoUI] engine could not start — fast AlarmKit fallback (floor-ignoring takeover) source=\(sourceAlarmId)")
                escalateLockedNoUIToAlarmKit(
                    sourceAlarmId: sourceAlarmId,
                    reason: "engine-start-failed-fast-fallback-\(reason)",
                    silenceDuration: Date().timeIntervalSince(reference),
                    failureCount: failureCount
                )
            }
            return false
        }
        startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
        let reference = lastConfirmedAudibleAtBySource[sourceAlarmId]
            ?? alarmKitWatchdogStartedAtBySource[sourceAlarmId]
            ?? Date()
        let silence = Date().timeIntervalSince(reference)
        escalateLockedNoUIToAlarmKit(
            sourceAlarmId: sourceAlarmId,
            reason: "engine-failed-\(reason)",
            silenceDuration: silence,
            failureCount: failureCount
        )
        return false
    }

    /// Watchdog: while locked in a no-UI recovery session, re-attempt engine
    /// playback within 5s if sound drops. Never schedules AlarmKit UI.
    func startLockedNoUIAudibleWatchdog(sourceAlarmId: String) {
        guard shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let now = Date()
        if lastConfirmedAudibleAtBySource[sourceAlarmId] == nil {
            lastConfirmedAudibleAtBySource[sourceAlarmId] = now
        }
        alarmKitWatchdogStartedAtBySource[sourceAlarmId] = now
        scheduleLockedNoUIAudibleWatchdogTick(sourceAlarmId: sourceAlarmId, delay: alarmKitAudibleWatchdogInterval)
        print("[LockedNoUIWatchdog] started source=\(sourceAlarmId) tick=\(alarmKitAudibleWatchdogInterval)s maxSilence=\(alarmKitAudibleMaxSilence)s")
    }

    func stopLockedNoUIAudibleWatchdog(sourceAlarmId: String) {
        alarmKitAudibleWatchdogWorkItems[sourceAlarmId]?.cancel()
        alarmKitAudibleWatchdogWorkItems.removeValue(forKey: sourceAlarmId)
        lastConfirmedAudibleAtBySource.removeValue(forKey: sourceAlarmId)
        alarmKitWatchdogStartedAtBySource.removeValue(forKey: sourceAlarmId)
    }

    func markLockedNoUIAudibleConfirmed(sourceAlarmId: String, reason: String) {
        lastConfirmedAudibleAtBySource[sourceAlarmId] = Date()
        // Engine is audible again — reset the failure counter and clear the
        // escalation flag so a future silence period can re-evaluate cleanly.
        if lockedNoUIFailureCountBySource[sourceAlarmId] != nil {
            lockedNoUIFailureCountBySource[sourceAlarmId] = 0
        }
        lockedNoUIEscalatedBySource.remove(sourceAlarmId)
        print("[LockedNoUIWatchdog] audible confirmed source=\(sourceAlarmId) reason=\(reason)")
        // Cancel pre-armed AlarmKit recovery only after strict engine verification.
        Task { @MainActor in
            await verifyAndCancelPreArmedRecoveryIfEngineAudible(
                sourceAlarmId: sourceAlarmId,
                reason: "engine-audible-\(reason)"
            )
        }
    }

    /// Phase 4 + 5 escalation: when the locked no-UI engine cannot become
    /// audible despite repeated attempts (engine cannot start, media volume 0,
    /// or screen-off keeps cutting `.playback`), we MUST re-show the audible
    /// AlarmKit lock-screen surface so the alarm is never left silent. This
    /// bypasses the normal "no-UI preferred after first suppression" policy
    /// because the alternative is permanent silence — a worse outcome for the
    /// user than seeing the lock-screen UI again.
    private func escalateLockedNoUIToAlarmKit(
        sourceAlarmId: String,
        reason: String,
        silenceDuration: TimeInterval,
        failureCount: Int
    ) {
        guard !lockedNoUIEscalatedBySource.contains(sourceAlarmId) else {
            print("[LockedNoUIWatchdog] escalation already scheduled — skipping duplicate source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        lockedNoUIEscalatedBySource.insert(sourceAlarmId)
        print("[LockedNoUIWatchdog] ⚠️ ESCALATING to audible AlarmKit re-alert — engine cannot stay audible (silence=\(String(format: "%.1f", silenceDuration))s failures=\(failureCount)) source=\(sourceAlarmId) reason=\(reason)")
        AlarmAudioStateController.shared.recordLockedEngineInaudible(reason: "watchdog-escalation-\(reason)")
        orchestrateAlarmKitRespawnWhenSoundGone(
            sourceAlarmId: sourceAlarmId,
            reason: "locked-no-ui-escalation-\(reason)"
        )
    }

    // Backward-compatible aliases
    func startAlarmKitAudibleWatchdog(sourceAlarmId: String) {
        startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
    }

    func stopAlarmKitAudibleWatchdog(sourceAlarmId: String) {
        stopLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
    }

    func markAlarmKitAudibleConfirmed(sourceAlarmId: String, reason: String) {
        markLockedNoUIAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    private func scheduleLockedNoUIAudibleWatchdogTick(sourceAlarmId: String, delay: TimeInterval) {
        alarmKitAudibleWatchdogWorkItems[sourceAlarmId]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.handleLockedNoUIAudibleWatchdogTick(sourceAlarmId: sourceAlarmId)
        }
        alarmKitAudibleWatchdogWorkItems[sourceAlarmId] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func isLockedNoUIEngineAudible(sourceAlarmId: String) -> Bool {
        let output = AVAudioSession.sharedInstance().outputVolume
        return AlarmContinuousAudioEngine.shared.confirmStillPlaying() &&
            output > AlarmAudioStateController.lowOutputVolumeThreshold
    }

    private func handleLockedNoUIAudibleWatchdogTick(sourceAlarmId: String) {
        alarmKitAudibleWatchdogWorkItems.removeValue(forKey: sourceAlarmId)

        guard shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) else {
            stopLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            stopLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            return
        }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
        guard ringing else {
            stopLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
            return
        }

        if UIApplication.shared.applicationState == .active {
            if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                markLockedNoUIAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: "watchdog-app-active")
            }
            scheduleLockedNoUIAudibleWatchdogTick(sourceAlarmId: sourceAlarmId, delay: alarmKitAudibleWatchdogInterval)
            return
        }

        if isLockedNoUIEngineAudible(sourceAlarmId: sourceAlarmId) {
            markLockedNoUIAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: "watchdog-tick-ok")
            scheduleLockedNoUIAudibleWatchdogTick(sourceAlarmId: sourceAlarmId, delay: alarmKitAudibleWatchdogInterval)
            return
        }

        let reference = lastConfirmedAudibleAtBySource[sourceAlarmId]
            ?? alarmKitWatchdogStartedAtBySource[sourceAlarmId]
            ?? Date()
        let silence = Date().timeIntervalSince(reference)
        if silence >= alarmKitAudibleMaxSilence {
            // Silence exceeded the no-UI tolerance window. Try one more engine
            // recovery; if it still cannot become audible (or has already failed
            // multiple times), escalate to an audible AlarmKit re-alert so the
            // alarm is NEVER left silent — even at the cost of re-showing the
            // system lock-screen UI.
            print("[LockedNoUIWatchdog] silence \(String(format: "%.1f", silence))s — last-chance engine retry before AlarmKit escalation source=\(sourceAlarmId)")
            emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "locked-no-ui-watchdog-silence")
            let recovered = attemptLockedNoUIEngineRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: "watchdog-\(String(format: "%.0f", silence))s-silence"
            )
            if !recovered {
                let failureCount = (lockedNoUIFailureCountBySource[sourceAlarmId] ?? 0) + 1
                lockedNoUIFailureCountBySource[sourceAlarmId] = failureCount
                if failureCount >= lockedNoUIEscalationFailureThreshold {
                    escalateLockedNoUIToAlarmKit(
                        sourceAlarmId: sourceAlarmId,
                        reason: "watchdog-silence-\(String(format: "%.0f", silence))s",
                        silenceDuration: silence,
                        failureCount: failureCount
                    )
                } else {
                    print("[LockedNoUIWatchdog] failure \(failureCount)/\(lockedNoUIEscalationFailureThreshold) — will escalate next tick if still silent source=\(sourceAlarmId)")
                }
            }
            // Reset the silence reference so the escalation cooldown is honoured
            // and the next tick measures fresh silence.
            lastConfirmedAudibleAtBySource[sourceAlarmId] = Date()
        } else if silence >= 1.0 {
            print("[LockedNoUIWatchdog] silence \(String(format: "%.1f", silence))s — early engine retry source=\(sourceAlarmId)")
            let recovered = attemptLockedNoUIEngineRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: "watchdog-early-retry"
            )
            if !recovered {
                let count = (lockedNoUIFailureCountBySource[sourceAlarmId] ?? 0) + 1
                lockedNoUIFailureCountBySource[sourceAlarmId] = count
            }
        }

        scheduleLockedNoUIAudibleWatchdogTick(sourceAlarmId: sourceAlarmId, delay: alarmKitAudibleWatchdogInterval)
    }

    func recordHardwareSuppressionEvent(sourceAlarmId: String) {
        let count = (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) + 1
        hardwareSuppressionCountBySource[sourceAlarmId] = count
        print("[LockedNoUI] hardware suppression recorded count=\(count) source=\(sourceAlarmId) — engine-only recovery for remainder of session")
        startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
    }

    /// True after side-button, slide-to-stop, volume, auth handoff, or AlarmKit-left-alerting.
    func hasExplicitHardwareSuppression(sourceAlarmId: String) -> Bool {
        if explicitAlarmKitSuppressionSourceIds.contains(sourceAlarmId) { return true }
        if (hardwareSuppressionCountBySource[sourceAlarmId] ?? 0) >= 1 { return true }
        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId {
            return true
        }
        return false
    }

    func clearSuppressionRecoveryStateForNewRing(sourceAlarmId: String) {
        hardwareSuppressionCountBySource.removeValue(forKey: sourceAlarmId)
        explicitAlarmKitSuppressionSourceIds.remove(sourceAlarmId)
        lockedNoUIFailureCountBySource.removeValue(forKey: sourceAlarmId)
        lockedNoUIEscalatedBySource.remove(sourceAlarmId)
    }

    // MARK: - Pre-armed AlarmKit recovery

    /// Pre-arms a system-owned audible AlarmKit recovery surface. Because the
    /// system schedules the alarm, it fires even if iOS suspends our process —
    /// solving the "delayed app-owned watchdog never runs" failure mode.
    ///
    /// The recovery is cancelled by `cancelPreArmedAlarmKitRecovery(...)` only
    /// when the engine is **verified** audible or the user explicitly stops the
    /// alarm via the in-app UI. Locked no-UI preference NEVER blocks this.
    func preArmAudibleAlarmKitRecovery(
        sourceAlarmId: String,
        runId: String? = nil,
        reason: String,
        delay: TimeInterval = preArmedRecoveryDefaultDelay,
        bypassCooldown: Bool = false,
        bypassLiveSurfaceCheck: Bool = false
    ) {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            cancelPreArmedAlarmKitRecovery(
                sourceAlarmId: sourceAlarmId,
                runId: runId,
                reason: "respawn-disabled"
            )
            print("[AlarmKitRecovery] pre-arm disabled — no respawn scheduling source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        let resolvedRunId = runId ?? currentRunId(for: sourceAlarmId)
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            print("[AlarmKitRecovery] pre-arm skipped final stop source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if AlarmAuthHandoffStore.isMissionCompleted(),
           AlarmAuthHandoffStore.alarmState() != .ringing {
            print("[AlarmKitRecovery] pre-arm skipped mission-completed source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        // Don't stack identical pre-arms in quick succession.
        if let existing = preArmedRecoveryBySource[sourceAlarmId],
           existing.runId == resolvedRunId,
           Date().timeIntervalSince(existing.scheduledAt) < Self.preArmedRecoveryDuplicateWindow {
            print("[AlarmKitRecovery] pre-arm skipped duplicate source=\(sourceAlarmId) runId=\(resolvedRunId) existingReason=\(existing.reason)")
            return
        }
        guard !preArmedRecoveryInFlight.contains(sourceAlarmId) else {
            print("[AlarmKitRecovery] pre-arm skipped — schedule already in flight source=\(sourceAlarmId)")
            return
        }
        if !bypassLiveSurfaceCheck,
           shouldUseNotificationInsteadOfAlarmKitRecovery(sourceAlarmId: sourceAlarmId, reason: reason) {
            return
        }
        if !bypassCooldown,
           isWithinAlarmKitRecoverySurfaceCooldown(sourceAlarmId: sourceAlarmId) {
            print("[RecoveryPolicy] suppressed AlarmKit pre-arm due to cooldown source=\(sourceAlarmId) reason=\(reason)")
            scheduleAlarmRecoveryOpenAppNotification(sourceAlarmId: sourceAlarmId, runId: resolvedRunId, reason: reason)
            return
        }

#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else {
            print("[AlarmKitRecovery] pre-arm skipped — not AlarmKit path source=\(sourceAlarmId)")
            return
        }
        guard #available(iOS 26.0, *) else { return }

        guard let sourceUUID = UUID(uuidString: sourceAlarmId),
              let originalAlarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else {
            print("[AlarmKitRecovery] pre-arm skipped — alarm model missing source=\(sourceAlarmId)")
            return
        }

        // Cancel any older pre-arm for this source so we never stack two
        // recovery surfaces. The new one supersedes the old.
        if let prior = preArmedRecoveryBySource.removeValue(forKey: sourceAlarmId) {
            try? AlarmManager.shared.cancel(id: prior.surfaceUUID)
            print("[AlarmKitRecovery] pre-arm replaced prior source=\(sourceAlarmId) priorReason=\(prior.reason)")
        }

        let newUUID = UUID()
        let fireDate = Date().addingTimeInterval(delay)
        let title = resolvedAlarmLabel(sourceAlarmId: sourceAlarmId, alarmName: originalAlarm.name)
        let preferredSound = originalAlarm.soundName

        preArmedRecoveryInFlight.insert(sourceAlarmId)
        print("[AlarmKitRecovery] pre-armed audible recovery source=\(sourceAlarmId) runId=\(resolvedRunId) delay=\(String(format: "%.1f", delay))s reason=\(reason) sound=\(preferredSound)")

        Task { @MainActor in
            defer { preArmedRecoveryInFlight.remove(sourceAlarmId) }
            // Re-check after the await: if the user already stopped, abort.
            if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
                print("[AlarmKitRecovery] pre-arm aborted — final stop set during scheduling source=\(sourceAlarmId)")
                return
            }
            do {
                let helper = AlarmSchedulerIOS26AlarmKit()
                _ = try await helper.scheduleRecoveryWithFallbackSound(
                    manager: AlarmManager.shared,
                    id: newUUID,
                    originalAlarmID: sourceUUID,
                    title: title,
                    schedule: .fixed(fireDate),
                    preferredSoundName: preferredSound,
                    sourceAlarm: originalAlarm
                )
                AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: newUUID)
                preArmedRecoveryBySource[sourceAlarmId] = PreArmedRecovery(
                    sourceAlarmId: sourceAlarmId,
                    runId: resolvedRunId,
                    surfaceUUID: newUUID,
                    reason: reason,
                    fireDate: fireDate,
                    scheduledAt: Date()
                )
                pendingAuthRecoverySurfaceIds[sourceAlarmId] = newUUID
                recordAlarmKitRecoverySurfaceScheduled(sourceAlarmId: sourceAlarmId)
                print("[AlarmKitRecovery] ✅ pre-armed surface scheduled source=\(sourceAlarmId) surface=\(newUUID.uuidString) fireAt=\(String(format: "%.1f", delay))s")
            } catch {
                print("[AlarmKitRecovery] ❌ pre-arm schedule failed source=\(sourceAlarmId) reason=\(reason) error=\(error.localizedDescription)")
            }
        }
#else
        _ = sourceAlarmId
        _ = resolvedRunId
        _ = reason
        _ = delay
#endif
    }

    /// Cancels the pre-armed recovery for `sourceAlarmId` ONLY if `runId`
    /// matches the one stored at pre-arm time. Stale callers (from a previous
    /// repeating-alarm occurrence) cannot accidentally cancel the live one.
    ///
    /// Allowed cancellation reasons: `engine-audible-verified`,
    /// `app-active-engine-verified`, `final-stop`, `snooze`, `mission-complete`.
    func cancelPreArmedAlarmKitRecovery(
        sourceAlarmId: String,
        runId: String? = nil,
        reason: String
    ) {
        guard let pre = preArmedRecoveryBySource[sourceAlarmId] else { return }
        if let runId, runId != pre.runId {
            print("[AlarmKitRecovery] cancellation skipped stale run source=\(sourceAlarmId) requestedRun=\(runId) preArmedRun=\(pre.runId)")
            return
        }
        preArmedRecoveryBySource.removeValue(forKey: sourceAlarmId)
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: pre.surfaceUUID)
        }
#endif
        if pendingAuthRecoverySurfaceIds[sourceAlarmId] == pre.surfaceUUID {
            pendingAuthRecoverySurfaceIds.removeValue(forKey: sourceAlarmId)
        }
        print("[AlarmKitRecovery] cancelled pre-armed recovery source=\(sourceAlarmId) reason=\(reason) preArmedReason=\(pre.reason)")
    }

    /// Verifies engine is genuinely audible (playing, currentTime advancing,
    /// outputVolume > floor) and only then cancels the pre-armed recovery.
    /// Safe to call at any time — no-op when no pre-arm exists.
    @discardableResult
    func verifyAndCancelPreArmedRecoveryIfEngineAudible(
        sourceAlarmId: String,
        reason: String
    ) async -> Bool {
        guard preArmedRecoveryBySource[sourceAlarmId] != nil else { return false }
        let audible = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
            reason: "prearm-verify-\(reason)"
        )
        if !audible {
            print("[AlarmKitRecovery] kept fallback reason=app-engine-not-audible source=\(sourceAlarmId) (\(reason))")
            return false
        }
        cancelPreArmedAlarmKitRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "engine-audible-verified-\(reason)"
        )
        stopAlarmKitRealertLoop(sourceAlarmId: sourceAlarmId, reason: "engine-audible-verified")
        return true
    }

    func hasPreArmedRecovery(sourceAlarmId: String) -> Bool {
        preArmedRecoveryBySource[sourceAlarmId] != nil
    }

    func hasAlarmKitAlertingSurface(sourceAlarmId: String) -> Bool {
        isAlarmKitAlreadyAlerting(for: sourceAlarmId)
    }

    func hasPendingAuthRecoverySurface(sourceAlarmId: String) -> Bool {
        pendingAuthRecoverySurfaceIds[sourceAlarmId] != nil
    }

    private func installAppEngineVolumeResetFailedObserverIfNeeded() {
        guard appEngineVolumeResetFailedObserver == nil else { return }
        appEngineVolumeResetFailedObserver = NotificationCenter.default.addObserver(
            forName: .alarmoAppEngineVolumeResetFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let sourceAlarmId = notification.userInfo?["sourceAlarmId"] as? String
            let currentVolume = notification.userInfo?["currentVolume"] as? Float ?? -1
            let runId = notification.userInfo?["runId"] as? String
            self.handleAppEngineVolumeResetFailed(
                sourceAlarmId: sourceAlarmId,
                runId: runId,
                currentVolume: currentVolume
            )
        }
    }

    @MainActor
    private func handleAppEngineVolumeResetFailed(
        sourceAlarmId: String?,
        runId: String?,
        currentVolume: Float
    ) {
        guard let sourceAlarmId else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        print(
            "[VolumeSafety] reset failed source=\(sourceAlarmId) run=\(runId ?? "nil") " +
            "output=\(String(format: "%.2f", currentVolume)) — AppEngine unsafe, scheduling recovery"
        )
        scheduleForbiddenAudioStateRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "appengine-volume-reset-failed"
        )
    }

    /// Schedules audible AlarmKit recovery when AppEngine is silently preparing
    /// with no audible owner — the forbidden silent state.
    func scheduleForbiddenAudioStateRecovery(sourceAlarmId: String, reason: String) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let explicitSuppressionRecovery = shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId)
        if UIApplication.shared.applicationState != .active,
           !explicitSuppressionRecovery,
           hasAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId) {
            print("[ForbiddenAudioState] suppressed — AlarmKit remains locked owner until explicit suppression source=\(sourceAlarmId) reason=\(reason)")
            AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "forbidden-state-preserve-\(reason)")
            return
        }
        if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression,
           explicitSuppressionRecovery {
            print("[ForbiddenAudioState] trying AppEngine suppression takeover source=\(sourceAlarmId) reason=\(reason)")
            _ = startAppEngineAfterAlarmKitSuppression(
                sourceAlarmId: sourceAlarmId,
                reason: "forbidden-state-\(reason)"
            )
            return
        }
        print("[ForbiddenAudioState] scheduling AlarmKit recovery source=\(sourceAlarmId) reason=\(reason)")
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "forbidden-state-\(reason)")
        scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "forbidden-state-\(reason)",
            delay: 0.5,
            allowEngineFirst: false,
            allowAlarmKitFallback: true,
            force: true,
            bypassNoUIPreference: true
        )
    }

    /// Arms strict async verification for a locked engine candidate — keeps AlarmKit
    /// recovery alive until `confirmLockedEngineVerified` succeeds.
    func beginLockedEngineCandidateVerification(sourceAlarmId: String, reason: String) {
        armEngineAudibleVerification(sourceAlarmId: sourceAlarmId, reason: "locked-candidate-\(reason)")
    }

    /// Returns the surface UUID of the active pre-arm — used by the AlarmKit
    /// alerting handler to recognise its own scheduled recovery and let it ring.
    func preArmedRecoverySurface(sourceAlarmId: String) -> UUID? {
        preArmedRecoveryBySource[sourceAlarmId]?.surfaceUUID
    }

    /// Unified entry for side-button / screen-off / slide-to-stop-cancel-auth while
    /// the alarm is active but the app is not foreground.
    ///
    /// **Reliability strategy:**
    /// 1. If nothing is audible, arm system-owned AlarmKit respawn (pre-arm + re-alert loop).
    /// 2. Attempt locked no-UI engine recovery while the app may still be alive.
    /// 3. Engine watchdog cancels pre-arm only after engine is verified audible.
    func handleLockedHardwareSuppression(
        sourceAlarmId: String,
        surfaceAlarmId: String?,
        scenePhaseLabel: String,
        reason: String = "side-button-or-lock-suppression"
    ) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }

        print("[HardwareRecovery] side/lock detected source=\(sourceAlarmId) scene=\(scenePhaseLabel) reason=\(reason)")

        // Side-button / screen-off during a ring is always treated as suppression.
        recordHardwareSuppressionEvent(sourceAlarmId: sourceAlarmId)
        explicitAlarmKitSuppressionSourceIds.insert(sourceAlarmId)

        let explicitSuppression = shouldAllowAppEngineSuppressionTakeover(
            sourceAlarmId: sourceAlarmId,
            reason: "\(reason)-\(scenePhaseLabel)"
        )

        // Only bootstrap the ring coordinator after a REAL suppression/auth event.
        // During the normal initial locked/background AlarmKit-owned ring, forcing
        // the coordinator active here causes the exact unwanted early AppEngine
        // takeover path the user is trying to avoid.
        if explicitSuppression, ringCoordinator?.isRinging != true {
            _ = startAlarmImmediatelyIfPossible(alarmId: sourceAlarmId)
        }

        if explicitSuppression {
            evaluateNoAudibleOwnerRecoveryIfNeeded(sourceAlarmId: sourceAlarmId, reason: reason)
        }

        if explicitSuppression {
            emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: reason)
            AlarmAudioStateController.shared.recordPossibleHardwareSuppression(
                reason: reason,
                scenePhase: scenePhaseLabel
            )
        }

        if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
            _ = startAppEngineAfterAlarmKitSuppression(
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: surfaceAlarmId,
                reason: "\(reason)-\(scenePhaseLabel)"
            )
            if explicitSuppression {
                scheduleHardwareSuppressionCheck(
                    sourceAlarmId: sourceAlarmId,
                    delay: 2.0,
                    reason: reason
                )
            }
            return
        }

        recordHardwareSuppressionEvent(sourceAlarmId: sourceAlarmId)

        // STEP 1 — Try AppEngine locked no-UI recovery (only takes effect if
        // the app is still running and audio is allowed in background).
        AlarmAudioStateController.shared.attemptImmediateLockedRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: reason
        )

        scheduleHardwareSuppressionCheck(
            sourceAlarmId: sourceAlarmId,
            delay: 2.0,
            reason: reason
        )

        let resolvedSurface = surfaceAlarmId
            ?? AlarmAuthHandoffStore.surfaceAlarmId()
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? sourceAlarmId
        AlarmBackgroundAudioBridge.shared.start(
            surfaceAlarmId: resolvedSurface,
            sourceAlarmId: sourceAlarmId
        )
        ringCoordinator?.reassertRingingAudio(reason: "locked-hardware-\(reason)")

        // STEP 3 — Try the orchestrated engine recovery; if it succeeds it will
        // call verifyAndCancelPreArmedRecoveryIfEngineAudible after verification.
        attemptLockedNoUIEngineRecovery(
            sourceAlarmId: sourceAlarmId,
            reason: "locked-hardware-\(reason)"
        )

        // STEP 4 — Respawn AlarmKit when ringer was suppressed (side button) or still silent.
        let needsRespawn = shouldForceAlarmKitRespawnDespiteAlertingSurface(
            sourceAlarmId: sourceAlarmId,
            reason: reason
        ) || !isAlarmAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: "post-engine-\(reason)")
        if needsRespawn {
            orchestrateAlarmKitRespawnWhenSoundGone(
                sourceAlarmId: sourceAlarmId,
                reason: reason,
                forceAfterDismissal: true
            )
        }
    }

    /// Detects the "dead audio" state — the alarm is still ringing but nothing is
    /// audibly playing while the app is backgrounded/locked (AlarmKit suppressed by
    /// the side button and the engine never took over) — and schedules one audible
    /// recovery. Routes through `scheduleAudibleAlarmKitRecoveryIfNeeded`, which is
    /// engine-first (no-UI) and falls back to an audible AlarmKit re-alert.
    func detectAndRecoverDeadAudioState(sourceAlarmId: String, reason: String) {
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "detect-\(reason)")
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            print("[DeadAudio] skipped because final stop/snooze true source=\(sourceAlarmId)")
            return
        }
        let state = AlarmAuthHandoffStore.alarmState()
        let ringing = state == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
        guard ringing else {
            print("[DeadAudio] skipped — alarm not ringing (state=\(state?.rawValue ?? "nil")) source=\(sourceAlarmId)")
            return
        }
        if UIApplication.shared.applicationState == .active {
            print("[DeadAudio] skipped because app active; should restore UI instead source=\(sourceAlarmId)")
            return
        }
        if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            print("[DeadAudio] skipped — engine confirmed playing source=\(sourceAlarmId)")
            return
        }
        let reference = lastConfirmedAudibleAtBySource[sourceAlarmId]
            ?? alarmKitWatchdogStartedAtBySource[sourceAlarmId]
        let silenceDuration = reference.map { Date().timeIntervalSince($0) } ?? alarmKitAudibleMaxSilence
        if (AlarmAudioStateController.shared.hardwareRecoveryPending
            || AlarmAuthHandoffStore.isAuthRecoveryPending()),
           silenceDuration < alarmKitAudibleMaxSilence {
            print("[DeadAudio] skipped because recovery already pending (silence \(String(format: "%.1f", silenceDuration))s < \(alarmKitAudibleMaxSilence)s) source=\(sourceAlarmId)")
            return
        }
        if AlarmAudioStateController.shared.hardwareRecoveryPending
            || AlarmAuthHandoffStore.isAuthRecoveryPending() {
            print("[DeadAudio] recovery pending but silence >= \(alarmKitAudibleMaxSilence)s — forcing retry source=\(sourceAlarmId)")
            AlarmAuthHandoffStore.setAuthRecoveryPending(false)
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
        }
        let phase = AlarmAudioStateController.shared.phase
        let appState = UIApplication.shared.applicationState.rawValue
        if phase == .appEnginePreparing {
            print("[DeadAudio] appEnginePreparing + background + engine not playing is recoverable failure source=\(sourceAlarmId)")
        }
        print("[DeadAudio] detected source=\(sourceAlarmId) phase=\(phase.rawValue) appState=\(appState) enginePlaying=false reason=\(reason)")
        // ANTI-OSCILLATION: once the engine has been proven inaudible while
        // locked (typically because media outputVolume is at or below the
        // floor), engine-first recovery cannot succeed and only burns owner
        // flips. Skip directly to AlarmKit-only recovery and let AlarmKit own
        // audio until the user unlocks or raises media volume.
        let engineProvenInaudible = AlarmAudioStateController.shared.engineInaudibleWhileLockedProven
        if engineProvenInaudible {
            if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
                print("[RecoveryPolicy] engine previously inaudible — no AlarmKit respawn; retrying AppEngine takeover source=\(sourceAlarmId)")
                _ = startAppEngineAfterAlarmKitSuppression(
                    sourceAlarmId: sourceAlarmId,
                    reason: "dead-audio-engine-proven-inaudible-\(reason)"
                )
                return
            }
            print("[RecoveryPolicy] skipping engine-first recovery — engine proven inaudible while locked source=\(sourceAlarmId)")
            orchestrateAlarmKitRespawnWhenSoundGone(
                sourceAlarmId: sourceAlarmId,
                reason: "dead-audio-\(reason)"
            )
            return
        }
        if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
            print("[DeadAudio] no-respawn policy — trying AppEngine suppression takeover source=\(sourceAlarmId)")
            _ = startAppEngineAfterAlarmKitSuppression(
                sourceAlarmId: sourceAlarmId,
                reason: "dead-audio-\(reason)"
            )
            return
        }
        if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            print("[LockedNoUI] dead-audio → engine-only recovery (no AlarmKit UI) source=\(sourceAlarmId)")
            attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: "dead-audio-\(reason)")
            return
        }
        print("[DeadAudio] scheduling engine-first then AlarmKit fallback source=\(sourceAlarmId)")
        scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "dead-audio-\(reason)",
            delay: 0.5,
            allowEngineFirst: true,
            allowAlarmKitFallback: true,
            force: true
        )
    }

    func handleHardwareSuppressionCheck(sourceAlarmId: String, reason: String) {
        hardwareSuppressionCheckWorkItems.removeValue(forKey: sourceAlarmId)
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression {
                print("[HardwareRecovery] no-respawn check — retrying AppEngine suppression takeover source=\(sourceAlarmId) reason=\(reason)")
                _ = startAppEngineAfterAlarmKitSuppression(
                    sourceAlarmId: sourceAlarmId,
                    reason: "hardware-check-\(reason)"
                )
            } else {
                print("[HardwareRecovery] disabled — no auto-recovery after suppression source=\(sourceAlarmId) reason=\(reason)")
            }
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
            AlarmAuthHandoffStore.setAuthRecoveryPending(false)
            return
        }
        let appState = UIApplication.shared.applicationState
        let engineHealthy = AlarmAudioStateController.shared.appEngineConfirmedPlaying()
        print("[HardwareRecovery] delayed check fired source=\(sourceAlarmId) appState=\(appState.rawValue) engineHealthy=\(engineHealthy) reason=\(reason)")

        let alarmRinging = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
        guard alarmRinging else {
            print("[HardwareRecovery] skipped; alarm not ringing source=\(sourceAlarmId)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[HardwareRecovery] skipped because final stop/snooze already pressed source=\(sourceAlarmId)")
            return
        }
        if AlarmAudioStateController.shared.hardwareRecoveryPending,
           AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
            print("[HardwareRecovery] skipped; recovery pending and engine playing source=\(sourceAlarmId)")
            return
        }
        if AlarmAudioStateController.shared.hardwareRecoveryPending {
            print("[HardwareRecovery] recovery pending but engine silent — continuing check source=\(sourceAlarmId)")
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
        }

        if appState == .active && engineHealthy {
            print("[HardwareRecovery] skipped because engine healthy source=\(sourceAlarmId)")
            ringCoordinator?.reassertRingingAudio(reason: "hardware-check-engine-healthy")
            return
        }

        if appState == .active && !engineHealthy {
            print("[HardwareRecovery] app active; reasserting AppEngine source=\(sourceAlarmId)")
            ringCoordinator?.reassertRingingAudio(reason: "hardware-check-app-active")
            AlarmAudioStateController.shared.handleAppBecameActive()
            return
        }

        if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            print("[LockedNoUI] hardware check → engine-only recovery source=\(sourceAlarmId) reason=\(reason)")
            attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }

        if isAlarmKitAlreadyAlerting(for: sourceAlarmId) {
            if !engineHealthy && appState != .active {
                print("[HardwareRecovery] AlarmKit alerting but engine silent — treating as dead audio source=\(sourceAlarmId)")
                detectAndRecoverDeadAudioState(
                    sourceAlarmId: sourceAlarmId,
                    reason: "side-button-or-lock-suppression"
                )
                return
            }
            print("[HardwareRecovery] skipped; AlarmKit already alerting and engine healthy source=\(sourceAlarmId)")
            scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
            return
        }

        let now = Date()
        let engineSilent = !AlarmContinuousAudioEngine.shared.confirmStillPlaying()
        if engineSilent,
           let lastHW = AlarmAudioStateController.shared.lastHardwareRecoveryScheduledAt,
           now.timeIntervalSince(lastHW) < hardwareRecoveryMinimumInterval {
            print("[HardwareRecovery] throttled but engine silent — routing to dead-audio detector source=\(sourceAlarmId)")
            detectAndRecoverDeadAudioState(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }
        if !engineSilent,
           let lastHW = AlarmAudioStateController.shared.lastHardwareRecoveryScheduledAt,
           now.timeIntervalSince(lastHW) < hardwareRecoveryMinimumInterval {
            print("[HardwareRecovery] skipped; throttled source=\(sourceAlarmId)")
            return
        }

        print("[HardwareRecovery] scheduling recovery source=\(sourceAlarmId) reason=\(reason)")
        if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }
        AlarmAudioStateController.shared.markHardwareRecoveryPending(true)
        scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "side-button-suppressed-current-surface",
            delay: 0.5,
            allowEngineFirst: true,
            allowAlarmKitFallback: true,
            force: true
        )
    }

    /// Lock-screen / AlarmKit secondary-button snooze. Honors per-alarm interval and max count.
    @MainActor
    func performAlarmKitSnooze(sourceAlarmId: String, surfaceAlarmId: String?) async -> Bool {
        guard let sourceUUID = UUID(uuidString: sourceAlarmId),
              let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: sourceUUID) else {
            print("[AlarmKitSnooze] failed — alarm not found source=\(sourceAlarmId)")
            return false
        }
        guard let totalSeconds = alarm.resolvedSnoozeTotalSeconds else {
            print("[AlarmKitSnooze] failed — snooze disabled source=\(sourceAlarmId)")
            return false
        }

        let newCount = AlarmAuthHandoffStore.recordRingSessionSnooze(sourceAlarmId: sourceAlarmId)
        if newCount > max(1, alarm.snoozeCount) {
            print("[AlarmKitSnooze] rejected — max snoozes exceeded count=\(newCount) limit=\(alarm.snoozeCount) source=\(sourceAlarmId)")
            return false
        }

        print("🧭 [ALARMTRACE_ACTION] EVENT=ALARMKIT_SNOOZE_INTENT_ACCEPTED SOURCE_ID=\(sourceAlarmId) SURFACE_ID=\(surfaceAlarmId ?? "nil") COUNT=\(newCount) TOTAL_SECONDS=\(totalSeconds)")

        cancelAllHardwareRecoveryState(sourceAlarmId: sourceAlarmId)
        cancelPreArmedAlarmKitRecovery(sourceAlarmId: sourceAlarmId, reason: "alarmkit-snooze")
        cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
        cancelRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
        cancelAllAlarmKitUnlockPrompts()
        if #available(iOS 26.0, *) {
            cancelAllBackupAlarmKitChains()
        }

        AlarmBackgroundAudioBridge.shared.stop()
        if AlarmContinuousAudioEngine.shared.isEngineActive {
            AlarmAudioStateController.shared.recordStopped(reason: "alarmkit-snooze")
            AlarmContinuousAudioEngine.shared.stop(reason: "alarmkit-snooze")
        }
        nukeAllAlertingAlarmKitSurfaces()
        dismissLinkedAlarmKitSurfaces(sourceAlarmId: sourceAlarmId)
        if let surfaceAlarmId {
            dismissLinkedAlarmKitSurfaces(sourceAlarmId: surfaceAlarmId)
        }
        markAlarmFlowCompleted(alarmId: sourceAlarmId)
        if let surfaceAlarmId {
            markAlarmFlowCompleted(alarmId: surfaceAlarmId)
        }
        clearCompletedAlarmFlow(alarmId: sourceAlarmId)

        AlarmAuthHandoffStore.clearOnFinalStop(preserveSnooze: true, reason: "alarmkit-snooze")
        AlarmCustomUIHandoffStore.clear()

        do {
            try await AlarmManagerFacade.shared.snoozeAlarm(
                id: sourceUUID,
                interval: TimeInterval(totalSeconds)
            )
            print("[AlarmKitSnooze] scheduled next ring in \(totalSeconds)s source=\(sourceAlarmId) snoozeCount=\(newCount)/\(alarm.snoozeCount)")
            return true
        } catch {
            print("[AlarmKitSnooze] schedule failed source=\(sourceAlarmId): \(error)")
            return false
        }
    }

    func scheduleAlarmRecoveryOpenAppNotification(
        sourceAlarmId: String,
        runId: String? = nil,
        reason: String
    ) {
        guard alarmRecoveryOpenAppNotificationEnabled else {
            cancelRecoveryPromptNotification(sourceAlarmId: sourceAlarmId, reason: "disabled-\(reason)")
            print("[RecoveryNotification] skipped — recovery open-app banner disabled reason=\(reason)")
            return
        }
        let now = Date()
        if let last = lastRecoveryNotificationScheduledAt[sourceAlarmId],
           now.timeIntervalSince(last) < Self.recoveryNotificationCooldown {
            print("[RecoveryNotification] skipped duplicate source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if UIApplication.shared.applicationState == .active,
           AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: "recovery-notification-\(reason)") {
            print("[RecoveryNotification] skipped — app active and engine verified source=\(sourceAlarmId) reason=\(reason)")
            return
        }

        let identifier = RecoveryOpenAppNotification.identifier(for: sourceAlarmId)
        let legacyIdentifier = RecoveryPrompt.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier, legacyIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier, legacyIdentifier])

        let resolvedRunId = runId ?? currentRunId(for: sourceAlarmId)
        let store = alarmStore ?? AlarmStore.shared
        let hasMissions = UUID(uuidString: sourceAlarmId)
            .flatMap { store.alarm(by: $0)?.hasActiveMissions } ?? false
        let content = UNMutableNotificationContent()
        content.title = "⏰ Alarm is still ringing"
        content.body = hasMissions
            ? "Unlock to open Alarmo and complete your mission."
            : "Unlock to open Alarmo and stop or snooze."
        // Use the dedicated "Unlock to Stop" category so the actionable button
        // foregrounds + authenticates and routes through the unified open-to-stop
        // handoff (NOT a final stop).
        content.categoryIdentifier = AppNotificationCategory.unlockToStop
        content.threadIdentifier = "alarmo.active.\(sourceAlarmId)"
        content.userInfo = [
            RecoveryOpenAppNotification.userInfoSourceAlarmIDKey: sourceAlarmId,
            RecoveryOpenAppNotification.userInfoRunIdKey: resolvedRunId,
            AlarmKitUnlockPrompt.userInfoSourceAlarmIDKey: sourceAlarmId,
            AlarmKitUnlockPrompt.userInfoSurfaceAlarmIDKey: sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        lastRecoveryNotificationScheduledAt[sourceAlarmId] = now
        center.add(request) { error in
            if let error {
                print("[RecoveryNotification] schedule failed source=\(sourceAlarmId) reason=\(reason): \(error)")
            } else {
                print("[RecoveryNotification] scheduled source=\(sourceAlarmId) reason=\(reason)")
            }
        }
    }

    func scheduleRecoveryPromptNotification(sourceAlarmId: String, surfaceAlarmId: String? = nil) {
        scheduleAlarmRecoveryOpenAppNotification(
            sourceAlarmId: sourceAlarmId,
            reason: "recovery-prompt-\(surfaceAlarmId ?? "none")"
        )
    }

    func cancelRecoveryPromptNotification(sourceAlarmId: String, reason: String = "cleanup") {
        let identifiers = [
            RecoveryOpenAppNotification.identifier(for: sourceAlarmId),
            RecoveryPrompt.identifier(for: sourceAlarmId)
        ]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        lastRecoveryNotificationScheduledAt.removeValue(forKey: sourceAlarmId)
        print("[RecoveryNotification] cancelled source=\(sourceAlarmId) reason=\(reason)")
    }

    /// Removes all pending/delivered "Unlock to open Alarmo" recovery banners.
    func purgeAllRecoveryOpenAppNotifications(reason: String) {
        let center = UNUserNotificationCenter.current()
        let prefixes = [
            RecoveryOpenAppNotification.identifierPrefix,
            RecoveryPrompt.identifierPrefix
        ]
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            print("[RecoveryNotification] purged \(ids.count) pending banner(s) reason=\(reason)")
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map(\.request.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            print("[RecoveryNotification] purged \(ids.count) delivered banner(s) reason=\(reason)")
        }
    }

    /// True when an alarm ring session is live (in-app, persisted, bridge, or AlarmKit alerting).
    @MainActor
    func isLiveAlarmSessionActive(
        ringCoordinator: AlarmRingCoordinator?,
        sourceAlarmId: String? = nil
    ) -> Bool {
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() { return false }
        if AlarmAuthHandoffStore.alarmState() == .ringing { return true }
        if ringCoordinator?.isRinging == true { return true }
        if AlarmAudioStateController.shared.isAlarmRinging { return true }
        if AlarmBackgroundAudioBridge.shared.isPlaying { return true }
        if let sourceAlarmId,
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId,
           AlarmAuthHandoffStore.alarmState() == .ringing {
            return true
        }
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            if let alarms = try? AlarmManager.shared.alarms,
               alarms.contains(where: { $0.state == .alerting }) {
                return true
            }
        }
#endif
        return false
    }

    private func isImminentAppLeaveReason(_ reason: String) -> Bool {
        reason == "willResignActive"
            || reason == "didEnterBackground"
            || reason.hasPrefix("scene-")
    }

    /// Classifies the leave event itself (lock vs Home vs app switcher).
    private func classifyLifecycleLeaveEvent(reason: String) -> AlarmLifecycleState {
        if reason == "didEnterBackground" || reason == "scene-background" {
            if AlarmAppLifecycleSession.isDeviceLockLikely() {
                return .normalDeviceLock
            }
            return .normalBackground
        }
        if reason == "willResignActive" || reason == "scene-inactive" {
            // Protected data unavailable or recent lock signal = side-button lock.
            // Phone still unlocked at inactive = app switcher → force-quit risk.
            if AlarmAppLifecycleSession.isDeviceLockLikely()
                || !UIApplication.shared.isProtectedDataAvailable {
                return .normalDeviceLock
            }
            return .staleAppRisk
        }
        return .normalBackground
    }

    func logLifecycleTransition(_ message: String) {
        print("[Lifecycle] \(message)")
    }

    func recordProtectedDataWillBecomeUnavailable() {
        AlarmAppLifecycleSession.markProtectedDataWillBecomeUnavailable()
        if let sourceId = AlarmAuthHandoffStore.activeRingingAlarmId(),
           !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed(),
           AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging {
            if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression,
               shouldUseLockedNoUIRecovery(sourceAlarmId: sourceId) {
                _ = attemptLockedNoUIEngineRecovery(
                    sourceAlarmId: sourceId,
                    reason: "protected-data-during-explicit-suppression"
                )
                armEngineAudibleVerification(
                    sourceAlarmId: sourceId,
                    reason: "protected-data-during-explicit-suppression"
                )
                return
            }
            print("[ProtectedData] preserving AlarmKit owner; no explicit suppression source=\(sourceId)")
            AlarmAudioStateController.shared.markAlarmKitSurfaceSuppressionRisk(
                sourceAlarmId: sourceId,
                reason: "protected-data-will-become-unavailable"
            )
            evaluateNoAudibleOwnerRecoveryIfNeeded(
                sourceAlarmId: sourceId,
                reason: "protected-data-will-become-unavailable"
            )
        }
    }

    func recordProtectedDataDidBecomeAvailable() {
        AlarmAppLifecycleSession.markProtectedDataDidBecomeAvailable()
    }

    /// Classifies a lifecycle event so callers can avoid punishing normal lock /
    /// Home Screen backgrounding with "reopen the app" warnings.
    @MainActor
    func classifyLifecycleState(
        ringCoordinator: AlarmRingCoordinator?,
        alarms: [Alarm],
        reason: String
    ) -> AlarmLifecycleState {
        let leave = classifyLifecycleLeaveEvent(reason: reason)
        let hasFutureAlarm = nearestUpcomingEnabledAlarm(alarms: alarms, from: Date()) != nil
        let isRinging = isLiveAlarmSessionActive(ringCoordinator: ringCoordinator, sourceAlarmId: nil)

        if isRinging {
            if leave == .staleAppRisk {
                print("[LifecycleClassifier] state=\(leave.rawValue) liveRinging=true reason=\(reason)")
                return .staleAppRisk
            }
            print("[LifecycleClassifier] state=\(AlarmLifecycleState.activeRingingBackground.rawValue) leave=\(leave.rawValue) reason=\(reason)")
            return .activeRingingBackground
        }

        if hasFutureAlarm {
            print("[LifecycleClassifier] state=\(leave.rawValue) futureAlarmScheduled=true reason=\(reason)")
        } else {
            print("[LifecycleClassifier] state=\(leave.rawValue) reason=\(reason)")
        }
        return leave
    }

    func logColdStartLifecycleInference() {
        AlarmAppLifecycleSession.logColdStartInferenceIfNeeded()
    }

    func markCleanForegroundSession(reason: String) {
        AlarmAppLifecycleSession.markCleanForegroundEntry(reason: reason)
    }

    /// Single entry point for leave events: cancel warnings on normal lock/background,
    /// keep the pre-armed fuse on switcher force-quit risk, refresh live-alarm fuse when needed.
    @MainActor
    func handleAppLeaveLifecycleEvent(
        ringCoordinator: AlarmRingCoordinator?,
        alarms: [Alarm],
        reason: String
    ) {
        let lifecycle = classifyLifecycleState(
            ringCoordinator: ringCoordinator,
            alarms: alarms,
            reason: reason
        )
        AlarmAppLifecycleSession.recordLeave(state: lifecycle, reason: reason)

        let isRinging = isLiveAlarmSessionActive(
            ringCoordinator: ringCoordinator,
            sourceAlarmId: nil
        )

        switch lifecycle {
        case .normalLock, .normalDeviceLock, .normalBackground:
            AlarmAppLifecycleSession.recordNormalBackgroundSnapshot(
                alarms: alarms,
                reason: reason,
                lifecycle: lifecycle
            )
            if isRinging {
                cancelLiveAlarmForceQuitWarnings(ringCoordinator: ringCoordinator, reason: reason)
            } else {
                cancelFutureAlarmForceCloseWarnings(reason: reason)
            }
        case .staleAppRisk:
            purgeAllOpenAlarmoAgainNotifications(reason: "stale-app-risk-\(reason)")
            cancelArmedAlarmCloseWarning(reason: "stale-app-risk-\(reason)")
            print("[ForceQuitPolicy] Open-Alarmo-again reminders disabled reason=\(reason)")
        case .activeRingingBackground:
            cancelLiveAlarmForceQuitWarnings(ringCoordinator: ringCoordinator, reason: reason)
        case .futureAlarmOnly:
            break
        }

        if isRinging {
            AlarmAudioStateController.shared.evaluateForbiddenAudioStateIfNeeded(reason: "app-leave-\(reason)")
        }
    }

    @MainActor
    func cancelLiveAlarmForceQuitWarnings(
        ringCoordinator: AlarmRingCoordinator?,
        reason: String
    ) {
        guard let sourceAlarmId = resolvedLiveAlarmSourceId(ringCoordinator: ringCoordinator) else { return }
        cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
        print("[ForceQuitPolicy] cancelled live-alarm leave warnings source=\(sourceAlarmId) reason=\(reason)")
    }

    @MainActor
    private func refreshLiveAlarmForceQuitStandbyIfNeeded(
        ringCoordinator: AlarmRingCoordinator?,
        reason: String
    ) {
        guard let ringCoordinator else { return }
        guard let sourceAlarmId = resolvedLiveAlarmSourceId(ringCoordinator: ringCoordinator) else { return }
        let surfaceAlarmId = resolvedLiveAlarmSurfaceId(
            ringCoordinator: ringCoordinator,
            fallbackSourceId: sourceAlarmId
        )
        let alarmName: String? = {
            if let name = ringCoordinator.activeAlarm?.name { return name }
            if let uuid = UUID(uuidString: sourceAlarmId),
               let alarm = (alarmStore ?? AlarmStore.shared).alarm(by: uuid) {
                return alarm.name
            }
            return nil
        }()
        refreshSwipeAwayWarningStandby(
            ringCoordinator: ringCoordinator,
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName,
            reason: reason
        )
    }

    @MainActor
    private func resolvedLiveAlarmSourceId(ringCoordinator: AlarmRingCoordinator?) -> String? {
        if let alarm = ringCoordinator?.activeAlarm { return alarm.id.uuidString }
        if let persisted = AlarmAuthHandoffStore.activeRingingAlarmId() { return persisted }
        if let bridgeSource = AlarmBackgroundAudioBridge.shared.currentSourceAlarmID { return bridgeSource }
        if let surface = AlarmBackgroundAudioBridge.shared.currentAlarmID {
            return AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surface)
        }
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            if let alerting = try? AlarmManager.shared.alarms.first(where: { $0.state == .alerting }) {
                return AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alerting.id.uuidString)
            }
        }
#endif
        return nil
    }

    @MainActor
    private func resolvedLiveAlarmSurfaceId(
        ringCoordinator: AlarmRingCoordinator?,
        fallbackSourceId: String
    ) -> String? {
        AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? AlarmAuthHandoffStore.surfaceAlarmId()
            ?? fallbackSourceId
    }

    /// Alarmy-style warning: leaving Alarmo (home, app switcher, swipe-up) means only basic
    /// AlarmKit sound plays until the user opens the app again.
    @MainActor
    func deliverBasicSoundOnlyWarningOnAppLeave(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil,
        reason: String
    ) {
        guard openAlarmoAgainNotificationsEnabled else {
            cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
            return
        }
        let appState = UIApplication.shared.applicationState
        let imminentLeave = isImminentAppLeaveReason(reason)
        guard imminentLeave || appState == .inactive || appState == .background else {
            print("[ForegroundSoundReminder] skipped — app still active source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }

        let now = Date()
        if !imminentLeave,
           let last = lastBasicSoundWarningDeliveredAtBySource[sourceAlarmId],
           now.timeIntervalSince(last) < basicSoundWarningMinimumInterval {
            print("[ForegroundSoundReminder] throttled source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        lastBasicSoundWarningDeliveredAtBySource[sourceAlarmId] = now

        let identifier = ForegroundSoundReminder.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let content = buildForegroundSoundReminderContent(
            sourceAlarmId: sourceAlarmId,
            alarmName: alarmName
        )
        content.categoryIdentifier = AppNotificationCategory.alarmForegroundSoundReminder
        content.threadIdentifier = "alarmo.foreground.sound.reminder"
        content.userInfo = [
            ForegroundSoundReminder.userInfoSourceAlarmIDKey: sourceAlarmId,
            ForegroundSoundReminder.userInfoSurfaceAlarmIDKey: surfaceAlarmId ?? sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if let attachment = brandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        // Slightly longer delay on imminent leave so iOS accepts the request before force-quit.
        let delay: TimeInterval = imminentLeave ? 1.0 : 0.1
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("[ForegroundSoundReminder] deliver failed source=\(sourceAlarmId) reason=\(reason) error=\(error)")
            } else {
                print("[ForegroundSoundReminder] delivered basic-sound warning source=\(sourceAlarmId) reason=\(reason) appState=\(appState.rawValue) delay=\(delay)s")
            }
        }
    }

    /// Keeps a short-fuse notification armed while the app is foreground during a live alarm.
    /// If the user swipes the app away, iOS still delivers it after the process dies.
    @MainActor
    func refreshSwipeAwayWarningStandby(
        ringCoordinator: AlarmRingCoordinator?,
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil,
        reason: String
    ) {
        guard openAlarmoAgainNotificationsEnabled else {
            cancelSwipeAwayWarningStandby(sourceAlarmId: sourceAlarmId, reason: "disabled-\(reason)")
            cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
            return
        }
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard isLiveAlarmSessionActive(
            ringCoordinator: ringCoordinator,
            sourceAlarmId: sourceAlarmId
        ) else { return }

        let identifier = SwipeAwayWarningStandby.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = buildForegroundSoundReminderContent(
            sourceAlarmId: sourceAlarmId,
            alarmName: alarmName
        )
        content.categoryIdentifier = AppNotificationCategory.alarmForegroundSoundReminder
        content.threadIdentifier = "alarmo.swipeAway.warning"
        content.userInfo = [
            ForegroundSoundReminder.userInfoSourceAlarmIDKey: sourceAlarmId,
            ForegroundSoundReminder.userInfoSurfaceAlarmIDKey: surfaceAlarmId ?? sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if let attachment = brandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: SwipeAwayWarningStandby.fireDelay,
            repeats: false
        )
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("[SwipeAwayWarning] arm failed source=\(sourceAlarmId) reason=\(reason) error=\(error)")
            } else {
                print("[SwipeAwayWarning] armed source=\(sourceAlarmId) reason=\(reason) delay=\(SwipeAwayWarningStandby.fireDelay)s")
            }
        }
    }

    func cancelSwipeAwayWarningStandby(sourceAlarmId: String, reason: String = "cleanup") {
        let identifier = SwipeAwayWarningStandby.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("[SwipeAwayWarning] cancelled source=\(sourceAlarmId) reason=\(reason)")
    }

    /// Disabled — superseded by `ForceQuitWarning` ("Alarmo was closed") on
    /// `applicationWillTerminate`. The old "🥲 Open Alarmy again" standby caused
    /// duplicate warnings.
    private let armedAlarmCloseWarningEnabled = false

    private func canScheduleInformationalNotifications() -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            print("[ArmedCloseWarning] skipped; notification permission not usable status=\(authorizationStatus.rawValue)")
            return false
        }
    }

    @MainActor
    func refreshArmedAlarmCloseWarningStandby(alarm: Alarm, fireDate: Date, reason: String) {
        guard armedAlarmCloseWarningEnabled else {
            cancelArmedAlarmCloseWarning(reason: "disabled-\(reason)")
            return
        }
        guard canScheduleInformationalNotifications() else { return }
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard alarm.enabled else { return }
        guard fireDate.timeIntervalSinceNow > 1 else { return }
        guard !isLiveAlarmSessionActive(ringCoordinator: ringCoordinator, sourceAlarmId: alarm.id.uuidString) else {
            return
        }

        let sourceAlarmId = alarm.id.uuidString
        let center = UNUserNotificationCenter.current()
        if let last = lastArmedAlarmCloseWarningSourceId, last != sourceAlarmId {
            center.removePendingNotificationRequests(withIdentifiers: [
                ArmedAlarmCloseWarningStandby.standbyIdentifier(for: last),
                ArmedAlarmCloseWarningStandby.immediateIdentifier(for: last)
            ])
            center.removeDeliveredNotifications(withIdentifiers: [
                ArmedAlarmCloseWarningStandby.standbyIdentifier(for: last),
                ArmedAlarmCloseWarningStandby.immediateIdentifier(for: last)
            ])
        }
        lastArmedAlarmCloseWarningSourceId = sourceAlarmId
        center.removePendingNotificationRequests(withIdentifiers: [
            ArmedAlarmCloseWarningStandby.standbyIdentifier(for: sourceAlarmId)
        ])
        center.removeDeliveredNotifications(withIdentifiers: [
            ArmedAlarmCloseWarningStandby.immediateIdentifier(for: sourceAlarmId)
        ])

        let content = buildArmedAlarmCloseWarningContent(alarmName: alarm.name)
        content.categoryIdentifier = AppNotificationCategory.appOpenReminder
        content.threadIdentifier = "alarmo.armed.close.warning"
        content.userInfo = [
            ArmedAlarmCloseWarningStandby.userInfoAlarmIDKey: sourceAlarmId,
            AlarmNotificationKind.userInfoKey: AlarmNotificationKind.openAppOnly
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if let attachment = brandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: ArmedAlarmCloseWarningStandby.fireDelay,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: ArmedAlarmCloseWarningStandby.standbyIdentifier(for: sourceAlarmId),
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("[ArmedCloseWarning] standby arm failed source=\(sourceAlarmId) reason=\(reason) error=\(error)")
            } else {
                print("[ArmedCloseWarning] standby armed source=\(sourceAlarmId) reason=\(reason) delay=\(ArmedAlarmCloseWarningStandby.fireDelay)s")
            }
        }
    }

    /// Cancels all future-alarm force-close warning paths. Used when the user
    /// normally locks the phone or backgrounds to Home Screen (app stays in
    /// switcher) — not when they force-quit from the switcher.
    func cancelFutureAlarmForceCloseWarnings(reason: String) {
        purgeAllOpenAlarmoAgainNotifications(reason: reason)
        cancelArmedAlarmCloseWarning(reason: reason)
        cancelAppClosedWarning(reason: reason)
        print("[ArmedCloseWarning] cancelled future-alarm force-close warnings reason=\(reason)")
    }

    func cancelArmedAlarmCloseWarning(reason: String = "cleanup") {
        let center = UNUserNotificationCenter.current()
        if let sourceAlarmId = lastArmedAlarmCloseWarningSourceId {
            center.removePendingNotificationRequests(withIdentifiers: [
                ArmedAlarmCloseWarningStandby.standbyIdentifier(for: sourceAlarmId),
                ArmedAlarmCloseWarningStandby.immediateIdentifier(for: sourceAlarmId)
            ])
            center.removeDeliveredNotifications(withIdentifiers: [
                ArmedAlarmCloseWarningStandby.standbyIdentifier(for: sourceAlarmId),
                ArmedAlarmCloseWarningStandby.immediateIdentifier(for: sourceAlarmId)
            ])
        }
        // Backward compatibility cleanup for older single-ID implementation.
        center.removePendingNotificationRequests(withIdentifiers: ["alarmo.armedAlarmCloseWarning.standby"])
        center.removeDeliveredNotifications(withIdentifiers: ["alarmo.armedAlarmCloseWarning.standby"])
        lastArmedAlarmCloseWarningSourceId = nil
        purgeAllArmedAlarmCloseWarningNotifications(reason: reason)
        print("[ArmedCloseWarning] cancelled reason=\(reason)")
    }

    /// Removes every pending/delivered "Open Alarmy again" notification.
    func purgeAllArmedAlarmCloseWarningNotifications(reason: String) {
        let center = UNUserNotificationCenter.current()
        let standbyPrefix = ArmedAlarmCloseWarningStandby.standbyIdentifierPrefix
        let immediatePrefix = ArmedAlarmCloseWarningStandby.immediateIdentifierPrefix
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter {
                $0.hasPrefix(standbyPrefix) || $0.hasPrefix(immediatePrefix)
            }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            print("[ArmedCloseWarning] purged \(ids.count) pending id(s) reason=\(reason)")
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map { $0.request.identifier }.filter {
                $0.hasPrefix(standbyPrefix) || $0.hasPrefix(immediatePrefix)
            }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            print("[ArmedCloseWarning] purged \(ids.count) delivered id(s) reason=\(reason)")
        }
    }

    /// Resolves the active alarm and delivers the basic-sound warning when the user leaves the app.
    @MainActor
    func deliverBasicSoundOnlyWarningForLiveSessionIfNeeded(
        ringCoordinator: AlarmRingCoordinator,
        sourceAlarmId: String?,
        surfaceAlarmId: String?,
        alarmName: String?,
        reason: String
    ) {
        guard let sourceAlarmId else { return }
        guard isLiveAlarmSessionActive(
            ringCoordinator: ringCoordinator,
            sourceAlarmId: sourceAlarmId
        ) else {
            print("[ForegroundSoundReminder] skipped — no live alarm session source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        deliverBasicSoundOnlyWarningOnAppLeave(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName,
            reason: reason
        )
    }

    /// Warn the user that leaving Alarmo (home screen, app switcher) while the phone is
    /// still unlocked means only the basic AlarmKit tone will play — not full app audio.
    func scheduleForegroundSoundReminderNotification(
        sourceAlarmId: String,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) {
        Task { @MainActor in
            deliverBasicSoundOnlyWarningOnAppLeave(
                sourceAlarmId: sourceAlarmId,
                surfaceAlarmId: surfaceAlarmId,
                alarmName: alarmName,
                reason: "foreground-sound-reminder"
            )
        }
    }

    func cancelForegroundSoundReminderNotification(sourceAlarmId: String) {
        let identifier = ForegroundSoundReminder.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        cancelSwipeAwayWarningStandby(sourceAlarmId: sourceAlarmId, reason: "foreground-sound-reminder-cancel")
    }

    // MARK: - Force-closed warning (pre-armed at schedule time)

    /// Pre-arms the "Open Alarmo again" force-close warning for `fireDate`. Scheduled
    /// when an alarm is set so it survives a force-close. Cancelled while the app is
    /// alive and the AppEngine is verified audible (see `cancelForceClosedWarning`).
    func scheduleForceClosedWarning(sourceAlarmId: String, fireDate: Date, alarmName: String?) {
        guard openAlarmoAgainNotificationsEnabled else {
            cancelForceClosedWarning(sourceAlarmId: sourceAlarmId, reason: "disabled")
            return
        }
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        let triggerDate = fireDate.addingTimeInterval(ForceClosedWarning.postFireDelay)
        guard triggerDate.timeIntervalSinceNow > 1 else {
            print("[ForceClosedWarning] skipped — fire time too close/past source=\(sourceAlarmId)")
            return
        }

        let identifier = ForceClosedWarning.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "😰 Open Alarmo again"
        if let name = alarmName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            content.subtitle = name
        }
        content.body = "If the app is closed, only the basic sound rings. Tap to open Alarmo →"
        content.sound = .default
        content.categoryIdentifier = AppNotificationCategory.alarmForegroundSoundReminder
        content.threadIdentifier = "alarmo.forceClosed.warning"
        content.userInfo = [
            ForceClosedWarning.userInfoSourceAlarmIDKey: sourceAlarmId,
            ForegroundSoundReminder.userInfoSourceAlarmIDKey: sourceAlarmId,
            ForegroundSoundReminder.userInfoSurfaceAlarmIDKey: sourceAlarmId
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if let attachment = brandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("[ForceClosedWarning] schedule failed source=\(sourceAlarmId): \(error)")
            } else {
                print("[ForceClosedWarning] scheduled source=\(sourceAlarmId) at=\(triggerDate)")
            }
        }
    }

    func cancelForceClosedWarning(sourceAlarmId: String, reason: String) {
        let identifier = ForceClosedWarning.identifier(for: sourceAlarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("[ForceClosedWarning] cancelled source=\(sourceAlarmId) reason=\(reason)")
    }

    /// Removes all "Open Alarmo again" style notifications (foreground reminder,
    /// swipe-away standby, post-fire force-closed warning).
    func purgeAllOpenAlarmoAgainNotifications(reason: String) {
        let prefixes = [
            ForegroundSoundReminder.identifierPrefix,
            SwipeAwayWarningStandby.identifierPrefix,
            ForceClosedWarning.identifierPrefix
        ]
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            print("[OpenAlarmoAgain] purged \(ids.count) pending notification(s) reason=\(reason)")
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map { $0.request.identifier }.filter { id in prefixes.contains { id.hasPrefix($0) } }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            print("[OpenAlarmoAgain] purged \(ids.count) delivered notification(s) reason=\(reason)")
        }
    }

    // MARK: - App Closed Warning ("Open Alarmo to keep your full wake-up flow active")

    /// True when the debug throttle bypass is active (launch argument or stored
    /// flag). DEBUG builds only — production always returns false.
    var debugBypassAppClosedWarningThrottle: Bool {
#if DEBUG
        if CommandLine.arguments.contains(AppClosedWarning.debugLaunchArgument) { return true }
        return UserDefaults.standard.bool(forKey: AppClosedWarning.debugBypassThrottleDefaultsKey)
#else
        return false
#endif
    }

    /// Schedules a real local notification (~35s after the app left foreground)
    /// telling the user that the basic AlarmKit sound is still scheduled but the
    /// full Alarmo experience requires the app to be open. This path is for
    /// FUTURE enabled alarms only — it deliberately does NOT require an active
    /// ringing session, AppEngine, the bridge, or a clean final-stop flag.
    /// Cancelled the moment the app becomes active again.
    @MainActor
    func scheduleAppClosedWarningForFutureAlarmIfNeeded(
        ringCoordinator: AlarmRingCoordinator?,
        alarms: [Alarm],
        reason: String,
        debugBypassThrottle: Bool = false,
        debugForceDelay: TimeInterval? = nil
    ) {
        let now = Date()
        print("[AppClosedWarning] checking future alarm warning reason=\(reason)")

        // Future-alarm absence warnings are NOT scheduled on normal lock or Home
        // Screen background. Force-quit is handled by foreground standby only.
        // This path remains for debug / explicit test harness calls only.
        if debugForceDelay == nil {
            print("[AppClosedWarning] skipped; use foreground standby for force-quit reason=\(reason)")
            return
        }

        // Skip ONLY when an alarm is actively ringing — that flow owns its own
        // "you left the app" warning. A stale finalStop flag from a previous,
        // already-finished session must NOT block a future-alarm warning.
        let isRingingNow: Bool = {
            if let coord = ringCoordinator, coord.isRinging { return true }
            if AlarmAuthHandoffStore.alarmState() == .ringing { return true }
            if AlarmAudioStateController.shared.isAlarmRinging { return true }
            return false
        }()
        if isRingingNow {
            print("[AppClosedWarning] skipped; alarm currently ringing reason=\(reason)")
            return
        }
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            // This is the exact bug from the logs: the final-stop flag lingers
            // after a previous ring session. Future-alarm warnings ignore it.
            print("[AppClosedWarning] final-stop cleanup ignored because this is a future-alarm warning reason=\(reason)")
            print("[AppClosedWarning] skipped final-stop cleanup only for active ringing alarm reason=\(reason)")
        }

        // Require at least one enabled future alarm.
        guard let next = nearestUpcomingEnabledAlarm(alarms: alarms, from: now) else {
            print("[AppClosedWarning] skipped; no future enabled alarm reason=\(reason)")
            return
        }
        print("[AppClosedWarning] next future alarm found source=\(next.alarm.id.uuidString) fireDate=\(next.fireDate)")

        let timeUntilNext = next.fireDate.timeIntervalSince(now)
        let bypassThrottle = debugBypassThrottle || debugBypassAppClosedWarningThrottle
        if bypassThrottle {
            print("[AppClosedWarning] debug bypass throttle enabled")
        }

        // Skip if the next alarm is far outside the warning window (unless debug).
        if !bypassThrottle, timeUntilNext > AppClosedWarning.nextAlarmWindow {
            print("[AppClosedWarning] next alarm too far; skipped reason=\(reason) timeUntilNext=\(Int(timeUntilNext))s")
            return
        }

        // Throttle: at most one warning per ~8h (unless debug bypass).
        if !bypassThrottle {
            let lastShown = UserDefaults.standard.double(forKey: AppClosedWarning.lastShownAtDefaultsKey)
            if lastShown > 0 {
                let lastShownDate = Date(timeIntervalSince1970: lastShown)
                if now.timeIntervalSince(lastShownDate) < AppClosedWarning.throttleInterval {
                    print("[AppClosedWarning] skipped due to throttle lastShown=\(lastShownDate)")
                    return
                }
            }
        }

        let delay = debugForceDelay ?? AppClosedWarning.scheduleDelay
        let nextAlarmId = next.alarm.id.uuidString
        let appActive = UIApplication.shared.applicationState == .active

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            print("[AppClosedWarning] notification permission usable status=\(authorizationStatus.rawValue)")
            performAppClosedWarningSchedule(
                nextAlarmId: nextAlarmId,
                delay: delay,
                reason: reason,
                now: now
            )
        case .notDetermined:
            // Never request permission from the background — iOS would ignore it
            // and the prompt belongs in alarm setup anyway.
            guard appActive else {
                print("[AppClosedWarning] skipped; notification permission notDetermined and app not active")
                print("[AppClosedWarning] permission must be requested during alarm setup")
                return
            }
            print("[AppClosedWarning] permission notDetermined; requesting because app is active reason=\(reason)")
            Task { @MainActor in
                let result = await ensureNotificationPermissionForAlarmFeatures(
                    reason: "app-closed-warning-\(reason)"
                )
                guard result == .granted else { return }
                print("[AppClosedWarning] permission granted; warning system ready")
                print("[AppClosedWarning] future alarm exists after permission grant")
                performAppClosedWarningSchedule(
                    nextAlarmId: nextAlarmId,
                    delay: delay,
                    reason: "\(reason)-after-grant",
                    now: Date()
                )
            }
        case .denied:
            print("[AppClosedWarning] skipped; notification permission not authorized status=\(authorizationStatus.rawValue)")
        @unknown default:
            print("[AppClosedWarning] skipped; notification permission not authorized status=\(authorizationStatus.rawValue)")
        }
    }

    /// Backwards-compatible alias retained for existing call sites.
    @MainActor
    func scheduleAppClosedWarningIfNeeded(
        ringCoordinator: AlarmRingCoordinator?,
        alarms: [Alarm],
        reason: String
    ) {
        scheduleAppClosedWarningForFutureAlarmIfNeeded(
            ringCoordinator: ringCoordinator,
            alarms: alarms,
            reason: reason
        )
    }

    private func performAppClosedWarningSchedule(
        nextAlarmId: String,
        delay: TimeInterval,
        reason: String,
        now: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Keep Alarmo ready"
        content.body = "Open Alarmo to keep your full wake-up flow active. Your basic alarm sound is still scheduled."
        content.sound = .default
        content.categoryIdentifier = AppNotificationCategory.appOpenReminder
        content.threadIdentifier = "alarmo.appClosedWarning"
        content.userInfo = [
            AppClosedWarning.userInfoNextAlarmIdKey: nextAlarmId,
            AppClosedWarning.userInfoScheduledAtKey: now.timeIntervalSince1970,
            AlarmNotificationKind.userInfoKey: AlarmNotificationKind.openAppOnly
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.7
        }
        if let attachment = brandLogoNotificationAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: AppClosedWarning.identifier,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [AppClosedWarning.identifier])
        print("[AppClosedWarning] scheduling UNNotificationRequest id=\(AppClosedWarning.identifier) delay=\(Int(delay))s source=\(nextAlarmId)")
        center.add(request) { [weak self] error in
            if let error {
                print("[AppClosedWarning] UNUserNotificationCenter.add failed id=\(AppClosedWarning.identifier) error=\(error)")
                return
            }
            print("[AppClosedWarning] UNUserNotificationCenter.add success id=\(AppClosedWarning.identifier)")
            print("[AppClosedWarning] app left foreground with future alarm; scheduling warning +\(Int(delay))s reason=\(reason) nextAlarm=\(nextAlarmId)")
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: AppClosedWarning.lastShownAtDefaultsKey)
            self?.verifyAppClosedWarningPending()
        }
    }

    /// Reads back the pending notification requests and logs whether the
    /// app-closed warning is actually queued. Critical for diagnosing why the
    /// notification does (not) appear after a force-close.
    private func verifyAppClosedWarningPending() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }
            let present = ids.contains(AppClosedWarning.identifier)
            if present {
                print("[AppClosedWarning] pending verification PASS id=\(AppClosedWarning.identifier)")
            } else {
                print("[AppClosedWarning] pending verification FAIL id=\(AppClosedWarning.identifier)")
            }
            print("[AppClosedWarning] pending ids=\(ids)")
        }
    }

#if DEBUG
    /// Debug-only forced scheduling so the warning can be tested without relying
    /// on real lifecycle timing. Uses a synthetic 4h-future alarm when no real
    /// enabled alarm exists, bypasses the throttle, and verifies pending after
    /// the (short) delay.
    @MainActor
    func debugForceScheduleAppClosedWarning(alarms: [Alarm]) {
        print("[AppClosedWarningTest] forced schedule started")
        let now = Date()
        let resolvedId = nearestUpcomingEnabledAlarm(alarms: alarms, from: now)?.alarm.id.uuidString
            ?? UUID().uuidString
        performAppClosedWarningSchedule(
            nextAlarmId: resolvedId,
            delay: AppClosedWarning.debugScheduleDelay,
            reason: "debug-test",
            now: now
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let ids = requests.map { $0.identifier }
                if ids.contains(AppClosedWarning.identifier) {
                    print("[AppClosedWarningTest] pending verification PASS")
                } else {
                    print("[AppClosedWarningTest] pending verification FAIL")
                }
                print("[AppClosedWarningTest] pending ids=\(ids)")
            }
        }
    }
#endif

    /// Cancels the pending "app closed" warning and updates the lastKnownAppOpenAt
    /// timestamp. Intended to be called from every app-foreground entry point.
    func cancelAppClosedWarning(reason: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [AppClosedWarning.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [AppClosedWarning.identifier])
        let nowTs = Date().timeIntervalSince1970
        UserDefaults.standard.set(nowTs, forKey: AppClosedWarning.lastKnownAppOpenAtDefaultsKey)
        print("[AppClosedWarning] app active; cancelling pending warning id=\(AppClosedWarning.identifier) reason=\(reason)")
        print("[AppClosedWarning] app active; removed delivered warning id=\(AppClosedWarning.identifier)")
        print("[AppClosedWarning] updated lastKnownAppOpenAt=\(nowTs)")
    }

    // MARK: - Best-effort force-quit warning (applicationWillTerminate)

    /// Schedules a local warning when `applicationWillTerminate` fires.
    /// Best-effort only — iOS may not call willTerminate on swipe-up force-quit.
    /// AlarmKit remains the reliable wake-up fallback. This notification may not
    /// fire in all force-quit cases.
    func scheduleBestEffortForceQuitWarningOnTerminate(alarms: [Alarm]) {
        print("[ForceQuitWarning] applicationWillTerminate fired")
        print("[ForceQuitWarning] best-effort only; not guaranteed by iOS")

        if AlarmAppLifecycleSession.isDeviceLockLikely() {
            print("[ForceQuitWarning] skipped because device lock detected")
            return
        }

        let isRingingNow: Bool = {
            if ringCoordinator?.isRinging == true { return true }
            if AlarmAuthHandoffStore.alarmState() == .ringing { return true }
            if AlarmAudioStateController.shared.isAlarmRinging { return true }
            return false
        }()
        if isRingingNow {
            print("[ForceQuitWarning] skipped; alarm currently ringing")
            return
        }

        guard let next = nearestUpcomingEnabledAlarm(alarms: alarms, from: Date()) else {
            print("[ForceQuitWarning] skipped; no future enabled alarm")
            return
        }

        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            print("[ForceQuitWarning] skipped; notification permission not authorized status=\(authorizationStatus.rawValue)")
            return
        }

        let nextAlarmId = next.alarm.id.uuidString
        print("[ForceQuitWarning] future alarm found source=\(nextAlarmId)")
        print("[ForceQuitWarning] scheduling best-effort notification")

        let content = UNMutableNotificationContent()
        content.title = "⏰ Alarmo was closed"
        content.body = "Open Alarmo again for the full wake-up flow. Your basic alarm sound is still scheduled."
        content.sound = nil
        content.categoryIdentifier = AppNotificationCategory.forceQuitWarning
        content.threadIdentifier = "alarmo.forceQuitWarning"
        content.userInfo = [
            ForceQuitWarning.userInfoNextAlarmIdKey: nextAlarmId,
            AlarmNotificationKind.userInfoKey: AlarmNotificationKind.openAppOnly
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 0.8
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ForceQuitWarning.identifier])
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: ForceQuitWarning.scheduleDelay,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: ForceQuitWarning.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("[ForceQuitWarning] UNNotificationRequest add failed id=\(ForceQuitWarning.identifier) error=\(error)")
            } else {
                print("[ForceQuitWarning] UNNotificationRequest add success id=\(ForceQuitWarning.identifier)")
                center.getPendingNotificationRequests { requests in
                    let present = requests.contains { $0.identifier == ForceQuitWarning.identifier }
                    if present {
                        print("[ForceQuitWarning] pending verification PASS id=\(ForceQuitWarning.identifier)")
                    } else {
                        print("[ForceQuitWarning] pending verification FAIL id=\(ForceQuitWarning.identifier)")
                    }
                }
            }
        }
    }

    func cancelForceQuitWarning(reason: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ForceQuitWarning.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [ForceQuitWarning.identifier])
        print("[ForceQuitWarning] cancelled reason=\(reason)")
    }

    private func handleForceQuitWarningTap(notification: UNNotification) {
        print("[NotificationTap] FORCE_QUIT_WARNING tapped")
        print("[Navigation] opening alarm menu only")
        print("[Audio] no sound start because alarm is not ringing")
        print("[AlarmRestore] skipped; warning notification is not active alarm handoff")
        cancelForceQuitWarning(reason: "user-tap")
        requestOpenAlarmMenuNavigation(reason: "force-quit-warning-tap")
    }

    /// One-time in-app education after saving an important future alarm.
    func requestForceQuitEducationAfterAlarmSetup(alarm: Alarm) {
        guard alarm.enabled else { return }
        guard !UserDefaults.standard.bool(forKey: ForceQuitWarning.educationShownDefaultsKey) else { return }
        let now = Date()
        guard let fire = AlarmStore.nextFireDate(for: alarm, from: now), fire.timeIntervalSince(now) > 5 * 60 else {
            return
        }
        print("[AlarmSetup] showing force-close education warning")
        NotificationCenter.default.post(name: .showForceQuitEducationAfterAlarmSetup, object: nil)
    }

    func markForceQuitEducationAcknowledged() {
        UserDefaults.standard.set(true, forKey: ForceQuitWarning.educationShownDefaultsKey)
        print("[AlarmSetup] user acknowledged force-close warning")
    }

    // MARK: - Pre-Alarm Readiness Reminder

    /// Reconciles pre-alarm readiness reminders. Scheduling is disabled; this
    /// only purges any legacy pending/delivered readiness notifications.
    @MainActor
    func reconcilePreAlarmReadinessReminders(alarms: [Alarm], reason: String = "reconcile") {
        guard preAlarmReadinessRemindersEnabled else {
            purgeAllPreAlarmReadinessReminders(reason: "disabled-\(reason)")
            return
        }
        let now = Date()
        let center = UNUserNotificationCenter.current()

        // Snapshot expected identifiers so we can prune stale ones.
        var keepIdentifiers: Set<String> = []
        for alarm in alarms {
            guard alarm.enabled else { continue }
            guard let fire = AlarmStore.nextFireDate(for: alarm, from: now) else { continue }
            let advance = fire.timeIntervalSince(now)
            // Only schedule when the alarm is more than 30min away. Closer
            // alarms don't benefit from a readiness nudge — the alarm itself
            // is imminent.
            guard advance > PreAlarmReadinessReminder.minAdvanceForScheduling else {
                print("[PreAlarmReadiness] skipped because alarm too soon/far alarmId=\(alarm.id.uuidString) advance=\(Int(advance))s")
                continue
            }
            let leadTime: TimeInterval = {
                if advance > PreAlarmReadinessReminder.shortLeadThreshold {
                    return PreAlarmReadinessReminder.leadTime
                }
                if advance > 10 * 60 {
                    return PreAlarmReadinessReminder.shortLeadTime
                }
                return PreAlarmReadinessReminder.imminentLeadTime
            }()
            let triggerDate = fire.addingTimeInterval(-leadTime)
            guard triggerDate.timeIntervalSinceNow > 1 else { continue }

            let alarmId = alarm.id.uuidString
            keepIdentifiers.insert(PreAlarmReadinessReminder.identifier(for: alarmId))
            schedulePreAlarmReadinessReminder(
                alarmId: alarmId,
                alarmName: alarm.name,
                fireDate: fire,
                triggerDate: triggerDate,
                reason: reason
            )
        }

        // Drop pending readiness requests that no longer correspond to an
        // enabled alarm.
        center.getPendingNotificationRequests { requests in
            let stale = requests
                .map { $0.identifier }
                .filter { PreAlarmReadinessReminder.isReadinessIdentifier($0) && !keepIdentifiers.contains($0) }
            guard !stale.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for identifier in stale {
                let alarmId = String(identifier.dropFirst(PreAlarmReadinessReminder.identifierPrefix.count))
                print("[PreAlarmReadiness] cancelled reminder alarmId=\(alarmId) reason=\(reason)-stale")
            }
        }
    }

    /// Cancels a single pre-alarm readiness reminder, e.g. when the alarm is
    /// disabled / deleted, or when an "I'm here, the app is healthy" check
    /// determines no further nudge is needed.
    func cancelPreAlarmReadinessReminder(alarmId: String, reason: String) {
        let identifier = PreAlarmReadinessReminder.identifier(for: alarmId)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        print("[PreAlarmReadiness] cancelled reminder alarmId=\(alarmId) reason=\(reason)")
    }

    @MainActor
    func runReadinessHealthCheckOnAppOpen(alarms: [Alarm]) {
        guard preAlarmReadinessRemindersEnabled else { return }
        let now = Date()
        for alarm in alarms where alarm.enabled {
            guard let fire = AlarmStore.nextFireDate(for: alarm, from: now) else { continue }
            let advance = fire.timeIntervalSince(now)
            if advance >= 0 && advance <= PreAlarmReadinessReminder.healthCheckWindow {
                cancelPreAlarmReadinessReminder(
                    alarmId: alarm.id.uuidString,
                    reason: "app-open-health-check"
                )
            }
        }
    }

    /// Removes every pending/delivered pre-alarm readiness notification.
    func purgeAllPreAlarmReadinessReminders(reason: String) {
        let center = UNUserNotificationCenter.current()
        let prefix = PreAlarmReadinessReminder.identifierPrefix
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            print("[PreAlarmReadiness] purged \(ids.count) pending id(s) reason=\(reason)")
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            print("[PreAlarmReadiness] purged \(ids.count) delivered id(s) reason=\(reason)")
        }
    }

    private func schedulePreAlarmReadinessReminder(
        alarmId: String,
        alarmName: String,
        fireDate: Date,
        triggerDate: Date,
        reason: String
    ) {
        guard preAlarmReadinessRemindersEnabled else { return }
        let identifier = PreAlarmReadinessReminder.identifier(for: alarmId)
        let center = UNUserNotificationCenter.current()

        // Replace any previously-scheduled reminder so a retimed alarm always
        // pulls the latest trigger date.
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let isUpdate = requests.contains { $0.identifier == identifier }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "⏰ Alarmo check-in"
            let trimmed = alarmName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                content.subtitle = trimmed
            }
            content.body = "Open Alarmo to keep your full wake-up flow ready. Your basic alarm sound is still scheduled."
            content.sound = .default
            content.categoryIdentifier = AppNotificationCategory.preAlarmReadiness
            content.threadIdentifier = "alarmo.preAlarmReadiness"
            content.userInfo = [
                PreAlarmReadinessReminder.userInfoSourceAlarmIDKey: alarmId,
                PreAlarmReadinessReminder.userInfoFireAtKey: fireDate.timeIntervalSince1970,
                AlarmNotificationKind.userInfoKey: AlarmNotificationKind.openAppOnly
            ]
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 0.6
            }
            if let attachment = self.brandLogoNotificationAttachment() {
                content.attachments = [attachment]
            }

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    print("[PreAlarmReadiness] schedule failed alarmId=\(alarmId) error=\(error)")
                } else if isUpdate {
                    print("[PreAlarmReadiness] updated reminder alarmId=\(alarmId) fireDate=\(fireDate) reason=\(reason)")
                } else {
                    print("[PreAlarmReadiness] scheduled reminder alarmId=\(alarmId) fireDate=\(fireDate) reason=\(reason)")
                }
            }
        }
    }

    /// Returns the nearest enabled alarm and its next fire date, if any.
    private func nearestUpcomingEnabledAlarm(alarms: [Alarm], from now: Date) -> (alarm: Alarm, fireDate: Date)? {
        let upcoming: [(Alarm, Date)] = alarms.compactMap { alarm in
            guard alarm.enabled else { return nil }
            guard let fire = AlarmStore.nextFireDate(for: alarm, from: now), fire > now else { return nil }
            return (alarm, fire)
        }
        return upcoming.min(by: { $0.1 < $1.1 })
    }

    /// Cancels the pre-armed warning only when the app is alive AND the AppEngine
    /// is proven audible — i.e. the full in-app sound is actually handling the ring.
    func cancelForceClosedWarningIfAppHandlingSound(sourceAlarmId: String) {
        guard !AlarmAuthHandoffStore.isHeartbeatStale() else {
            print("[ForceClosedWarning] left pending because heartbeat stale source=\(sourceAlarmId)")
            return
        }
        guard AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: "force-closed-warning-cancel") else {
            print("[ForceClosedWarning] left pending — AppEngine not yet proven audible source=\(sourceAlarmId)")
            return
        }
        cancelForceClosedWarning(sourceAlarmId: sourceAlarmId, reason: "app-alive-engine-audible")
    }

    private func buildForegroundSoundReminderContent(
        sourceAlarmId: String,
        alarmName: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let name = (alarmName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        let variants: [(title: String, body: String)] = [
            (
                "🥲 Open Alarmo again",
                "Away from the app, only the basic alarm tone plays — not your full sound.\nTap to open Alarmo →"
            ),
            (
                "🔊 Louder inside Alarmo",
                "We can't boost volume while you're away. Open Alarmo for full-strength alarm audio.\nTap to return →"
            ),
            (
                "⚡️ Your alarm needs you back",
                "Background mode = basic sound only. Come back to Alarmo for volume control + Stop/Snooze.\nTap to open →"
            ),
            (
                "🫠 Don't leave yet",
                "Your alarm is still ringing, but only the simple tone plays outside Alarmo.\nTap to open Alarmo →"
            )
        ]
        let index = abs(sourceAlarmId.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }) % variants.count
        let picked = variants[index]
        content.title = picked.title
        if let name {
            content.subtitle = "\(name) is still ringing"
        } else {
            content.subtitle = "Alarm still ringing"
        }
        content.body = picked.body
        content.sound = .default
        return content
    }

    private func buildArmedAlarmCloseWarningContent(alarmName: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "🥲 Open Alarmy again"
        let name = alarmName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            content.subtitle = name
        }
        content.body = "If app is closed, only basic sound rings\nTap to open >"
        content.sound = .default
        return content
    }

    private func brandLogoNotificationAttachment() -> UNNotificationAttachment? {
        prominentBrandLogoNotificationAttachment(targetPointSize: 96)
    }

    /// Larger Alarmo icon for lock-screen ringing control notifications.
    private func prominentBrandLogoNotificationAttachment(targetPointSize: CGFloat = 160) -> UNNotificationAttachment? {
        guard let image = UIImage(named: "BrandLogo") else { return nil }
        let scaled = UIGraphicsImageRenderer(size: CGSize(width: targetPointSize, height: targetPointSize)).image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: targetPointSize, height: targetPointSize)))
        }
        guard let data = scaled.pngData() else { return nil }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("alarmo-brand-prominent-\(UUID().uuidString).png")
        do {
            try data.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(
                identifier: "alarmo-brand-logo-prominent",
                url: fileURL,
                options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
            )
        } catch {
            print("[AppEngineRingingControl] prominent brand attachment failed: \(error)")
            return nil
        }
    }

    /// Stop / Snooze on the AppEngine ringing control notification only open
    /// AlarmRingingView — they never stop or snooze directly from the banner.
    private func handleAppEngineRingingControlAction(notification: UNNotification, action: String) {
        let userInfo = notification.request.content.userInfo
        let sourceAlarmId = (userInfo[AppEngineRingingControlNotification.userInfoSourceAlarmIDKey] as? String)
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()
        guard let sourceAlarmId else { return }

        let actionLabel: String = {
            switch action {
            case AppNotificationAction.appEngineRingingOpenStop: return "stop-open-ui"
            case AppNotificationAction.appEngineRingingOpenSnooze: return "snooze-open-ui"
            case UNNotificationDefaultActionIdentifier: return "default-open-ui"
            default: return action
            }
        }()
        print("[AppEngineRingingControl] action=\(actionLabel) source=\(sourceAlarmId) -> open AlarmRingingView")
        print("[NotificationRouter] category=APP_ENGINE_RINGING_CONTROL -> open ringing UI")

        guard !isAlarmFlowSuppressed(sourceAlarmId),
              alarmIsActuallyRingingOrDue(sourceAlarmId: sourceAlarmId) else {
            print("[AppEngineRingingControl] ignored stale tap source=\(sourceAlarmId) action=\(actionLabel)")
            cancelAppEngineRingingControlNotification(
                sourceAlarmId: sourceAlarmId,
                reason: "stale-tap-\(actionLabel)"
            )
            cancelCustomUIHandoffFallbackNotification(sourceAlarmId: sourceAlarmId)
            return
        }

        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: nil)
        startOrQueueAlarm(alarmId: sourceAlarmId)
        AlarmAudioStateController.shared.enforceForegroundVolumeControl(reason: "app-engine-ring-control-\(actionLabel)")
    }

    private func handleForegroundSoundReminderAction(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard let sourceAlarmId = userInfo[ForegroundSoundReminder.userInfoSourceAlarmIDKey] as? String else {
            return
        }
        let surfaceAlarmId = userInfo[ForegroundSoundReminder.userInfoSurfaceAlarmIDKey] as? String
        print("🧭 [ALARMTRACE_ACTION] EVENT=FOREGROUND_SOUND_REMINDER_TAP SOURCE_ID=\(sourceAlarmId)")

        let kind = userInfo[AlarmNotificationKind.userInfoKey] as? String

        // STRONG GATE: this handler is shared by both live-ring reminders AND
        // future-alarm "open the app again" warnings. Only the former may start
        // audio. Tapping a warning before the alarm is due must open the app
        // ONLY — never ring. (Genuine AlarmKit-alerting recovery is handled by
        // AppRootView's cold-launch alerting detection, so being conservative
        // here cannot drop a real ring.)
        if kind == AlarmNotificationKind.openAppOnly {
            print("[NotificationTap] open-app-only warning tapped; opening app without ringing source=\(sourceAlarmId)")
            cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
            return
        }

        guard alarmIsActuallyRingingOrDue(sourceAlarmId: sourceAlarmId) else {
            print("[NotificationTap] alarm not currently ringing/due; opening app only (no sound) source=\(sourceAlarmId)")
            cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
            return
        }

        print("[NotificationTap] alarm is live; starting in-app ringing handoff source=\(sourceAlarmId)")
        cancelForegroundSoundReminderNotification(sourceAlarmId: sourceAlarmId)
        requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: surfaceAlarmId)
        startOrQueueAlarm(alarmId: sourceAlarmId)
        AlarmAudioStateController.shared.enforceForegroundVolumeControl(reason: "foreground-reminder-tap")
    }

    /// True only when an alarm is genuinely ringing right now (in-app, persisted
    /// runtime state, background bridge, or a live AlarmKit alerting surface).
    /// A lingering `finalStopOrSnoozePressed` flag or a merely-scheduled future
    /// alarm both return false, so a notification tap before the alarm fires
    /// will NOT start sound.
    private func alarmIsActuallyRingingOrDue(sourceAlarmId: String) -> Bool {
        if AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() { return false }
        if ringCoordinator?.isRinging == true { return true }
        if AlarmAudioStateController.shared.isAlarmRinging { return true }
        if AlarmBackgroundAudioBridge.shared.isPlaying { return true }
        if AlarmAuthHandoffStore.alarmState() == .ringing,
           AlarmAuthHandoffStore.activeRingingAlarmId() == sourceAlarmId {
            return true
        }
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            if let alarms = try? AlarmManager.shared.alarms {
                for alarm in alarms where alarm.state == .alerting {
                    let surfaceId = alarm.id.uuidString
                    if AlarmCustomUIHandoffStore.isSurfaceConsumedBySlideToStop(surfaceId) { continue }
                    let mapped = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
                    if mapped == sourceAlarmId || surfaceId == sourceAlarmId { return true }
                }
            }
        }
#endif
        return false
    }

    /// Pre-alarm readiness tap: open the normal alarm menu only. Never start
    /// sound or present the full-screen Stop/Snooze UI for a future alarm.
    private func handlePreAlarmReadinessTap(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let alarmId = (userInfo[PreAlarmReadinessReminder.userInfoSourceAlarmIDKey] as? String) ?? "unknown"
        print("[NotificationTap] PRE_ALARM_READINESS tapped alarmId=\(alarmId)")
        print("[NotificationRouter] category=PRE_ALARM_READINESS -> open alarm menu")
        print("[Audio] no sound start for readiness notification")
        print("[Audio] AppEngine start skipped because alarm is not ringing")
        print("[AlarmRestore] skipped; notification was readiness only")
        cancelPreAlarmReadinessReminder(alarmId: alarmId, reason: "user-tap")
        cancelAppClosedWarning(reason: "preAlarmReadiness-tap")
        requestOpenAlarmMenuNavigation(reason: "pre-alarm-readiness-tap", alarmId: alarmId)
    }

    /// Tap on the pre-armed "🥲 Open Alarmy again" force-close warning.
    private func handleArmedCloseWarningTap(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let sourceAlarmId = (userInfo[ArmedAlarmCloseWarningStandby.userInfoAlarmIDKey] as? String) ?? "unknown"
        print("[ArmedCloseWarning] tapped source=\(sourceAlarmId)")
        cancelArmedAlarmCloseWarning(reason: "user-tap")
        cancelAppClosedWarning(reason: "armed-close-tap")
        guard AlarmAuthHandoffStore.isActivelyRinging() else {
            print("[Navigation] opening alarm menu from armed close warning")
            requestOpenAlarmMenuNavigation(reason: "armed-close-warning-tap")
            return
        }
        print("[NotificationRouter] category=ACTIVE_ALARM_HANDOFF -> open ringing UI")
    }

    /// Legacy "app closed" / app-open reminder tap. Informational only — opens
    /// the alarm menu, never the ringing UI, unless the alarm is genuinely live.
    private func handleAppOpenReminderTap(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let identifier = notification.request.identifier
        let isAppClosedWarning = identifier == AppClosedWarning.identifier

        if isAppClosedWarning {
            let nextAlarmId = (userInfo[AppClosedWarning.userInfoNextAlarmIdKey] as? String) ?? "unknown"
            print("[AppClosedWarning] tapped id=\(identifier)")
            print("[AppClosedWarning] opened app from warning source=\(nextAlarmId)")
        } else {
            print("[AppOpenReminder] tapped identifier=\(identifier)")
        }

        cancelAppClosedWarning(reason: "tap-appClosedWarning")

        // Only an actively ringing alarm may open the full-screen UI from a tap.
        guard AlarmAuthHandoffStore.isActivelyRinging() else {
            print("[AlarmRestore] skipped; alarm is not ringing source=app-open-reminder")
            print("[Navigation] opening alarm menu from readiness notification")
            requestOpenAlarmMenuNavigation(reason: "app-open-reminder-tap")
            return
        }

        print("[NotificationRouter] category=ACTIVE_ALARM_HANDOFF -> open ringing UI")
        print("[AlarmRestore] opening ringing UI from active alarm notification")
    }

    /// Internal AlarmKit `.alerting` record exists (may still be untrusted after side-button).
    @MainActor
    func alarmKitAlertingSurfaceExists(sourceAlarmId: String, reason: String = "check") -> Bool {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return false }
        guard let alarms = try? AlarmManager.shared.alarms else { return false }
        for alarm in alarms where alarm.state == .alerting {
            let surfaceId = alarm.id.uuidString
            if AlarmCustomUIHandoffStore.isSurfaceConsumedBySlideToStop(surfaceId) { continue }
            let mapped = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
            if mapped == sourceAlarmId || surfaceId == sourceAlarmId {
                return true
            }
        }
        return false
#else
        _ = sourceAlarmId
        _ = reason
        return false
#endif
    }

    /// Back-compat alias — means internal alerting record exists, NOT trusted audibility.
    @MainActor
    func hasAudibleAlarmKitAlertingSurface(sourceAlarmId: String, reason: String = "check") -> Bool {
        alarmKitAlertingSurfaceExists(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    /// Custom unlock/stop notification — control surface only, never an audible owner.
    @MainActor
    func hasCustomControlNotification(sourceAlarmId: String) -> Bool {
        if let last = lastRecoveryNotificationScheduledAt[sourceAlarmId],
           Date().timeIntervalSince(last) < Self.recoveryNotificationActiveWindow {
            return true
        }
        if appEngineRingingControlInFlight.contains(sourceAlarmId) {
            return true
        }
        if let last = lastAppEngineRingingControlAt[sourceAlarmId],
           Date().timeIntervalSince(last) < Self.recoveryNotificationActiveWindow {
            return true
        }
        return false
    }

    @MainActor
    func currentAlarmSurfaceStatus(sourceAlarmId: String, reason: String) -> AlarmSurfaceStatus {
        let runId = currentRunId(for: sourceAlarmId)
        let customNotif = hasCustomControlNotification(sourceAlarmId: sourceAlarmId)
        let existsAlarmKit = alarmKitAlertingSurfaceExists(sourceAlarmId: sourceAlarmId, reason: reason)
        let suppressionRisk = AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId
        )
        let trustedAlarmKit = existsAlarmKit
            && isAlarmKitRingerLikelyAudibleWhileLocked(sourceAlarmId: sourceAlarmId, reason: reason)

        if existsAlarmKit {
            let riskLabel = suppressionRisk ? "alerting-but-suppression-risk" : "alarmkit-alerting"
            print(
                "[AudibleSurfaceCheck] exists=true kind=audibleAlarmKit trusted=\(trustedAlarmKit) " +
                "reason=\(riskLabel) source=\(sourceAlarmId)"
            )
            return AlarmSurfaceStatus(
                kind: .audibleAlarmKit,
                exists: true,
                trustedAsAudible: trustedAlarmKit,
                sourceAlarmId: sourceAlarmId,
                runId: runId
            )
        }
        if customNotif {
            print(
                "[SurfaceCheck] exists=true kind=customControlNotification trustedAsAudible=false " +
                "source=\(sourceAlarmId)"
            )
            return AlarmSurfaceStatus(
                kind: .customControlNotification,
                exists: true,
                trustedAsAudible: false,
                sourceAlarmId: sourceAlarmId,
                runId: runId
            )
        }
        return .none(sourceAlarmId: sourceAlarmId)
    }

    @MainActor
    func alarmSurfaceStatus(sourceAlarmId: String, reason: String) -> AlarmSurfaceStatus {
        currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    @MainActor
    func shouldSuppressAudibleAlarmKitRecovery(
        sourceAlarmId: String,
        reason: String
    ) async -> (suppress: Bool, suppressReason: String?) {
        let surface = currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
        let customNotif = surface.kind == .customControlNotification
        let suppressionRisk = AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId
        )
        let engineQuick = AlarmAudioStateController.shared.isAppEngineQuickAudible(reason: reason)
        let engineVerified = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
            reason: "recovery-suppress-\(reason)"
        )
        let engineAudible = engineVerified || engineQuick
        let appState = UIApplication.shared.applicationState
        let phase = AlarmAudioStateController.shared.phase
        let owner = AlarmAudioStateController.shared.audibleOwner.rawValue
        let meter = AlarmAudioStateController.shared.engineMeterSummaryForLogs()
        print(
            "[AudioDecision] reason=\(reason) appState=\(appState.rawValue) phase=\(phase.rawValue) " +
            "owner=\(owner) engineAudible=\(engineAudible) \(meter) surfaceKind=\(surface.kind.rawValue) " +
            "surfaceTrustedAsAudible=\(surface.trustedAsAudible) customNotificationVisible=\(customNotif) " +
            "suppressionRisk=\(suppressionRisk) source=\(sourceAlarmId)"
        )

        if engineAudible {
            print("[RecoveryPolicy] suppressed reason=app-engine-audible source=\(sourceAlarmId)")
            return (true, "app-engine-audible")
        }
        if surface.kind == .audibleAlarmKit,
           surface.trustedAsAudible,
           !suppressionRisk,
           !customNotif {
            print("[RecoveryPolicy] suppressed reason=trusted-audible-alarmkit-surface source=\(sourceAlarmId)")
            return (true, "trusted-audible-alarmkit-surface")
        }

        let decisionReason = customNotif
            ? "only-custom-notification-no-audio"
            : suppressionRisk
                ? "no-trusted-audible-owner-suppression-risk"
                : "no-trusted-audible-owner"
        print("[AudioDecision] decision=schedule-audible-alarmkit-recovery reason=\(decisionReason) source=\(sourceAlarmId)")
        return (false, nil)
    }

    /// Central no-audible-owner detector — call on side-button / lock / interruption while ringing.
    @MainActor
    func evaluateNoAudibleOwnerRecoveryIfNeeded(sourceAlarmId: String, reason: String) {
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let ringing = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
            || ringCoordinator?.isRinging == true
        guard ringing else { return }

        Task { @MainActor in
            let (suppress, suppressReason) = await shouldSuppressAudibleAlarmKitRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: reason
            )
            if suppress {
                _ = suppressReason
                return
            }

            if AlarmFeatureFlags.appEngineTakesOverAfterAlarmKitSuppression,
               shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
                print("[SuppressionTakeover] no trusted audible owner — trying AppEngine source=\(sourceAlarmId) reason=\(reason)")
                _ = startAppEngineAfterAlarmKitSuppression(
                    sourceAlarmId: sourceAlarmId,
                    reason: "no-audible-owner-\(reason)"
                )
                return
            }

            let surface = currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
            let recoveryReason = surface.kind == .customControlNotification
                ? "only-custom-notification-no-audio-\(reason)"
                : "no-trusted-audible-owner-\(reason)"
            print("[AlarmKitRecovery] scheduling AUDIBLE recovery reason=\(recoveryReason) source=\(sourceAlarmId)")
            orchestrateAlarmKitRespawnWhenSoundGone(
                sourceAlarmId: sourceAlarmId,
                reason: recoveryReason,
                forceAfterDismissal: true
            )
            preArmAudibleAlarmKitRecovery(
                sourceAlarmId: sourceAlarmId,
                reason: recoveryReason,
                delay: 1.0,
                bypassCooldown: true,
                bypassLiveSurfaceCheck: true
            )
        }
    }

    @MainActor
    /// True when a valid, unconsumed AlarmKit surface is **currently** `.alerting`.
    func hasValidUnconsumedLiveAlarmKitSurface(sourceAlarmId: String, reason: String = "check") -> Bool {
        hasAudibleAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    @MainActor
    func hasLiveAlarmKitSurface(sourceAlarmId: String, reason: String = "check") -> Bool {
        hasAudibleAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason)
    }

    private func isAlarmKitAlreadyAlerting(for sourceAlarmId: String) -> Bool {
        hasAudibleAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId, reason: "isAlarmKitAlreadyAlerting")
    }

    /// Only a trusted audible AlarmKit ringer may suppress audible recovery.
    private func shouldUseNotificationInsteadOfAlarmKitRecovery(
        sourceAlarmId: String,
        reason: String
    ) -> Bool {
        if shouldForceAlarmKitRespawnDespiteAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason) {
            return false
        }
        if AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(sourceAlarmId: sourceAlarmId) {
            print("[RecoveryPolicy] not suppressed reason=alarmkit-suppression-risk source=\(sourceAlarmId)")
            return false
        }
        let status = currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
        if status.kind == .customControlNotification {
            print("[RecoveryPolicy] not suppressed reason=only-custom-notification-no-audio source=\(sourceAlarmId)")
            return false
        }
        guard AlarmSurfacePolicy.canSurfaceSuppressAudibleRecovery(status) else {
            if status.kind == .audibleAlarmKit {
                print("[RecoveryPolicy] not suppressed reason=alerting-record-untrusted source=\(sourceAlarmId)")
            }
            return false
        }
        print("[RecoveryPolicy] suppressed reason=trusted-audible-alarmkit-surface source=\(sourceAlarmId)")
        return true
    }

    private func isWithinAlarmKitRecoverySurfaceCooldown(
        sourceAlarmId: String,
        now: Date = Date(),
        controlledRealert: Bool = false
    ) -> Bool {
        guard let last = lastAlarmKitRecoverySurfaceAt[sourceAlarmId] else { return false }
        let interval = controlledRealert
            ? Self.realertLoopMinScheduleInterval
            : Self.alarmKitRecoverySurfaceCooldown
        return now.timeIntervalSince(last) < interval
    }

    private func recordAlarmKitRecoverySurfaceScheduled(sourceAlarmId: String) {
        alarmKitRecoverySurfaceCountBySource[sourceAlarmId, default: 0] += 1
        lastAlarmKitRecoverySurfaceAt[sourceAlarmId] = Date()
        AlarmAudioStateController.shared.clearAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId,
            reason: "audible-recovery-surface-scheduled"
        )
    }

    private func lastAudibleRecoveryScheduledAt(for sourceAlarmId: String) -> Date? {
        let auth = lastAuthRecoveryScheduledAt[sourceAlarmId]
        let hardware = AlarmAudioStateController.shared.lastHardwareRecoveryScheduledAt
        switch (auth, hardware) {
        case let (a?, h?): return max(a, h)
        case let (a?, nil): return a
        case let (nil, h?): return h
        default: return nil
        }
    }

    /// Bounded audible AlarmKit recovery for auth, hardware, and volume suppression paths.
    /// Scheduled recovery alarms use `RecoveryStopAlarmIntent` (openAppWhenRun=false) so
    /// tapping the lock-screen button never re-prompts Face ID — it just respawns again.
    ///
    /// `bypassNoUIPreference` is the Phase 4/5 escape hatch: when the locked
    /// no-UI engine recovery cannot make the alarm audible (volume 0, screen-off
    /// keeps cutting the engine, etc.), the watchdog flips this on so the system
    /// lock-screen AlarmKit surface comes back even though the session normally
    /// prefers no UI after the first hardware suppression. Permanent silence is
    /// always worse than seeing AlarmKit again.
    func scheduleAudibleAlarmKitRecoveryIfNeeded(
        sourceAlarmId: String,
        reason: String,
        delay: TimeInterval,
        allowEngineFirst: Bool = true,
        allowAlarmKitFallback: Bool = true,
        force: Bool = false,
        bypassNoUIPreference: Bool = false,
        controlledRealert: Bool = false
    ) {
        if AlarmFeatureFlags.alarmKitPrimaryOwnerNoRespawn {
            print("[AlarmKitRecovery] disabled — not scheduling new recovery surface source=\(sourceAlarmId) reason=\(reason)")
            AlarmAuthHandoffStore.setAuthRecoveryPending(false)
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
            return
        }
        print("[AlarmKitRecovery] requested source=\(sourceAlarmId) reason=\(reason) allowEngineFirst=\(allowEngineFirst) force=\(force) bypassNoUI=\(bypassNoUIPreference)")
        emitDeadAudioProbe(sourceAlarmId: sourceAlarmId, reason: "recovery-\(reason)")
        if !bypassNoUIPreference, shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            print("[LockedNoUI] AlarmKit recovery BLOCKED — locked no-UI session active source=\(sourceAlarmId) reason=\(reason)")
            attemptLockedNoUIEngineRecovery(sourceAlarmId: sourceAlarmId, reason: "blocked-alarmkit-\(reason)")
            return
        }
        if bypassNoUIPreference {
            print("[LockedNoUI] AlarmKit recovery FORCE — engine cannot stay audible, allowing system surface as last resort source=\(sourceAlarmId)")
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[AlarmKitRecovery] skipped due to final stop/snooze source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if AlarmAuthHandoffStore.isMissionCompleted(), AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
            print("[AlarmKitRecovery] skipped after mission completion source=\(sourceAlarmId)")
            return
        }
        let runtimeState = AlarmAuthHandoffStore.alarmState()
        if runtimeState == .stopped || runtimeState == .snoozed {
            print("[AlarmKitRecovery] skipped; alarm state=\(runtimeState?.rawValue ?? "nil") source=\(sourceAlarmId)")
            return
        }
        guard !isAlarmFlowSuppressed(sourceAlarmId) else {
            print("[AlarmKitRecovery] skipped — flow suppressed source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        if !force,
           (AlarmAuthHandoffStore.isAuthRecoveryPending() || AlarmAudioStateController.shared.hardwareRecoveryPending),
           pendingAuthRecoverySurfaceIds[sourceAlarmId] != nil {
            print("[AlarmKitRecovery] skipped duplicate pending recovery source=\(sourceAlarmId) reason=\(reason)")
            return
        }

        let now = Date()
        let isUrgentDeadAudio = force
            || reason.contains("dead-audio")
            || reason.contains("side-button")
            || reason.contains("lock-suppression")
            || reason.contains("takeover-deferred")
            || reason.contains("silent-alarmkit")
            || reason.contains("watchdog")
        if !controlledRealert,
           shouldUseNotificationInsteadOfAlarmKitRecovery(sourceAlarmId: sourceAlarmId, reason: reason) {
            return
        }
        if controlledRealert,
           !shouldForceAlarmKitRespawnDespiteAlertingSurface(sourceAlarmId: sourceAlarmId, reason: reason),
           hasAudibleAlarmKitAlertingSurface(sourceAlarmId: sourceAlarmId, reason: "controlled-realert-\(reason)") {
            print("[AlarmKitRealertLoop] skipped schedule — audible AlarmKit surface exists source=\(sourceAlarmId)")
            return
        }
        if !isUrgentDeadAudio,
           let last = lastAudibleRecoveryScheduledAt(for: sourceAlarmId),
           now.timeIntervalSince(last) < hardwareRecoveryMinimumInterval {
            print("[AlarmKitRecovery] throttled source=\(sourceAlarmId) reason=\(reason) delta=\(String(format: "%.1f", now.timeIntervalSince(last)))")
            if !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
                if shouldUseNotificationInsteadOfAlarmKitRecovery(
                    sourceAlarmId: sourceAlarmId,
                    reason: "throttled-\(reason)"
                ) {
                    return
                }
                if !isWithinAlarmKitRecoverySurfaceCooldown(sourceAlarmId: sourceAlarmId) {
                    preArmAudibleAlarmKitRecovery(
                        sourceAlarmId: sourceAlarmId,
                        reason: "throttled-fallback-\(reason)",
                        delay: Self.preArmedRecoveryDefaultDelay
                    )
                } else {
                    scheduleAlarmRecoveryOpenAppNotification(
                        sourceAlarmId: sourceAlarmId,
                        reason: "throttled-\(reason)"
                    )
                }
            }
            return
        }

        let appActive = UIApplication.shared.applicationState == .active
        let engineLiveHealthy = AlarmAudioStateController.shared.appEngineConfirmedPlaying()
        if appActive && engineLiveHealthy {
            print("[AlarmKitRecovery] skipped because app active and engine healthy source=\(sourceAlarmId) reason=\(reason)")
            return
        }

        // No-UI-first recovery: while the phone is locked, keep the alarm ringing
        // through the app's own engine (`.playback`, no system surface) instead of
        // re-showing the AlarmKit system UI. An audible AlarmKit re-alert (which
        // always shows the lock-screen alarm surface) is used ONLY if the engine
        // cannot take over — verified a short moment later so the alarm is never
        // left silent (e.g. media volume at 0 while locked, where the engine plays
        // but produces no sound).
        if allowEngineFirst, !appActive {
            if AlarmAudioStateController.shared.tryEngineAudibleWhileLocked(reason: reason) {
                print("[AlarmKitRecovery] engine took over audibly while locked — no AlarmKit UI source=\(sourceAlarmId) reason=\(reason)")
                dismissAlarmKitUIForAppEngineOwnedSession(sourceAlarmId: sourceAlarmId, reason: "recovery-engine-\(reason)")
                AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                armEngineAudibleVerification(sourceAlarmId: sourceAlarmId, reason: reason)
                return
            }
            print("[AlarmKitRecovery] engine could not take over while locked — falling back to AlarmKit re-alert source=\(sourceAlarmId) reason=\(reason)")
        }

        if !allowAlarmKitFallback {
            print("[AlarmKitRecovery] AlarmKit fallback suppressed (no-UI-only policy) source=\(sourceAlarmId) reason=\(reason)")
            armEngineAudibleVerification(sourceAlarmId: sourceAlarmId, reason: reason)
            return
        }

        lastAuthRecoveryScheduledAt[sourceAlarmId] = now
        AlarmAudioStateController.shared.markHardwareRecoveryPending(true)
        AlarmAuthHandoffStore.setAuthRecoveryPending(true)

#if canImport(AlarmKit)
        guard AlarmManagerFacade.shared.selectedPath == .alarmKit else { return }
        guard #available(iOS 26.0, *) else { return }

        Task { @MainActor in
            if self.isAlarmKitAlreadyAlerting(for: sourceAlarmId) {
                let surface = self.currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
                let suppressionRisk = AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(
                    sourceAlarmId: sourceAlarmId
                )
                let appInactive = UIApplication.shared.applicationState != .active
                let untrusted = suppressionRisk || !surface.trustedAsAudible
                if appInactive, untrusted || self.shouldForceAlarmKitRespawnDespiteAlertingSurface(
                    sourceAlarmId: sourceAlarmId,
                    reason: reason
                ) {
                    print("[AlarmKitRecovery] alerting record untrusted — scheduling fresh AUDIBLE surface source=\(sourceAlarmId) reason=\(reason) suppressionRisk=\(suppressionRisk)")
                    self.markReplacingWithAudibleAlarmKitRecovery(sourceAlarmId: sourceAlarmId, reason: reason)
                    self.dismissLinkedAlarmKitSurfaces(sourceAlarmId: sourceAlarmId, reason: "recovery-reschedule-\(reason)")
                } else if appInactive, surface.trustedAsAudible {
                    print("[AlarmKitRecovery] trusted audible AlarmKit surface present; preserving system owner source=\(sourceAlarmId) reason=\(reason)")
                    AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "live-alerting-surface-\(reason)")
                    self.cancelAllBackupAlarmKitChains()
                    self.scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
                    AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                    AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                    self.startAlarmKitAudibleWatchdog(sourceAlarmId: sourceAlarmId)
                    if AlarmAuthHandoffStore.isWaitingForAuthentication() {
                        self.scheduleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
                    }
                    return
                } else if force {
                    // App ACTIVE + explicit refresh: safe to make-before-break since
                    // the in-app UI is about to take over the surface.
                    print("[AlarmKitRecovery] app active + forced refresh — rescheduling fresh surface source=\(sourceAlarmId) reason=\(reason)")
                    self.markReplacingWithAudibleAlarmKitRecovery(sourceAlarmId: sourceAlarmId, reason: reason)
                    self.dismissLinkedAlarmKitSurfaces(sourceAlarmId: sourceAlarmId, reason: "forced-refresh-\(reason)")
                    // Fall through to schedule a new audible surface below.
                } else {
                    print("[AlarmKitRecovery] skipped — AlarmKit already alerting source=\(sourceAlarmId) reason=\(reason)")
                    self.scheduleRecoveryPromptNotification(sourceAlarmId: sourceAlarmId)
                    AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                    AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                    self.startAlarmKitAudibleWatchdog(sourceAlarmId: sourceAlarmId)
                    return
                }
            }
            guard let sourceUUID = UUID(uuidString: sourceAlarmId) else { return }
            let store = alarmStore ?? AlarmStore.shared
            guard let originalAlarm = store.alarm(by: sourceUUID) else {
                print("[AlarmKitRecovery] recovery failed — alarm not found source=\(sourceAlarmId) reason=\(reason)")
                AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                return
            }

            do {
                let alarms = try AlarmManager.shared.alarms
                let alreadyAlerting = alarms.contains { alarm in
                    let mapped = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: alarm.id.uuidString)
                    return (mapped == sourceAlarmId || alarm.id.uuidString == sourceAlarmId) && alarm.state == .alerting
                }
                if alreadyAlerting {
                    let surface = self.currentAlarmSurfaceStatus(sourceAlarmId: sourceAlarmId, reason: reason)
                    let suppressionRisk = AlarmAudioStateController.shared.isAlarmKitSurfaceSuppressionRisk(
                        sourceAlarmId: sourceAlarmId
                    )
                    if surface.trustedAsAudible, !suppressionRisk {
                        print("[AlarmKitRecovery] trusted alerting surface exists; no new surface scheduled source=\(sourceAlarmId) reason=\(reason)")
                        if UIApplication.shared.applicationState != .active {
                            AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "direct-check-\(reason)")
                        }
                        AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                        AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                        self.startAlarmKitAudibleWatchdog(sourceAlarmId: sourceAlarmId)
                        if AlarmAuthHandoffStore.isWaitingForAuthentication(),
                           UIApplication.shared.applicationState != .active {
                            self.scheduleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
                        }
                        return
                    }
                    print("[AlarmKitRecovery] alerting record untrusted — continuing to schedule AUDIBLE recovery source=\(sourceAlarmId) reason=\(reason)")
                } else if self.isWithinAlarmKitRecoverySurfaceCooldown(
                    sourceAlarmId: sourceAlarmId,
                    controlledRealert: controlledRealert
                ) {
                    print("[RecoveryPolicy] suppressed AlarmKit recovery due to cooldown source=\(sourceAlarmId) reason=\(reason)")
                    self.scheduleAlarmRecoveryOpenAppNotification(sourceAlarmId: sourceAlarmId, reason: reason)
                    AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                    AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                    return
                } else {
                    print("[RecoveryPolicy] allowed last-resort AlarmKit recovery because no live surface exists source=\(sourceAlarmId) reason=\(reason)")
                    print("[AlarmKitRecovery] no live surface; scheduling recovery surface source=\(sourceAlarmId) reason=\(reason)")
                }
            } catch {
                print("[AlarmKitRecovery] inspect failed source=\(sourceAlarmId): \(error)")
            }

            let helper = AlarmSchedulerIOS26AlarmKit()
            let title = resolvedAlarmLabel(sourceAlarmId: sourceAlarmId, alarmName: originalAlarm.name)
            let delays = Self.authRecoveryDelays.map { max(delay, $0) }

            for attemptDelay in delays {
                let newUUID = UUID()
                do {
                    _ = try await helper.scheduleRecoveryWithFallbackSound(
                        manager: AlarmManager.shared,
                        id: newUUID,
                        originalAlarmID: sourceUUID,
                        title: title,
                        schedule: .fixed(Date().addingTimeInterval(attemptDelay)),
                        preferredSoundName: originalAlarm.soundName,
                        sourceAlarm: originalAlarm
                    )
                    pendingAuthRecoverySurfaceIds[sourceAlarmId] = newUUID
                    AlarmCustomUIHandoffStore.request(alarmID: sourceUUID, surfaceAlarmID: newUUID)
                    AlarmAuthHandoffStore.updateSurfaceAlarmId(newUUID)
                    self.recordAlarmKitRecoverySurfaceScheduled(sourceAlarmId: sourceAlarmId)
                    self.scheduleAlarmRecoveryOpenAppNotification(
                        sourceAlarmId: sourceAlarmId,
                        reason: "alarmkit-recovery-\(reason)"
                    )
                    print("[AlarmKitRecovery] scheduled audible recovery source=\(sourceAlarmId) surface=\(newUUID.uuidString) delay=\(attemptDelay) reason=\(reason)")
                    // INTENTIONALLY do NOT call markAlarmKitAudibleConfirmed here:
                    // scheduling a recovery surface is not the same as the user
                    // hearing it. The watchdog tick will confirm true audibility
                    // (engine playing AND outputVolume above the floor) on its
                    // next pass; until then, keep the pre-armed recovery alive
                    // and the failure counters intact.
                    print("[AlarmKitRecovery] recovery scheduled; engine not yet audible source=\(sourceAlarmId)")
                    // Reset the watchdog start time so the upcoming AlarmKit
                    // surface gets a clean silence window to fire and become
                    // audible before escalation logic kicks in again.
                    self.alarmKitWatchdogStartedAtBySource[sourceAlarmId] = Date()
                    self.startAlarmKitAudibleWatchdog(sourceAlarmId: sourceAlarmId)
                    AlarmAuthHandoffStore.setAuthRecoveryPending(false)
                    AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
                    if AlarmAuthHandoffStore.isWaitingForAuthentication(),
                       UIApplication.shared.applicationState != .active {
                        self.scheduleAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
                    }
                    return
                } catch {
                    print("[AlarmKitRecovery] attempt +\(attemptDelay)s failed source=\(sourceAlarmId): \(error)")
                }
            }
            AlarmAuthHandoffStore.setAuthRecoveryPending(false)
            AlarmAudioStateController.shared.markHardwareRecoveryPending(false)
            print("[AlarmKitRecovery] all recovery attempts failed source=\(sourceAlarmId) reason=\(reason)")
        }
#endif
    }

    /// Never-silent safety net for the no-UI (engine) recovery path. After the
    /// engine is promoted to audible while locked, this re-checks a short moment
    /// later whether the engine is *actually* audible (playing AND system output
    /// above the floor). If not — e.g. media volume is at 0 while locked, where the
    /// engine plays but produces no sound — it schedules an audible AlarmKit
    /// re-alert (which shows the system UI) so the alarm is never left silent.
    func armEngineAudibleVerification(sourceAlarmId: String, reason: String) {
        engineAudibleVerificationWorkItems[sourceAlarmId]?.cancel()
        engineAudibleVerificationWorkItems.removeValue(forKey: sourceAlarmId)
        let delays: [TimeInterval] = [0.5, 1.5, 2.5]
        for (index, delay) in delays.enumerated() {
            let work = DispatchWorkItem { [weak self] in
                self?.handleEngineAudibleVerification(
                    sourceAlarmId: sourceAlarmId,
                    reason: "\(reason)-pass-\(index + 1)",
                    isFinalPass: index == delays.count - 1
                )
            }
            engineAudibleVerificationWorkItems[sourceAlarmId] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
        print("[AlarmKitRecovery] armed engine-audible verification passes=\(delays) source=\(sourceAlarmId) reason=\(reason)")
    }

    private func handleEngineAudibleVerification(
        sourceAlarmId: String,
        reason: String,
        isFinalPass: Bool = true
    ) {
        if isFinalPass {
            engineAudibleVerificationWorkItems.removeValue(forKey: sourceAlarmId)
        }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else {
            print("[AlarmKitRecovery] engine-audible verification cancelled — final stop/snooze source=\(sourceAlarmId)")
            return
        }
        let state = AlarmAuthHandoffStore.alarmState()
        guard state == nil || state == .ringing else {
            print("[AlarmKitRecovery] engine-audible verification cancelled — state=\(state?.rawValue ?? "nil") source=\(sourceAlarmId)")
            return
        }
        if UIApplication.shared.applicationState == .active {
            // User opened the app — the in-app ring UI now owns audio.
            print("[AlarmKitRecovery] engine-audible verification skipped — app active source=\(sourceAlarmId)")
            return
        }
        Task { @MainActor in
            let verified = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
                reason: "locked-candidate-verify-\(reason)"
            )
            if verified {
                print("[LockedNoUI] engine-audible verification PASS (strict) source=\(sourceAlarmId)")
                engineAudibleVerificationWorkItems.removeValue(forKey: sourceAlarmId)
                await AlarmAudioStateController.shared.confirmLockedEngineVerified(
                    sourceAlarmId: sourceAlarmId,
                    reason: reason
                )
                markLockedNoUIAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: "verification-pass")
                startLockedNoUIAudibleWatchdog(sourceAlarmId: sourceAlarmId)
                lockedNoUIFailureCountBySource[sourceAlarmId] = 0
                lockedNoUIEscalatedBySource.remove(sourceAlarmId)
                return
            }

            guard isFinalPass else {
                print("[LockedNoUI] engine-audible verification pending (intermediate pass) source=\(sourceAlarmId) reason=\(reason)")
                return
            }

            let playing = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
            let output = AVAudioSession.sharedInstance().outputVolume
            print("[LockedNoUI] engine-audible verification FAIL source=\(sourceAlarmId) playing=\(playing) output=\(String(format: "%.2f", output))")
            AlarmAudioStateController.shared.markLockedEngineCandidateFailed(
                sourceAlarmId: sourceAlarmId,
                reason: "engine-verification-fail-\(reason)"
            )
            evaluateNoAudibleOwnerRecoveryIfNeeded(
                sourceAlarmId: sourceAlarmId,
                reason: "engine-verification-fail-\(reason)"
            )
            if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
                let failureCount = (lockedNoUIFailureCountBySource[sourceAlarmId] ?? 0) + 1
                lockedNoUIFailureCountBySource[sourceAlarmId] = failureCount
                if failureCount >= lockedNoUIEscalationFailureThreshold {
                    let reference = lastConfirmedAudibleAtBySource[sourceAlarmId]
                        ?? alarmKitWatchdogStartedAtBySource[sourceAlarmId]
                        ?? Date()
                    let silence = Date().timeIntervalSince(reference)
                    escalateLockedNoUIToAlarmKit(
                        sourceAlarmId: sourceAlarmId,
                        reason: "verification-fail-\(reason)",
                        silenceDuration: silence,
                        failureCount: failureCount
                    )
                } else {
                    print("[LockedNoUI] verification FAIL → retry engine only (failure \(failureCount)/\(lockedNoUIEscalationFailureThreshold)) source=\(sourceAlarmId)")
                    attemptLockedNoUIEngineRecovery(
                        sourceAlarmId: sourceAlarmId,
                        reason: "engine-verification-fail-\(reason)"
                    )
                }
            } else {
                print("[AlarmKitRecovery] verification FAIL → AlarmKit fallback source=\(sourceAlarmId)")
                AlarmAudioStateController.shared.recordLockedEngineInaudible(reason: reason)
                scheduleAudibleAlarmKitRecoveryIfNeeded(
                    sourceAlarmId: sourceAlarmId,
                    reason: "engine-inaudible-\(reason)",
                    delay: 1.0,
                    allowEngineFirst: false
                )
            }
        }
    }

    /// Legacy entry point — routes through delayed hardware suppression check.
    func scheduleHardwareButtonRespawnIfNeeded(
        sourceAlarmId: String,
        alarmName: String?,
        reason: String
    ) {
        _ = alarmName
        AlarmAudioStateController.shared.recordPossibleHardwareSuppression(reason: reason)
        scheduleHardwareSuppressionCheck(
            sourceAlarmId: sourceAlarmId,
            delay: 3.0,
            reason: reason
        )
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

        // AlarmKit left `.alerting` (side button, slide-to-stop, auth sheet, etc.).
        // The ringer is gone — start AppEngine immediately if the ring session
        // is still live. Do NOT respawn AlarmKit surfaces here.
        cancelPendingLockedSurfaceReassert(for: sourceAlarmId)
        handleAlarmKitLeftAlerting(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            reason: "alarmkit-state-\(alarm.state)"
        )
    }

    /// Called when a lock-screen AlarmKit surface is no longer `.alerting` while
    /// the logical alarm session should still be ringing (side button / auth / dismiss).
    @MainActor
    func handleAlarmKitLeftAlerting(
        sourceAlarmId: String,
        surfaceAlarmId: String,
        reason: String
    ) {
        guard !isAlarmFlowSuppressed(sourceAlarmId) else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        let sessionLive = AlarmAuthHandoffStore.alarmState() == .ringing
            || AlarmAudioStateController.shared.isAlarmRinging
        guard sessionLive else {
            print("[AlarmKitObservation] left alerting — no live session source=\(sourceAlarmId) reason=\(reason)")
            return
        }
        // HIJACK GUARD: only honor a left-alerting takeover for the alarm that is
        // actually the committed live ring. A DIFFERENT alarm's surface leaving
        // `.alerting` — e.g. a stale/orphaned duplicate scheduled with an OLD sound
        // (an AlarmKit registration whose store row was replaced and never
        // cancelled) — must NOT rebind the session to its sound. That is the root of
        // the "I press the side button and hear the PREVIOUS sound" bug: the stale
        // surface hijacks the ring and restarts the engine on the old file.
        let committedRing = AlarmAudioStateController.shared.currentAlarmId
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()
        if let committedRing, committedRing != sourceAlarmId {
            print("[AlarmKitObservation] left alerting IGNORED — source=\(sourceAlarmId) is not the committed ring \(committedRing) (stale/secondary surface) reason=\(reason)")
            return
        }
        if AlarmContinuousAudioEngine.shared.confirmStillPlaying()
            && AlarmAudioStateController.shared.phase == .appEnginePrimary {
            print("[AlarmKitObservation] left alerting — AppEngine already primary source=\(sourceAlarmId)")
            return
        }
        print("[AlarmKitObservation] left alerting — AlarmKit sound/UI gone; AppEngine takeover source=\(sourceAlarmId) surface=\(surfaceAlarmId) reason=\(reason)")
        recordHardwareSuppressionEvent(sourceAlarmId: sourceAlarmId)
        explicitAlarmKitSuppressionSourceIds.insert(sourceAlarmId)
        AlarmAudioStateController.shared.markAlarmKitSurfaceSuppressionRisk(
            sourceAlarmId: sourceAlarmId,
            reason: "alarmkit-left-alerting-\(reason)"
        )
        _ = startAppEngineAfterAlarmKitSuppression(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            reason: "alarmkit-left-alerting-\(reason)"
        )
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
        if !AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI(),
           await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: "process-alerting-ui-suppressed") {
            print("[AlarmKitObservation] dismissing alerting surface — AppEngine strictly verified surface=\(surfaceAlarmId)")
            dismissAlarmKitUIForAppEngineOwnedSession(sourceAlarmId: sourceAlarmId, reason: "process-alerting-ui-suppressed")
#if canImport(AlarmKit)
            await stopAlarmKitSurfaceIfAllowed(
                alarm: alarm,
                sourceAlarmId: sourceAlarmId,
                reason: "process-alerting-ui-suppressed"
            )
#endif
            return
        }
        _ = phase

        // Per-surface dedupe: AlarmKit can re-fire `.alerting` for the same surface
        // rapidly. Reprocessing the full recovery/bridge/prompt setup each time is
        // what drives the surface-churn loop. Within the dedupe window, just refresh
        // tracking and bail.
        let nowAlerting = Date()
        if let last = lastProcessedAlertingSurfaceAt[surfaceAlarmId],
           nowAlerting.timeIntervalSince(last) < Self.alertingDedupeWindow {
            lastProcessedAlertingSurfaceAt[surfaceAlarmId] = nowAlerting
            print("[AlarmKitObservation] duplicate alerting callback skipped surface=\(surfaceAlarmId) delta=\(String(format: "%.2f", nowAlerting.timeIntervalSince(last)))")
            return
        }
        lastProcessedAlertingSurfaceAt[surfaceAlarmId] = nowAlerting

        let alarmNameForSwipeWarning: String? = {
            if let name = ringCoordinator?.activeAlarm?.name { return name }
            if let uuid = UUID(uuidString: sourceAlarmId) {
                return alarmStore?.alarm(by: uuid)?.name
            }
            return nil
        }()
        if openAlarmoAgainNotificationsEnabled {
            await MainActor.run {
                refreshSwipeAwayWarningStandby(
                    ringCoordinator: ringCoordinator,
                    sourceAlarmId: sourceAlarmId,
                    surfaceAlarmId: surfaceAlarmId,
                    alarmName: alarmNameForSwipeWarning,
                    reason: "alarmkit-alerting"
                )
            }
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
                extra: "dismiss-alarmkit-ui=\(!AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI())"
            )
            AlarmBackgroundAudioBridge.shared.start(
                surfaceAlarmId: surfaceAlarmId,
                sourceAlarmId: sourceAlarmId
            )
            if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId)
                || !AlarmAudioStateController.shared.shouldAllowAlarmKitLockScreenUI(),
               await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: "engine-live-healthy") {
                print("[AlarmKitUIShell] engine strictly verified — dismissing AlarmKit UI source=\(sourceAlarmId)")
                dismissAlarmKitUIForAppEngineOwnedSession(
                    sourceAlarmId: sourceAlarmId,
                    reason: "engine-live-healthy"
                )
            } else if UIApplication.shared.applicationState != .active {
                ensureSilentAlarmKitUIShell(sourceAlarmId: sourceAlarmId, reason: "engine-live-healthy")
            }
            return
        }
        if AlarmCustomUIHandoffStore.isUIShellSurface(surfaceAlarmId) {
            print("[AlarmKitUIShell] alerting — engine should own audio source=\(sourceAlarmId) surface=\(surfaceAlarmId)")
            if !AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                _ = attemptLockedNoUIEngineRecovery(
                    sourceAlarmId: sourceAlarmId,
                    reason: "ui-shell-engine-not-playing"
                )
            }
            AlarmBackgroundAudioBridge.shared.start(
                surfaceAlarmId: surfaceAlarmId,
                sourceAlarmId: sourceAlarmId
            )
            if phase != .appEnginePrimary && phase != .appEngineFadingIn,
               await AlarmAudioStateController.shared.isAppEngineActuallyAudible(reason: "ui-shell-engine-primary") {
                AlarmAudioStateController.shared.transitionAudioPhase(
                    to: .appEnginePrimary,
                    reason: "ui-shell-engine-primary"
                )
            }
            setAlarmFlowPhase(
                UIApplication.shared.applicationState == .active ? .ringingUnlocked : .ringingLocked,
                for: sourceAlarmId
            )
            return
        }
        let sourceAlarm: Alarm? = {
            guard let uuid = UUID(uuidString: sourceAlarmId) else { return nil }
            return (alarmStore ?? AlarmStore.shared).alarm(by: uuid)
        }()
        print("[NotificationManager] 🔔 AlarmKit alarm alerting: surface=\(surfaceAlarmId), source=\(sourceAlarmId)")
        if shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            let isPreArmedSurface = preArmedRecoverySurface(sourceAlarmId: sourceAlarmId) == alarm.id
            let isEscalatedRecoverySurface = lockedNoUIEscalatedBySource.contains(sourceAlarmId)
                || pendingAuthRecoverySurfaceIds[sourceAlarmId] == alarm.id
                || isPreArmedSurface
            if isPreArmedSurface {
                print("[AlarmKitRecovery] fired source=\(sourceAlarmId) surface=\(surfaceAlarmId) reason=\(preArmedRecoveryBySource[sourceAlarmId]?.reason ?? "unknown")")
            }
            if isEscalatedRecoverySurface {
                // Audible AlarmKit re-alert (pre-armed or escalated). Let it ring
                // unless the engine is now verified audible — in which case we can
                // dismiss to avoid dual-sound.
                let engine = AlarmContinuousAudioEngine.shared
                let output = AVAudioSession.sharedInstance().outputVolume
                let engineAudible = engine.confirmStillPlaying() && output > AlarmAudioStateController.lowOutputVolumeThreshold
                if engineAudible {
                    print("[AlarmKitRecovery] suppressed because engine already audible source=\(sourceAlarmId) surface=\(surfaceAlarmId)")
                    try? AlarmManager.shared.stop(id: alarm.id)
                    try? AlarmManager.shared.cancel(id: alarm.id)
                    if isPreArmedSurface {
                        cancelPreArmedAlarmKitRecovery(
                            sourceAlarmId: sourceAlarmId,
                            reason: "engine-audible-verified-on-fire"
                        )
                    }
                } else {
                    print("[AlarmKitRecovery] allowed to alert because engine not audible source=\(sourceAlarmId) surface=\(surfaceAlarmId)")
                    print("[LockedNoUI] AlarmKit recovery surface alerting — keeping audible source=\(sourceAlarmId) surface=\(surfaceAlarmId)")
                    markAlarmKitAudibleConfirmed(sourceAlarmId: sourceAlarmId, reason: "escalated-recovery-surface")
                    if isPreArmedSurface {
                        // The pre-armed surface has fired and is now ringing — clear our
                        // bookkeeping so a future suppression event can pre-arm again.
                        preArmedRecoveryBySource.removeValue(forKey: sourceAlarmId)
                    }
                }
            } else {
                print("[LockedNoUI] AlarmKit alerting during no-UI session — trying engine takeover source=\(sourceAlarmId)")
                let engineTookOver = attemptLockedNoUIEngineRecovery(
                    sourceAlarmId: sourceAlarmId,
                    reason: "alarmkit-alerting-during-no-ui-session"
                )
                if engineTookOver {
                    dismissAlarmKitUIForAppEngineOwnedSession(
                        sourceAlarmId: sourceAlarmId,
                        reason: "alarmkit-alerting-engine-takeover"
                    )
                }
            }
        }
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
	            print("[NotificationManager] AlarmKit alerting — routing audio ownership via state machine. sound=\(sourceAlarm.soundName)")
	            AlarmAudioStateController.shared.handleAlarmKitAlerting(
	                alarmId: sourceAlarm.id.uuidString,
	                soundName: sourceAlarm.soundName,
	                reason: "alarmkit-alerting"
	            )
	        } else {
            print("[AlarmKit→Engine] Source alarm model missing for \(sourceAlarmId); engine start skipped")
        }

        let appActive = UIApplication.shared.applicationState == .active
        let shouldBootstrapBackgroundUnlockedAppEngine =
            shouldAllowBackgroundUnlockedAppEngineOwnership(sourceAlarmId: sourceAlarmId)

        // During the initial locked/background AlarmKit-owned ring, do NOT
        // bootstrap the in-app ring coordinator or bridge watchdog yet. They are
        // only needed once the app is foregrounded or explicit suppression/auth
        // handoff has occurred.
        if appActive
            || shouldBootstrapBackgroundUnlockedAppEngine
            || shouldUseLockedNoUIRecovery(sourceAlarmId: sourceAlarmId) {
            if ringCoordinator?.isRinging != true {
                _ = startAlarmImmediatelyIfPossible(alarmId: sourceAlarmId)
            }

            AlarmBackgroundAudioBridge.shared.start(
                surfaceAlarmId: surfaceAlarmId,
                sourceAlarmId: sourceAlarmId
            )
	        } else {
	            print("[NotificationManager] preserving AlarmKit-only ownership; AppEngine idle until explicit handoff source=\(sourceAlarmId)")
	            AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "process-alerting-preserve-owner")
	        }

        // Dismiss a prior surface only when it is NOT the primary scheduled alarm.
        // Recovery/backup surfaces must never replace the original Snooze UI.
        if let priorAlertingId = lastFiredAlarmIdsBySource[sourceAlarmId],
           priorAlertingId != alarm.id {
            let priorIsPrimaryScheduled = priorAlertingId.uuidString == sourceAlarmId
            let incomingIsRecovery = alarm.id.uuidString != sourceAlarmId
            if priorIsPrimaryScheduled && incomingIsRecovery {
                let priorConsumed = AlarmCustomUIHandoffStore.isSurfaceConsumedBySlideToStop(
                    priorAlertingId.uuidString
                )
                if priorConsumed {
                    print("[SurfaceDedupe] primary consumed; preserving incoming recovery surface=\(alarm.id.uuidString)")
                    try? AlarmManager.shared.stop(id: priorAlertingId)
                    try? AlarmManager.shared.cancel(id: priorAlertingId)
                    print("[SurfaceDedupe] current live surface updated to recovery surface=\(alarm.id.uuidString)")
                } else {
                    print("[SurfaceDedupe] preserving primary snooze surface=\(priorAlertingId.uuidString); dismissing incoming recovery=\(alarm.id.uuidString)")
                    try? AlarmManager.shared.stop(id: alarm.id)
                    try? AlarmManager.shared.cancel(id: alarm.id)
                    AlarmAudioStateController.shared.markAlarmKitPrimaryLocked(reason: "preserve-primary-snooze-ui")
                    scheduleAlarmRecoveryOpenAppNotification(
                        sourceAlarmId: sourceAlarmId,
                        reason: "incoming-recovery-suppressed"
                    )
                    return
                }
            }
            try? AlarmManager.shared.stop(id: priorAlertingId)
            try? AlarmManager.shared.cancel(id: priorAlertingId)
            print("[NotificationManager] 🧹 Dismissed prior alerting alarm \(priorAlertingId.uuidString) to prevent banner stacking")
        }
        lastFiredAlarmIdsBySource[sourceAlarmId] = alarm.id
        lastProcessedAlertingSurfaceAt[alarm.id.uuidString] = Date()

        // Mark the backup slot empty if this was a backup that fired.
        if let (chainSource, _) = isBackupAlarmKitAlarm(alarm.id) {
            pendingBackupAlarmIds.removeValue(forKey: chainSource)
        }

	        // BACKUP ALARM CHAIN: only fire backups when app is NOT in foreground.
	        // In foreground, AppEngine owns sound/UI immediately and we don't want
	        // AlarmKit banners stacking up on the user's screen. When the user
	        // backgrounds/locks, the scenePhase handler kicks off the chain.
	        if UIApplication.shared.applicationState != .active {
	            await ensureBackupAlarmKitChain(sourceAlarmId: sourceAlarmId)
	        } else {
	            let enginePlaying = AlarmContinuousAudioEngine.shared.confirmStillPlaying()
	            if enginePlaying {
	                try? AlarmManager.shared.stop(id: alarm.id)
	                try? AlarmManager.shared.cancel(id: alarm.id)
	                lastFiredAlarmIdsBySource.removeValue(forKey: sourceAlarmId)
	                print("[NotificationManager] 🧹 Foreground — dismissed AlarmKit surface after AppEngine start \(alarm.id.uuidString)")
	            } else {
	                print("[NotificationManager] Foreground — kept AlarmKit surface because AppEngine is not playing \(alarm.id.uuidString)")
	            }
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
	                    extra: "alarmkit-surface-dismissed-after-engine-start=true"
	                )
	                if AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
	                    try? AlarmManager.shared.stop(id: alarm.id)
	                    try? AlarmManager.shared.cancel(id: alarm.id)
	                }
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
	            // App is backgrounded/locked — AlarmKit remains the audible/system UI
	            // owner; this request only enables post-unlock custom UI handoff.
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
        print("🧭 [ALARMTRACE_ACTION] EVENT=LEGACY_ALARM_STOP_ACTION_RECEIVED REQUEST_ID=\(notification.request.identifier) IS_RINGING=\(ringCoordinator?.isRinging == true)")
        if notification.request.content.categoryIdentifier == AppNotificationCategory.appEngineRingingControl {
            handleAppEngineRingingControlAction(notification: notification, action: AppNotificationAction.appEngineRingingOpenStop)
            return
        }
        if ringCoordinator?.isRinging == true {
            // PRD: the alarm stops ONLY via the Stop button in the custom in-app
            // ringing UI (after mission completion). A notification Stop action must
            // bring the user into that UI — it must never stop the alarm directly.
            print("[NotificationManager] alarmStop tapped while ringing — redirecting to custom UI (not stopping)")
            let sourceAlarmId = (notification.request.content.userInfo["alarmId"] as? String)
                ?? ringCoordinator?.activeAlarm?.id.uuidString
            if let sourceAlarmId {
                requestCustomUIHandoff(sourceAlarmId: sourceAlarmId, surfaceAlarmId: nil)
                startOrQueueAlarm(alarmId: sourceAlarmId)
            }
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
        print("🧭 [ALARMTRACE_ACTION] EVENT=LEGACY_ALARM_SNOOZE_ACTION_RECEIVED REQUEST_ID=\(notification.request.identifier) IS_RINGING=\(ringCoordinator?.isRinging == true)")
        if notification.request.content.categoryIdentifier == AppNotificationCategory.appEngineRingingControl {
            handleAppEngineRingingControlAction(notification: notification, action: AppNotificationAction.alarmSnooze)
            return
        }
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

    private enum PendingNotificationNavigation {
        static let openAlarmMenuKey = "alarmo.notification.pendingOpenAlarmMenu"
        static let suppressHomeUpsellOnceKey = "alarmo.navigation.suppressHomeUpsellOnce"
        static let forceShowOnboardingNextLaunchKey = "alarmo.onboarding.forceShowNextLaunch"
    }

    /// Routes informational notification taps to the alarm tab. Persists intent for
    /// cold launches where `didReceive` fires before `AppRootView` subscribes.
    func requestOpenAlarmMenuNavigation(reason: String, alarmId: String? = nil) {
        UserDefaults.standard.set(true, forKey: PendingNotificationNavigation.openAlarmMenuKey)
        UserDefaults.standard.set(true, forKey: PendingNotificationNavigation.suppressHomeUpsellOnceKey)
        // Force-quit sets this in `applicationWillTerminate`; clear it so tap lands on alarms.
        UserDefaults.standard.set(false, forKey: PendingNotificationNavigation.forceShowOnboardingNextLaunchKey)
        print("[Navigation] queued open-alarm-menu reason=\(reason)")
        var userInfo: [AnyHashable: Any] = [:]
        if let alarmId {
            userInfo["alarmId"] = alarmId
        }
        NotificationCenter.default.post(
            name: .openAlarmMenuFromReadinessNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    func hasPendingOpenAlarmMenuNavigation() -> Bool {
        UserDefaults.standard.bool(forKey: PendingNotificationNavigation.openAlarmMenuKey)
    }

    func clearPendingOpenAlarmMenuNavigation() {
        UserDefaults.standard.removeObject(forKey: PendingNotificationNavigation.openAlarmMenuKey)
    }

    func consumeSuppressHomeUpsellOnce() -> Bool {
        let key = PendingNotificationNavigation.suppressHomeUpsellOnceKey
        guard UserDefaults.standard.bool(forKey: key) else { return false }
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }

    private func isInformationalOpenAppNotification(_ notification: UNNotification) -> Bool {
        let userInfo = notification.request.content.userInfo
        if userInfo[AlarmNotificationKind.userInfoKey] as? String == AlarmNotificationKind.openAppOnly {
            return true
        }
        let identifier = notification.request.identifier
        if identifier == ForceQuitWarning.identifier || identifier == AppClosedWarning.identifier {
            return true
        }
        if PreAlarmReadinessReminder.isReadinessIdentifier(identifier) {
            return true
        }
        return ArmedAlarmCloseWarningStandby.isArmedCloseWarningIdentifier(identifier)
    }

    private func handleInformationalOpenAppNotificationTap(notification: UNNotification) {
        let identifier = notification.request.identifier
        print("[NotificationTap] informational open-app notification id=\(identifier)")
        if identifier == ForceQuitWarning.identifier {
            cancelForceQuitWarning(reason: "informational-tap")
        }
        if identifier == AppClosedWarning.identifier {
            cancelAppClosedWarning(reason: "informational-tap")
        }
        if ArmedAlarmCloseWarningStandby.isArmedCloseWarningIdentifier(identifier) {
            cancelArmedAlarmCloseWarning(reason: "informational-tap")
        }
        if PreAlarmReadinessReminder.isReadinessIdentifier(identifier) {
            let alarmId = (notification.request.content.userInfo[PreAlarmReadinessReminder.userInfoSourceAlarmIDKey] as? String)
            if let alarmId {
                cancelPreAlarmReadinessReminder(alarmId: alarmId, reason: "informational-tap")
            }
        }
        requestOpenAlarmMenuNavigation(reason: "informational-open-app-\(identifier)")
    }
}

enum AppNotificationCategory {
    static let alarmRing = "ALARM_RING"
    static let appEngineRingingControl = "APP_ENGINE_RINGING_CONTROL"
    static let alarmRecoveryOpenApp = "ALARM_RECOVERY_OPEN_APP"
    static let alarmKitUnlock = "ALARMKIT_UNLOCK"
    static let alarmAuthPrompt = "ALARM_AUTH_PROMPT"
    static let alarmPostSlideControl = "ALARM_POST_SLIDE_CONTROL"
    static let alarmForegroundSoundReminder = "ALARM_FOREGROUND_SOUND_REMINDER"
    static let appOpenReminder = "ALARM_APP_OPEN_REMINDER"
    static let preAlarmReadiness = "PRE_ALARM_READINESS"
    static let forceQuitWarning = "FORCE_QUIT_WARNING"
    static let unlockToStop = "UNLOCK_TO_STOP"
    // Legacy category retained for backward compatibility with already-delivered notifications.
    static let alarmStopCard = "ALARM_STOP_CATEGORY"
    static let planReminder = "PLAN_REMINDER"
    static let focusSession = "FOCUS_SESSION"
    static let countdown = "COUNTDOWN"
}

enum AppNotificationAction {
    static let alarmSnooze = "ALARM_SNOOZE"
    static let alarmStop = "ALARM_STOP"
    static let appEngineRingingOpenStop = "APP_ENGINE_RINGING_OPEN_STOP"
    static let appEngineRingingOpenSnooze = "APP_ENGINE_RINGING_OPEN_SNOOZE"
    static let appOpenReminderOpen = "ALARM_APP_OPEN_REMINDER_OPEN"
    static let preAlarmReadinessOpen = "PRE_ALARM_READINESS_OPEN"
    static let forceQuitWarningOpen = "FORCE_QUIT_WARNING_OPEN"
    static let unlockToStop = "UNLOCK_TO_STOP_ACTION"
    static let alarmForegroundSoundOpen = "ALARM_FOREGROUND_SOUND_OPEN"
    static let alarmPostSlideStopAlarm = "ALARM_POST_SLIDE_STOP_ALARM"
    // Legacy action retained for backward compatibility with already-delivered notifications.
    static let alarmStopCardAction = "ALARM_STOP_ACTION"
    static let alarmKitUnlockDismiss = "ALARMKIT_UNLOCK_DISMISS"
    static let alarmRecoveryOpenApp = "ALARM_RECOVERY_OPEN_APP"
    static let alarmAuthPromptUnlock = "ALARM_AUTH_PROMPT_UNLOCK"
    static let planMarkDone = "PLAN_MARK_DONE"
    static let planRemindIn10 = "PLAN_REMIND_IN_10"
    static let focusStartNow = "FOCUS_START_NOW"
    static let focusSkipBreak = "FOCUS_SKIP_BREAK"
    static let countdownAddMinute = "COUNTDOWN_ADD_MINUTE"
    static let countdownStop = "COUNTDOWN_STOP"
}

extension Notification.Name {
    static let openAlarmMenuFromReadinessNotification = Notification.Name("alarmo.notification.openAlarmMenu")
    static let showForceQuitEducationAfterAlarmSetup = Notification.Name("alarmo.alarmSetup.showForceQuitEducation")
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
