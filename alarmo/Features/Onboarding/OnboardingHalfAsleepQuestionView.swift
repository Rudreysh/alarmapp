import SwiftUI

struct OnboardingHalfAsleepQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "b"
    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [QuestionOption] = [
        .init(id: "a", text: "No, I feel aware"),
        .init(id: "b", text: "Sometimes"),
        .init(id: "c", text: "Often"),
        .init(id: "d", text: "Almost every morning")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "Do you feel confused or half-asleep after your alarm?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 8,
            questionTotal: 30,
            onNext: onNext
        )
    }
}

