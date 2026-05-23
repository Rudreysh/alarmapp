import SwiftUI

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
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
                    .offset(x: size.width - 200, y: -50)
                
                Circle()
                    .fill(backgroundColors.1.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -100, y: size.height * 0.5)
            }
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
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Only animate the transition within the TabView layout
                .animation(.easeInOut, value: currentPage)

                Spacer()
                
                PageDots(count: 2, activeIndex: currentPage)
                    .padding(.bottom, Spacing.m)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: currentPage == 1 ? "Get Started" : "Next", style: .blueGlass) {
                    if currentPage < 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Elevated like the other screens
                // Also let the button title animate
                .animation(.easeInOut, value: currentPage)
            }
        }
    }
    
    // Dynamic background colors
    private var backgroundColors: (Color, Color) {
        switch currentPage {
        case 0: return (Colors.accentTeal, Colors.accentBlue)
        case 1: return (Colors.accentBlue, Color.purple)
        default: return (Colors.accentTeal, Colors.accentBlue)
        }
    }
    
    // MARK: - Pages
    
    private var pageOne: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header(title: "Master your time.", subtitle: "Alarms, habits and focus in one unified workspace.")

                VStack(spacing: Spacing.m) {
                    bentoCard(icon: "alarm.fill", color: Colors.accentTeal, title: "Smart Alarms", subtitle: "Wake up reliably with alarm missions and louder fallback options.", height: 138)

                    bentoCard(icon: "timer", color: Color.orange, title: "Pomodoro", subtitle: "Stay in deep focus.", height: 124)

                    bentoCard(icon: "chart.xyaxis.line", color: Colors.accentBlue, title: "Progress Reports", subtitle: "Track your daily and weekly consistency at a glance.", height: 116)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }
    
    private var pageTwo: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header(title: "Deep Work, Simplified.", subtitle: "Stay focused with app blocking and coordinate better with time overlap.")

                VStack(spacing: Spacing.m) {
                    bentoCard(icon: "shield.lefthalf.filled", color: Color.orange, title: "App Blocking", subtitle: "Block distracting apps during focus sessions and alarm missions.", height: 138)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }
    
    // Header Builder
    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
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
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .padding(.bottom, 2)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
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
