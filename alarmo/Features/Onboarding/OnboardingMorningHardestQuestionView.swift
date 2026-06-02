import SwiftUI

struct OnboardingMorningHardestQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: "a", text: "Heavy tiredness", emoji: "😴"),
        .init(id: "b", text: "Low motivation", emoji: "🪫"),
        .init(id: "c", text: "Stress about the day", emoji: "😵‍💫"),
        .init(id: "d", text: "Poor sleep quality", emoji: "🛌"),
        .init(id: "e", text: "No clear routine", emoji: "🧭")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "What makes mornings hardest for you?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: 7,
            questionTotal: 30,
            onNext: onNext
        )
    }
}
