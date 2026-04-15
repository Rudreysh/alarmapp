import SwiftUI

struct OnboardingLiveActivitiesView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false

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
                        onNext()
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}
