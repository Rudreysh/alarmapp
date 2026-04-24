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
                notificationManager.recoverAlarmFromDeliveredNotificationsIfNeeded()
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
                notificationManager.recoverAlarmFromDeliveredNotificationsIfNeeded()
                handlePendingCustomAlarmUIHandoff()
            } else if newPhase == .inactive || newPhase == .background {
                pomodoroEngine.handleSceneDidEnterBackground()
            }
        }
        .onOpenURL { url in
            handleAlarmHandoffURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmKitCustomUIHandoffRequested)) { _ in
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

        let alarmId = AlarmCustomUIHandoffStore.pendingAlarmID()
            ?? AlarmBackgroundAudioBridge.shared.currentAlarmID
        guard let alarmId else { return }

        if ringCoordinator.startRinging(alarmId: alarmId, source: .notification) {
            AlarmCustomUIHandoffStore.clear()
            notificationManager.cancelAlarmKitUnlockPrompt(alarmId: alarmId)
            // Hand off from bridge to coordinator audio with a short overlap so
            // the user never hears a gap.
            AlarmBackgroundAudioBridge.shared.handoffToForeground(alarmId: alarmId, stopDelay: 0.4)
            stopAlarmKitSurfaceAfterCustomAudioStarts(alarmId: alarmId)
        } else if AlarmBackgroundAudioBridge.shared.isPlaying {
            // Coordinator could not start (e.g. alarm was deleted), but bridge
            // is still playing. Stop it to avoid orphaned audio.
            AlarmBackgroundAudioBridge.shared.stop(alarmId: alarmId)
            AlarmCustomUIHandoffStore.clear()
            notificationManager.cancelAlarmKitUnlockPrompt(alarmId: alarmId)
        }
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
            try? await Task.sleep(nanoseconds: 350_000_000)
            try? AlarmManager.shared.stop(id: uuid)
        }
#endif
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
