import SwiftUI
import UserNotifications

#if canImport(AlarmKit)
import AlarmKit
#endif

private enum AlarmPermissionStepState {
    case notDetermined
    case authorized
    case denied
    case unavailable
}

struct OnboardingAlarmPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var isRequesting = false
    @State private var alarmState: AlarmPermissionStepState = .notDetermined
    @State private var showAlarmPrompt = false
    @State private var showPermissionDeniedAlert = false
    @State private var showPermissionErrorAlert = false
    @State private var permissionErrorMessage = "Alarm permission request failed."
    @State private var showNotificationsDeniedAlert = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 4, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                Spacer()

                VStack(alignment: .center, spacing: 16) {
                    PermissionHeroIcon(
                        systemName: "alarm.fill",
                        tint: Color(red: 0.98, green: 0.62, blue: 0.27),
                        showBadge: true
                    )
                    .padding(.bottom, 8)

                    Text("Allow Alarms to Ring on Lock Screen")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("On iOS 26+, Alarm permission enables true system alarm behavior so alarms can ring while the phone is locked and in Silent mode.")
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
                            .foregroundColor(.white)
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

            if showAlarmPrompt {
                alarmPromptOverlay
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
            await refreshAlarmState()
            animateIn = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshAlarmState() }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationsDeniedAlert) {
            Button("Continue", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text("Alarm permission requires Notifications to be enabled first. Enable notifications for Awayk, then try again.")
        }
        .alert("Alarm Permission Needed", isPresented: $showPermissionDeniedAlert) {
            Button("Continue", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text("To use system alarm behavior, enable Alarm permission for Awayk in Settings.")
        }
        .alert("Alarm Permission Request Failed", isPresented: $showPermissionErrorAlert) {
            Button("Continue", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                openAppSettings()
            }
        } message: {
            Text(permissionErrorMessage)
        }
    }

    private var alarmPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Allow \"Awayk\" to schedule alarms and timers?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineSpacing(3)

                Text("This lets Awayk ring on Lock Screen and in Silent mode using iOS system alarm behavior.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.72))
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    Button {
                        showAlarmPrompt = false
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
                        showAlarmPrompt = false
                        Task { await requestAlarmPermissionFlow() }
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
        switch alarmState {
        case .authorized:
            onNext()
        case .denied:
            showPermissionDeniedAlert = true
        case .unavailable:
            #if targetEnvironment(simulator)
            permissionErrorMessage = "AlarmKit permission cannot be reliably requested in the iOS Simulator. Use a physical iPhone/iPad on iOS 26+."
            showPermissionErrorAlert = true
            #else
            onNext()
            #endif
        case .notDetermined:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showAlarmPrompt = true
            }
        }
    }

    @MainActor
    private func requestAlarmPermissionFlow() async {
        isRequesting = true

        let notificationsGranted = await NotificationManager.shared.ensureAuthorization()
        if !notificationsGranted {
            isRequesting = false
            showNotificationsDeniedAlert = true
            return
        }

        let granted = await AlarmManagerFacade.shared.requestAlarmAuthorizationIfNeeded()
        await refreshAlarmState()
        isRequesting = false

        if granted || alarmState == .authorized {
            onNext()
            return
        }

        if alarmState == .denied {
            showPermissionDeniedAlert = true
            return
        }

        permissionErrorMessage = AlarmKitSchedulingMessenger.shared.latestMessage()
        showPermissionErrorAlert = true
    }

    @MainActor
    private func refreshAlarmState() async {
#if targetEnvironment(simulator)
        alarmState = .unavailable
#else
#if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized:
                alarmState = .authorized
            case .denied:
                alarmState = .denied
            case .notDetermined:
                alarmState = .notDetermined
            @unknown default:
                alarmState = .notDetermined
            }
            return
        }
#endif
        alarmState = .unavailable
#endif
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
