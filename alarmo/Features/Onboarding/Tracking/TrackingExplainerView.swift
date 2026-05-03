import SwiftUI

struct TrackingExplainerView: View {
    @StateObject private var viewModel = TrackingExplainerViewModel()
    let onNext: () -> Void
    @State private var isRequesting = false
    @State private var animateItems = false

    var body: some View {
        ZStack {
            // Premium ambient background matching Intro
            Colors.bgPrimary.ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                Circle()
                    .fill(Colors.accentTeal.opacity(0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: animateItems ? size.width - 200 : -50,
                            y: animateItems ? -20 : size.height * 0.3)
                
                Circle()
                    .fill(Colors.accentBlue.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: animateItems ? -100 : size.width - 150,
                            y: animateItems ? size.height * 0.6 : 0)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateItems)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personalized Experience.")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text("Alarmo can securely tailor ads to your interests.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.s)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateItems)

                ProgressHeader(step: 12, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xs)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.m) {
                        TrackingFeatureCard(
                            icon: "megaphone.fill",
                            color: Colors.accentTeal,
                            title: "Relevant Advertisements",
                            subtitle: "Display ads that actually match your interests."
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)

                        TrackingFeatureCard(
                            icon: "checkmark.shield.fill",
                            color: Colors.accentBlue,
                            title: "Improve Alarmo",
                            subtitle: "Help us understand usage to build better features."
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    requestPermission()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48)
                .opacity(animateItems ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.5), value: animateItems)
            }
        }
        .onAppear {
            animateItems = true
        }
    }
    
    private func requestPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task { @MainActor in
            _ = await viewModel.handleNext()
            isRequesting = false
            onNext() // Move to next screen automatically after handling system prompt
        }
    }
}

private struct TrackingFeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .padding(.top, 2)
            
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}
