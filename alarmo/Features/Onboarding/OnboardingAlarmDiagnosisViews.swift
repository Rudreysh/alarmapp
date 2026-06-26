import SwiftUI

/// Q1 of the alarm diagnosis. One strong question that also bridges into the
/// app-blocking pillar via the "I wake up but start scrolling" option.
struct OnboardingMorningProblemView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: MorningProblem.sleepThrough.rawValue, text: "I sleep through alarms", emoji: "😴"),
        .init(id: MorningProblem.snooze.rawValue, text: "I snooze too many times", emoji: "🔁"),
        .init(id: MorningProblem.scrolling.rawValue, text: "I wake up but start scrolling", emoji: "📱"),
        .init(id: MorningProblem.stayInBed.rawValue, text: "I wake up but stay in bed", emoji: "🛌"),
        .init(id: MorningProblem.tired.rawValue, text: "I wake up tired", emoji: "🥱")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "\(viewModel.displayFirstName), what usually makes mornings hard?",
            subtitle: "We don't judge — tell us the truth.",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: OnboardingStep.morningProblem.rawValue,
            questionTotal: OnboardingStep.progressTotal,
            onNext: {
                if let id = selectedOptionID, let problem = MorningProblem(rawValue: id) {
                    viewModel.setMorningProblem(problem)
                }
                onNext()
            }
        )
    }
}

/// Q3 of the alarm diagnosis. Directly configures mission difficulty + snooze cap.
struct OnboardingAlarmDifficultyView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: AlarmDifficulty.easy.rawValue, text: "Easy — one tap to stop", emoji: "👆"),
        .init(id: AlarmDifficulty.medium.rawValue, text: "Medium — a quick mission", emoji: "🎯"),
        .init(id: AlarmDifficulty.hard.rawValue, text: "Hard — mission, no easy stop", emoji: "💪"),
        .init(id: AlarmDifficulty.extreme.rawValue, text: "Extreme — keep me up till I'm awake", emoji: "🔥")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "How hard should it be to stop your alarm?",
            subtitle: "We'll set up your wake-up mission to match.",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: OnboardingStep.alarmDifficulty.rawValue,
            questionTotal: OnboardingStep.progressTotal,
            onNext: {
                if let id = selectedOptionID, let difficulty = AlarmDifficulty(rawValue: id) {
                    viewModel.setAlarmDifficulty(difficulty)
                }
                onNext()
            }
        )
    }
}
