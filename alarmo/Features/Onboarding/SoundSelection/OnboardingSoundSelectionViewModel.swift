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
    private var cancellables = Set<AnyCancellable>()

    init(repository: SoundCatalogRepositoryProtocol = SoundCatalogRepository(),
         audioPlayer: AudioPreviewPlayerProtocol = AudioPreviewPlayer.shared) {
        self.repository = repository
        self.audioPlayer = audioPlayer
        load()

        // Listen for remote updates
        AssetManager.shared.$remoteSounds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    func load() {
        let sounds = repository.loadAllSounds()
        var grouped = Dictionary(grouping: sounds, by: { $0.category })
        
        let remoteSounds = AssetManager.shared.remoteSounds.map { remote in
            let fileURL = AssetManager.shared.localURL(for: remote.filename) ?? remote.url
            return SoundAsset(id: remote.id, title: remote.title, fileURL: fileURL, category: .cloud)
        }
        
        let remoteIDs = Set(remoteSounds.map { $0.id })
        for (cat, catSounds) in grouped {
            grouped[cat] = catSounds.filter { !remoteIDs.contains($0.id) }
        }
        
        grouped[.cloud] = remoteSounds
        
        soundsByCategory = grouped
        categories = SoundCategory.order
        if let first = categories.first {
            selectedCategory = first
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

    func selectSoundOnly(_ sound: SoundAsset) {
        selectedSoundId = sound.id
        audioPlayer.stop()
        nowPlayingSoundId = nil
    }

    func setInitialSelection(_ sound: SoundAsset) {
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
