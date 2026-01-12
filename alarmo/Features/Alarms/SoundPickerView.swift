import SwiftUI

struct SoundPickerView: View {
    @Binding var selectedSound: String

    @Environment(\.dismiss) private var dismiss
    @State private var sounds: [SoundAsset] = []
    private let repository = SoundCatalogRepository()
    private let audioPlayer = AudioPreviewPlayer()

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.m) {
                HStack {
                    Spacer()
                    Text("Sound")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                List {
                    ForEach(sounds) { sound in
                        HStack {
                        Button(action: {
                            selectedSound = sound.title
                            audioPlayer.play(url: sound.fileURL, volume: 0.9, fadeIn: false)
                        }) {
                                Image(systemName: selectedSound == sound.title ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedSound == sound.title ? Colors.accentTeal : Colors.textTertiary)
                            }
                            Text(sound.title)
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                            Button(action: {
                                audioPlayer.play(url: sound.fileURL, volume: 0.9, fadeIn: false)
                            }) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .listRowBackground(Colors.bgPrimary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            sounds = (try? repository.loadBundledSounds()) ?? []
            if let first = sounds.first, !sounds.contains(where: { $0.title == selectedSound }) {
                selectedSound = first.title
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}
