import SwiftUI

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
    let onNext: () -> Void

    private var downloadableSections: [(category: String, sounds: [RemoteSound])] {
        viewModel.downloadableSections
    }

    private var topTabs: [TopTab] {
        var tabs: [TopTab] = [.category(.favorites), .category(.alarmTone)]
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
                // ─── Progress header ──────────────────────────────────────
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.s)

                Text("Choose your alarm sound")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.s)
                    .accessibilityAddTraits(.isHeader)

                // ─── Category pills ───────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(topTabs) { tab in
                            OnboardingTopTabPill(
                                title: tab.title,
                                emoji: tab.emoji,
                                isSelected: isTopTabSelected(tab)
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

            // ─── Next button ───────────────────────────────────────────
            VStack {
                Spacer()
                PrimaryButton(title: "Next", style: .blueGlass) { onNext() }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
        }
        .onAppear {
            if AssetManager.shared.remoteSounds.isEmpty {
                Task { await AssetManager.shared.fetchCatalog() }
            }
            if viewModel.selectedSoundId == nil,
               let first = viewModel.soundsForSelectedCategory().first {
                viewModel.setInitialSelection(first)
                onboardingViewModel.setSelectedSound(first)
            }
        }
        .onDisappear { viewModel.stopPlayback() }
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
        ForEach(sounds) { sound in
            SoundRow(
                sound: sound,
                isSelected: viewModel.selectedSoundId == sound.id,
                isPlaying: viewModel.soundPlayer.isPlaying && viewModel.soundPlayer.playingResourceName == sound.title,
                isBuffering: viewModel.soundPlayer.isBuffering && viewModel.soundPlayer.playingResourceName == sound.title
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

            if sound.id != sounds.last?.id {
                Divider()
                    .background(Colors.cardStroke)
                    .padding(.leading, 56)
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
            isPlaying: viewModel.soundPlayer.isPlaying && viewModel.soundPlayer.playingResourceName == remoteSound.title,
            isBuffering: viewModel.soundPlayer.isBuffering && viewModel.soundPlayer.playingResourceName == remoteSound.title,
            isStarred: isStarred,
            onSelect: {
                if let url = AssetManager.shared.localURL(for: remoteSound.filename) {
                    let asset = SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud)
                    viewModel.selectSoundOnly(asset)
                    onboardingViewModel.setSelectedSound(asset)
                }
            },
            onPreview: {
                if viewModel.soundPlayer.isPlaying && viewModel.soundPlayer.playingResourceName == remoteSound.title {
                    viewModel.soundPlayer.stop()
                } else {
                    viewModel.soundPlayer.playStreamURL(remoteSound.url, resourceName: remoteSound.title, volume: onboardingViewModel.state.selectedVolume)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
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
