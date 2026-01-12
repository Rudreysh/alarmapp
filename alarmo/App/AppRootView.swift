import SwiftUI

struct AppRootView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var appPreferences = AppPreferences()
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var ringCoordinator = AlarmRingCoordinator()
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var foregroundScheduler: AlarmForegroundScheduler?

    var body: some View {
        Group {
            if !appPreferences.devAlwaysShowOnboarding && appPreferences.onboardingCompleted {
                MainTabContainerView(preferences: appPreferences, alarmStore: alarmStore)
            } else {
                OnboardingFlowView(viewModel: onboardingViewModel, appPreferences: appPreferences, alarmStore: alarmStore)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
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
    }
}

#Preview {
    AppRootView()
}
