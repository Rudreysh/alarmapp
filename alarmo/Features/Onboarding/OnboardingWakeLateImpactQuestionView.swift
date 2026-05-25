import SwiftUI

struct OnboardingWakeLateImpactQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "b"
    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [QuestionOption] = [
        .init(id: "a", text: "It does not affect much"),
        .init(id: "b", text: "I feel rushed"),
        .init(id: "c", text: "I feel stressed"),
        .init(id: "d", text: "It affects my whole day")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "How does waking up late affect your day?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 5,
            questionTotal: 30,
            onNext: onNext
        )
    }
}

