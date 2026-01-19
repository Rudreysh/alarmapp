import SwiftUI
import Combine

struct AppRootView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var appPreferences = AppPreferences()
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var ringCoordinator = AlarmRingCoordinator()
    @StateObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var settingsStore = SettingsStore.shared
    @State private var foregroundScheduler: AlarmForegroundScheduler?
    @State private var showingMainTab = false

    var body: some View {
        let _ = print("[AppRootView] body re-evaluating. onboardingCompleted: \(appPreferences.onboardingCompleted), showingMainTab: \(showingMainTab)")
        return Group {
            if showingMainTab {
                let _ = print("[AppRootView] Showing MainTabContainerView")
                MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
            } else {
                let _ = print("[AppRootView] Showing OnboardingFlowView")
                OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences, alarmStore: alarmStore)
            }
        }
        .preferredColorScheme(SettingsStore.shared.themeMode.colorScheme)
        .onAppear {
            updateViewState()
            if foregroundScheduler == nil {
                let scheduler = AlarmForegroundScheduler(alarmStore: alarmStore, ringCoordinator: ringCoordinator)
                foregroundScheduler = scheduler
                ringCoordinator.configure(alarmStore: alarmStore, foregroundScheduler: scheduler)
                notificationManager.configure(ringCoordinator: ringCoordinator, alarmStore: alarmStore)
                scheduler.start()
            }
        }
        .environmentObject(ringCoordinator)
        .environmentObject(notificationManager)
        .fullScreenCover(isPresented: Binding(
            get: { ringCoordinator.isRinging },
            set: { _ in }
        )) {
            AlarmRingingView(ringCoordinator: ringCoordinator)
        }
        .onReceive(alarmStore.$alarms) { _ in
            foregroundScheduler?.scheduleNext()
        }
        .onReceive(appPreferences.objectWillChange) { _ in
            DispatchQueue.main.async {
                updateViewState()
            }
        }
    }
    
    private func updateViewState() {
        let newState = !appPreferences.devAlwaysShowOnboarding && appPreferences.onboardingCompleted
        if newState != showingMainTab {
            withAnimation(.easeInOut) {
                showingMainTab = newState
            }
        }
    }
}

#Preview {
    AppRootView()
}
