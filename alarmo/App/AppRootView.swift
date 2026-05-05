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
    @AppStorage("settings.alarmThemeStyleRaw") private var appThemeStyleRaw: String = AlarmThemeStyle.default.rawValue

    init() {
        let preferences = AppPreferences()
        _appPreferences = StateObject(wrappedValue: preferences)
        // Resolve onboarding/main-tab state up-front to avoid a one-frame onboarding flash
        // that can look like "Next" skipped onboarding and jumped to Home.
        _showingMainTab = State(initialValue: Self.initialMainTabState(from: preferences))
    }

    var body: some View {
        let _ = print("[AppRootView] body re-evaluating. onboardingCompleted: \(appPreferences.onboardingCompleted), showingMainTab: \(showingMainTab), appThemeStyle: \(appThemeStyleRaw)")
        return Group {
            if showingMainTab {
                let _ = print("[AppRootView] Showing MainTabContainerView")
                MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
            } else {
                let _ = print("[AppRootView] Showing OnboardingFlowView")
                OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences, alarmStore: alarmStore)
            }
        }
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
            handlePendingCustomAlarmUIHandoff()
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
            get: { ringCoordinator.isRinging },
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
                if hasPendingLiveActivityOpenRequest() {
                    navigationStore.selectedTab = .timer
                    navigationStore.requestedTimerMode = .pomo
                }
                pomodoroEngine.handleSceneDidBecomeActive()
                tamperDetectionService.evaluateOnForeground(ringCoordinator: ringCoordinator)
                ringCoordinator.reassertRingingAudio(reason: "scene-active")
                notificationManager.recoverAlarmFromDeliveredNotificationsIfNeeded()
                notificationManager.recoverAlarmKitAlertingIfNeeded()
                enforceAlarmCustomUIIfNeeded()
                handlePendingCustomAlarmUIHandoff()
                refreshAlarmUnlockPromptIfNeeded()
            } else if newPhase == .inactive || newPhase == .background {
                pomodoroEngine.handleSceneDidEnterBackground()
                if ringCoordinator.isRinging, let alarm = ringCoordinator.activeAlarm {
                    notificationManager.startAlarmKitUnlockPromptLoop(
                        sourceAlarmId: alarm.id.uuidString,
                        surfaceAlarmId: AlarmBackgroundAudioBridge.shared.currentAlarmID ?? alarm.id.uuidString,
                        alarmName: alarm.name
                    )
                }
            }
        }
        .onOpenURL { url in
            handleAlarmHandoffURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmKitCustomUIHandoffRequested)) { _ in
            handlePendingCustomAlarmUIHandoff()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            notificationManager.recoverAlarmKitAlertingIfNeeded()
            enforceAlarmCustomUIIfNeeded()
            handlePendingCustomAlarmUIHandoff()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            enforceAlarmCustomUIIfNeeded()
            handlePendingCustomAlarmUIHandoff()
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

    private func handlePendingCustomAlarmUIHandoff() {
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

        customUIHandoffRetryWorkItem?.cancel()
        customUIHandoffRetryWorkItem = nil
        let didStartPrimary = ringCoordinator.startRinging(alarmId: sourceAlarmId, source: .notification)
        let mappedSource = AlarmCustomUIHandoffStore.sourceAlarmID(forSurfaceAlarmID: surfaceAlarmId)
        let didStartMapped = (!didStartPrimary && mappedSource != sourceAlarmId)
            ? ringCoordinator.startRinging(alarmId: mappedSource, source: .notification)
            : false

        if didStartPrimary || didStartMapped {
            let resolvedSource = didStartPrimary ? sourceAlarmId : mappedSource
            AlarmCustomUIHandoffStore.clear()
            refreshAlarmUnlockPromptIfNeeded(
                sourceAlarmId: resolvedSource,
                surfaceAlarmId: surfaceAlarmId,
                alarmName: ringCoordinator.activeAlarm?.name
            )
            notificationManager.dismissLinkedAlarmKitSurfacesAggressively(sourceAlarmId: resolvedSource)
            stopAlarmKitSurfaceAfterCustomAudioStarts(alarmId: surfaceAlarmId)
            return
        }

        // Do not allow a silent unlock state: keep prompting + retrying custom UI
        // whether or not bridge audio is currently active.
        notificationManager.scheduleAlarmKitUnlockPrompt(
            sourceAlarmId: mappedSource,
            surfaceAlarmId: surfaceAlarmId
        )
        let retry = DispatchWorkItem { [weak notificationManager, weak ringCoordinator] in
            guard notificationManager != nil, ringCoordinator != nil else { return }
            handlePendingCustomAlarmUIHandoff()
        }
        customUIHandoffRetryWorkItem = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: retry)
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

        DispatchQueue.main.async {
            handlePendingCustomAlarmUIHandoff()
        }
    }

    private func stopAlarmKitSurfaceAfterCustomAudioStarts(alarmId: String) {
#if canImport(AlarmKit)
        guard #available(iOS 26.0, *),
              let uuid = UUID(uuidString: alarmId) else { return }

        Task {
            // Give Alarmo's own looping audio a short head start before dismissing
            // the system AlarmKit surface, so the user does not hear a silent gap.
            try? await Task.sleep(nanoseconds: 175_000_000)
            try? AlarmManager.shared.stop(id: uuid)
        }
#endif
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
        appThemeStyleRaw == AlarmThemeStyle.lilacCalm.rawValue ? .light : settingsStore.themeMode.colorScheme
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
