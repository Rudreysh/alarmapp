import SwiftUI

/// Pick the stop-mission. Difficulty comes from the earlier alarm-difficulty
/// answer; this only chooses the TYPE. A curated subset keeps it approachable.
struct OnboardingMissionPickerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selected: WakeUpMissionType?

    private struct MissionChoice: Identifiable {
        let type: WakeUpMissionType
        let title: String
        let emoji: String
        var id: String { type.rawValue }
    }

    private let choices: [MissionChoice] = [
        .init(type: .math, title: "Math", emoji: "➗"),
        .init(type: .typing, title: "Type a phrase", emoji: "⌨️"),
        .init(type: .shake, title: "Shake", emoji: "📳"),
        .init(type: .step, title: "Walk steps", emoji: "🚶"),
        .init(type: .qrBarcode, title: "Scan a barcode", emoji: "📷"),
        .init(type: .objectHunt, title: "Find an object", emoji: "🔍")
    ]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressHeader(step: OnboardingStep.missionType.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should wake you up?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("Finish this mission to stop the alarm — and to unlock blocked apps.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(choices) { choice in
                        choiceButton(choice)
                    }
                }
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .blueGlass) {
                    if let selected { viewModel.setMission(selected) }
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.55 : 1.0)
            }
        }
        .onAppear { if viewModel.missionType != .off { selected = viewModel.missionType } }
    }

    private func choiceButton(_ choice: MissionChoice) -> some View {
        let isOn = selected == choice.type
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = choice.type }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 8) {
                Text(choice.emoji).font(.system(size: 28))
                Text(choice.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(RoundedRectangle(cornerRadius: 16).fill(isOn ? Colors.accentBlue.opacity(0.10) : Colors.cardSurface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isOn ? Colors.accentBlue : Colors.cardStroke, lineWidth: isOn ? 2 : 1.5))
            .scaleEffect(isOn ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

/// When Alarmo should block the chosen apps. Recommended option first.
struct OnboardingBlockingScheduleView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: BlockingSchedule.afterAlarmUntilMission.rawValue, text: "After my alarm — until I finish my mission", emoji: "⏰"),
        .init(id: BlockingSchedule.focusTime.rawValue, text: "During focus time", emoji: "🎯"),
        .init(id: BlockingSchedule.beforeSleep.rawValue, text: "Before sleep", emoji: "🌙"),
        .init(id: BlockingSchedule.customLater.rawValue, text: "I'll set this up later", emoji: "⚙️")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "When should Alarmo block distracting apps?",
            subtitle: "Most people start with \u{201C}until my mission is done.\u{201D}",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: OnboardingStep.blockingSchedule.rawValue,
            questionTotal: OnboardingStep.progressTotal,
            onNext: {
                if let id = selectedOptionID, let schedule = BlockingSchedule(rawValue: id) {
                    viewModel.blockingSchedule = schedule
                }
                onNext()
            }
        )
        .onAppear { if selectedOptionID == nil { selectedOptionID = viewModel.blockingSchedule.rawValue } }
    }
}

/// Final recap — "{Name}'s Alarmo plan". Rows check in one by one.
struct OnboardingPlanSummaryView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onStart: () -> Void
    @State private var shown = 0

    private var rows: [(emoji: String, title: String, value: String)] {
        [
            ("⏰", "Wake-up time", viewModel.selectedTimeString),
            ("🔁", "Snooze", snoozeText),
            ("🎯", "Stop mission", missionText),
            ("🔒", "Blocked", blockedText),
            ("🛡️", "Blocking window", scheduleText)
        ]
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressHeader(step: OnboardingStep.planSummary.rawValue, total: OnboardingStep.progressTotal, showsBadge: false)
                    .padding(.horizontal, Spacing.l)

                VStack(spacing: 6) {
                    Text("🎉").font(.system(size: 44))
                    Text("\(viewModel.displayFirstName)'s Alarmo plan")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                    Text("You can change any of this anytime.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                }
                .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        summaryRow(row)
                            .opacity(index < shown ? 1 : 0)
                            .offset(x: index < shown ? 0 : -16)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, 8)

                Spacer()
            }
            .onboardingContentFrame()
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Start Alarmo", style: .blueGlass, action: onStart)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            shown = 0
            for i in 0..<rows.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 * Double(i + 1)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { shown = i + 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    private func summaryRow(_ row: (emoji: String, title: String, value: String)) -> some View {
        HStack(spacing: 14) {
            Text(row.emoji).font(.system(size: 22))
            Text(row.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Spacer()
            Text(row.value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(RoundedRectangle(cornerRadius: 14).fill(Colors.cardSurface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Colors.cardStroke, lineWidth: 1))
    }

    private var snoozeText: String {
        let count = viewModel.resolvedSnoozeCount
        if count == 0 { return "Off" }
        return "\(count)× · \(viewModel.resolvedSnoozeMinutes) min"
    }

    private var missionText: String {
        if viewModel.alarmDifficulty == .easy { return "One tap" }
        let type = viewModel.missionType == .off ? WakeUpMissionType.math : viewModel.missionType
        return AlarmMission(type: type).title
    }

    private var blockedText: String {
        var parts = viewModel.blockedCategoryIDs.count
        if viewModel.blockAdultContent { parts += 1 }
        if parts == 0 { return "None yet" }
        return "\(parts) categor\(parts == 1 ? "y" : "ies")"
    }

    private var scheduleText: String {
        switch viewModel.blockingSchedule {
        case .afterAlarmUntilMission: return "Until mission"
        case .focusTime: return "Focus time"
        case .beforeSleep: return "Before sleep"
        case .customLater: return "Set later"
        }
    }
}
