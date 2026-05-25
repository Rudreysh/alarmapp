import SwiftUI
import ImageIO

struct OnboardingSnoozeCountQuestionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    private let questionPurple = Color(hex: "#7F77DD")

    private let options: [(title: String, snoozes: Int)] = [
        ("I don't", 0),
        ("Just once", 1),
        ("2 – 3 times", 3),
        ("4 – 5 times", 5),
        ("6 – 7 times", 7),
        ("Lost count", 8)
    ]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                OnboardingQuestionFlowProgress(step: 7, total: 30, tint: Color(hex: "#7F77DD"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("How often do you snooze?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Pick the one that sounds most like you on a typical morning.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    ForEach(options, id: \.title) { option in
                        Button {
                            viewModel.snoozesPerMorning = option.snoozes
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Text("⏰").font(.system(size: 22))
                                Text(option.title).font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 102)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(viewModel.snoozesPerMorning == option.snoozes ? questionPurple.opacity(0.09) : Colors.cardSurface.opacity(0.6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(viewModel.snoozesPerMorning == option.snoozes ? questionPurple : Colors.cardStroke, lineWidth: 1.5)
                            )
                        }.buttonStyle(.plain)
                    }
                }
                Text("That's \(viewModel.snoozeCalculator.dailyMinutesLost) minutes lost every morning")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "That's me →", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }
}

struct OnboardingSnoozeAgeQuestionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    private let ageRanges: [(label: String, age: Int, icon: String)] = [
        ("Under 20", 18, "🌱"),
        ("20 – 25", 23, "🔥"),
        ("26 – 30", 28, "🏃"),
        ("31 – 40", 35, "💼"),
        ("41 – 50", 45, "☕"),
        ("Over 50", 55, "🌤")
    ]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                OnboardingQuestionFlowProgress(step: 8, total: 30, tint: Color(hex: "#7F77DD"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("How old are you?")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("This lets us calculate your lifetime snooze total.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    ForEach(ageRanges, id: \.label) { option in
                        Button {
                            viewModel.userAge = option.age
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            VStack(spacing: 6) {
                                Text(option.icon).font(.system(size: 22))
                                Text(option.label).font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(viewModel.userAge == option.age ? Color.awCoral : Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 102)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Colors.cardSurface.opacity(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(viewModel.userAge == option.age ? Color.awCoral : Colors.cardStroke, lineWidth: 1.5))
                        }.buttonStyle(.plain)
                    }
                }
                Text("You could reclaim \(viewModel.snoozeCalculator.lifetimeYearsLost, specifier: "%.1f") years of mornings")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Show me the truth →", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }
}

struct OnboardingSnoozeDailyDrainView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var count = 0
    @State private var reveal = false

    var body: some View {
        let calc = viewModel.snoozeCalculator
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 14) {
                OnboardingQuestionFlowProgress(step: 9, total: 30, tint: Color(hex: "#7F77DD"))
                Text("Daily drain").font(.system(size: 14, weight: .semibold)).foregroundColor(Colors.textSecondary)
                Text("This is what snooze costs you every morning")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(count)").font(.system(size: 94, weight: .bold, design: .rounded)).foregroundColor(Color.awCoral)
                Text("minutes lost").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("before you've even started your day").font(.system(size: 18, weight: .medium)).foregroundColor(Colors.textSecondary)
                Text(calc.dailyContextString)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.awCoralDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.awCoralLight))
                    .opacity(reveal ? 1 : 0).offset(y: reveal ? 0 : 18)
                GeometryReader { geo in
                    let w = geo.size.width
                    let p = min(1.0, Double(calc.dailyMinutesLost) / 100.0)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.awGrayDot).frame(height: 14)
                        Capsule().fill(Color.awCoral).frame(width: w * p, height: 14)
                    }
                }.frame(height: 14)
                HStack {
                    MetricCard(title: "This month", value: "\(String(format: "%.1f", calc.hoursLostPerMonth)) hrs", accent: .awCoral)
                    MetricCard(title: "This year", value: "\(calc.hoursLostPerYear) hrs", accent: .awCoral)
                }
                .opacity(reveal ? 1 : 0)
                Spacer()
            }
            .padding(Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Keep going →", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            count = 0
            let target = calc.dailyMinutesLost
            Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { t in
                if count >= target { t.invalidate(); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); return }
                count += max(1, target / 24)
                if count > target { count = target }
            }
            withAnimation(.easeOut.delay(0.45)) { reveal = true }
        }
    }
}

