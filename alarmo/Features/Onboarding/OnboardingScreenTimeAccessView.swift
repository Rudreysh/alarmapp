import SwiftUI

struct OnboardingScreenTimeAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var systemSettingsDeniedAlert = false
    @StateObject private var screenTimeManager = ScreenTimeAuthorizationManager.shared
    @State private var animateIn = false

    
    private var isTiimoTheme: Bool {
        UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
    }
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
                    PermissionHeroIcon(
                        systemName: "hourglass.circle.fill",
                        tint: Colors.accentTeal
                    )
                        .padding(.bottom, 10)
                    
                    Text("Permission for Screen Time")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isTiimoTheme ? .black : .white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Screen Time permissions are required for the Accountability features, allowing Awayk to block distracting apps while you focus.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isTiimoTheme ? .black.opacity(0.72) : Color.white.opacity(0.82))
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .center)
                .permissionEntrance(animateIn)
                
                Spacer()
                
                // Bottom Buttons
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
                PermissionAnimatedLoadingCard(title: "Requesting Access")
                .zIndex(3)
            }
        }
        .onAppear {
            animateIn = true
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
            Text("Screen Time access is disabled. Please enable it in iOS Settings to use Awayk's focus and accountability features.")
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
