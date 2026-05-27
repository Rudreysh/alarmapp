import SwiftUI
import Combine
import SwiftData
import UIKit
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
    @State private var showAlarmKitFailureNotice = false
    @State private var alarmKitFailureMessage = "AlarmKit scheduling failed."
    @State private var customUIHandoffRetryWorkItem: DispatchWorkItem?
    @State private var stopAlarmKitSurfaceTask: Task<Void, Never>?
    @State private var customUIHandoffInProgress = false
    @State private var customUIHandoffActiveRequestKey: String?
    @State private var customUIHandoffStartedAt: Date?
    @State private var customUIHandoffAttemptCount: Int = 0
    @AppStorage("settings.alarmThemeStyleRaw") private var appThemeStyleRaw: String = AlarmThemeStyle.default.rawValue

    init() {
        let preferences = AppPreferences()
        _appPreferences = StateObject(wrappedValue: preferences)
        // Resolve onboarding/main-tab state up-front to avoid a one-frame onboarding flash
        // that can look like "Next" skipped onboarding and jumped to Home.
        _showingMainTab = State(initialValue: Self.initialMainTabState(from: preferences))
    }

    var body: some View {
        return Group {
            if showingMainTab {
                MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
            } else {
                OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences, alarmStore: alarmStore)
            }
        }
        .environmentObject(themeManager)
        .preferredColorScheme(resolvedColorScheme)
        .onAppear {
            // Configure remote assets from GitHub
            // Note: Change 'green-theme' to 'main' when merging to production branch.
            AssetManager.shared.configure(catalogURL: "https://raw.githubusercontent.com/Rudreysh/alarmapp/green-theme/HostedAssets/catalog.json")
            Task {
                await AssetManager.shared.fetchCatalog()
            }
            
            updateViewState()
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
            }
            handlePendingCustomAlarmUIHandoff(trigger: "onAppear")
            NotificationOrchestrator.shared.reconcileAlarmLifecycleNotifications(alarms: alarmStore.alarms)
            shutdownDetectionService.startMonitoring(alarmStore: alarmStore, ringCoordinator: ringCoordinator, ringingAlarmId: ringCoordinator.activeAlarm?.id)
            accountabilityManager.ensureShieldRestoredOnLaunch()
            AccountabilityShieldEngine.shared.reconcileActiveSessionOnLaunch(ringingAlarmId: ringCoordinator.activeAlarm?.id, alarmStore: alarmStore)
            pomodoroEngine.configure(with: appPreferences)
            if hasPendingLiveActivityOpenRequest() {
                navigationStore.selectedTab = .timer
                navigationStore.requestedTimerMode = .pomo
            }
            if !didRunAppListMigration {
                AppListMigrationCoordinator.migrateLegacySelectionIfNeeded(context: modelContext, settings: settingsStore)
                didRunAppListMigration = true
            }
        }
        .environmentObject(ringCoordinator)
        .environmentObject(notificationManager)
        .environmentObject(taskStore)
        .environmentObject(pomodoroEngine)
        .environmentObject(navigationStore)
        .fullScreenCover(isPresented: Binding(
            get: { ringCoordinator.isRingingUIVisible },
            set: { _ in }
        )) {
            AlarmRingingView(ringCoordinator: ringCoordinator)
        }
        .onReceive(alarmStore.$alarms) { _ in
            foregroundScheduler?.scheduleNext()
            NotificationOrchestrator.shared.reconcileAlarmLifecycleNotifications(alarms: alarmStore.alarms)
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
            if newPhase == .active {
                AlarmAudioStateController.shared.handleAppBecameActive()
                AlarmContinuousAudioEngine.shared.recoverIfNeeded()
                print("[AppRoot] Engine recovery check on active — isEngineActive: \(AlarmContinuousAudioEngine.shared.isEngineActive)")
                if hasPendingLiveActivityOpenRequest() {
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
                    notificationManager.nukeAllAlertingAlarmKitSurfaces()
                    // Reschedule a fresh backup so re-lock has fast recovery.
                    // Cancel the old (which we're about to dismiss anyway)
                    // and schedule a new one.
                    notificationManager.cancelAllBackupAlarmKitChains()
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
                enforceAlarmCustomUIIfNeeded()
                handlePendingCustomAlarmUIHandoff(trigger: "scenePhase.active")
                refreshAlarmUnlockPromptIfNeeded()
            } else if newPhase == .inactive || newPhase == .background {
                pomodoroEngine.handleSceneDidEnterBackground()
                stopAlarmKitSurfaceTask?.cancel()
                stopAlarmKitSurfaceTask = nil
                // CRITICAL: cancel any in-flight AlarmKit dismissal. If the user
                // re-locks during a deferred dismissal window, we must NOT stop
                // AlarmKit — its lock-screen surface is the most reliable audio
                // continuity for the alarm.
                notificationManager.cancelPendingAlarmKitDismissals(reason: "scene-inactive-background")
                ringCoordinator.cancelDeferredBridgeStop(reason: "scene-inactive-background")
                if ringCoordinator.isRinging, let alarm = ringCoordinator.activeAlarm {
                    ringCoordinator.reassertRingingAudio(reason: "scene-inactive-background")
                    notificationManager.scheduleHardwareButtonRespawnIfNeeded(
                        sourceAlarmId: alarm.id.uuidString,
                        alarmName: alarm.name,
                        reason: "Side button detected via scenePhase"
                    )
                    notificationManager.startAlarmKitUnlockPromptLoop(
                        sourceAlarmId: alarm.id.uuidString,
                        surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? alarm.id.uuidString,
                        alarmName: alarm.name
                    )
                    let phase = AlarmAudioStateController.shared.phase
                    if phase == .appEnginePrimary || phase == .alarmKitFallback {
                        guard UIApplication.shared.applicationState != .active else {
                            print("[AppRoot] enforceLockedRingingState suppressed — app is foreground")
                            return
                        }
                        notificationManager.enforceLockedRingingState(
                            sourceAlarmId: alarm.id.uuidString,
                            surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? alarm.id.uuidString
                        )
                    } else {
                        print("[AppRoot] enforceLockedRingingState suppressed — phase \(phase.rawValue) (engine not primary yet)")
                    }
                    // App is now backgrounded/locked. Bridge audio can fail
                    // when iOS suspends us. Arm the AlarmKit backup chain so
                    // a fresh AlarmKit alarm fires every 2s as a fallback.
                    if #available(iOS 26.0, *) {
                        Task {
                            let engineLiveHealthy = AlarmContinuousAudioEngine.shared.isEngineActive &&
                                AlarmContinuousAudioEngine.shared.cachedIsHealthy &&
                                AlarmContinuousAudioEngine.shared.confirmStillPlaying()
                            if !engineLiveHealthy {
                                if AlarmAudioStateController.shared.shouldAllowAlarmKitRespawn() {
                                    await notificationManager.ensureBackupAlarmKitChain(sourceAlarmId: alarm.id.uuidString)
                                    print("[AppRoot] Scene background — backup chain scheduled (engine not healthy)")
                                } else {
                                    print("[AppRoot] Scene background — backup chain suppressed by phase \(AlarmAudioStateController.shared.phase.rawValue)")
                                }
                            } else {
                                print("[AppRoot] Scene background — backup chain skipped (engine healthy)")
                            }
                        }
                    }
                } else if let surfaceAlarmId = AlarmBackgroundAudioBridge.shared.currentAlarmID {
                    let sourceAlarmId = AlarmBackgroundAudioBridge.shared.currentSourceAlarmID
                        ?? AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
                    notificationManager.scheduleHardwareButtonRespawnIfNeeded(
                        sourceAlarmId: sourceAlarmId,
                        alarmName: nil,
                        reason: "Side button detected via scenePhase"
                    )
                    let phase = AlarmAudioStateController.shared.phase
                    if phase == .appEnginePrimary || phase == .alarmKitFallback {
                        guard UIApplication.shared.applicationState != .active else {
                            print("[AppRoot] enforceLockedRingingState suppressed — app is foreground")
                            return
                        }
                        notificationManager.enforceLockedRingingState(
                            sourceAlarmId: sourceAlarmId,
                            surfaceAlarmId: surfaceAlarmId
                        )
                    } else {
                        print("[AppRoot] enforceLockedRingingState suppressed — phase \(phase.rawValue)")
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
            handlePendingCustomAlarmUIHandoff(trigger: "customUIHandoffRequested")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Fires BEFORE scenePhase becomes .active and BEFORE
            // protectedDataDidBecomeAvailable. Force-reset the audio session
            // to clear any stuck state from AlarmKit's interference, then
            // reassert audio. This is what makes "open the app brings sound
            // back" actually work — without the force-reset, the session can
            // be in a state where setActive(true) is technically successful
            // but no actual audio output happens.
            if AlarmAudioStateController.shared.isAlarmRinging {
                print("[AppRoot] willEnterForeground: forceReset skipped because alarm is ringing")
            } else if !AlarmContinuousAudioEngine.shared.isEngineActive {
                AudioRouteManager.shared.forceResetAlarmSession()
            } else {
                print("[AppRoot] willEnterForeground: skipping AudioRouteManager reset — engine active")
            }
            if ringCoordinator.isRinging {
                ringCoordinator.reassertRingingAudio(reason: "willEnterForeground")
            } else if AlarmBackgroundAudioBridge.shared.isPlaying {
                AlarmBackgroundAudioBridge.shared.reinforceLockedLoopNow(reason: "willEnterForeground")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            AlarmAudioStateController.shared.handleAppBecameActive()
            AlarmContinuousAudioEngine.shared.recoverIfNeeded()
            print("[AppRoot] Engine recovery check on active — isEngineActive: \(AlarmContinuousAudioEngine.shared.isEngineActive)")
            notificationManager.recoverAlarmKitAlertingIfNeeded()
            enforceAlarmCustomUIIfNeeded()
            handlePendingCustomAlarmUIHandoff(trigger: "didBecomeActive")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            let appState = UIApplication.shared.applicationState
            // Earliest moment after FaceID/Touch ID auth. Force-reset the
            // audio session to clear AlarmKit's audio session interference,
            // then reassert audio. This minimizes the silence window the
            // user perceives between unlock and audio resuming.
            if AlarmAudioStateController.shared.isAlarmRinging {
                print("[AppRoot] protectedDataAvailable: forceReset skipped because alarm is ringing")
            } else if !AlarmContinuousAudioEngine.shared.isEngineActive {
                AudioRouteManager.shared.forceResetAlarmSession()
            } else {
                print("[AppRoot] protectedDataAvailable: skipping AudioRouteManager reset — engine active")
            }
            if ringCoordinator.isRinging {
                ringCoordinator.reassertRingingAudio(reason: "protectedDataAvailable")
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
    }
    
    private func updateViewState() {
        let shouldForceOnboarding =
            appPreferences.forceShowOnboardingNextLaunch ||
            (appPreferences.devAlwaysShowOnboarding && !appPreferences.onboardingCompleted)
        let newState = !shouldForceOnboarding && appPreferences.onboardingCompleted
        if newState != showingMainTab {
            withAnimation(.easeInOut) {
                showingMainTab = newState
            }
        }
    }

    private static func initialMainTabState(from preferences: AppPreferences) -> Bool {
        let shouldForceOnboarding =
            preferences.forceShowOnboardingNextLaunch ||
            (preferences.devAlwaysShowOnboarding && !preferences.onboardingCompleted)
        return !shouldForceOnboarding && preferences.onboardingCompleted
    }

    private func hasPendingLiveActivityOpenRequest() -> Bool {
        let key = "alarmo.liveActivity.openSessionId"
        guard let raw = UserDefaults.standard.string(forKey: key) else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handlePendingCustomAlarmUIHandoff(trigger: String, bypassDedup: Bool = false) {
        guard foregroundScheduler != nil else { return }

        let pending = AlarmCustomUIHandoffStore.pendingRequest()
        let sourceAlarmId = pending?.sourceAlarmID
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID.map {
                AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: $0)
            }
        let surfaceAlarmId = pending?.surfaceAlarmID
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
            ?? sourceAlarmId
        guard let sourceAlarmId, let surfaceAlarmId else { return }
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
            AlarmCustomUIHandoffStore.clear()
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
        (appThemeStyleRaw == AlarmThemeStyle.lilacCalm.rawValue || appThemeStyleRaw == AlarmThemeStyle.tiimo.rawValue) ? .light : settingsStore.themeMode.colorScheme
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

#Preview {
    AppRootView()
}
