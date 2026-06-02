import SwiftUI

struct OnboardingWakeFeelQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: "a", text: "Ready to go", emoji: "⚡️"),
        .init(id: "b", text: "Groggy", emoji: "🥱"),
        .init(id: "c", text: "Anxious or stressed", emoji: "😰"),
        .init(id: "d", text: "Neutral", emoji: "😐")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "How do you feel right after waking up?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: 6,
            questionTotal: 30,
            onNext: onNext
        )
    }
}
