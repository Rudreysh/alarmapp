import SwiftUI

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    @State private var searchText: String = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    private var filteredOptions: [EmojiOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return emojiOptions }
        return emojiOptions.filter { option in
            option.emoji.contains(query) || option.keywords.contains(where: { $0.contains(query) })
        }
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack {
                Text("Choose Emoji")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
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

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Colors.textSecondary)
                TextField("Search emoji", text: $searchText)
                    .foregroundColor(Colors.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if filteredOptions.isEmpty {
                Spacer()
                Text("No emoji found")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(filteredOptions.enumerated()), id: \.offset) { _, option in
                            Button {
                                onSelect(option.emoji)
                                dismiss()
                            } label: {
                                Text(option.emoji)
                                    .font(.system(size: 30))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Colors.cardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Colors.cardStroke, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(Spacing.l)
        .background(Colors.bgPrimary)
    }
}

private struct EmojiOption {
    let emoji: String
    let keywords: [String]
}

private let emojiOptions: [EmojiOption] = [
    .init(emoji: "😀", keywords: ["smile", "happy", "joy"]),
    .init(emoji: "😃", keywords: ["smile", "happy", "grin"]),
    .init(emoji: "😄", keywords: ["smile", "happy", "grin"]),
    .init(emoji: "😁", keywords: ["smile", "teeth", "happy"]),
    .init(emoji: "😆", keywords: ["laugh", "funny", "happy"]),
    .init(emoji: "😅", keywords: ["sweat", "relief", "smile"]),
    .init(emoji: "😂", keywords: ["laugh", "funny", "tears"]),
    .init(emoji: "🤣", keywords: ["rolling", "laugh", "funny"]),
    .init(emoji: "😊", keywords: ["blush", "smile", "cute"]),
    .init(emoji: "🙂", keywords: ["smile", "calm", "friendly"]),
    .init(emoji: "😉", keywords: ["wink", "playful", "flirt"]),
    .init(emoji: "😍", keywords: ["love", "heart", "eyes"]),
    .init(emoji: "😘", keywords: ["kiss", "love", "heart"]),
    .init(emoji: "😗", keywords: ["kiss", "love"]),
    .init(emoji: "😙", keywords: ["kiss", "happy"]),
    .init(emoji: "😚", keywords: ["kiss", "closed eyes"]),
    .init(emoji: "😋", keywords: ["yum", "food", "taste"]),
    .init(emoji: "😛", keywords: ["tongue", "playful"]),
    .init(emoji: "😜", keywords: ["wink", "tongue", "fun"]),
    .init(emoji: "🤪", keywords: ["zany", "crazy", "fun"]),
    .init(emoji: "🤨", keywords: ["skeptical", "doubt"]),
    .init(emoji: "🧐", keywords: ["curious", "inspect"]),
    .init(emoji: "🤓", keywords: ["nerd", "study", "smart"]),
    .init(emoji: "😎", keywords: ["cool", "sunglasses"]),
    .init(emoji: "🥳", keywords: ["party", "celebrate"]),
    .init(emoji: "😏", keywords: ["smirk", "confident"]),
    .init(emoji: "😒", keywords: ["unamused", "annoyed"]),
    .init(emoji: "😞", keywords: ["sad", "down"]),
    .init(emoji: "😔", keywords: ["sad", "thoughtful"]),
    .init(emoji: "😟", keywords: ["worried", "concern"]),
    .init(emoji: "😕", keywords: ["confused", "uncertain"]),
    .init(emoji: "🙁", keywords: ["sad", "frown"]),
    .init(emoji: "☹️", keywords: ["sad", "frown"]),
    .init(emoji: "😣", keywords: ["struggle", "tense"]),
    .init(emoji: "😖", keywords: ["frustrated", "sad"]),
    .init(emoji: "😫", keywords: ["tired", "stressed"]),
    .init(emoji: "😩", keywords: ["weary", "tired"]),
    .init(emoji: "🥺", keywords: ["pleading", "cute"]),
    .init(emoji: "😢", keywords: ["cry", "sad"]),
    .init(emoji: "😭", keywords: ["cry", "tears"]),
    .init(emoji: "😤", keywords: ["steam", "angry", "proud"]),
    .init(emoji: "😠", keywords: ["angry", "mad"]),
    .init(emoji: "😡", keywords: ["angry", "rage"]),
    .init(emoji: "🤯", keywords: ["mind blown", "shock"]),
    .init(emoji: "😳", keywords: ["surprised", "embarrassed"]),
    .init(emoji: "🥶", keywords: ["cold", "freeze"]),
    .init(emoji: "🥵", keywords: ["hot", "heat"]),
    .init(emoji: "😱", keywords: ["scream", "fear"]),
    .init(emoji: "😨", keywords: ["scared", "fear"]),
    .init(emoji: "😰", keywords: ["anxious", "sweat"]),
    .init(emoji: "😥", keywords: ["relief", "sad"]),
    .init(emoji: "😓", keywords: ["sweat", "stress"]),
    .init(emoji: "🤗", keywords: ["hug", "care"]),
    .init(emoji: "🤔", keywords: ["think", "hmm"]),
    .init(emoji: "🫡", keywords: ["salute", "respect"]),
    .init(emoji: "🤭", keywords: ["oops", "giggle"]),
    .init(emoji: "🤫", keywords: ["quiet", "shh"]),
    .init(emoji: "🤥", keywords: ["lie", "nose"]),
    .init(emoji: "😶‍🌫️", keywords: ["dizzy", "fog"]),
    .init(emoji: "😴", keywords: ["sleep", "tired"]),
    .init(emoji: "🤤", keywords: ["drool", "hungry"]),
    .init(emoji: "🤢", keywords: ["sick", "nausea"]),
    .init(emoji: "🤮", keywords: ["vomit", "sick"]),
    .init(emoji: "🤧", keywords: ["sneeze", "cold"]),
    .init(emoji: "😷", keywords: ["mask", "health"]),
    .init(emoji: "🤒", keywords: ["fever", "sick"]),
    .init(emoji: "🤕", keywords: ["injured", "bandage"]),
    .init(emoji: "👍", keywords: ["thumbs up", "ok", "good"]),
    .init(emoji: "👎", keywords: ["thumbs down", "bad"]),
    .init(emoji: "👏", keywords: ["clap", "applause"]),
    .init(emoji: "🙌", keywords: ["celebrate", "hooray"]),
    .init(emoji: "🙏", keywords: ["pray", "thanks"]),
    .init(emoji: "🤝", keywords: ["deal", "handshake"]),
    .init(emoji: "💪", keywords: ["strong", "gym", "fitness"]),
    .init(emoji: "🫶", keywords: ["heart hands", "love"]),
    .init(emoji: "🫵", keywords: ["you", "point"]),
    .init(emoji: "👀", keywords: ["look", "watch"]),
    .init(emoji: "🤳", keywords: ["selfie", "phone"]),
    .init(emoji: "❤️", keywords: ["heart", "love"]),
    .init(emoji: "🧡", keywords: ["orange heart", "love"]),
    .init(emoji: "💛", keywords: ["yellow heart", "love"]),
    .init(emoji: "💚", keywords: ["green heart", "love"]),
    .init(emoji: "💙", keywords: ["blue heart", "love"]),
    .init(emoji: "💜", keywords: ["purple heart", "love"]),
    .init(emoji: "🖤", keywords: ["black heart", "love"]),
    .init(emoji: "🤍", keywords: ["white heart", "love"]),
    .init(emoji: "🤎", keywords: ["brown heart", "love"]),
    .init(emoji: "💖", keywords: ["sparkle heart", "love"]),
    .init(emoji: "💯", keywords: ["hundred", "perfect"]),
    .init(emoji: "✨", keywords: ["sparkles", "magic"]),
    .init(emoji: "⭐️", keywords: ["star", "favorite"]),
    .init(emoji: "🌟", keywords: ["glowing star", "favorite"]),
    .init(emoji: "🔥", keywords: ["fire", "hot", "streak"]),
    .init(emoji: "⏰", keywords: ["alarm", "clock", "time"]),
    .init(emoji: "⌚️", keywords: ["watch", "time"]),
    .init(emoji: "📱", keywords: ["phone", "mobile"]),
    .init(emoji: "💻", keywords: ["laptop", "work"]),
    .init(emoji: "🖥️", keywords: ["computer", "desktop"]),
    .init(emoji: "⌨️", keywords: ["keyboard", "type"]),
    .init(emoji: "🖱️", keywords: ["mouse", "computer"]),
    .init(emoji: "🎧", keywords: ["headphones", "music"]),
    .init(emoji: "🎵", keywords: ["music", "note"]),
    .init(emoji: "🎶", keywords: ["music", "notes"]),
    .init(emoji: "📚", keywords: ["books", "study"]),
    .init(emoji: "📖", keywords: ["book", "read"]),
    .init(emoji: "📝", keywords: ["notes", "write"]),
    .init(emoji: "✏️", keywords: ["pencil", "write"]),
    .init(emoji: "📌", keywords: ["pin", "important"]),
    .init(emoji: "📎", keywords: ["paperclip", "attach"]),
    .init(emoji: "📦", keywords: ["box", "package"]),
    .init(emoji: "🔑", keywords: ["key", "lock"]),
    .init(emoji: "🧠", keywords: ["brain", "focus"]),
    .init(emoji: "💡", keywords: ["idea", "light"]),
    .init(emoji: "🔋", keywords: ["battery", "energy"]),
    .init(emoji: "⚡️", keywords: ["lightning", "energy", "quick"]),
    .init(emoji: "🔔", keywords: ["bell", "notification"]),
    .init(emoji: "🎁", keywords: ["gift", "present"]),
    .init(emoji: "🏆", keywords: ["trophy", "win"]),
    .init(emoji: "🥇", keywords: ["gold", "first"]),
    .init(emoji: "🥈", keywords: ["silver", "second"]),
    .init(emoji: "🥉", keywords: ["bronze", "third"]),
    .init(emoji: "⚽️", keywords: ["soccer", "sport"]),
    .init(emoji: "🏀", keywords: ["basketball", "sport"]),
    .init(emoji: "🎾", keywords: ["tennis", "sport"]),
    .init(emoji: "🏋️‍♂️", keywords: ["gym", "workout"]),
    .init(emoji: "🏃‍♂️", keywords: ["run", "cardio"]),
    .init(emoji: "🧘‍♀️", keywords: ["meditate", "calm"]),
    .init(emoji: "🚴‍♂️", keywords: ["bike", "cycle"]),
    .init(emoji: "☕️", keywords: ["coffee", "drink"]),
    .init(emoji: "🍵", keywords: ["tea", "drink"]),
    .init(emoji: "🥤", keywords: ["drink", "juice"]),
    .init(emoji: "🍎", keywords: ["apple", "fruit"]),
    .init(emoji: "🍌", keywords: ["banana", "fruit"]),
    .init(emoji: "🍕", keywords: ["pizza", "food"]),
    .init(emoji: "🍔", keywords: ["burger", "food"]),
    .init(emoji: "🥗", keywords: ["salad", "food"]),
    .init(emoji: "🍪", keywords: ["cookie", "snack"]),
    .init(emoji: "🌞", keywords: ["sun", "morning"]),
    .init(emoji: "🌤️", keywords: ["sun", "weather"]),
    .init(emoji: "⛅️", keywords: ["cloud", "weather"]),
    .init(emoji: "🌧️", keywords: ["rain", "weather"]),
    .init(emoji: "❄️", keywords: ["snow", "cold"]),
    .init(emoji: "🌈", keywords: ["rainbow", "color"]),
    .init(emoji: "🌙", keywords: ["moon", "night"]),
    .init(emoji: "🌍", keywords: ["earth", "world"]),
    .init(emoji: "🌱", keywords: ["plant", "grow"]),
    .init(emoji: "🌳", keywords: ["tree", "nature"]),
    .init(emoji: "🌸", keywords: ["flower", "spring"]),
    .init(emoji: "🍀", keywords: ["luck", "clover"]),
    .init(emoji: "🚗", keywords: ["car", "drive"]),
    .init(emoji: "🚌", keywords: ["bus", "travel"]),
    .init(emoji: "🚆", keywords: ["train", "travel"]),
    .init(emoji: "✈️", keywords: ["plane", "travel"]),
    .init(emoji: "🏠", keywords: ["home", "house"]),
    .init(emoji: "🏢", keywords: ["office", "building"]),
    .init(emoji: "🏫", keywords: ["school", "study"]),
    .init(emoji: "✅", keywords: ["check", "done"]),
    .init(emoji: "❌", keywords: ["cross", "wrong"]),
    .init(emoji: "⚠️", keywords: ["warning", "alert"]),
    .init(emoji: "🚫", keywords: ["blocked", "no"]),
    .init(emoji: "🔒", keywords: ["lock", "secure"]),
    .init(emoji: "🔓", keywords: ["unlock", "open"]),
    .init(emoji: "🛡️", keywords: ["shield", "protect"]),
    .init(emoji: "📈", keywords: ["growth", "chart"]),
    .init(emoji: "📉", keywords: ["down", "chart"]),
    .init(emoji: "🗓️", keywords: ["calendar", "schedule"]),
    .init(emoji: "📅", keywords: ["date", "calendar"]),
    .init(emoji: "⏳", keywords: ["hourglass", "waiting"]),
    .init(emoji: "⌛️", keywords: ["time", "hourglass"]),
    .init(emoji: "🎯", keywords: ["target", "goal"]),
    .init(emoji: "🚀", keywords: ["rocket", "launch"]),
    .init(emoji: "🐶", keywords: ["dog", "pet"]),
    .init(emoji: "🐱", keywords: ["cat", "pet"]),
    .init(emoji: "🐼", keywords: ["panda", "animal"]),
    .init(emoji: "🐸", keywords: ["frog", "animal"]),
    .init(emoji: "🐵", keywords: ["monkey", "animal"]),
    .init(emoji: "🦁", keywords: ["lion", "animal"]),
    .init(emoji: "🐯", keywords: ["tiger", "animal"]),
    .init(emoji: "🦊", keywords: ["fox", "animal"]),
    .init(emoji: "🐻", keywords: ["bear", "animal"]),
    .init(emoji: "🦄", keywords: ["unicorn", "magic"])
]
