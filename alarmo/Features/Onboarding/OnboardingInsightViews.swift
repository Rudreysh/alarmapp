import SwiftUI

/// The single combined insight screen that replaces the old 5-screen snooze-cost
/// sequence. Adds the snooze + scroll math and ends on a POSITIVE figure: the
/// time the user could reclaim. Numbers animate up; a dot grid shows the share of
/// the day lost to the loop vs reclaimable.
struct OnboardingDailyLoopInsightView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @State private var reclaimCount = 0
    @State private var reveal = false
    @State private var revealedDots = 0

    private let lossColor = Color(hex: "#E24B4A")
    private let gainColor = Color(hex: "#1D9E75")
    private let totalDots = 40
    private let columns = Array(repeating: GridItem(.fixed(13), spacing: 7), count: 10)

    private var calc: DailyLoopCalculator { viewModel.dailyLoopCalculator }
    private var lostDots: Int { min(totalDots, Int((Double(totalDots) * calc.dailyLoopFraction).rounded())) }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressHeader(step: OnboardingStep.dailyLoopInsight.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                Text("Here's your daily loop, \(viewModel.displayFirstName)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, Spacing.l)
                    .fixedSize(horizontal: false, vertical: true)

                // The equation
                VStack(spacing: 10) {
                    loopRow(emoji: "🔁", value: "\(calc.dailySnoozeMinutes) min", label: "snoozing")
                    loopRow(emoji: "📱", value: calc.screenTimeLabel, label: "scrolling")
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 18).fill(Colors.cardSurface.opacity(0.6)))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Colors.cardStroke, lineWidth: 1))
                .padding(.horizontal, Spacing.l)

                // Dot grid: red = lost to the loop, green = reclaimable
                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(0..<totalDots, id: \.self) { idx in
                        Circle()
                            .fill(idx < revealedDots ? (idx < lostDots ? lossColor : gainColor) : Color.gray.opacity(0.18))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.horizontal, Spacing.l)

                // The positive payoff
                VStack(spacing: 2) {
                    Text("\(reclaimCount)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(gainColor)
                        .contentTransition(.numericText())
                    Text("hours a month you could reclaim")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.top, 4)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : 14)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "But there's good news →", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear { runAnimation() }
    }

    private func loopRow(emoji: String, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 24))
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(lossColor)
            Text(label).font(.system(size: 17, weight: .medium)).foregroundColor(Colors.textSecondary)
            Spacer()
        }
    }

    private func runAnimation() {
        reclaimCount = 0
        revealedDots = 0
        let target = max(1, calc.reclaimableHoursPerMonth)
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { t in
            if revealedDots < totalDots { revealedDots += 1 }
            if reclaimCount < target { reclaimCount += max(1, target / 28) }
            if reclaimCount > target { reclaimCount = target }
            if revealedDots >= totalDots && reclaimCount >= target {
                t.invalidate()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        withAnimation(.easeOut.delay(0.5)) { reveal = true }
    }
}

/// The hope screen: names BOTH pillars so the user understands why Alarmo has alarm
/// missions AND app blocking. Cards spring in; includes a friction-science line.
struct OnboardingHopePillarsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @State private var card1 = false
    @State private var card2 = false
    @State private var noteIn = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressHeader(step: OnboardingStep.hopePillars.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                Text("\(viewModel.displayFirstName), Alarmo gives you two things")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.horizontal, Spacing.l)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                pillarCard(
                    emoji: "⏰",
                    title: "Smart alarm missions",
                    body: "A mission stands between you and snooze — so you actually get up.",
                    tint: Colors.accentBlue
                )
                .opacity(card1 ? 1 : 0)
                .offset(y: card1 ? 0 : 26)

                pillarCard(
                    emoji: "🔒",
                    title: "App blocking with mission unlock",
                    body: "Distracting apps stay locked until you finish a quick mission.",
                    tint: Colors.accentGreen
                )
                .opacity(card2 ? 1 : 0)
                .offset(y: card2 ? 0 : 26)

                Text("Most scrolling starts before you even decide to. Alarmo adds a small moment of friction first — so you choose on purpose.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Colors.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Colors.cardSurface.opacity(0.5)))
                    .padding(.horizontal, Spacing.l)
                    .opacity(noteIn ? 1 : 0)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Let's set it up →", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { card1 = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) { card2 = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) { noteIn = true }
        }
    }

    private func pillarCard(emoji: String, title: String, body: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.12)).frame(width: 54, height: 54)
                Text(emoji).font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                Text(body)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Colors.cardSurface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.35), lineWidth: 1.5))
        .padding(.horizontal, Spacing.l)
    }
}
