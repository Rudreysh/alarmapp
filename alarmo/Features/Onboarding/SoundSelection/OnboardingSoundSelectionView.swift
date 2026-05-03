import SwiftUI
import Combine

/// Onboarding sound selection screen.
///
/// This view intentionally reuses all of the production components from
/// `SoundPickerView` (CategoryPill, SoundRow, RemoteSoundRow, etc.) so that
/// the behaviour, playback, categories and UI are 100% identical.
struct OnboardingSoundSelectionView: View {
    private enum TopTab: Hashable, Identifiable {
        case category(SoundCategory)
        case downloadable(String)

        var id: String {
            switch self {
            case .category(let category): return "cat:\(category.id)"
            case .downloadable(let name): return "cloud:\(name.lowercased())"
            }
        }

        var title: String {
            switch self {
            case .category(let category): return category.title
            case .downloadable(let name): return name
            }
        }

        var emoji: String? {
            switch self {
            case .category(let category): return category.emoji
            case .downloadable: return nil
            }
        }
    }

    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var viewModel = OnboardingSoundSelectionViewModel()
    @ObservedObject private var soundPlayer = SoundPreviewPlayer.shared

    let onNext: () -> Void

    private var downloadableSections: [(category: String, sounds: [RemoteSound])] {
        viewModel.downloadableSections
    }

    private var topTabs: [TopTab] {
        var tabs: [TopTab] = [.category(.favorites), .category(.alarmTone), .category(.focus)]
        tabs += downloadableSections.map { .downloadable($0.category) }
        return tabs
    }

    private var currentCloudCategory: String {
        if let selected = viewModel.selectedCloudCategory,
           downloadableSections.contains(where: { $0.category == selected }) {
            return selected
        }
        return downloadableSections.first?.category ?? ""
    }

    private func isTopTabSelected(_ tab: TopTab) -> Bool {
        switch tab {
        case .category(let category):
            return viewModel.selectedCategory == category
        case .downloadable(let name):
            return viewModel.selectedCategory == .cloud && currentCloudCategory == name
        }
    }

    private func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    private func isCurrentPlayingResource(named title: String) -> Bool {
        guard let playing = soundPlayer.playingResourceName else { return false }
        return normalizedTitle(playing) == normalizedTitle(title)
    }

    private func isSoundPlaying(named title: String) -> Bool {
        soundPlayer.isPlaying && isCurrentPlayingResource(named: title)
    }

    private func isSoundBuffering(named title: String) -> Bool {
        soundPlayer.isBuffering && isCurrentPlayingResource(named: title)
    }

