import SwiftUI

struct OnboardingPermissionsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var isRequesting = false
    
    // For visual iOS version display as requested in image (iOS 26)
    // We'll use the device version but allow the user to see the specific format
    private var iosVersion: String {
        let version = UIDevice.current.systemVersion.prefix(2)
        return "(iOS \(version))"
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ProgressHeader(step: 2, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

                Text("Ensure your alarm rings")
                    .font(.system(size: 32, weight: .bold)) // Bolder as in mockup
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.m)

                HStack(spacing: 30) {
                    PermissionIconLabel(
                        title: "Alarms\n\(iosVersion)",
                        systemImage: "alarm.fill",
                        color: .orange
                    )

                    PermissionIconLabel(
                        title: "Notifications",
                        systemImage: "bell.fill",
                        color: Colors.accentRed
                    )
                }

                Spacer()
                
                PermissionDialogPreview(onAllow: {
                    requestPermission()
                })
                .padding(.bottom, 60) // Positioned like a floating modal center-bottom-ish

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next") {
                    requestPermission()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
    
    private func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task { @MainActor in
            await viewModel.requestNotificationPermissionAndAdvance()
            isRequesting = false
            onNext()
        }
    }
}

private struct PermissionIconLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 40, height: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct PermissionDialogPreview: View {
    let onAllow: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.s) {
                Text("Please allow permission")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text("Alarm and Notification permissions let us ring when the phone is locked")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)

            Divider()
                .background(Colors.cardStroke)

            HStack(spacing: 0) {
                Button(action: {}) { // Don't allow usually does nothing in preview
                    Text("Don’t Allow")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Divider()
                    .frame(height: 44) // Smaller divider Height
                    .background(Colors.cardStroke)

                Button(action: onAllow) {
                    Text("Allow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 280) // Slightly narrower card too
        .background(Colors.cardSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 0.5)
        )
        .appShadow(Shadows.card)
    }
}
