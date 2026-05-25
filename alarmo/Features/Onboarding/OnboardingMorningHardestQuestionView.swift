import SwiftUI

struct OnboardingMorningHardestQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "a"
    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [QuestionOption] = [
        .init(id: "a", text: "Heavy tiredness"),
        .init(id: "b", text: "Low motivation"),
        .init(id: "c", text: "Stress about the day"),
        .init(id: "d", text: "Poor sleep quality"),
        .init(id: "e", text: "No clear routine")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "What makes mornings hardest for you?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 7,
            questionTotal: 30,
            onNext: onNext
        )
    }
}

