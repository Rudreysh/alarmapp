import SwiftUI

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Colors.bgPrimary
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Colors.accentTeal.opacity(0.20),
                    Color.clear,
                    Colors.accentBlue.opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 16)
            .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Header with Skip
                HStack {
                    Spacer()
                    if let onSkip = onSkip {
                        Button("Skip") {
                            onSkip()
                        }
                        .foregroundColor(Colors.textSecondary)
                        .padding()
                    }
                }
                
                VStack(spacing: Spacing.s) {
                    Text("No more snoozing")
                        .heroTitle()
                    Text("Own your day")
                        .heroTitle()
                }
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .padding(.top, Spacing.xxl)
                .accessibilityAddTraits(.isHeader)

                HStack(spacing: Spacing.m) {
                    ComparisonCardOtherAppsView()
                    ComparisonCardAppView()
                }
                .padding(.horizontal, Spacing.l)

                PageDots(count: 3, activeIndex: 1)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onNext) {
                    Text("Next")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.m)
                        .background(
                            LinearGradient(
                                colors: [
                                    Colors.accentTeal.opacity(0.95),
                                    Colors.accentBlue.opacity(0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Colors.accentTeal.opacity(0.20), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(PressedScaleButtonStyle())
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}