    private func isPlayingInCategory(_ tab: TopTab) -> Bool {
        guard soundPlayer.isPlaying else { return false }
        guard let playing = soundPlayer.playingResourceName else { return false }
        
        switch tab {
        case .category(let category):
            let allSounds = SoundCatalogRepository().loadAllSounds()
            if category == .alarmTone {
                if let playingAsset = allSounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) }) {
                    return playingAsset.category == .alarmTone || playingAsset.category == .loud || playingAsset.category == .classic
                }
            } else if category == .favorites {
                return allSounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) })?.isStarred == true
            } else {
                return allSounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) })?.category == category
            }
        case .downloadable(let name):
             if let cloudSound = AssetManager.shared.remoteSounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) }) {
                 return cloudSound.category.caseInsensitiveCompare(name) == .orderedSame
             }
        }
        return false
    }

    private func selectTopTab(_ tab: TopTab) {
        switch tab {
        case .category(let category):
            viewModel.selectCategory(category)
        case .downloadable(let name):
            viewModel.selectCategory(.cloud)
            viewModel.selectedCloudCategory = name
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Choose your alarm sound")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.s)
                    .accessibilityAddTraits(.isHeader)

                // ─── Progress header ──────────────────────────────────────
                ProgressHeader(step: 10, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, Spacing.s)

                // ─── Category pills ───────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(topTabs) { tab in
                            OnboardingTopTabPill(
                                title: tab.title,
                                emoji: tab.emoji,
                                isSelected: isTopTabSelected(tab),
                                isPlaying: isPlayingInCategory(tab)
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectTopTab(tab)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                }
                .padding(.bottom, Spacing.m)

                // ─── Sound list ───────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        soundListBody
                    }
                    .background(Colors.cardSurface.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, 100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // ─── Next button ───────────────────────────────────────────
            VStack {
                Spacer()
                PrimaryButton(title: "Next", style: .blueGlass) { onNext() }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
        }
        .onAppear {
            Task { await AssetManager.shared.fetchCatalog() }
            if viewModel.selectedSoundId == nil,
               let first = viewModel.soundsForSelectedCategory().first {
                viewModel.setInitialSelection(first)
                onboardingViewModel.setSelectedSound(first)
            }
        }
        .onDisappear { soundPlayer.stop() }
    }

    // MARK: - Sound list body (mirrors SoundPickerView exactly)

    @ViewBuilder
    private var soundListBody: some View {
        if viewModel.selectedCategory == .cloud {
            cloudSoundList
        } else if viewModel.selectedCategory == .favorites && viewModel.soundsForSelectedCategory().isEmpty {
            // Empty favorites placeholder
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.system(size: 40))
                    .foregroundColor(Colors.textTertiary)
                Text("No favorites yet")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                Text("Tap the star on any sound to add it to your favorites.")
                    .font(.subheadline)
                    .foregroundColor(Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 60)
        } else {
            localSoundList
        }
    }

    // ── Local / favourite sounds ──────────────────────────────────────────
    @ViewBuilder
    private var localSoundList: some View {
        let sounds = viewModel.soundsForSelectedCategory()
        if sounds.isEmpty && viewModel.selectedCategory != .favorites {
             VStack(spacing: 20) {
                 Text("No sounds found for this category.")
                     .foregroundColor(Colors.textSecondary)
                 Button("Refresh Catalog") {
                     Task { await AssetManager.shared.fetchCatalog() }
                 }
                 .font(.caption)
                 .foregroundColor(Colors.accentTeal)
             }
             .padding(.vertical, 40)
        } else {
            ForEach(sounds) { sound in
                // Determine if this is a remote asset not yet downloaded
                let isRemote = !sound.fileURL.isFileURL
                
                if isRemote {
                    // Render using RemoteSoundRow logic but adapted for SoundAsset
                    let remoteSound = RemoteSound(
                        id: sound.id,
                        filename: sound.fileURL.lastPathComponent,
                        title: sound.title,
                        category: viewModel.selectedCategory.title,
                        url: sound.fileURL,
                        isPremium: false
                    )
                    
                    RemoteSoundRow(
                        remoteSound: remoteSound,
                        isSelected: viewModel.selectedSoundId == sound.id,
                        isPlaying: isSoundPlaying(named: sound.title),
                        isBuffering: isSoundBuffering(named: sound.title),
                        isStarred: sound.isStarred,
                        onSelect: {
                            if let url = AssetManager.shared.localURL(for: sound.fileURL.lastPathComponent) {
                                let asset = SoundAsset(id: sound.id, title: sound.title, fileURL: url, category: sound.category)
                                viewModel.tapSound(asset, volume: onboardingViewModel.state.selectedVolume)
                                onboardingViewModel.setSelectedSound(asset)
                            }
                        },
                        onPreview: {
                            if isSoundPlaying(named: sound.title) {
                                soundPlayer.stop()
                            } else {
                                soundPlayer.playStreamURL(sound.fileURL, resourceName: sound.title, volume: onboardingViewModel.state.selectedVolume)
                            }
                        },
                        onToggleStar: {
                            viewModel.toggleStar(sound)
                        }
                    )
                } else {
                    SoundRow(
                        sound: sound,
                        isSelected: viewModel.selectedSoundId == sound.id,
                        isPlaying: isSoundPlaying(named: sound.title),
                        isBuffering: isSoundBuffering(named: sound.title)
                    ) { action in
                        switch action {
                        case .select:
                            viewModel.selectSoundOnly(sound)
                            onboardingViewModel.setSelectedSound(sound)
                        case .play:
                            viewModel.tapSound(sound, volume: onboardingViewModel.state.selectedVolume)
                            onboardingViewModel.setSelectedSound(sound)
                        case .toggleStar:
                            viewModel.toggleStar(sound)
                        }
                    }
                }

                if sound.id != sounds.last?.id {
                    Divider()
                        .background(Colors.cardStroke)
                        .padding(.leading, 56)
                }
            }
        }
    }

    // ── Cloud / downloadable sounds ───────────────────────────────────────
    @ViewBuilder
    private var cloudSoundList: some View {
        if AssetManager.shared.isLoadingCatalog {
            ProgressView("Loading sounds…").padding()
        } else if viewModel.downloadableSections.isEmpty {
            VStack(spacing: 12) {
                Text("No downloadable sounds found.")
                    .foregroundColor(Colors.textSecondary)
                Button("Refresh Catalog") {
                    Task { await AssetManager.shared.fetchCatalog() }
                }
                .font(.caption)
                .foregroundColor(Colors.accentTeal)
            }
            .padding()
        } else {
            cloudSectionRows
        }
    }

    /// Separate property to avoid Swift ViewBuilder type-inference bugs with
    /// let-bindings + ForEach inside nested else{} blocks.
    @ViewBuilder
    private var cloudSectionRows: some View {
        if let section = downloadableSections.first(where: { $0.category == currentCloudCategory }) {
            ForEach(section.sounds) { remoteSound in
                cloudSoundRowView(for: remoteSound)
            }
        }
    }

    /// Renders a single RemoteSoundRow + divider for a cloud sound.
    @ViewBuilder
    private func cloudSoundRowView(for remoteSound: RemoteSound) -> some View {
        let isStarred = viewModel.soundsForSelectedCategory()
            .first(where: { $0.id == remoteSound.id })?.isStarred ?? false
        RemoteSoundRow(
            remoteSound: remoteSound,
            isSelected: viewModel.selectedSoundId == remoteSound.id,
            isPlaying: isSoundPlaying(named: remoteSound.title),
            isBuffering: isSoundBuffering(named: remoteSound.title),
            isStarred: isStarred,
            onSelect: {
                if let url = AssetManager.shared.localURL(for: remoteSound.filename) {
                    let asset = SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud)
                    viewModel.tapSound(asset, volume: onboardingViewModel.state.selectedVolume)
                    onboardingViewModel.setSelectedSound(asset)
                }
            },
            onPreview: {
                if isSoundPlaying(named: remoteSound.title) {
                    soundPlayer.stop()
                } else {
                    soundPlayer.playStreamURL(remoteSound.url, resourceName: remoteSound.title, volume: onboardingViewModel.state.selectedVolume)
                }
            },
            onToggleStar: {
                let asset = SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: remoteSound.url, category: .cloud, isStarred: isStarred)
                viewModel.toggleStar(asset)
            }
        )

        Divider()
            .background(Colors.cardStroke)
            .padding(.leading, 16)
    }
}

private struct OnboardingTopTabPill: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white : Colors.accentTeal)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Colors.accentTeal : Colors.cardSurface)
            .foregroundColor(isSelected ? .white : Colors.textPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}
