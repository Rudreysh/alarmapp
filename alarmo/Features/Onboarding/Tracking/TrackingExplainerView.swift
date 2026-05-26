import SwiftUI
import Combine

struct TrackingExplainerView: View {
    @StateObject private var viewModel = TrackingExplainerViewModel()
    let onNext: () -> Void
    @State private var isRequesting = false
    @State private var animateItems = false
    @State private var activeFeatureIndex = 0
    private let featureTimer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

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
                    Text("Build Your Perfect Wake Flow.")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(Colors.textPrimary)

                    Text("Alarm, focus, and app blocking in one setup.")
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
                            icon: "alarm.fill",
                            color: Color(hex: "#FF4D57"),
                            title: "Smart Alarm",
                            subtitle: "Reliable alarms with stronger fallback wake behavior.",
                            isActive: activeFeatureIndex == 0
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)

                        TrackingFeatureCard(
                            icon: "timer",
                            color: Color(hex: "#F39C35"),
                            title: "Pomodoro Focus",
                            subtitle: "Stay locked in with clean focus sessions and breaks.",
                            isActive: activeFeatureIndex == 1
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)

                        TrackingFeatureCard(
                            icon: "shield.lefthalf.filled",
                            color: Color(hex: "#35B6FF"),
                            title: "Block Apps",
                            subtitle: "Reduce distractions while you sleep or focus.",
                            isActive: activeFeatureIndex == 2
                        )
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
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
        .onReceive(featureTimer) { _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                activeFeatureIndex = (activeFeatureIndex + 1) % 3
            }
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
    let isActive: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            ZStack {
                Circle()
                    .fill(color.opacity(isActive ? 0.22 : 0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .scaleEffect(isActive ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.35), value: isActive)
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
                .stroke(isActive ? color.opacity(0.55) : Colors.cardStroke, lineWidth: isActive ? 1.5 : 1)
        )
        .appShadow(Shadows.card)
        .scaleEffect(isActive ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.35), value: isActive)
    }
}
