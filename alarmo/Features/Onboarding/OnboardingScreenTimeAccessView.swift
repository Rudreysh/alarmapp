import SwiftUI

struct OnboardingScreenTimeAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showPrompt = false
    @State private var systemSettingsDeniedAlert = false
    @StateObject private var screenTimeManager = ScreenTimeAuthorizationManager.shared

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Let's assume Screen Time is the new step 4, shifting motion to 5, live actions to 6, health to 7, sound to 8...
                ProgressHeader(step: 4, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Custom Icon
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                        .padding(24)
                        .background(Colors.cardSurface)
                        .cornerRadius(24)
                        .padding(.bottom, 12)
                    
                    Text("Permission for Screen Time")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Screen Time permissions are required for the Accountability features, allowing Alarmo to block distracting apps while you focus.")
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPrompt = true
                        }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            
            if showPrompt {
                customOverlay
                    .zIndex(1)
            }
            
            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                VStack(spacing: 10) {
                    ProgressView().tint(Colors.accentTeal)
                    Text("Requesting Access...")
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
        .alert("Screen Time Denied", isPresented: $systemSettingsDeniedAlert) {
            Button("Cancel", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Screen Time access is disabled. Please enable it in iOS Settings to use Alarmo's focus and accountability features.")
        }
    }
    
    private var customOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                Text("\"Alarmo\" would like to access Screen Time.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineSpacing(2)
                
                Text("This allows Alarmo to enforce accountability missions by blocking distractions during your active tasks.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(3)
                
                HStack(spacing: 12) {
                    Button {
                        showPrompt = false
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
                        showPrompt = false
                        requestAccess()
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
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .cornerRadius(24)
            .padding(.horizontal, 24)
        }
    }
    
    private func requestAccess() {
        guard screenTimeManager.state != .approved else {
            onNext()
            return
        }
        
        isRequesting = true
        Task {
            await screenTimeManager.requestAuthorization()
            await MainActor.run {
                isRequesting = false
                if screenTimeManager.isAuthorized {
                    onNext()
                } else if screenTimeManager.state == .notAvailable {
                    // Usually gracefully skip if the simulator or capabilities are completely broken
                    onNext()
                } else {
                    systemSettingsDeniedAlert = true
                }
            }
        }
    }
}
