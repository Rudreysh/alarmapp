import SwiftUI
import Combine
import SwiftData
import UIKit
import AVFoundation
#if canImport(AlarmKit)
import AlarmKit
#endif

struct AppRootView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var appPreferences: AppPreferences
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var ringCoordinator = AlarmRingCoordinator()
    @StateObject private var notificationManager: NotificationManager = NotificationManager.shared
    @StateObject private var taskStore = TaskStore()
    @StateObject private var pomodoroEngine = PomodoroEngine()
    @StateObject private var navigationStore = NavigationStore()
    @ObservedObject private var settingsStore = SettingsStore.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var foregroundScheduler: AlarmForegroundScheduler?
    @State private var showingMainTab: Bool
    @State private var didRunAppListMigration = false
    @StateObject private var accountabilityManager = AccountabilityEnforcementManager.shared
    @StateObject private var shutdownDetectionService = ShutdownDetectionService()
    @StateObject private var tamperDetectionService = TamperDetectionService.shared
    @State private var showLegacyAlarmModeNotice = false
    @State private var showNotificationsDisabledWarning = false
    @State private var didRequestAlarmNotificationPermission = false
    @State private var showAlarmKitFailureNotice = false
    @State private var alarmKitFailureMessage = "AlarmKit scheduling failed."
    @State private var customUIHandoffRetryWorkItem: DispatchWorkItem?
    @State private var stopAlarmKitSurfaceTask: Task<Void, Never>?
    @State private var foregroundTakeoverVerificationTask: Task<Void, Never>?
    @State private var customUIHandoffInProgress = false
    @State private var customUIHandoffActiveRequestKey: String?
    @State private var customUIHandoffStartedAt: Date?
    @State private var customUIHandoffAttemptCount: Int = 0
    @AppStorage("settings.alarmThemeStyleRaw") private var appThemeStyleRaw: String = AlarmThemeStyle.default.rawValue
    @State private var showLaunchLogo = true
    @State private var forceCloseWarningHeartbeat: Timer?
    @State private var showForceQuitEducationAlert = false

    init() {
        let preferences = AppPreferences()
        _appPreferences = StateObject(wrappedValue: preferences)
        // Resolve onboarding/main-tab state up-front to avoid a one-frame onboarding flash
        // that can look like "Next" skipped onboarding and jumped to Home.
        _showingMainTab = State(initialValue: Self.initialMainTabState(from: preferences))
    }

    var body: some View {
        return ZStack {
            Group {
                if showingMainTab {
                    MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
                } else {
                    OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences, alarmStore: alarmStore)
                }
            }

            if showLaunchLogo {
                LaunchLogoView(isTiimoTheme: isTiimoTheme)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: showLaunchLogo)
        .onAppear {
            let dismissDelay: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0.55 : 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                showLaunchLogo = false
                applyOpenAlarmMenuNavigationIfPending(trigger: "post-launch-logo")
            }
        }
        .environmentObject(themeManager)
        .preferredColorScheme(resolvedColorScheme)
        .onAppear {
            // Assets served from Cloudflare R2 (awayk-assets-prod bucket).
            AssetManager.shared.configure(catalogURL: "https://pub-867c22af17a844a8abf716b25dec2772.r2.dev/HostedAssets/catalog.json")
            Task {
                await AssetManager.shared.fetchCatalog()
            }
            
            clearStaleForceOnboardingFlagIfNeeded(trigger: "onAppear")
            updateViewState()
            applyOpenAlarmMenuNavigationIfPending(trigger: "onAppear")
            if foregroundScheduler == nil {
                let alarmScheduler = AlarmManagerFacade.shared
                let scheduler = AlarmForegroundScheduler(alarmStore: alarmStore, ringCoordinator: ringCoordinator)
                foregroundScheduler = scheduler
                ringCoordinator.configure(alarmStore: alarmStore, foregroundScheduler: scheduler, modelContext: modelContext)
                AlarmBackgroundAudioBridge.shared.configure(alarmStore: alarmStore)
                scheduler.start()
                notificationManager.configure(ringCoordinator: ringCoordinator, alarmStore: alarmStore)
                Task {
                    _ = await alarmScheduler.requestAlarmAuthorizationIfNeeded()
                }
                notificationManager.recoverAlarmFromDeliveredNotificationsIfNeeded()
                notificationManager.recoverAlarmKitAlertingIfNeeded()
                alarmScheduler.reconcilePersistedAlarms(alarmStore.alarms)
                // Launch may occur directly into the background (e.g. relaunched by
                // the system) — start the keep-alive if an alarm is pending.
                AlarmKeepAliveAudioService.shared.evaluate(reason: "launch")
                // Re-apply (or release if expired) any standalone timed app lock so
                // it survives force-quit / reboot.
                TimedAppLockManager.shared.restoreOnLaunch()
            }
            restoreAndTakeoverWhenAppActive(reason: "onAppear")
            handlePendingCustomAlarmUIHandoff(trigger: "onAppear")
#if DEBUG
            if AlarmRecoveryTestHarness.shouldSkipOnboarding {
                UserDefaults.standard.set(true, forKey: "alarmo.onboarding.completed")
            }
            if let fireIn = AlarmRecoveryTestHarness.fireTestAlarmInSeconds {
                AlarmRecoveryTestHarness.scheduleSimulatorTestAlarm(
                    alarmStore: alarmStore,
                    secondsFromNow: fireIn
                )
            }
            if AlarmRecoveryTestHarness.isEnabled {
                AlarmRecoveryTestHarness.runLoop(notificationManager: notificationManager)
            }
            if CommandLine.arguments.contains(NotificationManager.AppClosedWarning.debugLaunchArgument) {
                notificationManager.debugForceScheduleAppClosedWarning(alarms: alarmStore.alarms)
            }
#endif
            NotificationOrchestrator.shared.reconcileAlarmLifecycleNotifications(alarms: alarmStore.alarms)
            shutdownDetectionService.startMonitoring(alarmStore: alarmStore, ringCoordinator: ringCoordinator, ringingAlarmId: ringCoordinator.activeAlarm?.id)
            accountabilityManager.ensureShieldRestoredOnLaunch()
            AccountabilityShieldEngine.shared.reconcileActiveSessionOnLaunch(ringingAlarmId: ringCoordinator.activeAlarm?.id, alarmStore: alarmStore)
            pomodoroEngine.configure(with: appPreferences)
            if hasPendingLiveActivityOpenRequest(), !notificationManager.hasPendingOpenAlarmMenuNavigation() {
                navigationStore.selectedTab = .timer
                navigationStore.requestedTimerMode = .pomo
            }
            if !didRunAppListMigration {
                AppListMigrationCoordinator.migrateLegacySelectionIfNeeded(context: modelContext, settings: settingsStore)
                didRunAppListMigration = true
            }
            SystemOutputVolumeFloorManager.shared.prepareVolumeViewIfNeeded()
            notificationManager.logColdStartLifecycleInference()
            notificationManager.markCleanForegroundSession(reason: "onAppear")
            notificationManager.purgeAllOpenAlarmoAgainNotifications(reason: "onAppear")
            notificationManager.purgeAllRecoveryOpenAppNotifications(reason: "onAppear")
            notificationManager.cancelAppClosedWarning(reason: "onAppear")
            notificationManager.cancelArmedAlarmCloseWarning(reason: "onAppear")
            notificationManager.purgeAllArmedAlarmCloseWarningNotifications(reason: "onAppear")
            notificationManager.cancelForceQuitWarning(reason: "onAppear")
            notificationManager.reconcilePreAlarmReadinessReminders(alarms: alarmStore.alarms, reason: "onAppear")
            notificationManager.runReadinessHealthCheckOnAppOpen(alarms: alarmStore.alarms)
            ensureAlarmNotificationPermissionIfNeeded(reason: "onAppear-existing-alarm")
        }
        .environmentObject(ringCoordinator)
        .environmentObject(notificationManager)
        .environmentObject(taskStore)
        .environmentObject(pomodoroEngine)
        .environmentObject(navigationStore)
        .fullScreenCover(isPresented: Binding(
            get: { shouldPresentAlarmRingingFullScreen },
            set: { _ in }
        )) {
            AlarmRingingView(ringCoordinator: ringCoordinator)
        }
        .onReceive(alarmStore.$alarms) { _ in
            foregroundScheduler?.scheduleNext()
            NotificationOrchestrator.shared.reconcileAlarmLifecycleNotifications(alarms: alarmStore.alarms)
            notificationManager.purgeAllOpenAlarmoAgainNotifications(reason: "alarms-updated")
            notificationManager.reconcilePreAlarmReadinessReminders(alarms: alarmStore.alarms, reason: "alarms-updated")
            ensureAlarmNotificationPermissionIfNeeded(reason: "first-alarm-enable")
            applyOpenAlarmMenuNavigationIfPending(trigger: "alarms-updated")
        }
        .onChange(of: appPreferences.onboardingCompleted) { _, _ in
            updateViewState()
        }
        .onChange(of: appPreferences.forceShowOnboardingNextLaunch) { _, _ in
            updateViewState()
        }
        .onChange(of: appPreferences.devAlwaysShowOnboarding) { _, _ in
            updateViewState()
        }
        .onChange(of: ringCoordinator.activeAlarm) { newAlarm in
            shutdownDetectionService.startMonitoring(alarmStore: alarmStore, ringCoordinator: ringCoordinator, ringingAlarmId: newAlarm?.id)
        }
        .onChange(of: scenePhase) { _, newPhase in
            notificationManager.logLifecycleTransition("scenePhase=\(String(describing: newPhase))")
            if newPhase == .active {
                // App is alive in foreground — the overnight keep-alive is no longer
                // needed; stop it to save battery.
                AlarmKeepAliveAudioService.shared.evaluate(reason: "scene-active")
                // Release an expired timed app-lock, or re-assert + tamper-check an
                // active one (the lock's tick timer is suspended in the background).
                TimedAppLockManager.shared.refreshOnForeground()
                applyOpenAlarmMenuNavigationIfPending(trigger: "scene-active")
                SystemOutputVolumeFloorManager.shared.prepareVolumeViewIfNeeded()
                notificationManager.markCleanForegroundSession(reason: "scene-active")
                AlarmAudioStateController.shared.handleAppBecameActive()
                restoreAndTakeoverWhenAppActive(reason: "scenePhase.active")
                AlarmAuthHandoffStore.writeHeartbeat(
                    runId: AlarmAudioStateController.shared.currentAlarmRunId?.uuidString,
                    isPlaying: AlarmContinuousAudioEngine.shared.confirmStillPlaying()
                )
                if let sourceId = ringCoordinator.activeAlarm?.id.uuidString
                    ?? AlarmAuthHandoffStore.activeRingingAlarmId() {
                    notificationManager.cancelForegroundSoundReminderNotification(sourceAlarmId: sourceId)
                }
                notificationManager.cancelArmedAlarmCloseWarning(reason: "scene-active")
                notificationManager.cancelAppClosedWarning(reason: "scene-active")
                notificationManager.cancelForceQuitWarning(reason: "scene-active")
                notificationManager.purgeAllRecoveryOpenAppNotifications(reason: "scene-active")
                notificationManager.runReadinessHealthCheckOnAppOpen(alarms: alarmStore.alarms)
                refreshSwipeAwayWarningStandbyIfNeeded(reason: "scene-active")
                startForceCloseWarningHeartbeat()
                if ringCoordinator.isRinging || AlarmAudioStateController.shared.isAlarmRinging {
                    AlarmAudioStateController.shared.enforceForegroundVolumeControl(reason: "scene-active")
                }
                AlarmContinuousAudioEngine.shared.recoverIfNeeded()
                print("[AppRoot] Engine recovery check on active — isEngineActive: \(AlarmContinuousAudioEngine.shared.isEngineActive)")
                if hasPendingLiveActivityOpenRequest(), !notificationManager.hasPendingOpenAlarmMenuNavigation() {
                    navigationStore.selectedTab = .timer
                    navigationStore.requestedTimerMode = .pomo
                }
                pomodoroEngine.handleSceneDidBecomeActive()
                tamperDetectionService.evaluateOnForeground(ringCoordinator: ringCoordinator)
                // Pre-warm audio session SYNCHRONOUSLY before any other work
                // so the first user-perceivable moment after unlock has audio
                // ready to play.
                try? AudioRouteManager.configureAlarmSession()
                ringCoordinator.reassertRingingAudio(reason: "scene-active")
                // App is now foreground. Dismiss any currently-alerting
                // AlarmKit banners so they don't sit on top of our in-app UI,
                // BUT keep the backup chain alive — if the user re-locks
                // quickly, we need a fresh backup to fire within ~2s so the
                // lock-screen slide-to-stop reappears with system audio. The
                // chain naturally dismisses each backup as it fires in
                // foreground (see processAlarmKitAlertingAlarm) so banners
                // never accumulate.
                if #available(iOS 26.0, *), ringCoordinator.isRinging,
                   let alarm = ringCoordinator.activeAlarm {
                    Task {
                        let appEngineAudible = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
                            reason: "scene-active-dismiss-alarmkit"
                        )
                        if appEngineAudible {
                            notificationManager.nukeAllAlertingAlarmKitSurfaces(reason: "scene-active-engine-verified")
                            notificationManager.cancelAllBackupAlarmKitChains()
                        } else {
                            print("[AppRoot] Scene active — keeping AlarmKit surfaces until AppEngine is strictly verified")
                        }
                    }
                    Task {
                        let engineLiveHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
                            AlarmContinuousAudioEngine.shared.cachedIsHealthy &&
                            AlarmContinuousAudioEngine.shared.confirmStillPlaying()
                        if !engineLiveHealthy {
                            if AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() {
                                await notificationManager.ensureBackupAlarmKitChain(sourceAlarmId: alarm.id.uuidString)
                                print("[AppRoot] Scene active — backup chain scheduled (engine not healthy)")
                            } else {
                                print("[AppRoot] Scene active — backup chain suppressed by phase \(AlarmAudioStateController.shared.phase.rawValue)")
                            }
                        } else {
                            print("[AppRoot] Scene active — backup chain skipped (engine healthy, avoiding session conflict)")
                        }
                    }
                }
                notificationManager.recoverAlarmFromDeliveredNotificationsIfNeeded()
                notificationManager.recoverAlarmKitAlertingIfNeeded()
                // Fast path: if coordinator already knows alarm is ringing, make
                // sure the full-screen UI is visible immediately on re-foreground.
                ringCoordinator.ensureRingingUIVisible()
                // Cold-launch fast path: coordinator has no state yet but AlarmKit
                // may already be alerting. Synchronous check so the alarm UI appears
                // without waiting for the async recoverAlarmKitAlertingIfNeeded task.
                if foregroundScheduler != nil, !ringCoordinator.isRinging {
#if canImport(AlarmKit)
                    if #available(iOS 26.0, *) {
                        if let alertingAlarm = (try? AlarmManager.shared.alarms)?
                            .first(where: { $0.state == .alerting }) {
                            let surfaceId = alertingAlarm.id.uuidString
                            let sourceId = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceId)
                            print("[AppRoot] Direct AlarmKit alerting alarm on foreground — starting ring source=\(sourceId)")
                            _ = ringCoordinator.startRinging(alarmId: sourceId, source: .notification)
                        }
                    }
