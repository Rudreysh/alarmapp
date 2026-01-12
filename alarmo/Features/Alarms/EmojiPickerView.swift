import SwiftUI

struct EmojiPickerView: View {
    let onSelect: (String) -> Void

    private let emojis = ["🌞", "😀", "😴", "🔥", "💪", "🚀", "🎯", "⭐️", "🍀", "🎵", "📚", "🏃‍♂️"]

    var body: some View {
        VStack(spacing: Spacing.l) {
            Text("Choose an emoji")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Colors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { onSelect(emoji) }) {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 56, height: 56)
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(Spacing.l)
        .background(Colors.bgPrimary)
    }
}
