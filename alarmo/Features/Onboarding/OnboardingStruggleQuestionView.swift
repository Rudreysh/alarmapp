import SwiftUI

struct OnboardingStruggleQuestionView: View {
    let onNext: () -> Void
    @State private var selectedOptionID: String = "a"

    private let tiimoPurple = Color(hex: "#7F77DD")

    private let options: [StruggleOption] = [
        .init(id: "a", text: "I sleep through alarms", emoji: "😴"),
        .init(id: "b", text: "I snooze too many times", emoji: "🔁"),
        .init(id: "c", text: "I wake up but can't get out of bed", emoji: "😶"),
        .init(id: "d", text: "I wake up on time but feel terrible", emoji: "😤"),
        .init(id: "e", text: "I just don't get enough sleep", emoji: "💤")
    ]

    var body: some View {
        OnboardingQuestionScaffold(
            title: "What's your biggest morning challenge?",
            options: options.map { QuestionOption(id: $0.id, text: $0.text, emoji: $0.emoji) },
            selectedOptionID: $selectedOptionID,
            selectedColor: tiimoPurple,
            questionIndex: 4,
            questionTotal: 30,
            onNext: onNext
        )
    }
}

private struct StruggleOption: Identifiable {
    let id: String
    let text: String
    let emoji: String
}