#endif
                }
                restoreAndTakeoverWhenAppActive(reason: "scenePhase.active-post-recovery")
                enforceAlarmCustomUIIfNeeded()
                handlePendingCustomAlarmUIHandoff(trigger: "scenePhase.active")
                refreshAlarmUnlockPromptIfNeeded()
                if let sourceId = ringCoordinator.activeAlarm?.id.uuidString
                    ?? AlarmAuthHandoffStore.activeRingingAlarmId() {
                    notificationManager.cancelForceClosedWarningIfAppHandlingSound(sourceAlarmId: sourceId)
                    notificationManager.cancelAppEngineRingingControlNotification(
                        sourceAlarmId: sourceId,
                        reason: "scene-active"
                    )
                }
            } else if newPhase == .inactive || newPhase == .background {
                stopForceCloseWarningHeartbeat()
                AlarmAuthHandoffStore.writeHeartbeat(
                    runId: AlarmAudioStateController.shared.currentAlarmRunId?.uuidString,
                    isPlaying: AlarmContinuousAudioEngine.shared.confirmStillPlaying()
                )
                pomodoroEngine.handleSceneDidEnterBackground()
                // Backgrounding with a pending alarm: start the bounded silent
                // keep-alive so the process stays alive until the alarm fires and the
                // AppEngine can take over (no-op if no alarm is pending / ring active).
                AlarmKeepAliveAudioService.shared.evaluate(reason: "scene-\(newPhase == .inactive ? "inactive" : "background")")
                stopAlarmKitSurfaceTask?.cancel()
                stopAlarmKitSurfaceTask = nil
                print("🧭 [ALARMTRACE_ACTION] EVENT=SCENE_LEFT_FOREGROUND POSSIBLE_SIDE_BUTTON=true SCENE_PHASE=\(String(describing: newPhase).uppercased()) APP_STATE=\(UIApplication.shared.applicationState.rawValue) IS_RINGING=\(ringCoordinator.isRinging) ENGINE_ACTIVE=\(AlarmContinuousAudioEngine.shared.isEngineActive) ENGINE_HEALTHY=\(AlarmContinuousAudioEngine.shared.cachedIsHealthy) PHASE=\(AlarmAudioStateController.shared.phase.rawValue) BRIDGE_SURFACE=\(AlarmBackgroundAudioBridge.shared.currentAlarmID ?? "nil")")
                let _sysVol = AVAudioSession.sharedInstance().outputVolume
                let _playerVol = AlarmContinuousAudioEngine.shared.currentPlayerVolume
                let _appTarget = AlarmAudioStateController.shared.selectedSoundVolume
                print("[SideButton] pressed: system=\(String(format: "%.2f", _sysVol)) player=\(String(format: "%.2f", _playerVol)) appTarget=\(String(format: "%.2f", _appTarget)) phase=\(AlarmAudioStateController.shared.phase.rawValue) isRinging=\(ringCoordinator.isRinging)")
                // CRITICAL: cancel any in-flight AlarmKit dismissal. If the user
                // re-locks during a deferred dismissal window, we must NOT stop
                // AlarmKit — its lock-screen surface is the most reliable audio
                // continuity for the alarm.
                notificationManager.cancelPendingAlarmKitDismissals(reason: "scene-inactive-background")
                ringCoordinator.cancelDeferredBridgeStop(reason: "scene-inactive-background")
                let sceneLabel = newPhase == .inactive ? "inactive" : "background"
                notificationManager.handleAppLeaveLifecycleEvent(
                    ringCoordinator: ringCoordinator,
                    alarms: alarmStore.alarms,
                    reason: "scene-\(sceneLabel)"
                )
                let resolvedSourceAlarmId: String? = {
                    if let alarm = ringCoordinator.activeAlarm { return alarm.id.uuidString }
                    if let persisted = AlarmAuthHandoffStore.activeRingingAlarmId() { return persisted }
                    if let bridgeSource = AlarmBackgroundAudioBridge.shared.currentSourceAlarmID { return bridgeSource }
                    if let surface = AlarmBackgroundAudioBridge.shared.currentAlarmID {
                        return AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surface)
                    }
                    return nil
                }()
                let resolvedSurfaceAlarmId: String? = {
                    AlarmBackgroundAudioBridge.shared.currentAlarmID
                        ?? AlarmAuthHandoffStore.surfaceAlarmId()
                        ?? resolvedSourceAlarmId
                }()
                if let sourceAlarmId = resolvedSourceAlarmId,
                   !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
                    let alarmStillActive = notificationManager.isLiveAlarmSessionActive(
                        ringCoordinator: ringCoordinator,
                        sourceAlarmId: sourceAlarmId
                    )
                    if alarmStillActive {
                        let enginePhase = AlarmAudioStateController.shared.phase
                        let engineOwnsAudio = (enginePhase == .appEnginePrimary || enginePhase == .appEngineFadingIn)
                            && AlarmContinuousAudioEngine.shared.confirmStillPlaying()
                        if engineOwnsAudio
                            || AlarmAudioStateController.shared.userHasUnlockedDuringThisAlarmRun {
                            notificationManager.dismissAlarmKitUIForAppEngineOwnedSession(
                                sourceAlarmId: sourceAlarmId,
                                reason: "scene-\(sceneLabel)-engine-primary"
                            )
                        }
                        print("🧭 [ALARMTRACE_ACTION] EVENT=SIDE_BUTTON_OR_BACKGROUND_DURING_RINGING ALARM_ID=\(sourceAlarmId) RC_RINGING=\(ringCoordinator.isRinging) ENGINE_ACTIVE=\(AlarmContinuousAudioEngine.shared.isEngineActive)")
                        notificationManager.handleLockedHardwareSuppression(
                            sourceAlarmId: sourceAlarmId,
                            surfaceAlarmId: resolvedSurfaceAlarmId,
                            scenePhaseLabel: sceneLabel,
                            reason: "side-button-scene-\(sceneLabel)"
                        )
                        if !engineOwnsAudio {
                            notificationManager.startAlarmKitUnlockPromptLoop(
                                sourceAlarmId: sourceAlarmId,
                                surfaceAlarmId: resolvedSurfaceAlarmId ?? sourceAlarmId,
                                alarmName: ringCoordinator.activeAlarm?.name
                            )
                        }
                    }
                }
            }
        }
        .onOpenURL { url in
            handleAlarmHandoffURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmKitCustomUIHandoffRequested)) { _ in
            let appState = UIApplication.shared.applicationState
            guard appState == .active else {
                print("[AppRoot] Deferring custom UI handoff request until app active (state=\(appState.rawValue))")
                return
            }
            restoreAndTakeoverWhenAppActive(reason: "customUIHandoffRequested")
            handlePendingCustomAlarmUIHandoff(trigger: "customUIHandoffRequested")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            notificationManager.logLifecycleTransition("willEnterForeground")
            print("🧭 [ALARMTRACE_ACTION] EVENT=WILL_ENTER_FOREGROUND IS_RINGING=\(ringCoordinator.isRinging) ENGINE_ACTIVE=\(AlarmContinuousAudioEngine.shared.isEngineActive) ENGINE_HEALTHY=\(AlarmContinuousAudioEngine.shared.cachedIsHealthy) PHASE=\(AlarmAudioStateController.shared.phase.rawValue) BRIDGE_PLAYING=\(AlarmBackgroundAudioBridge.shared.isPlaying)")
            restoreAndTakeoverWhenAppActive(reason: "willEnterForeground")
            if ringCoordinator.isRinging {
                ringCoordinator.reassertRingingAudio(reason: "willEnterForeground")
                ringCoordinator.ensureRingingUIVisible()
            } else if AlarmBackgroundAudioBridge.shared.isPlaying {
                AlarmBackgroundAudioBridge.shared.reinforceLockedLoopNow(reason: "willEnterForeground")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            notificationManager.logLifecycleTransition("willResignActive")
            notificationManager.handleAppLeaveLifecycleEvent(
                ringCoordinator: ringCoordinator,
                alarms: alarmStore.alarms,
                reason: "willResignActive"
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            notificationManager.logLifecycleTransition("didEnterBackground")
            notificationManager.handleAppLeaveLifecycleEvent(
                ringCoordinator: ringCoordinator,
                alarms: alarmStore.alarms,
                reason: "didEnterBackground"
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAlarmMenuFromReadinessNotification)) { _ in
            applyOpenAlarmMenuNavigationIfPending(trigger: "notification-tap")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            notificationManager.logLifecycleTransition("didBecomeActive")
            print("🧭 [ALARMTRACE_ACTION] EVENT=DID_BECOME_ACTIVE IS_RINGING=\(ringCoordinator.isRinging) ENGINE_ACTIVE=\(AlarmContinuousAudioEngine.shared.isEngineActive) ENGINE_HEALTHY=\(AlarmContinuousAudioEngine.shared.cachedIsHealthy) PHASE=\(AlarmAudioStateController.shared.phase.rawValue)")
            notificationManager.markCleanForegroundSession(reason: "didBecomeActive")
            AlarmAudioStateController.shared.handleAppBecameActive()
            restoreAndTakeoverWhenAppActive(reason: "didBecomeActive")
            AlarmContinuousAudioEngine.shared.recoverIfNeeded()
            print("[AppRoot] Engine recovery check on active — isEngineActive: \(AlarmContinuousAudioEngine.shared.isEngineActive)")
            ringCoordinator.reassertRingingAudio(reason: "didBecomeActive")
            ringCoordinator.ensureRingingUIVisible()
            notificationManager.cancelArmedAlarmCloseWarning(reason: "didBecomeActive")
            notificationManager.cancelAppClosedWarning(reason: "didBecomeActive")
            notificationManager.cancelForceQuitWarning(reason: "didBecomeActive")
            notificationManager.purgeAllRecoveryOpenAppNotifications(reason: "didBecomeActive")
            applyOpenAlarmMenuNavigationIfPending(trigger: "didBecomeActive")
            notificationManager.runReadinessHealthCheckOnAppOpen(alarms: alarmStore.alarms)
            refreshSwipeAwayWarningStandbyIfNeeded(reason: "didBecomeActive")
            startForceCloseWarningHeartbeat()
            notificationManager.recoverAlarmKitAlertingIfNeeded()
            enforceAlarmCustomUIIfNeeded()
            handlePendingCustomAlarmUIHandoff(trigger: "didBecomeActive")
            if let sourceId = ringCoordinator.activeAlarm?.id.uuidString
                ?? AlarmAuthHandoffStore.activeRingingAlarmId() {
                notificationManager.cancelAppEngineRingingControlNotification(
                    sourceAlarmId: sourceId,
                    reason: "didBecomeActive"
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            notificationManager.recordProtectedDataWillBecomeUnavailable()
            if let sourceId = ringCoordinator.activeAlarm?.id.uuidString
                ?? AlarmAuthHandoffStore.activeRingingAlarmId()
                ?? AlarmAudioStateController.shared.currentAlarmId,
               AlarmAuthHandoffStore.alarmState() == .ringing,
               notificationManager.isLiveAlarmSessionActive(
                   ringCoordinator: ringCoordinator,
                   sourceAlarmId: sourceId
               ),
               !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() {
                let surfaceId = AlarmBackgroundAudioBridge.shared.currentAlarmID
                    ?? AlarmAuthHandoffStore.surfaceAlarmId()
                    ?? sourceId
                print("🧭 [ALARMTRACE_ACTION] EVENT=PROTECTED_DATA_LOCK_DURING_RING ALARM_ID=\(sourceId)")
                notificationManager.handleLockedHardwareSuppression(
                    sourceAlarmId: sourceId,
                    surfaceAlarmId: surfaceId,
                    scenePhaseLabel: "protected-data-lock",
                    reason: "protected-data-lock-side-button"
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            notificationManager.recordProtectedDataDidBecomeAvailable()
            let appState = UIApplication.shared.applicationState
            print("🧭 [ALARMTRACE_ACTION] EVENT=PROTECTED_DATA_AVAILABLE APP_STATE=\(appState.rawValue) IS_RINGING=\(ringCoordinator.isRinging) ENGINE_ACTIVE=\(AlarmContinuousAudioEngine.shared.isEngineActive) ENGINE_HEALTHY=\(AlarmContinuousAudioEngine.shared.cachedIsHealthy) PHASE=\(AlarmAudioStateController.shared.phase.rawValue)")
            restoreAndTakeoverWhenAppActive(reason: "protectedDataDidBecomeAvailable")
            if ringCoordinator.isRinging {
                ringCoordinator.reassertRingingAudio(reason: "protectedDataAvailable")
                ringCoordinator.ensureRingingUIVisible()
            } else if AlarmBackgroundAudioBridge.shared.isPlaying {
                AlarmBackgroundAudioBridge.shared.reinforceLockedLoopNow(reason: "protectedDataAvailable")
            }
            if appState == .active {
                enforceAlarmCustomUIIfNeeded()
                handlePendingCustomAlarmUIHandoff(trigger: "protectedDataAvailable")
            } else {
                print("[AppRoot] protectedDataAvailable handoff deferred until app active (state=\(appState.rawValue))")
            }
        }
        .onReceive(settingsStore.$notificationPrefs) { _ in
            NotificationOrchestrator.shared.reconcileAlarmLifecycleNotifications(alarms: alarmStore.alarms)
        }
        .onReceive(NotificationCenter.default.publisher(for: .planNotificationMarkDoneRequested)) { output in
            handlePlanNotificationMarkDone(userInfo: output.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusStartRequestedFromNotification)) { _ in
            navigationStore.selectedTab = .timer
            navigationStore.requestedTimerMode = .pomo
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSkipBreakRequestedFromNotification)) { _ in
            navigationStore.selectedTab = .timer
            navigationStore.requestedTimerMode = .pomo
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownAddMinuteRequestedFromNotification)) { _ in
            navigationStore.selectedTab = .timer
            navigationStore.requestedTimerMode = .stopwatch
        }
        .onReceive(NotificationCenter.default.publisher(for: .countdownStopRequestedFromNotification)) { _ in
            navigationStore.selectedTab = .timer
            navigationStore.requestedTimerMode = .stopwatch
        }
        .onReceive(NotificationCenter.default.publisher(for: .legacyAlarmModeNoticeRequested)) { _ in
            showLegacyAlarmModeNotice = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmKitSchedulingFailureNoticeRequested)) { _ in
            alarmKitFailureMessage = AlarmKitSchedulingMessenger.shared.latestMessage()
            showAlarmKitFailureNotice = true
        }
        .modifier(RootNoticeAlerts(
            showLegacyAlarmModeNotice: $showLegacyAlarmModeNotice,
            showAlarmKitFailureNotice: $showAlarmKitFailureNotice,
            showNotificationsDisabledWarning: $showNotificationsDisabledWarning,
            showForceQuitEducationAlert: $showForceQuitEducationAlert,
            alarmKitFailureMessage: alarmKitFailureMessage,
            onForceQuitEducationAcknowledged: {
                notificationManager.markForceQuitEducationAcknowledged()
            }
        ))
    }

    /// Requests notification permission the first time an enabled alarm exists
    /// while the app is foreground. If permission is denied, surfaces an in-app
    /// warning explaining the limitation. Idempotent per app session.
    private func ensureAlarmNotificationPermissionIfNeeded(reason: String) {
        guard UIApplication.shared.applicationState == .active else { return }
        guard !didRequestAlarmNotificationPermission else { return }
        guard alarmStore.alarms.contains(where: { $0.enabled }) else { return }
        guard notificationManager.authorizationStatus == .notDetermined
            || notificationManager.authorizationStatus == .denied else { return }

        didRequestAlarmNotificationPermission = true
        print("[AlarmSetup] ensuring notification permission before enabling alarm")
        Task { @MainActor in
            let result = await notificationManager.ensureNotificationPermissionForAlarmFeatures(reason: reason)
            switch result {
            case .granted:
                print("[AlarmSetup] notification permission granted")
                notificationManager.reconcilePreAlarmReadinessReminders(alarms: alarmStore.alarms, reason: "permission-granted")
            case .denied, .notDetermined:
                print("[AlarmSetup] notification permission denied; showing warning")
                showNotificationsDisabledWarning = true
            }
        }
    }
    
    /// Active ringing alarm always wins over onboarding — full-screen cover binding.
    /// Requires a genuine ring session (alarmState == ringing), not merely a
    /// future scheduled alarm or a readiness-notification tap.
    private var shouldPresentAlarmRingingFullScreen: Bool {
        guard AlarmAuthHandoffStore.isActivelyRinging() else { return false }
        if ringCoordinator.isRingingUIVisible { return true }
        if ringCoordinator.isRinging { return true }
        return true
    }

    /// "Open Alarmo again" reminders are disabled — purge any stale copies on foreground.
    private func refreshSwipeAwayWarningStandbyIfNeeded(reason: String) {
        notificationManager.purgeAllOpenAlarmoAgainNotifications(reason: reason)
        notificationManager.cancelArmedAlarmCloseWarning(reason: reason)
    }

    private func startForceCloseWarningHeartbeat() {
        stopForceCloseWarningHeartbeat()
    }

    private func stopForceCloseWarningHeartbeat() {
        forceCloseWarningHeartbeat?.invalidate()
        forceCloseWarningHeartbeat = nil
    }

    private func resolvedNextEnabledAlarmForCloseWarning() -> (alarm: Alarm, fireDate: Date)? {
        let now = Date()
        let upcoming = alarmStore.alarms.compactMap { alarm -> (Alarm, Date)? in
            guard alarm.enabled else { return nil }
            guard let fire = AlarmStore.nextFireDate(for: alarm, from: now), fire > now else { return nil }
            return (alarm, fire)
        }
        return upcoming.min(by: { $0.1 < $1.1 })
    }

    private func resolvedLiveAlarmSourceId() -> String? {
        if let alarm = ringCoordinator.activeAlarm { return alarm.id.uuidString }
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

    private func resolvedLiveAlarmSurfaceId(fallbackSourceId: String) -> String? {
        AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? AlarmAuthHandoffStore.surfaceAlarmId()
            ?? fallbackSourceId
    }

    private struct ForegroundEngineVerificationSample {
        let isPlaying: Bool
        let currentTime: TimeInterval
        let outputVolume: Float
        let hasValidRoute: Bool
    }

    /// Unified foreground takeover: when app is active and alarm is still ringing,
    /// AppEngine must reclaim audio immediately and only then dismiss AlarmKit.
    private func restoreAndTakeoverWhenAppActive(sourceAlarmId: String? = nil, reason: String) {
        print("[ForegroundTakeover] ENTRY reason=\(reason) source=\(sourceAlarmId ?? AlarmAuthHandoffStore.activeRingingAlarmId() ?? "nil")")
        guard UIApplication.shared.applicationState == .active else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        guard AlarmAuthHandoffStore.alarmState() == .ringing else { return }

        let resolvedSourceAlarmId = sourceAlarmId
            ?? AlarmAuthHandoffStore.activeRingingAlarmId()
            ?? resolvedLiveAlarmSourceId()
        guard let resolvedSourceAlarmId else { return }
        print("[AlarmRestore] active ringing alarm found before root routing source=\(resolvedSourceAlarmId)")

        let sessionLive = notificationManager.isLiveAlarmSessionActive(
            ringCoordinator: ringCoordinator,
            sourceAlarmId: resolvedSourceAlarmId
        )
        guard sessionLive else { return }

        print("[ForegroundTakeover] app active with ringing alarm source=\(resolvedSourceAlarmId) reason=\(reason)")
        if !appPreferences.onboardingCompleted {
            print("[AlarmRestore] active alarm overrides onboarding source=\(resolvedSourceAlarmId)")
        }
        print("[AlarmRestore] active alarm overrides main UI source=\(resolvedSourceAlarmId)")

        AlarmAuthHandoffStore.markAppBecameActive()
        restoreActiveRingingAlarmIfNeeded(trigger: "foreground-takeover-\(reason)")
        ringCoordinator.ensureRingingUIVisible()
        print("[ForegroundTakeover] presenting AlarmRingingView source=\(resolvedSourceAlarmId)")
        print("[AlarmRestore] presenting AlarmRingingView full-screen source=\(resolvedSourceAlarmId)")
        print("[ForegroundTakeover] starting AppEngine source=\(resolvedSourceAlarmId)")

        // Start takeover immediately in foreground.
        AlarmAudioStateController.shared.handleAppBecameActive()
        let appEngineAudible = AlarmAudioStateController.shared.isAppEngineQuickAudible(
            reason: "foreground-takeover-precheck-\(reason)"
        )
        if !appEngineAudible {
            print("[ForegroundTakeover] starting AppEngine takeover source=\(resolvedSourceAlarmId)")
            AudioRouteManager.shared.forceResetAlarmSession()
            AlarmContinuousAudioEngine.shared.recoverIfNeeded()
            ringCoordinator.reassertRingingAudio(reason: "foreground-takeover-\(reason)")
        }

        foregroundTakeoverVerificationTask?.cancel()
        foregroundTakeoverVerificationTask = Task { @MainActor in
            await verifyForegroundTakeoverAndFinalize(sourceAlarmId: resolvedSourceAlarmId, reason: reason)
        }
    }

    private func verifyForegroundTakeoverAndFinalize(sourceAlarmId: String, reason: String) async {
        try? await Task.sleep(nanoseconds: 170_000_000)
        let sample1 = captureForegroundEngineVerificationSample()
        try? await Task.sleep(nanoseconds: 220_000_000)
        let sample2 = captureForegroundEngineVerificationSample()
        let timeAdvanced = sample2.currentTime > sample1.currentTime + 0.02
        let strictAudible = await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
            reason: "foreground-takeover-verify-\(reason)"
        )
        print("[ForegroundTakeover] engine verification sample isPlaying=\(sample2.isPlaying) currentTime=\(String(format: "%.2f", sample2.currentTime)) outputVolume=\(String(format: "%.2f", sample2.outputVolume)) routeValid=\(sample2.hasValidRoute) timeAdvanced=\(timeAdvanced) strictAudible=\(strictAudible)")

        let pass = strictAudible
        if pass {
            print("[ForegroundTakeover] engine verification PASS source=\(sourceAlarmId)")
            print("[ForegroundTakeover] AppEngine verified playing source=\(sourceAlarmId)")
            print("[AudioOwner] AppEngine now owns sound after Unlock/Open-to-Stop")
            AlarmAudioStateController.shared.markUserUnlockedDuringAlarmRun(reason: "foreground-takeover-verified")
            print("[ForegroundTakeover] dismissing AlarmKit after engine verified source=\(sourceAlarmId)")
            notificationManager.dismissAlarmKitUIForAppEngineOwnedSession(
                sourceAlarmId: sourceAlarmId,
                reason: "foreground-engine-verified"
            )
            if let surfaceId = AlarmAuthHandoffStore.surfaceAlarmId(), surfaceId != sourceAlarmId {
                notificationManager.dismissLinkedAlarmKitSurfaces(
                    sourceAlarmId: surfaceId,
                    reason: "foreground-engine-verified-surface"
                )
            }
            print("[AlarmKitRecovery] not cancelled yet; waiting for engine verification")
            let cancelled = await notificationManager.verifyAndCancelPreArmedRecoveryIfEngineAudible(
                sourceAlarmId: sourceAlarmId,
                reason: "foreground-engine-verified"
            )
            if cancelled {
                print("[ForegroundTakeover] cancelling pre-armed recovery after engine verified source=\(sourceAlarmId)")
                print("[AlarmKitRecovery] cancelled reason=foreground-engine-verified")
            }
            notificationManager.cancelPendingAuthRecovery(sourceAlarmId: sourceAlarmId)
            notificationManager.cancelHardwareSuppressionChecks(sourceAlarmId: sourceAlarmId)
            notificationManager.cancelForceClosedWarningIfAppHandlingSound(sourceAlarmId: sourceAlarmId)
            return
        }

        print("[ForegroundTakeover] engine verification FAIL; keeping AlarmKit/recovery armed")
        print("[ForegroundTakeover] AppEngine failed; alarm remains active")
        print("[ForegroundTakeover] AlarmKit not dismissed because engine failed")
        notificationManager.scheduleAudibleAlarmKitRecoveryIfNeeded(
            sourceAlarmId: sourceAlarmId,
            reason: "foreground-engine-verify-fail-\(reason)",
            delay: 1.0,
            force: true
        )
        print("[AlarmKitRecovery] recovery remains armed because foreground engine failed")
    }

    private func captureForegroundEngineVerificationSample() -> ForegroundEngineVerificationSample {
        let engine = AlarmContinuousAudioEngine.shared
        let isPlaying = engine.confirmStillPlaying()
        return ForegroundEngineVerificationSample(
            isPlaying: isPlaying,
            currentTime: engine.currentTime,
            outputVolume: AVAudioSession.sharedInstance().outputVolume,
            hasValidRoute: engine.hasValidAudibleRoute
        )
    }

    /// Restores alarm UI + audio from persisted auth handoff (cold launch, failed auth, manual open).
    private func restoreActiveRingingAlarmIfNeeded(trigger: String) {
        guard foregroundScheduler != nil else { return }
        guard let sourceAlarmId = AlarmAuthHandoffStore.activeRingingAlarmId() else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }

        print("[AlarmRestore] app active with active ringing alarm source=\(sourceAlarmId) trigger=\(trigger)")
        print("[AlarmRestore] manual/cold app open found active ringing alarm source=\(sourceAlarmId) trigger=\(trigger)")
        print("[ManualRestore] user opened app while alarm still ringing source=\(sourceAlarmId)")
        if !appPreferences.onboardingCompleted {
            print("[AlarmRestore] presenting AlarmRingingView before onboarding source=\(sourceAlarmId)")
            print("[Onboarding] skipped because alarm is ringing source=\(sourceAlarmId)")
        }
        print("[AuthHandoff] app became active; restoring ringing UI source=\(sourceAlarmId)")
        print("[AlarmRestore] restoring full-screen alarm UI source=\(sourceAlarmId)")
        print("[ManualRestore] restoring full-screen alarm UI source=\(sourceAlarmId)")

        AlarmAuthHandoffStore.markAppBecameActive()
        notificationManager.cancelAuthHandoffTimeout(sourceAlarmId: sourceAlarmId)
        notificationManager.cancelHardwareSuppressionChecks(sourceAlarmId: sourceAlarmId)

        let engineLiveHealthy = AlarmAudioStateController.shared.isAppEngineQuickAudible(
            reason: "restore-\(trigger)"
        )

        if !ringCoordinator.isRinging {
            let didStart = ringCoordinator.startRinging(alarmId: sourceAlarmId, source: .notification)
            if !didStart {
                handlePendingCustomAlarmUIHandoff(trigger: "restore-\(trigger)", bypassDedup: true)
                return
            }
        }

        ringCoordinator.ensureRingingUIVisible()
        print("[AuthHandoff] presenting AlarmRingingView from persisted handoff source=\(sourceAlarmId)")

        if engineLiveHealthy {
            print("[AlarmRestore] engine quick-check passed; scheduling strict verify source=\(sourceAlarmId)")
            Task { @MainActor in
                if await AlarmAudioStateController.shared.isAppEngineActuallyAudible(
                    reason: "restore-strict-\(trigger)"
                ) {
                    print("[AlarmRestore] engine strictly verified; cancelling pending recovery source=\(sourceAlarmId)")
                    notificationManager.cancelPendingAuthRecovery(sourceAlarmId: sourceAlarmId)
                    notificationManager.cancelHardwareSuppressionChecks(sourceAlarmId: sourceAlarmId)
                    _ = await notificationManager.verifyAndCancelPreArmedRecoveryIfEngineAudible(
                        sourceAlarmId: sourceAlarmId,
                        reason: "app-active-engine-verified"
                    )
                    AlarmAudioStateController.shared.clearHardwareRecoveryState()
                }
            }
        } else {
            print("[AlarmRestore] AppEngine not playing; starting recovery/takeover source=\(sourceAlarmId)")
            print("[AuthHandoff] AppEngine not playing; starting takeover/recovery source=\(sourceAlarmId)")
            print("[HardwareRecovery] app active after suppression; restoring alarm UI source=\(sourceAlarmId)")
            print("[ManualRestore] starting AppEngine recovery source=\(sourceAlarmId)")
            AlarmAudioStateController.shared.handleAppBecameActive()
            ringCoordinator.reassertRingingAudio(reason: "auth-handoff-restore-\(trigger)")
            if UIApplication.shared.applicationState == .active,
               !AlarmContinuousAudioEngine.shared.confirmStillPlaying() {
                notificationManager.scheduleAudibleAlarmKitRecoveryIfNeeded(
                    sourceAlarmId: sourceAlarmId,
                    reason: "manual-open-restore",
                    delay: 1.0
                )
            }
        }
    }

    private func updateViewState() {
        print("[AppRoot] checking active ringing handoff before root routing")
        if AlarmAuthHandoffStore.isActivelyRinging() {
            let sourceAlarmId = AlarmAuthHandoffStore.activeRingingAlarmId() ?? "unknown"
            print("[AlarmRestore] active ringing alarm found source=\(sourceAlarmId)")
            print("[AlarmRestore] active alarm overrides onboarding source=\(sourceAlarmId)")
            print("[AlarmRestore] active alarm overrides main UI source=\(sourceAlarmId)")
            print("[AlarmRestore] presenting AlarmRingingView full-screen source=\(sourceAlarmId)")
            restoreAndTakeoverWhenAppActive(sourceAlarmId: sourceAlarmId, reason: "updateViewState")
            return
        }
        if AlarmAuthHandoffStore.activeRingingAlarmId() != nil {
            print("[AlarmRestore] skipped; alarm is not ringing source=\(AlarmAuthHandoffStore.activeRingingAlarmId() ?? "unknown")")
        }
        let newState = Self.shouldShowMainTab(
            preferences: appPreferences,
            hasPersistedAlarms: !alarmStore.alarms.isEmpty
        )
        if newState != showingMainTab {
            withAnimation(.easeInOut) {
                showingMainTab = newState
            }
        }
    }

    private static func initialMainTabState(from preferences: AppPreferences) -> Bool {
        shouldShowMainTab(preferences: preferences, hasPersistedAlarms: preferences.hasAnyAlarm)
    }

    /// Returning users should land on the Alarmo logo → home flow, not replay onboarding.
    private static func shouldShowMainTab(
        preferences: AppPreferences,
        hasPersistedAlarms: Bool
    ) -> Bool {
        if preferences.onboardingCompleted || hasPersistedAlarms {
            return true
        }
        return !shouldForceOnboarding(from: preferences)
    }

    private static func shouldForceOnboarding(from preferences: AppPreferences) -> Bool {
        guard !preferences.onboardingCompleted else { return false }
        return preferences.forceShowOnboardingNextLaunch || preferences.devAlwaysShowOnboarding
    }

    private func clearStaleForceOnboardingFlagIfNeeded(trigger: String) {
        guard appPreferences.onboardingCompleted || appPreferences.hasAnyAlarm else { return }
        guard appPreferences.forceShowOnboardingNextLaunch else { return }
        appPreferences.forceShowOnboardingNextLaunch = false
        print("[AppRoot] cleared stale force-onboarding flag trigger=\(trigger)")
    }

    private func applyOpenAlarmMenuNavigationIfPending(trigger: String) {
        guard notificationManager.hasPendingOpenAlarmMenuNavigation() else { return }
        openAlarmMenuFromNotification(trigger: trigger)
    }

    /// Informational notification taps (e.g. "Alarmo was closed") should land on the
    /// alarm tab, not replay onboarding or the Report dashboard.
    private func openAlarmMenuFromNotification(trigger: String) {
        print("[Navigation] showing alarm menu trigger=\(trigger)")
        appPreferences.forceShowOnboardingNextLaunch = false
        navigationStore.selectedTab = .alarm

        let isReturningUser =
            appPreferences.onboardingCompleted
            || appPreferences.hasAnyAlarm
            || !alarmStore.alarms.isEmpty
        guard isReturningUser else { return }

        showingMainTab = true
        notificationManager.clearPendingOpenAlarmMenuNavigation()
        print("[Navigation] applied alarm-menu route trigger=\(trigger) tab=\(navigationStore.selectedTab.rawValue)")
    }

    private func hasPendingLiveActivityOpenRequest() -> Bool {
        let key = "alarmo.liveActivity.openSessionId"
        guard let raw = UserDefaults.standard.string(forKey: key) else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handlePendingCustomAlarmUIHandoff(trigger: String, bypassDedup: Bool = false) {
        guard foregroundScheduler != nil else { return }

        let pending = AlarmCustomUIHandoffStore.pendingRequest()
        let sourceAlarmId = AlarmAuthHandoffStore.activeRingingAlarmId()
            ?? pending?.sourceAlarmID
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID.map {
                AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0)
            }
        let surfaceAlarmId = AlarmAuthHandoffStore.surfaceAlarmId()
            ?? pending?.surfaceAlarmID
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? sourceAlarmId
        guard let sourceAlarmId, let surfaceAlarmId else { return }
        guard !AlarmAuthHandoffStore.isFinalStopOrSnoozePressed() else { return }
        print("[AlarmHandoff] active ringing alarm found before routing source=\(sourceAlarmId) trigger=\(trigger)")
        let controller = AlarmAudioStateController.shared
        let appState = UIApplication.shared.applicationState
        let engine = AlarmContinuousAudioEngine.shared
        let bridge = AlarmBackgroundAudioBridge.shared
        print(
            "📲 [ALARMTRACE_ROOT] EVENT=HANDLE_HANDOFF_ENTRY TRIGGER=\(trigger.uppercased()) BYPASS_DEDUP=\(bypassDedup) " +
            "APP_STATE=\(String(describing: appState).uppercased()) PHASE=\(controller.phase.rawValue.uppercased()) OWNER=\(controller.audibleOwner.rawValue.uppercased()) " +
            "SOURCE=\(sourceAlarmId) SURFACE=\(surfaceAlarmId) " +
            "ENGINE_ACTIVE=\(engine.isEngineActive) ENGINE_HEALTHY=\(engine.cachedIsHealthy) ENGINE_VOL=\(String(format: "%.2f", engine.currentPlayerVolume)) " +
            "BRIDGE_PLAYING=\(bridge.isPlaying) BRIDGE_SURFACE=\(bridge.currentAlarmID ?? "nil")"
        )
        let requestKey = "\(sourceAlarmId)|\(surfaceAlarmId)"
        let isNewRequest = customUIHandoffActiveRequestKey != requestKey
        if isNewRequest {
            customUIHandoffRetryWorkItem?.cancel()
            customUIHandoffRetryWorkItem = nil
            customUIHandoffAttemptCount = 0
            customUIHandoffStartedAt = Date()
            customUIHandoffInProgress = false
            customUIHandoffActiveRequestKey = requestKey
        }
        if !bypassDedup {
            if customUIHandoffInProgress && customUIHandoffActiveRequestKey == requestKey {
                return
            }
            customUIHandoffInProgress = true
            customUIHandoffActiveRequestKey = requestKey
            if customUIHandoffStartedAt == nil {
                customUIHandoffStartedAt = Date()
            }
            print("[AppRootView] 🚀 Custom UI handoff trigger=\(trigger) request=\(requestKey)")
        }

        customUIHandoffRetryWorkItem?.cancel()
        customUIHandoffRetryWorkItem = nil
        let didStartPrimary = ringCoordinator.startRinging(alarmId: sourceAlarmId, source: .notification)
        let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        let didStartMapped = (!didStartPrimary && mappedSource != sourceAlarmId)
            ? ringCoordinator.startRinging(alarmId: mappedSource, source: .notification)
            : false
        print("📲 [ALARMTRACE_ROOT] EVENT=HANDLE_HANDOFF_START_RESULT TRIGGER=\(trigger.uppercased()) DID_START_PRIMARY=\(didStartPrimary) DID_START_MAPPED=\(didStartMapped) MAPPED_SOURCE=\(mappedSource)")

        if didStartPrimary || didStartMapped {
            let resolvedSource = didStartPrimary ? sourceAlarmId : mappedSource
            print("[AlarmHandoff] startRinging succeeded from foreground handoff source=\(resolvedSource) engineActive=\(AlarmContinuousAudioEngine.shared.isEngineActive) phase=\(AlarmAudioStateController.shared.phase.rawValue)")
            print("[AuthHandoff] presenting AlarmRingingView from persisted handoff source=\(resolvedSource)")
            AlarmAuthHandoffStore.markAppBecameActive()
            customUIHandoffInProgress = false
            customUIHandoffActiveRequestKey = nil
            customUIHandoffStartedAt = nil
            customUIHandoffAttemptCount = 0
            notificationManager.cancelAlarmAuthenticationPrompt(
                sourceAlarmId: resolvedSource,
                reason: "custom-ui-handoff-success-\(trigger)"
            )
            notificationManager.cancelCustomUIHandoffFallbackNotification(sourceAlarmId: resolvedSource)
            refreshAlarmUnlockPromptIfNeeded(
                sourceAlarmId: resolvedSource,
                surfaceAlarmId: surfaceAlarmId,
                alarmName: ringCoordinator.activeAlarm?.name
            )
            // DO NOT dismiss AlarmKit aggressively here. Aggressive dismissal calls
            // AlarmManager.shared.stop synchronously on its first attempt, which
            // deactivates AlarmKit's audio session. If the user re-locks at this
            // moment (fast unlock+relock), the bridge's player gets interrupted
            // mid-stream, AlarmKit's lock-screen surface is gone, and the alarm
            // goes silent. The deferred-and-cancellable dismissal below preserves
            // AlarmKit's lock-screen surface as a fallback audio source until we
            // know the user is committed to staying in-app.
            stopAlarmKitSurfaceAfterCustomAudioStarts(
                alarmId: surfaceAlarmId,
                sourceAlarmId: resolvedSource
            )
            return
        }

        let startedAt = customUIHandoffStartedAt ?? Date()
        if Date().timeIntervalSince(startedAt) >= 5.0 {
            customUIHandoffInProgress = false
            customUIHandoffActiveRequestKey = nil
            customUIHandoffStartedAt = nil
            customUIHandoffAttemptCount = 0
            notificationManager.scheduleCustomUIHandoffFallbackNotification(
                sourceAlarmId: mappedSource,
                alarmName: ringCoordinator.activeAlarm?.name
            )
            return
        }

        notificationManager.scheduleAlarmKitUnlockPrompt(
            sourceAlarmId: mappedSource,
            surfaceAlarmId: surfaceAlarmId
        )
        customUIHandoffAttemptCount += 1
        let retryDelay: TimeInterval
        switch customUIHandoffAttemptCount {
        case 1:
            retryDelay = 0.1
        case 2:
            retryDelay = 0.2
        case 3:
            retryDelay = 0.3
        default:
            retryDelay = 0.6
        }
        let retry = DispatchWorkItem { [weak notificationManager, weak ringCoordinator] in
            guard notificationManager != nil, ringCoordinator != nil else { return }
            handlePendingCustomAlarmUIHandoff(trigger: "retry", bypassDedup: true)
        }
        customUIHandoffRetryWorkItem = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: retry)
    }

    private func enforceAlarmCustomUIIfNeeded() {
        guard !ringCoordinator.isRinging else { return }
        guard let surfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID else { return }

        let sourceAlarmId = AlarmBackgroundAudioBridge.shared.currentSourceAlarmID
            ?? AlarmCustomUIHandoffStore.pendingRequest()?.sourceAlarmID
            ?? AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)

        guard let sourceUUID = UUID(uuidString: sourceAlarmId),
              let surfaceUUID = UUID(uuidString: surfaceAlarmId) else { return }

        AlarmCustomUIHandoffStore.request(
            alarmID: sourceUUID,
            surfaceAlarmID: surfaceUUID
        )
        NotificationCenter.default.post(
            name: .alarmKitCustomUIHandoffRequested,
            object: nil,
            userInfo: [
                "alarmId": sourceAlarmId,
                "surfaceAlarmId": surfaceAlarmId
            ]
        )
    }

    private func handleAlarmHandoffURL(_ url: URL) {
        guard let alarmID = AlarmCustomUIHandoffStore.alarmID(from: url) else { return }
        AlarmCustomUIHandoffStore.request(alarmID: alarmID)
        restoreAndTakeoverWhenAppActive(sourceAlarmId: alarmID.uuidString, reason: "handoffURL")
        handlePendingCustomAlarmUIHandoff(trigger: "handoffURL")
    }

    private func stopAlarmKitSurfaceAfterCustomAudioStarts(alarmId: String, sourceAlarmId: String) {
        stopAlarmKitSurfaceTask?.cancel()
        stopAlarmKitSurfaceTask = Task { @MainActor in
            print("📲 [ALARMTRACE_ROOT] EVENT=DEFERRED_DISMISS_SURFACE_SCHEDULED SOURCE=\(sourceAlarmId) SURFACE=\(alarmId)")
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard ringCoordinator.isRinging else { return }
            print("📲 [ALARMTRACE_ROOT] EVENT=DEFERRED_DISMISS_SURFACE_SKIPPED_ACTIVE_RING SOURCE=\(sourceAlarmId) SURFACE=\(alarmId)")
            _ = alarmId
        }
    }

    private func refreshAlarmUnlockPromptIfNeeded(
        sourceAlarmId: String? = nil,
        surfaceAlarmId: String? = nil,
        alarmName: String? = nil
    ) {
        let resolvedSourceAlarmId = sourceAlarmId
            ?? ringCoordinator.activeAlarm?.id.uuidString
            ?? AlarmBackgroundAudioBridge.shared.currentSourceAlarmID
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID.map {
                AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0)
            }

        let resolvedSurfaceAlarmId = surfaceAlarmId
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? resolvedSourceAlarmId

        guard let sourceAlarmId = resolvedSourceAlarmId,
              let surfaceAlarmId = resolvedSurfaceAlarmId else { return }

        guard ringCoordinator.isRinging || AlarmBackgroundAudioBridge.shared.isPlaying else { return }

        guard UIApplication.shared.applicationState != .active else { return }

        if notificationManager.isAppEngineControllingAlarmAudioForNotifications() {
            notificationManager.ensureAppEngineRingingControlNotification(
                sourceAlarmId: sourceAlarmId,
                alarmName: alarmName ?? ringCoordinator.activeAlarm?.name,
                reason: "refresh-unlock-prompt-engine-primary"
            )
            return
        }

        notificationManager.scheduleAlarmKitUnlockPrompt(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName ?? ringCoordinator.activeAlarm?.name
        )
        notificationManager.startAlarmKitUnlockPromptLoop(
            sourceAlarmId: sourceAlarmId,
            surfaceAlarmId: surfaceAlarmId,
            alarmName: alarmName ?? ringCoordinator.activeAlarm?.name
        )
    }

    private var resolvedColorScheme: ColorScheme? {
        let style = AlarmThemeStyle(rawValue: appThemeStyleRaw) ?? .default
        switch style {
        case .tiimo:
            return .light
        case .default:
            return .dark
        }
    }

    private var isTiimoTheme: Bool {
        let style = AlarmThemeStyle(rawValue: appThemeStyleRaw) ?? .default
        return style.usesTiimoLayoutBranch
    }

    private func handlePlanNotificationMarkDone(userInfo: [AnyHashable: Any]?) {
        guard let idString = userInfo?["planItemId"] as? String,
              let id = UUID(uuidString: idString) else { return }

        let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { item in
            item.id == id
        })
        guard let item = try? modelContext.fetch(descriptor).first else { return }

        let calendar = Calendar.current
        let alreadyCompleted = item.completionLogs.contains { log in
            calendar.isDateInToday(log.date) && log.completed
        }
        guard !alreadyCompleted else { return }

        let completionDate = Date()
        let log = CompletionLog(date: completionDate, completed: true)
        item.completionLogs.append(log)
        item.updatedAt = completionDate
        modelContext.insert(
            ActivityEvent(
                domain: item.type == .habit ? .habit : .task,
                entityId: item.id,
                timestampUTC: completionDate,
                status: .completed
            )
        )
        if item.type == .habit {
            PointsService.shared.habitCompleted(
                habitId: item.id,
                habitName: item.title,
                streakDays: habitStreak(for: item)
            )
        } else {
            PointsService.shared.taskCompleted(
                taskId: item.id,
                taskName: item.title,
                completedBeforeDeadline: didCompleteBeforeDeadline(item, at: completionDate)
            )
        }
        try? modelContext.save()
    }

    private func didCompleteBeforeDeadline(_ item: PlanItem, at completionDate: Date) -> Bool {
        guard let dueDate = item.scheduledDate else { return false }
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: item.scheduledTime ?? dueDate)
        var mergedComponents = DateComponents()
        mergedComponents.year = dateComponents.year
        mergedComponents.month = dateComponents.month
        mergedComponents.day = dateComponents.day
        mergedComponents.hour = timeComponents.hour ?? 23
        mergedComponents.minute = timeComponents.minute ?? 59
        mergedComponents.second = timeComponents.second ?? 59

        guard let deadline = calendar.date(from: mergedComponents) else {
            return completionDate <= dueDate
        }
        return completionDate <= deadline
    }

    private func habitStreak(for item: PlanItem) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        for _ in 0..<365 {
            let completed = item.completionLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: checkDate) && log.completed
            }
            guard completed else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        return streak
    }
}

