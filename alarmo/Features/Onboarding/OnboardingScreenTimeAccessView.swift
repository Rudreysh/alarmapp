import SwiftUI

struct OnboardingScreenTimeAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var systemSettingsDeniedAlert = false
    @StateObject private var screenTimeManager = ScreenTimeAuthorizationManager.shared

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 5, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .center, spacing: 14) {
                    // Custom Icon
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                        .padding(20)
                        .background(Colors.cardSurface)
                        .cornerRadius(20)
                        .padding(.bottom, 10)
                    
                    Text("Permission for Screen Time")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Screen Time permissions are required for the Accountability features, allowing Alarmo to block distracting apps while you focus.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .center)
                
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
                        requestAccess()
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
    
    private func requestAccess() {
        screenTimeManager.refreshStatus()
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
