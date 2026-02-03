import SwiftUI

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

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
                PrimaryButton(title: "Next", action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }
}
