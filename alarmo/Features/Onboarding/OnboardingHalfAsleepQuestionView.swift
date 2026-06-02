import SwiftUI

struct OnboardingHalfAsleepQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: "a", text: "No, I feel aware", emoji: "✅"),
        .init(id: "b", text: "Sometimes", emoji: "🤔"),
        .init(id: "c", text: "Often", emoji: "😵"),
        .init(id: "d", text: "Almost every morning", emoji: "🌫")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "Do you feel confused or half-asleep after your alarm?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: 8,
            questionTotal: 30,
            onNext: onNext
        )
    }
}
