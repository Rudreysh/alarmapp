import SwiftUI
import CoreMotion

struct OnboardingMotionAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showMotionPrompt = false
    @State private var systemSettingsDeniedAlert = false
    @State private var animateIn = false
    
    private let motionManager = CMMotionActivityManager()

    
    private var isTiimoTheme: Bool {
        UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
    }
var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 6, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .center, spacing: 14) {
                    PermissionHeroIcon(
                        systemName: "figure.run.circle.fill",
                        tint: Color(red: 0.98, green: 0.60, blue: 0.33)
                    )
                        .padding(.bottom, 10)
                    
                    Text("Permission to Access Motion Data")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Motion data powers live movement tracking for activity-based habits. If disabled, live tracking features will be limited.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
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
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.cardSurface)
                            .cornerRadius(32)
                    }
                    .disabled(isRequesting)
                    
                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showMotionPrompt = true
                        }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 24)
            }
             .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onboardingContentFrame()
            
            if showMotionPrompt {
                customMotionOverlay
                    .zIndex(1)
            }
            
            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                PermissionAnimatedLoadingCard(title: "Requesting Motion Access")
                .zIndex(3)
            }
        }
        .onAppear {
            animateIn = true
        }
        .alert("Motion & Fitness Disabled", isPresented: $systemSettingsDeniedAlert) {
            Button("Cancel", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Motion access is disabled. To enable live movement features, please turn it on in Settings.")
        }
    }
    
    private var customMotionOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                Text("\"Awayk\" would like to access your Motion & Fitness activity.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                
                Text("Motion data helps detect movement-based activity sessions and improves live habit tracking.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))
                    .lineSpacing(3)
                
                HStack(spacing: 12) {
                    Button {
                        showMotionPrompt = false
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
                        showMotionPrompt = false
                        Task { await requestMotion() }
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
    
    @MainActor
    private func requestMotion() async {
        let status = CMMotionActivityManager.authorizationStatus()
        
        switch status {
        case .authorized:
            onNext()
        case .denied, .restricted:
            systemSettingsDeniedAlert = true
        case .notDetermined:
            guard CMMotionActivityManager.isActivityAvailable() else {
                onNext()
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
            
            if granted {
                onNext()
            } else {
                onNext()
            }
        @unknown default:
            onNext()
        }
    }
}