private struct LaunchLogoView: View {
    let isTiimoTheme: Bool

    var body: some View {
        ZStack {
            (isTiimoTheme ? Color.white : Color.black)
                .ignoresSafeArea()

            Text("Alarmo")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(isTiimoTheme ? .black : .white)
                .kerning(0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alarmo")
    }
}

/// Bundles the root-level informational alerts into a single modifier so the
/// main `body` expression stays small enough for the Swift type-checker.
private struct RootNoticeAlerts: ViewModifier {
    @Binding var showLegacyAlarmModeNotice: Bool
    @Binding var showAlarmKitFailureNotice: Bool
    @Binding var showNotificationsDisabledWarning: Bool
    @Binding var showForceQuitEducationAlert: Bool
    let alarmKitFailureMessage: String
    let onForceQuitEducationAcknowledged: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .showForceQuitEducationAfterAlarmSetup)) { _ in
                showForceQuitEducationAlert = true
            }
            .alert("Keep Alarmo available", isPresented: $showForceQuitEducationAlert) {
                Button("OK", role: .cancel) {
                    onForceQuitEducationAcknowledged()
                }
            } message: {
                Text("Your basic alarm sound is scheduled. For the full wake-up screen, missions, and in-app sound, don't force-close Alarmo from the app switcher before the alarm.")
            }
            .alert("Alarm Compatibility", isPresented: $showLegacyAlarmModeNotice) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This iPhone is using the notification fallback path. Alarms still schedule and notify, but silent-mode override depends on iOS capabilities and permissions.")
            }
            .alert("AlarmKit Required", isPresented: $showAlarmKitFailureNotice) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(alarmKitFailureMessage)
            }
            .alert("Notifications are off", isPresented: $showNotificationsDisabledWarning) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alarmo can still schedule the basic alarm sound, but it cannot remind you to reopen the app if it is closed. Enable notifications in Settings for the full alarm experience.")
            }
    }
}

#Preview {
    AppRootView()
}
