import SwiftUI

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @State private var animateItems = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // New ambient luxury background
            Colors.bgPrimary.ignoresSafeArea()
            
            GeometryReader { proxy in
                let size = proxy.size
                Circle()
                    .fill(backgroundColors.0.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: animateItems ? size.width - 200 : -50,
                            y: animateItems ? -50 : size.height * 0.4)
                
                Circle()
                    .fill(backgroundColors.1.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: animateItems ? -100 : size.width - 150,
                            y: animateItems ? size.height * 0.5 : 0)
            }
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: animateItems)
            .animation(.easeInOut(duration: 0.5), value: currentPage)
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
                
                TabView(selection: $currentPage) {
                    pageOne.tag(0)
                    pageTwo.tag(1)
                    pageThree.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Only animate the transition within the TabView layout
                .animation(.easeInOut, value: currentPage)

                Spacer()
                
                PageDots(count: 3, activeIndex: currentPage)
                    .padding(.bottom, Spacing.m)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: currentPage == 2 ? "Get Started" : "Next", style: .blueGlass) {
                    if currentPage < 2 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Elevated like the other screens
                .opacity(animateItems ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.6), value: animateItems)
                // Also let the button title animate
                .animation(.easeInOut, value: currentPage)
            }
        }
        .onAppear {
            animateItems = true
        }
    }
    
    // Dynamic background colors
    private var backgroundColors: (Color, Color) {
        switch currentPage {
        case 0: return (Colors.accentTeal, Colors.accentBlue)
        case 1: return (Colors.accentBlue, Color.purple)
        case 2: return (Color.green, Colors.accentTeal)
        default: return (Colors.accentTeal, Colors.accentBlue)
        }
    }
    
    // MARK: - Pages
    
    private var pageOne: some View {
        VStack(spacing: 0) {
            header(title: "Master your time.", subtitle: "Alarms, Habits & Focus in one elegant unified workspace.")
            
            // Bento Box Grid
            VStack(spacing: Spacing.m) {
                // Feature 1: Core Alarms (Biggest)
                bentoCard(icon: "alarm.fill", color: Colors.accentTeal, title: "Smart Alarms", subtitle: "Missions guarantee you wake up.", height: 140)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateItems)

                HStack(spacing: Spacing.m) {
                    // Feature 2: Pomodoro
                    bentoCard(icon: "timer", color: Color.orange, title: "Pomodoro", subtitle: "Deep focus.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)
                    
                    // Feature 3: Habit
                    bentoCard(icon: "checklist.checked", color: Color.green, title: "Habits", subtitle: "Build streaks.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                }

                // Feature 4: Overlap
                bentoCard(icon: "globe.americas.fill", color: Colors.accentBlue, title: "Time Overlap", subtitle: "Connect across global timezones.", height: 120)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            
            Spacer()
        }
    }
    
    private var pageTwo: some View {
        VStack(spacing: 0) {
            header(title: "Deep Work, Simplified.", subtitle: "Reclaim your attention in a world full of distractions.")
            
            // Bento Box Grid
            VStack(spacing: Spacing.m) {
                // Feature 1
                bentoCard(icon: "timer.square", color: Colors.accentBlue, title: "The Flow State", subtitle: "25-minute Pomodoro cycles help the brain enter flow faster.", height: 140)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateItems)

                HStack(spacing: Spacing.m) {
                    // Feature 2
                    bentoCard(icon: "waveform", color: Color.purple, title: "Soundscapes", subtitle: "Mask outside noise.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)
                    
                    // Feature 3
                    bentoCard(icon: "shield.lefthalf.filled", color: Color.orange, title: "App Blocking", subtitle: "Block distracting apps and stay radically focused.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                }

                // Feature 4
                bentoCard(icon: "bolt.fill", color: Colors.accentTeal, title: "Peak Output", subtitle: "Stop multitasking. Start mastering.", height: 120)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            
            Spacer()
        }
    }
    
    private var pageThree: some View {
        VStack(spacing: 0) {
            header(title: "Small Steps. Big Results.", subtitle: "Build habits that stick and track your journey to the top.")
            
            // Bento Box Grid
            VStack(spacing: Spacing.m) {
                // Feature 1
                bentoCard(icon: "square.stack.3d.up.fill", color: Color.green, title: "Habit Stacks", subtitle: "Bridge the gap between intention and action.", height: 140)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateItems)

                HStack(spacing: Spacing.m) {
                    // Feature 2
                    bentoCard(icon: "flame.fill", color: Color.orange, title: "Streaks", subtitle: "Visual momentum.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateItems)
                    
                    // Feature 3
                    bentoCard(icon: "checkmark.seal.fill", color: Colors.accentTeal, title: "Missions", subtitle: "Wake up on time.", height: 120)
                        .scaleEffect(animateItems ? 1 : 0.9)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: animateItems)
                }

                // Feature 4
                bentoCard(icon: "chart.xyaxis.line", color: Colors.accentBlue, title: "Insights", subtitle: "Consistency is the only secret to success.", height: 120)
                    .scaleEffect(animateItems ? 1 : 0.9)
                    .opacity(animateItems ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4), value: animateItems)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.xl)
            
            Spacer()
        }
    }
    
    // Header Builder
    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .opacity(animateItems ? 1 : 0)
        .offset(y: animateItems ? 0 : 20)
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
