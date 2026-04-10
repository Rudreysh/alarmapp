import SwiftUI
import ActivityKit

struct OnboardingLiveActivitiesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showPrompt = false
    @State private var systemSettingsDeniedAlert = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 6, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Custom Icon
                    ZStack {
                        Colors.cardSurface
                            .frame(width: 108, height: 108)
                            .cornerRadius(24)
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 60, weight: .regular))
                            .foregroundColor(Colors.accentTeal)
                    }
                    .padding(.bottom, 12)
                    
                    Text("Live Habit Tracking")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Track your active focus timers, alarms, and accountability missions directly from your Lock Screen in real-time without opening the app.")
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
                customLiveActivitiesOverlay
                    .zIndex(1)
            }
            
        }
        .alert("Live Activities Disabled", isPresented: $systemSettingsDeniedAlert) {
            Button("Cancel", role: .cancel) {
                onNext()
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Live Tracking is disabled. To view timers on your Lock Screen, please enable Live Activities in Settings.")
        }
    }
    
    private var customLiveActivitiesOverlay: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 14) {
                Text("Allow Live Habit Tracking?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineSpacing(2)
                
                Text("\"Alarmo\" uses Live tracking technologies to keep you fully updated on your active missions from the Lock Screen.")
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
                        Task { await requestActivities() }
                    } label: {
                        Text("Allow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.accentTeal)
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
    private func requestActivities() async {
        let isEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        if isEnabled {
            onNext()
        } else {
            systemSettingsDeniedAlert = true
        }
    }
}
