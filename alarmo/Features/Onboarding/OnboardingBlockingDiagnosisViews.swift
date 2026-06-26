import SwiftUI

/// The pivot from the alarm pillar to the app-blocking pillar. A short emotional
/// beat that reframes the problem: getting up is only step one.
struct OnboardingBlockingTransitionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @State private var phoneIn = false
    @State private var textIn = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressHeader(step: OnboardingStep.blockingTransition.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                Spacer()

                ZStack {
                    Circle()
                        .fill(Colors.accentBlue.opacity(0.10))
                        .frame(width: 150, height: 150)
                        .scaleEffect(phoneIn ? 1 : 0.6)
                    Text("📱")
                        .font(.system(size: 78))
                        .scaleEffect(phoneIn ? 1 : 0.4)
                        .rotationEffect(.degrees(phoneIn ? 0 : -18))
                }

                VStack(spacing: 14) {
                    Text("Nice, \(viewModel.displayFirstName).\nWaking up is only half the battle.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("The next trap is unlocking your phone and falling straight into apps.")
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.l)
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 20)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Show me →", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { phoneIn = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) { textIn = true }
        }
    }
}

/// App-blocking diagnosis Q1 — when apps catch the user. Used to suggest a default
/// blocking schedule.
struct OnboardingAppsWhenView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: AppsWhenContext.afterWaking.rawValue, text: "Right after waking up", emoji: "🌅"),
        .init(id: AppsWhenContext.beforeSleep.rawValue, text: "Before sleep", emoji: "🌙"),
        .init(id: AppsWhenContext.work.rawValue, text: "During work or study", emoji: "💼"),
        .init(id: AppsWhenContext.boredStressed.rawValue, text: "When I'm bored or stressed", emoji: "😵"),
        .init(id: AppsWhenContext.wheneverUnlock.rawValue, text: "Whenever I unlock my phone", emoji: "📱")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "When do distracting apps pull you in most?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: OnboardingStep.appsWhen.rawValue,
            questionTotal: OnboardingStep.progressTotal,
            onNext: {
                if let id = selectedOptionID, let when = AppsWhenContext(rawValue: id) {
                    viewModel.setAppsWhen(when)
                }
                onNext()
            }
        )
    }
}

/// App-blocking diagnosis Q2 — self-estimated daily screen time. Feeds the insight
/// math only (no scary external claims). Big number animates with the slider.
struct OnboardingScreenTimeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var hours: Double = 4

    private var numberColor: Color {
        switch hours {
        case ..<2: return Colors.accentGreen
        case ..<4: return Colors.accentTeal
        case ..<6: return Colors.accentOrange
        default: return Color(hex: "#E24B4A")
        }
    }

    private var label: String {
        DailyLoopCalculator(snoozesPerMorning: viewModel.snoozesPerMorning, dailyScreenHours: hours).screenTimeLabel
    }

    private var context: String {
        DailyLoopCalculator(snoozesPerMorning: viewModel.snoozesPerMorning, dailyScreenHours: hours).screenTimeContextString
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressHeader(step: OnboardingStep.screenTime.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How much time do you spend on screens daily?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("Your estimate is enough — Alarmo uses it to personalize your plan.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)

                Spacer()

                Text(label)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(numberColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hours)

                Text(context)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.l)
                    .fixedSize(horizontal: false, vertical: true)

                Slider(value: $hours, in: 0...8, step: 0.5)
                    .tint(numberColor)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, 8)
                HStack {
                    Text("0h").font(.system(size: 13, weight: .semibold)).foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text("8h+").font(.system(size: 13, weight: .semibold)).foregroundColor(Colors.textSecondary)
                }
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .blueGlass) {
                    viewModel.dailyScreenHours = hours
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
        .onAppear { hours = viewModel.dailyScreenHours }
    }
}

/// App-blocking diagnosis Q3 — friendly category chips (soft selection). Maps to
/// real `MockActivityPickerSheet.categories` ids; exact app picker comes later.
struct OnboardingAppsToBlockView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selected: Set<String> = []
    @State private var adult: Bool = false

    private struct Chip: Identifiable {
        let id: String          // real category id
        let title: String
        let emoji: String
    }

    private let chips: [Chip] = [
        .init(id: "social", title: "Social media", emoji: "💬"),
        .init(id: "entertainment", title: "Short videos & streaming", emoji: "🍿"),
        .init(id: "games", title: "Games", emoji: "🎮"),
        .init(id: "shopping", title: "Shopping", emoji: "🛍️"),
        .init(id: "information", title: "News", emoji: "📰")
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressHeader(step: OnboardingStep.appsToBlock.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Which apps should be harder to open?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("Pick the categories that pull you in. You can choose exact apps later.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(chips) { chip in
                        chipButton(chip)
                    }
                }
                .padding(.horizontal, Spacing.l)

                adultRow
                    .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: selected.isEmpty && !adult ? "Skip for now" : "Continue", style: .blueGlass) {
                    syncSelectionToViewModel()
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            selected = viewModel.blockedCategoryIDs
            adult = viewModel.blockAdultContent
        }
    }

    private func chipButton(_ chip: Chip) -> some View {
        let isOn = selected.contains(chip.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isOn { selected.remove(chip.id) } else { selected.insert(chip.id) }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 8) {
                Text(chip.emoji).font(.system(size: 26))
                Text(chip.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? Colors.accentBlue.opacity(0.10) : Colors.cardSurface.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn ? Colors.accentBlue : Colors.cardStroke, lineWidth: isOn ? 2 : 1.5)
            )
            .scaleEffect(isOn ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var adultRow: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { adult.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Text("🔞").font(.system(size: 22))
                Text("Also block adult content")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Image(systemName: adult ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(adult ? Colors.accentBlue : Colors.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 16).fill(Colors.cardSurface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(adult ? Colors.accentBlue : Colors.cardStroke, lineWidth: adult ? 2 : 1.5))
        }
        .buttonStyle(.plain)
    }

    private func syncSelectionToViewModel() {
        // Reconcile the view model's set with the local selection.
        for id in chips.map(\.id) {
            let want = selected.contains(id)
            let have = viewModel.blockedCategoryIDs.contains(id)
            if want != have { viewModel.toggleBlockedCategory(id) }
        }
        viewModel.blockAdultContent = adult
    }
}
