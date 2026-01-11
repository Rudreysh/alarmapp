import SwiftUI

struct OnboardingPermissionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ProgressHeader(step: 2, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

                Text("Ensure your alarm rings")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: Spacing.l) {
                    PermissionIconLabel(
                        title: "Alarms\n(iOS 17+)",
                        systemImage: "alarm.fill",
                        color: .orange
                    )

                    PermissionIconLabel(
                        title: "Notifications",
                        systemImage: "bell.fill",
                        color: Colors.accentRed
                    )
                }

                PermissionDialogPreview()
                    .padding(.top, Spacing.s)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next") {
                    guard !isRequesting else { return }
                    isRequesting = true
                    Task { @MainActor in
                        await viewModel.requestNotificationPermissionAndAdvance()
                        isRequesting = false
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}

private struct PermissionIconLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
        }
    }
}

private struct PermissionDialogPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Please allow permission")
                    .cardTitle()
                    .foregroundColor(Colors.textPrimary)
                Text("Alarm and Notification permissions\nlet us ring when the phone is locked")
                    .bodyText()
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Colors.cardStroke)

            HStack(spacing: 0) {
                Text("Don’t Allow")
                    .bodyText()
                    .foregroundColor(Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)

                Divider()
                    .background(Colors.cardStroke)

                Text("Allow")
                    .bodyText()
                    .foregroundColor(Colors.accentTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
            }
        }
        .background(Colors.bgSecondary)
        .cornerRadius(Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
        .padding(.horizontal, Spacing.l)
    }
}