struct OnboardingSnoozeYearGridView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var revealedCount = 0

    private let columns = Array(repeating: GridItem(.fixed(12), spacing: 6), count: 20)

    var body: some View {
        let calc = viewModel.snoozeCalculator
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                OnboardingQuestionFlowProgress(step: 10, total: 30, tint: Color(hex: "#7F77DD"))
                Text("This is your year in mornings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 14) {
                    Label("Lost to snooze", systemImage: "circle.fill").foregroundColor(.awCoral)
                    Label("Free morning", systemImage: "circle.fill").foregroundColor(.awGrayDot)
                }.font(.system(size: 15, weight: .semibold))
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<365, id: \.self) { idx in
                        Circle()
                            .fill(idx < revealedCount ? Color.awCoral : Color.awGrayDot)
                            .frame(width: 11, height: 11)
                    }
                }
                Text("\(calc.morningsLostPerYear) mornings this year swallowed by the snooze button. \(calc.daysPerYear - calc.morningsLostPerYear) could be yours.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    MetricCard(title: "Days lost / year", value: "\(String(format: "%.1f", calc.daysLostPerYear)) days", accent: .awCoral)
                    MetricCard(title: "Mornings affected", value: "\(calc.morningsLostPerYear) / yr", accent: .awCoral)
                }
                Spacer()
            }
            .padding(Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next →", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            revealedCount = 0
            let target = max(0, min(365, calc.morningsLostPerYear))
            guard target > 0 else { return }
            let step = max(0.01, 1.8 / Double(target))
            Timer.scheduledTimer(withTimeInterval: step, repeats: true) { t in
                if revealedCount >= target {
                    t.invalidate()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    return
                }
                revealedCount += 1
            }
        }
    }
}

struct OnboardingSnoozeLifetimeTotalView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var yearsCount: Double = 0
    @State private var pulse = false

    var body: some View {
        let calc = viewModel.snoozeCalculator
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 12) {
                OnboardingQuestionFlowProgress(step: 11, total: 30, tint: Color(hex: "#7F77DD"))
                Text("From now until you're 80").font(.system(size: 18, weight: .semibold)).foregroundColor(Colors.textSecondary)
                Text("You're on track to spend")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(yearsCount, specifier: "%.1f")")
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.awCoral)
                    .scaleEffect(pulse ? 1.02 : 1.0)
                Text("years asleep between alarms")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("That's not rest. That's fragmented, groggy limbo.")
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(Colors.textSecondary).multilineTextAlignment(.center)
                HStack { MetricCard(title: "Lifetime hours", value: "\(Int(calc.lifetimeHoursLost).formatted())", accent: .awCoral)
                    MetricCard(title: "Lifetime days", value: "\(calc.lifetimeDaysLost) days", accent: .awCoral) }
                HStack { MetricCard(title: "Hours / year", value: "\(calc.hoursLostPerYear) hrs", accent: .awCoral)
                    MetricCard(title: "Days / year", value: "\(String(format: "%.1f", calc.daysLostPerYear)) days", accent: .awCoral) }
                Spacer()
            }
            .padding(Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "But there's good news →", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            yearsCount = 0
            withAnimation(.easeOut(duration: 1.5)) { yearsCount = calc.lifetimeYearsLost }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.easeInOut(duration: 0.15)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { withAnimation(.easeInOut(duration: 0.15)) { pulse = false } }
            }
        }
    }
}

