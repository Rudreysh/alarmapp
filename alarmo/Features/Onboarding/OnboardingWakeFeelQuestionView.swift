import SwiftUI

struct OnboardingWakeFeelQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "b"
    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [QuestionOption] = [
        .init(id: "a", text: "Ready to go"),
        .init(id: "b", text: "Groggy"),
        .init(id: "c", text: "Anxious or stressed"),
        .init(id: "d", text: "Neutral")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "How do you feel right after waking up?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 6,
            questionTotal: 30,
            onNext: onNext
        )
    }
}

