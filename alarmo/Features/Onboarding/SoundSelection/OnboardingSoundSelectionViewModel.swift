import Foundation
import Combine

final class OnboardingSoundSelectionViewModel: ObservableObject {
    @Published private(set) var categories: [SoundCategory] = []
    @Published private(set) var soundsByCategory: [SoundCategory: [SoundAsset]] = [:]
    @Published var selectedCategory: SoundCategory = .loud
    @Published private(set) var selectedSoundId: SoundAsset.ID?
    @Published private(set) var nowPlayingSoundId: SoundAsset.ID?

    private let repository: SoundCatalogRepositoryProtocol
    private let audioPlayer: AudioPreviewPlayerProtocol

    init(repository: SoundCatalogRepositoryProtocol = SoundCatalogRepository(),
         audioPlayer: AudioPreviewPlayerProtocol = AudioPreviewPlayer()) {
        self.repository = repository
        self.audioPlayer = audioPlayer
        load()
    }

    func load() {
        do {
            let sounds = try repository.loadBundledSounds()
            let grouped = Dictionary(grouping: sounds, by: { $0.category })
            soundsByCategory = grouped
            categories = SoundCategory.order.filter { grouped[$0] != nil } + grouped.keys.filter { !SoundCategory.order.contains($0) }
            if let first = categories.first {
                selectedCategory = first
            }
        } catch {
            categories = []
            soundsByCategory = [:]
        }
    }

    func selectCategory(_ category: SoundCategory) {
        selectedCategory = category
    }

    func tapSound(_ sound: SoundAsset, volume: Float) {
        if nowPlayingSoundId == sound.id {
            audioPlayer.stop()
            nowPlayingSoundId = nil
        } else {
            audioPlayer.play(url: sound.fileURL, volume: volume, fadeIn: false)
            nowPlayingSoundId = sound.id
        }
        selectedSoundId = sound.id
    }

    func stopPlayback() {
        audioPlayer.stop()
        nowPlayingSoundId = nil
    }

    func soundsForSelectedCategory() -> [SoundAsset] {
        soundsByCategory[selectedCategory] ?? []
    }
}
