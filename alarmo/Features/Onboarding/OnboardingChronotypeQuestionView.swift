import SwiftUI

struct OnboardingChronotypeQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "b"

    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [QuestionOption] = [
        .init(id: "a", text: "Early bird — I'm up before 7am naturally", emoji: "🌅"),
        .init(id: "b", text: "Middle ground — 7-9am feels right", emoji: "☀️"),
        .init(id: "c", text: "Night owl — Before 9am is a struggle", emoji: "🌙"),
        .init(id: "d", text: "It changes — Depends on the day", emoji: "😵")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "When do you naturally wake up best?",
            options: options,
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 3,
            questionTotal: 30,
            onNext: onNext
        )
    }
}
