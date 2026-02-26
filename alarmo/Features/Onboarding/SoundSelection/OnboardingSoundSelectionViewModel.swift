import Foundation
import Combine
import UIKit

final class OnboardingSoundSelectionViewModel: ObservableObject {
    @Published private(set) var categories: [SoundCategory] = []
    @Published private(set) var soundsByCategory: [SoundCategory: [SoundAsset]] = [:]
    @Published var selectedCategory: SoundCategory = .alarmTone
    @Published private(set) var selectedSoundId: SoundAsset.ID?
    @Published var selectedCloudCategory: String? = nil

    var downloadableSections: [(category: String, sounds: [RemoteSound])] {
        AssetManager.shared.remoteSoundsByCategory.filter { $0.category.lowercased() != "alarm" }
    }

    private let repository: SoundCatalogRepositoryProtocol
    /// Exposed so the View can bind directly to isPlaying / isBuffering / playingResourceName
    /// without going through Published proxies — this is how SoundPickerView works.
    let soundPlayer: SoundPreviewPlayer
    private var cancellables = Set<AnyCancellable>()

    init(repository: SoundCatalogRepositoryProtocol = SoundCatalogRepository(),
         soundPlayer: SoundPreviewPlayer = SoundPreviewPlayer.shared) {
        self.repository = repository
        self.soundPlayer = soundPlayer
        load()

        // Reload when remote catalog arrives
        AssetManager.shared.$remoteSounds
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    // MARK: - Data

    func load() {
        let sounds = repository.loadAllSounds()
        let grouped = Dictionary(grouping: sounds, by: { $0.category })

        soundsByCategory = grouped
        categories = SoundCategory.order

        // Only reset category to first when there is truly no valid selection
        if !categories.contains(selectedCategory) {
            selectedCategory = categories.first ?? .alarmTone
        }

        if selectedCloudCategory == nil {
            selectedCloudCategory = downloadableSections.first?.category
        }
    }

    func soundsForSelectedCategory() -> [SoundAsset] {
        if selectedCategory == .cloud {
            let cat = selectedCloudCategory ?? downloadableSections.first?.category ?? ""
            if let section = downloadableSections.first(where: { $0.category == cat }) {
                return section.sounds.map { remote in
                    let url = AssetManager.shared.localURL(for: remote.filename) ?? remote.url
                    let isStarred = repository.loadAllSounds().first(where: { $0.id == remote.id })?.isStarred ?? false
                    return SoundAsset(id: remote.id, title: remote.title, fileURL: url, category: .cloud, isStarred: isStarred)
                }
            }
        }
        if selectedCategory == .favorites {
            return repository.loadAllSounds().filter { $0.isStarred }
        }
        if selectedCategory == .alarmTone {
            return repository.loadAllSounds().filter {
                $0.category == .alarmTone || $0.category == .loud || $0.category == .classic
            }
        }
        return soundsByCategory[selectedCategory] ?? []
    }

    // MARK: - Actions

    func selectCategory(_ category: SoundCategory) {
        selectedCategory = category
    }

    /// Plays or stops a sound — mirrors SoundPickerView.togglePlay exactly.
    func tapSound(_ sound: SoundAsset, volume: Float) {
        if soundPlayer.isPlaying && soundPlayer.playingResourceName == sound.title {
            soundPlayer.stop()
        } else {
            soundPlayer.play(resourceName: sound.title, volume: volume)
        }
        selectedSoundId = sound.id
    }

    func selectSoundOnly(_ sound: SoundAsset) {
        selectedSoundId = sound.id
        soundPlayer.stop()
    }

    func setInitialSelection(_ sound: SoundAsset) {
        selectedSoundId = sound.id
    }

    func stopPlayback() {
        soundPlayer.stop()
    }

    func toggleStar(_ sound: SoundAsset) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        repository.toggleStar(soundID: sound.id)
        load()
        objectWillChange.send()
    }
}
