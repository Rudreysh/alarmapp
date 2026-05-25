import SwiftUI

struct OnboardingWakeLateImpactQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String? = nil

    private let options: [QuestionOption] = [
        .init(id: "a", text: "It does not affect much", emoji: "🙂"),
        .init(id: "b", text: "I feel rushed", emoji: "🏃"),
        .init(id: "c", text: "I feel stressed", emoji: "😣"),
        .init(id: "d", text: "It affects my whole day", emoji: "💥")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "How does waking up late affect your day?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: Colors.accentBlue,
            questionIndex: 5,
            questionTotal: 30,
            onNext: onNext
        )
    }
}
