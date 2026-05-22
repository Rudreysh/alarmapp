import SwiftUI
import HealthKit
import UserNotifications
import CoreMotion

private enum PermissionStatus {
    case notRequested
    case granted
    case denied
    case unavailable

    var title: String {
        switch self {
        case .notRequested: return "Not Requested"
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .unavailable: return "Unavailable"
        }
    }

    var color: Color {
        switch self {
        case .notRequested: return Colors.textSecondary
        case .granted: return Colors.accentGreen
        case .denied: return Colors.accentRed
        case .unavailable: return Colors.textTertiary
        }
    }
}

private enum PermissionStage {
    case motion
    case notifications
    case health
}

struct OnboardingPermissionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var stage: PermissionStage = .motion
    @State private var motionStatus: PermissionStatus = .notRequested
    @State private var notificationsStatus: PermissionStatus = .notRequested
    @State private var healthStatus: PermissionStatus = .notRequested

    @State private var showMotionPrompt = false
    @State private var showNotificationPrompt = false
    @State private var showHealthPrompt = false
    @State private var isRequesting = false
    @State private var feedbackText: String?
    @State private var feedbackIsError = false

    private let motionManager = CMMotionActivityManager()
    private let healthStore = HKHealthStore()
    private let appName = "Awayk"

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            LinearGradient(
                colors: [Colors.bgSecondary.opacity(0.20), Colors.bgPrimary.opacity(0.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        iconView
                            .padding(.top, 10)

                        Text(stageTitle)
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(stageBody)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        statusBadge

                        if stage == .motion {
                            motionPreviewCard
                        } else if stage == .notifications {
                            notificationPreviewCard
                        } else {
                            healthPreviewCard
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, 220)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if let feedbackText {
                        Text(feedbackText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(feedbackIsError ? Colors.accentRed : Colors.accentGreen)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.l)
                    }

                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        handleContinueTapped()
                    }
                    .disabled(isRequesting)

                    Button("Skip for now") {
                        handleSkipTapped()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .disabled(isRequesting)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 14)
            }

            if showNotificationPrompt {
                permissionPromptOverlay(
                    title: "\"\(appName)\" Would Like to Send You Notifications",
                    body: "Notifications may include alerts, sounds and icon badges. You can change this in Settings.",
                    allowTitle: "Allow",
                    denyTitle: "Don't Allow",
                    onAllow: {
                        showNotificationPrompt = false
                        Task { await requestNotifications() }
                    },
                    onDeny: {
                        showNotificationPrompt = false
                        showFeedback("Notifications skipped. You can enable them later in Settings.", isError: false)
                        stage = .health
                    }
                )
            }

            if showMotionPrompt {
                permissionPromptOverlay(
                    title: "\"\(appName)\" would like to access your Motion & Fitness activity.",
                    body: "Motion data helps detect movement-based activity sessions and improves live habit tracking.",
                    allowTitle: "Allow",
                    denyTitle: "Don't Allow",
                    onAllow: {
                        showMotionPrompt = false
                        Task { await requestMotion() }
                    },
                    onDeny: {
                        showMotionPrompt = false
                        showFeedback("Motion access skipped. Live movement features stay off.", isError: false)
                        stage = .notifications
                    }
                )
            }

            if showHealthPrompt {
                healthPromptOverlay
            }

            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView().tint(Colors.accentTeal)
                    Text("Requesting access...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Colors.cardSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
            }
        }
        .onAppear {
            Task { await refreshStatuses() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshStatuses() }
        }
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    stage == .health
                    ? Color(red: 0.24, green: 0.19, blue: 0.52).opacity(0.45)
                    : Colors.accentBlue.opacity(0.24)
                )
                .frame(width: 176, height: 176)

            Image(systemName: iconName)
                .font(.system(size: 62, weight: .bold))
                .foregroundColor(iconColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var iconName: String {
        switch stage {
        case .motion:
            return "figure.run.circle.fill"
        case .notifications:
            return "bell.badge.fill"
        case .health:
            return "heart.text.square.fill"
        }
    }

    private var iconColor: Color {
        switch stage {
        case .motion:
            return Color(red: 0.98, green: 0.60, blue: 0.33)
        case .notifications:
            return Colors.accentBlue
        case .health:
            return Colors.accentRed
        }
    }

    private var stageTitle: String {
        switch stage {
        case .motion:
            return "Permission to Access Motion Data"
        case .notifications:
            return "Don't Miss Important Reports and Insights"
        case .health:
            return "Permission to Access Apple Health"
        }
    }

    private var stageBody: String {
        switch stage {
        case .motion:
            return "Motion data powers live movement tracking for activity-based habits.\n\nImportant!\nIf disabled, movement detection and live tracking features will be limited."
        case .notifications:
            return "Let \(appName) notify you for important alarms, reminders, reports and habit insights."
        case .health:
            return "Connect Apple Health to track steps and activity-based habit progress automatically."
        }
    }

    private var statusBadge: some View {
        let status: PermissionStatus
        switch stage {
        case .motion:
            status = motionStatus
        case .notifications:
            status = notificationsStatus
        case .health:
            status = healthStatus
        }
        return HStack(spacing: 8) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(status.color.opacity(0.14))
        .clipShape(Capsule())
    }

    private var notificationPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sample alert")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Colors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("7:00 AM — Morning alarm")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text("8:00 PM — Read for 10 minutes")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .cornerRadius(14)
        }
        .padding(12)
        .background(Colors.cardSurface.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var motionPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Motion Detection")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Text("Detect walking and movement in real-time for motion-based habits and wake-up flows.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(2)

            HStack {
                Text("Walking now")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text("342 steps")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Colors.accentTeal)
            }
            .padding(12)
            .background(Color.black.opacity(0.22))
            .cornerRadius(14)
        }
        .padding(14)
        .background(Colors.cardSurface.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var healthPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Access")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            healthToggleRow(title: "Steps", subtitle: "Read daily step count for habit progress")
            healthToggleRow(title: "Distance", subtitle: "Read walking distance for activity goals")
            healthToggleRow(title: "Cycling", subtitle: "Read cycling distance for ride goals")
            healthToggleRow(title: "Sleep", subtitle: "Read sleep duration for recovery habits")
            healthToggleRow(title: "Hydration", subtitle: "Read water intake for drink-water habits")
            healthToggleRow(title: "Standing", subtitle: "Read standing time for posture habits")
            healthToggleRow(title: "Mindfulness", subtitle: "Read mindful minutes for meditation habits")
        }
        .padding(14)
        .background(Colors.cardSurface.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func healthToggleRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.accentBlue)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Capsule()
                    .fill(Colors.accentGreen)
                    .frame(width: 50, height: 30)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .offset(x: 10)
                    )
            }

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Colors.textSecondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.22))
        .cornerRadius(14)
    }

    private var healthPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Health Access")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)

                Text("\"\(appName)\" would like to access Apple Health to read activity, cycling, sleep, hydration, standing, and mindfulness data for habit tracking.")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .lineSpacing(2)

                Text("You can change this anytime in Apple Health or Settings.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Colors.textSecondary)

                Spacer(minLength: 10)

                Button {
                    showHealthPrompt = false
                    Task { await requestHealth() }
                } label: {
                    Text("Allow")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Colors.accentBlue, Colors.accentTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }

                Button {
                    showHealthPrompt = false
                    showFeedback("Health access skipped. You can enable it later.", isError: false)
                    onNext()
                } label: {
                    Text("Don't Allow")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black.opacity(0.30))
                        .overlay(
                            Capsule()
                                .stroke(Colors.cardStroke, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(22)
            .frame(maxWidth: 560)
            .background(Colors.cardSurface.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .cornerRadius(24)
            .padding(.horizontal, 20)
        }
    }

    private func permissionPromptOverlay(
        title: String,
        body: String,
        allowTitle: String,
        denyTitle: String,
        onAllow: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .lineSpacing(2)
                    .foregroundColor(Colors.textPrimary)
                    .minimumScaleFactor(0.35)
                    .fixedSize(horizontal: false, vertical: true)

                Text(body)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: onDeny) {
                        Text(denyTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black.opacity(0.28))
                            .clipShape(Capsule())
                    }

                    Button(action: onAllow) {
                        Text(allowTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black.opacity(0.28))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(Colors.cardSurface.opacity(0.98))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .cornerRadius(26)
            .padding(.horizontal, 24)
        }
    }

    private func handleContinueTapped() {
        switch stage {
        case .motion:
            if motionStatus == .granted || motionStatus == .unavailable {
                stage = .notifications
            } else {
                showMotionPrompt = true
            }
        case .notifications:
            if notificationsStatus == .granted {
                stage = .health
            } else {
                showNotificationPrompt = true
            }
        case .health:
            if healthStatus == .granted || healthStatus == .unavailable {
                onNext()
            } else {
                showHealthPrompt = true
            }
        }
    }

    private func handleSkipTapped() {
        switch stage {
        case .motion:
            stage = .notifications
        case .notifications:
            stage = .health
        case .health:
            onNext()
        }
    }

    @MainActor
    private func requestMotion() async {
        let status = CMMotionActivityManager.authorizationStatus()
        switch status {
        case .authorized:
            motionStatus = .granted
            showFeedback("Motion access enabled.", isError: false)
            stage = .notifications
            return
        case .denied, .restricted:
            motionStatus = .denied
            showFeedback("Motion access not enabled. You can change it later in Settings.", isError: true)
            return
        case .notDetermined:
            guard CMMotionActivityManager.isActivityAvailable() else {
                motionStatus = .unavailable
                showFeedback("Motion access is unavailable on this device.", isError: true)
                stage = .notifications
                return
            }

            isRequesting = true
            let granted = await withCheckedContinuation { continuation in
                let queue = OperationQueue()
                var completed = false

                let finish: () -> Void = {
                    if completed { return }
                    completed = true
                    let allowed = CMMotionActivityManager.authorizationStatus() == .authorized
                    continuation.resume(returning: allowed)
                }

                motionManager.queryActivityStarting(from: Date().addingTimeInterval(-60), to: Date(), to: queue) { _, _ in
                    DispatchQueue.main.async { finish() }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    finish()
                }
            }
            isRequesting = false

            await refreshStatuses()
            if granted {
                showFeedback("Motion access enabled.", isError: false)
                stage = .notifications
            } else {
                showFeedback("Motion access not enabled. You can continue without live motion features.", isError: true)
            }
        @unknown default:
            motionStatus = .notRequested
        }
    }

    @MainActor
    private func requestNotifications() async {
        isRequesting = true
        let granted = await NotificationManager.shared.ensureAuthorization()
        await refreshStatuses()
        isRequesting = false

        if granted {
            showFeedback("Notifications enabled.", isError: false)
            stage = .health
        } else {
            showFeedback("Notifications not enabled. You can change this later in Settings.", isError: true)
        }
    }

    @MainActor
    private func requestHealth() async {
        guard EntitlementInspector.hasHealthKitAccess else {
            healthStatus = .unavailable
            showFeedback("Health access unavailable in this build profile.", isError: true)
            onNext()
            return
        }

        isRequesting = true
        let granted = await HealthKitManager.shared.requestAuthorization(
            for: ["activity", "cycling", "sleep", "water", "standing", "mindfulness"]
        )
        await refreshStatuses()
        isRequesting = false

        if granted {
            showFeedback("Health access enabled.", isError: false)
            onNext()
        } else {
            showFeedback("Health access not enabled. You can continue and set it later.", isError: true)
        }
    }

    @MainActor
    private func refreshStatuses() async {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            motionStatus = .granted
        case .denied:
            motionStatus = .denied
        case .restricted:
            motionStatus = .denied
        case .notDetermined:
            motionStatus = CMMotionActivityManager.isActivityAvailable() ? .notRequested : .unavailable
        @unknown default:
            motionStatus = .notRequested
        }

        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        switch notificationSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsStatus = .granted
        case .denied:
            notificationsStatus = .denied
        case .notDetermined:
            notificationsStatus = .notRequested
        @unknown default:
            notificationsStatus = .notRequested
        }

        guard HKHealthStore.isHealthDataAvailable(),
              EntitlementInspector.hasHealthKitAccess,
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            healthStatus = .unavailable
            return
        }

        switch healthStore.authorizationStatus(for: stepsType) {
        case .sharingAuthorized:
            healthStatus = .granted
        case .sharingDenied:
            healthStatus = .denied
        case .notDetermined:
            healthStatus = .notRequested
        @unknown default:
            healthStatus = .notRequested
        }
    }

    private func showFeedback(_ text: String, isError: Bool) {
        feedbackText = text
        feedbackIsError = isError

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            if feedbackText == text {
                feedbackText = nil
            }
        }
    }
}
