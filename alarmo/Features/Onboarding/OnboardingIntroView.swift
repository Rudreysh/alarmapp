import SwiftUI

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @State private var animateItems = false

    var body: some View {
        ZStack {
            // New ambient luxury background
            Colors.bgPrimary.ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                Circle()
                    .fill(Colors.accentTeal.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: animateItems ? size.width - 200 : -50,
                            y: animateItems ? -50 : size.height * 0.4)
                
                Circle()
                    .fill(Colors.accentBlue.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: animateItems ? -100 : size.width - 150,
                            y: animateItems ? size.height * 0.5 : 0)
            }
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animateItems)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with Skip
                HStack {
                    Spacer()
                    if let onSkip = onSkip {
                        Button("Skip") {
                            onSkip()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .padding()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Master your time.")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("Alarms, Habits & Focus in one elegant unified workspace.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)

                // Bento Box Grid
                VStack(spacing: Spacing.m) {
                    // Feature 1: Core Alarms (Biggest)
                    bentoCard(
                        icon: "alarm.fill",
                        color: Colors.accentTeal,
                        title: "Smart Alarms",
                        subtitle: "Missions guarantee you wake up.",
                        height: 140
                    )
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateItems)

                    HStack(spacing: Spacing.m) {
                        // Feature 2: Pomodoro
                        bentoCard(
                            icon: "timer",
                            color: Color.orange,
                            title: "Pomodoro",
                            subtitle: "Deep focus.",
                            height: 120
                        )
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)
                        
                        // Feature 3: Habit
                        bentoCard(
                            icon: "checklist.checked",
                            color: Color.green,
                            title: "Habits",
                            subtitle: "Build streaks.",
                            height: 120
                        )
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                    }

                    // Feature 4: Overlap
                    bentoCard(
                        icon: "globe.americas.fill",
                        color: Colors.accentBlue,
                        title: "Time Overlap",
                        subtitle: "Connect across global timezones.",
                        height: 95
                    )
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)

                Spacer()
                
                PageDots(count: 3, activeIndex: 1)
                    .padding(.bottom, Spacing.m)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Get Started", style: .blueGlass) {
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Elevated like the other screens
                .opacity(animateItems ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.6), value: animateItems)
            }
        }
        .onAppear {
            animateItems = true
        }
    }
    
    // Bento Card Builder
    private func bentoCard(icon: String, color: Color, title: String, subtitle: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .padding(.bottom, 2)
            
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(Spacing.l) // robust padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}
