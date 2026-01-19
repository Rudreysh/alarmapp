import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (String) -> Void

    private let emojis = ["🌞", "😀", "😴", "🔥", "💪", "🚀", "🎯", "⭐️", "🍀", "🎵", "📚", "🏃‍♂️"]

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack {
                Spacer()
                Text("Choose an emoji")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                
                Button(action: { 
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(Colors.textSecondary)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .padding(.bottom, Spacing.s)

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
