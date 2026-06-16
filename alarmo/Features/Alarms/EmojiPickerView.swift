import SwiftUI
import UIKit

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let initialEmoji: String
    let onSelect: (String) -> Void

    @State private var customEmojiText: String
    @State private var focusEmojiField = false

    init(initialEmoji: String = "", onSelect: @escaping (String) -> Void) {
        self.initialEmoji = initialEmoji
        self.onSelect = onSelect
        _customEmojiText = State(initialValue: initialEmoji)
    }

    private var typedEmoji: String? {
        normalizedEmoji(from: customEmojiText)
    }

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack {
                Text("Choose Emoji")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Button("Remove") {
                    onSelect("")
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.accentRed)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Colors.cardSurface)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 16) {
                Text(typedEmoji ?? fallbackPreviewEmoji)
                    .font(.system(size: 56))
                    .frame(width: 116, height: 116)
                    .background(Colors.cardSurface)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Emoji")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    HStack(spacing: 8) {
                        Image(systemName: "face.smiling")
                            .foregroundColor(Colors.textSecondary)

                        EmojiKeyboardTextField(
                            text: $customEmojiText,
                            placeholder: "Type any emoji with keyboard",
                            isFirstResponder: focusEmojiField,
                            textColor: UIColor(Colors.textPrimary)
                        )
                        .frame(height: 24)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Colors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("The emoji keyboard opens automatically. The last emoji you type is used.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Colors.textSecondary)
                }
            }

            HStack(spacing: 12) {
                Button("Clear") {
                    customEmojiText = ""
                    focusEmojiField = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focusEmojiField = true
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Colors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Use") {
                    guard let emoji = typedEmoji else { return }
                    onSelect(emoji)
                    dismiss()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(typedEmoji == nil ? Colors.textSecondary.opacity(0.3) : Colors.accentTeal)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(typedEmoji == nil)
            }
        }
        .padding(Spacing.l)
        .background(Colors.bgPrimary)
        .onAppear {
            focusEmojiField = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusEmojiField = true
            }
        }
    }

    private var fallbackPreviewEmoji: String {
        initialEmoji.isEmpty ? defaultAlarmEmoji : initialEmoji
    }

    private func normalizedEmoji(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }
}

private struct EmojiKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isFirstResponder: Bool
    let textColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> ForcedEmojiTextField {
        let textField = ForcedEmojiTextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.textColor = textColor
        textField.tintColor = textColor
        textField.font = .systemFont(ofSize: 16, weight: .medium)
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.keyboardAppearance = .default
        textField.returnKeyType = .done
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: ForcedEmojiTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        uiView.textColor = textColor
        uiView.tintColor = textColor

        if isFirstResponder, uiView.window != nil, uiView.isFirstResponder == false {
            uiView.becomeFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textDidChange(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

private final class ForcedEmojiTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        let emojiMode = UITextInputMode.activeInputModes.first { inputMode in
            inputMode.primaryLanguage == "emoji"
        }
        return emojiMode ?? super.textInputMode
    }
}
