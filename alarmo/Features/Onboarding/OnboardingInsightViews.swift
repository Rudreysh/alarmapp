import SwiftUI

/// Combined insight screen — a STAGED, count-up reveal (snooze → scroll → daily
/// total → the flip to reclaimable → lifetime wasted vs saved). Built to feel like
/// the "here's your number" moments in Cal AI / Opal / Rise: numbers tick up, bars
/// grow, and the story turns from cost to hope on a single screen.
struct OnboardingDailyLoopInsightView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    /// Reveal stage, advanced on a timeline (1 snooze → 2 scroll → 3 total → 4 flip → 5 lifetime).
    @State private var stage = 0

    private let lossColor = Color(hex: "#E24B4A")
    private let gainColor = Color(hex: "#1D9E75")

    private var calc: DailyLoopCalculator { viewModel.dailyLoopCalculator }
    private var scrollMinutes: Int { Int(viewModel.dailyScreenHours * 60) }
    private var maxLoopMinutes: Int { max(1, max(calc.dailySnoozeMinutes, scrollMinutes)) }

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

                equationCard

                if stage >= 4 { flipPayoff }
                if stage >= 5 { lifetimeCards }

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "But there's good news →", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
                    .opacity(stage >= 1 ? 1 : 0.5)
            }
        }
        .onAppear { runTimeline() }
    }

    // MARK: Pieces

    private var equationCard: some View {
        VStack(spacing: 14) {
            loopRow(emoji: "🔁", label: "snoozing", value: calc.dailySnoozeMinutes,
                    fraction: Double(calc.dailySnoozeMinutes) / Double(maxLoopMinutes), revealed: stage >= 1)
            loopRow(emoji: "📱", label: "scrolling", value: scrollMinutes,
                    fraction: Double(scrollMinutes) / Double(maxLoopMinutes), revealed: stage >= 2)

            if stage >= 3 {
                Rectangle().fill(Colors.cardStroke).frame(height: 1)
                HStack(spacing: 8) {
                    Text("=").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(Colors.textSecondary)
                    Text(dailyTotalText).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(lossColor)
                    Text("lost every day").font(.system(size: 16, weight: .medium)).foregroundColor(Colors.textSecondary)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Colors.cardSurface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.cardStroke, lineWidth: 1))
        .padding(.horizontal, Spacing.l)
    }

    private var flipPayoff: some View {
        VStack(spacing: 2) {
            Text("But you can take most of it back")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                CountUpNumber(target: max(1, calc.reclaimableHoursPerMonth), active: stage >= 4,
                              font: .system(size: 54, weight: .bold, design: .rounded), color: gainColor)
                Text("hrs / month").font(.system(size: 18, weight: .semibold)).foregroundColor(gainColor)
            }
        }
        .transition(.scale(scale: 0.82).combined(with: .opacity))
    }

    private var lifetimeCards: some View {
        HStack(spacing: 12) {
            lifetimeCard(title: "Lost in \(Int(calc.yearsHorizon)) yrs", days: calc.lifetimeLostDays, color: lossColor)
            lifetimeCard(title: "Saved with Alarmo", days: calc.lifetimeReclaimableDays, color: gainColor)
        }
        .padding(.horizontal, Spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var dailyTotalText: String {
        let total = Int(calc.dailyLostMinutes)
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func loopRow(emoji: String, label: String, value: Int, fraction: Double, revealed: Bool) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    CountUpNumber(target: value, active: revealed,
                                  font: .system(size: 24, weight: .bold, design: .rounded), color: lossColor)
                    Text("min").font(.system(size: 15, weight: .bold)).foregroundColor(lossColor)
                    Text(label).font(.system(size: 16, weight: .medium)).foregroundColor(Colors.textSecondary)
                    Spacer()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15)).frame(height: 9)
                        Capsule().fill(lossColor.opacity(0.85))
                            .frame(width: geo.size.width * (revealed ? min(1, fraction) : 0), height: 9)
                    }
                }
                .frame(height: 9)
                .animation(.easeOut(duration: 0.7), value: revealed)
            }
        }
        .opacity(revealed ? 1 : 0)
        .offset(x: revealed ? 0 : -18)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: revealed)
    }

    private func lifetimeCard(title: String, days: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            CountUpNumber(target: days, active: stage >= 5,
                          font: .system(size: 30, weight: .bold, design: .rounded), color: color)
            Text("days · ≈\(String(format: "%.1f", Double(days) / 365.0)) yrs")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color.opacity(0.9))
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1.5))
    }

    private func runTimeline() {
        let steps: [(Double, Int)] = [(0.3, 1), (1.2, 2), (2.2, 3), (3.0, 4), (4.0, 5)]
        for (delay, value) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { stage = value }
                let style: UIImpactFeedbackGenerator.FeedbackStyle = value >= 4 ? .heavy : .light
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        }
    }
}

/// A number that ticks up from 0 to `target` when `active` becomes true.
private struct CountUpNumber: View {
    let target: Int
    let active: Bool
    let font: Font
    let color: Color
    @State private var value = 0

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { if active { run() } }
            .onChange(of: active) { _, now in if now { run() } }
    }

    private func run() {
        value = 0
        guard target > 0 else { return }
        let increment = max(1, target / 24)
        Timer.scheduledTimer(withTimeInterval: 0.028, repeats: true) { t in
            withAnimation(.linear(duration: 0.028)) { value += increment }
            if value >= target { value = target; t.invalidate() }
        }
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
