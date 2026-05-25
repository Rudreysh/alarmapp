import SwiftUI
import UserNotifications

private enum NotificationPermissionState {
    case notDetermined
    case authorized
    case denied
}

struct OnboardingReportsInsightsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var isRequesting = false
    @State private var notificationState: NotificationPermissionState = .notDetermined
    @State private var showNotificationsDeniedAlert = false
    @State private var showNotificationPrompt = false
    @State private var animateIn = false

    
    private var isTiimoTheme: Bool {
        UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
    }
var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                Spacer()

                VStack(alignment: .center, spacing: 16) {
                    PermissionHeroIcon(
                        systemName: "bell.badge.fill",
                        tint: Color(red: 0.98, green: 0.36, blue: 0.36),
                        showBadge: true
                    )
                    .padding(.bottom, 8)

                    Text("Don’t Miss Important Reports and Insights")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Enable notifications so Awayk can alert you for reports, reminders, and alarm events.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .center)
                .permissionEntrance(animateIn)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onNext) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(isTiimoTheme ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(32)
                    }
                    .disabled(isRequesting)

                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        Task { await handleContinueTapped() }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 24)
            }
             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onboardingContentFrame()

            if showNotificationPrompt {
                notificationPromptOverlay
                    .zIndex(1)
            }

            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                PermissionAnimatedLoadingCard(title: "Requesting access")
                .zIndex(3)
            }
        }
        .task {
            await refreshNotificationState()
            animateIn = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshNotificationState() }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationsDeniedAlert) {
            Button("Continue", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text("Notifications are currently disabled for Awayk. Enable notifications in Settings for reliable alarm and report alerts.")
        }
    }

    private var notificationPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("\"Awayk\" would like to send you notifications")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineSpacing(3)

                Text("Notifications may include alerts, sounds, and badges. These can be configured in Settings.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.72))
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    Button {
                        showNotificationPrompt = false
                        onNext()
                    } label: {
                        Text("Don't Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Button {
                        showNotificationPrompt = false
                        Task { await requestNotificationFromPrompt() }
                    } label: {
                        Text("Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.accentBlue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 6)
            }
            .padding(26)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }

    @MainActor
    private func handleContinueTapped() async {
        switch notificationState {
        case .authorized:
            onNext()
        case .denied:
            showNotificationsDeniedAlert = true
        case .notDetermined:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showNotificationPrompt = true
            }
        }
    }

    @MainActor
    private func requestNotificationFromPrompt() async {
        isRequesting = true
        let granted = await NotificationManager.shared.ensureAuthorization()
        await refreshNotificationState()
        isRequesting = false

        if granted || notificationState == .authorized {
            onNext()
        } else {
            showNotificationsDeniedAlert = true
        }
    }

    @MainActor
    private func refreshNotificationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationState = .authorized
        case .denied:
            notificationState = .denied
        case .notDetermined:
            notificationState = .notDetermined
        @unknown default:
            notificationState = .notDetermined
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