struct OnboardingSnoozePayoffView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var yearsCount: Double = 0
    @State private var bar1: CGFloat = 0
    @State private var bar2: CGFloat = 0
    @State private var bar3: CGFloat = 0
    @State private var reveal = false

    var body: some View {
        let calc = viewModel.snoozeCalculator
        let maxMetric = max(calc.booksCouldRead, max(calc.workoutsCouldDo, calc.calmMornings))
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 8) {
                OnboardingQuestionFlowProgress(step: 12, total: 30, tint: Color(hex: "#7F77DD"))
                Text("The good news is...").font(.system(size: 16, weight: .semibold)).foregroundColor(.awGreen)
                Text("Awayk can give you").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("\(yearsCount, specifier: "%.1f")").font(.system(size: 72, weight: .bold, design: .rounded)).foregroundColor(.awGreen)
                Text("years back").font(.system(size: 32, weight: .bold, design: .rounded)).foregroundColor(.awGreen)
                Text("Here's what you could do with that time.").font(.system(size: 17, weight: .semibold)).foregroundColor(Colors.textSecondary)
                PayoffBarRow(title: "Books you could read", value: calc.booksCouldRead, progress: bar1)
                PayoffBarRow(title: "Workouts you could do", value: calc.workoutsCouldDo, progress: bar2)
                PayoffBarRow(title: "Calm mornings", value: calc.calmMornings, progress: bar3)
                Text("Starting tomorrow, Awayk wakes you at the right moment in your sleep cycle — so you never waste another minute.")
                    .font(.system(size: 15, weight: .medium)).foregroundColor(.awGreen)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.awGreenLight))
                    .opacity(reveal ? 1 : 0)
                HStack {
                    MetricCard(title: "Saved / year", value: "\(calc.hoursLostPerYear) hrs", accent: .awGreen)
                    MetricCard(title: "Saved lifetime", value: "\(Int(calc.lifetimeHoursLost).formatted()) hrs", accent: .awGreen)
                }.opacity(reveal ? 1 : 0)
                Spacer()
            }
            .padding(Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Let's fix this →", style: .alarmDefault) {
                    viewModel.persistSnoozeOnboardingInputs()
                    UserDefaults.standard.set(true, forKey: "onboarding_complete")
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            yearsCount = 0
            withAnimation(.easeOut(duration: 1.2)) { yearsCount = calc.lifetimeYearsLost }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) { bar1 = maxMetric == 0 ? 0 : CGFloat(calc.booksCouldRead) / CGFloat(maxMetric) }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) { bar2 = maxMetric == 0 ? 0 : CGFloat(calc.workoutsCouldDo) / CGFloat(maxMetric) }
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) { bar3 = maxMetric == 0 ? 0 : CGFloat(calc.calmMornings) / CGFloat(maxMetric) }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) { reveal = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(Colors.textSecondary)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Colors.cardSurface.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Colors.cardStroke, lineWidth: 1))
    }
}

private struct OnboardingQuestionFlowProgress: View {
    let step: Int
    let total: Int
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            GeometryReader { geo in
                let fraction = total > 0 ? CGFloat(step) / CGFloat(total) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10)).frame(height: 10)
                    Capsule().fill(tint.opacity(0.85)).frame(width: geo.size.width * min(max(fraction, 0), 1), height: 10)
                }
            }
            .frame(height: 10)
            SnoozeHeaderGIFIcon(resourceName: "purple-bg-alarm", resourceExtension: "gif", size: 54)
                .frame(width: 54, height: 54)
        }
    }
}

private struct SnoozeHeaderGIFIcon: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    let size: CGFloat

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        loadGIF(into: imageView)
        return imageView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: size, height: size)
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.bounds.size = CGSize(width: size, height: size)
        if !uiView.isAnimating { loadGIF(into: uiView) }
    }

    private func loadGIF(into imageView: UIImageView) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return }

        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += max(0.02, frameDuration(source: source, index: index))
        }
        guard !frames.isEmpty else { return }
        imageView.stopAnimating()
        imageView.animationImages = frames
        imageView.animationDuration = max(0.1, duration)
        imageView.animationRepeatCount = 0
        imageView.image = frames.first
        imageView.startAnimating()
    }

    private func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        return unclamped ?? clamped ?? 0.1
    }
}

private struct PayoffBarRow: View {
    let title: String
    let value: Int
    let progress: CGFloat
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(value.formatted())").font(.system(size: 16, weight: .bold)).foregroundColor(.awGreen)
            }
            GeometryReader { geo in
                let w = max(0, min(1, progress)) * geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.awGrayDot).frame(height: 6)
                    Capsule().fill(Color.awGreen).frame(width: w, height: 6)
                }
            }.frame(height: 8)
        }
    }
}

private extension Color {
    static let awCoral = Color(hex: "#E8724A")
    static let awCoralLight = Color(hex: "#FAECE7")
    static let awCoralDark = Color(hex: "#993C1D")
    static let awGreen = Color(hex: "#1D9E75")
    static let awGreenLight = Color(hex: "#E1F5EE")
    static let awGrayDot = Color(hex: "#D8D4CC")
}
