import SwiftUI

struct OnboardingReportsInsightsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showNotificationPrompt = false
    @State private var systemSettingsDeniedAlert = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Custom Icon
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 60, weight: .semibold))
                            .foregroundColor(Colors.accentBlue)
                            .padding(24)
                            .background(Colors.cardSurface)
                            .cornerRadius(24)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .offset(x: -8, y: 8)
                    }
                    .padding(.bottom, 12)
                    
                    Text("Don't Miss Important Reports and Insights")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Let Alarmo notify you of important findings, sleep reports and more. This feature requires permission to receive notifications from Alarmo.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Bottom Buttons
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNotificationPrompt = true
                        }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            
            if showNotificationPrompt {
                customPermissionOverlay
                    .zIndex(1)
            }
            
            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
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
                .zIndex(3)
            }
        }
        .alert("Notifications Disabled", isPresented: $systemSettingsDeniedAlert) {
            Button("Cancel", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Notifications are currently disabled for Alarmo. To receive alarms and reports, please enable them in Settings.")
        }
    }
    
    @MainActor
    private func handleAllowTapped() async {
        isRequesting = true
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let wasAlreadyDenied = settings.authorizationStatus == .denied
        
        let granted = await NotificationManager.shared.ensureAuthorization()
        isRequesting = false
        
        if granted {
            onNext()
        } else if wasAlreadyDenied {
            systemSettingsDeniedAlert = true
        } else {
            onNext()
        }
    }
    
    private var customPermissionOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("\"Alarmo\" Would Like to Send You Notifications")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                
                Text("Notifications may include alerts, sounds and icon badges. These can be configured in Settings.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
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
                        Task { await handleAllowTapped() }
                    } label: {
                        Text("Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15)) // Both styled the same as Pillow reference
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }
}
