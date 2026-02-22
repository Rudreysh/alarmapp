import SwiftUI

struct OnboardingSoundSelectionView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var viewModel = OnboardingSoundSelectionViewModel()
    let onNext: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

                Text("Choose your alarm sound")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.l) {
                        if viewModel.categories.isEmpty {
                            Text("No bundled sounds found. Ensure BundledSounds/ringtones is added to the app target.")
                                .bodyText()
                                .foregroundColor(Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.l)
                        } else {
                            CategoryPillsRow(categories: viewModel.categories, selected: viewModel.selectedCategory) { category in
                                viewModel.selectCategory(category)
                            }
                            .padding(.horizontal, Spacing.l)
                        }

                        if !viewModel.categories.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                Text(viewModel.selectedCategory.title)
                                    .cardTitle()
                                    .foregroundColor(Colors.textPrimary)
                                    .padding(.horizontal, Spacing.l)

                                SoundListCard(
                                    sounds: viewModel.soundsForSelectedCategory(),
                                    selectedId: viewModel.selectedSoundId,
                                    playingId: viewModel.nowPlayingSoundId,
                                    onSelect: { sound in
                                        viewModel.selectSoundOnly(sound)
                                        onboardingViewModel.setSelectedSound(sound)
                                    },
                                    onPlay: { sound in
                                        viewModel.tapSound(sound, volume: onboardingViewModel.state.selectedVolume)
                                        onboardingViewModel.setSelectedSound(sound)
                                    },
                                    onReloadNeeded: {
                                        viewModel.load()
                                    }
                                )
                                .padding(.horizontal, Spacing.l)
                            }
                        }
                    }
                    .padding(.bottom, Spacing.xl)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
        .onAppear {
            if viewModel.selectedSoundId == nil,
               let first = viewModel.soundsForSelectedCategory().first {
                viewModel.setInitialSelection(first)
                onboardingViewModel.setSelectedSound(first)
            }
        }
    }
}

private struct CategoryPillsRow: View {
    let categories: [SoundCategory]
    let selected: SoundCategory
    let onSelect: (SoundCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    let isSelected = category == selected
                    
                    Button(action: { onSelect(category) }) {
                        HStack(spacing: 6) {
                            if let emoji = category.emoji {
                                Text(emoji).font(.caption)
                            }
                            Text(category.title)
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
        }
    }

    private func pillTitle(_ category: SoundCategory) -> String {
        if let emoji = category.emoji {
            return "\(emoji) \(category.title)"
        }
        return category.title
    }
}

private struct SoundListCard: View {
    let sounds: [SoundAsset]
    let selectedId: SoundAsset.ID?
    let playingId: SoundAsset.ID?
    let onSelect: (SoundAsset) -> Void
    let onPlay: (SoundAsset) -> Void
    let onReloadNeeded: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sounds) { sound in
                if sound.category == .cloud {
                    OnboardingRemoteSoundRow(
                        sound: sound,
                        isSelected: sound.id == selectedId,
                        isPlaying: sound.id == playingId,
                        onSelect: { onSelect(sound) },
                        onPlay: { onPlay(sound) },
                        onReloadNeeded: onReloadNeeded
                    )
                } else {
                    OnboardingSoundRow(
                        title: sound.title,
                        isSelected: sound.id == selectedId,
                        isPlaying: sound.id == playingId,
                        onSelect: { onSelect(sound) },
                        onPlay: { onPlay(sound) }
                    )
                }

                if sound.id != sounds.last?.id {
                    Divider().background(Colors.cardStroke)
                }
            }
        }
        .padding(.vertical, Spacing.s)
        .background(Colors.cardSurface)
        .cornerRadius(Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}

private struct OnboardingSoundRow: View {
    let title: String
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Colors.accentTeal : Colors.textTertiary)
                    .font(.system(size: 22))

                Text(title)
                    .bodyText()
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)

            Button(action: onPlay) {
                ZStack {
                    if isPlaying {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .padding(.trailing, Spacing.l - 12)
        }
    }
}

private struct OnboardingRemoteSoundRow: View {
    let sound: SoundAsset
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void
    let onReloadNeeded: () -> Void
    
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0

    var body: some View {
        let isDownloaded = sound.fileURL.isFileURL
        
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Colors.accentTeal : Colors.textTertiary)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .bodyText()
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                    
                    if isDownloading {
                        Text("Downloading \(Int(downloadProgress * 100))%...")
                            .font(.caption2)
                            .foregroundColor(Colors.accentTeal)
                    } else if !isDownloaded {
                        Text("Download to select")
                            .font(.caption2)
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isDownloaded {
                    onSelect()
                } else {
                    Task { await performDownload(playAfter: false) }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)

            Button(action: {
                if isDownloaded {
                    onPlay()
                } else {
                    Task { await performDownload(playAfter: true) }
                }
            }) {
                ZStack {
                    if isDownloading {
                        ProgressView().tint(Colors.textSecondary)
                    } else if !isDownloaded {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    } else if isPlaying {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .padding(.trailing, Spacing.l - 12)
        }
    }
    
    private func performDownload(playAfter: Bool) async {
        guard !isDownloading, !sound.fileURL.isFileURL else { return }
        
        let assetManager = AssetManager.shared
        guard let remote = assetManager.remoteSounds.first(where: { $0.id == sound.id }) else { return }
        
        await MainActor.run { isDownloading = true }
        
        do {
            _ = try await assetManager.downloadAsset(from: remote.url, filename: remote.filename) { p in
                DispatchQueue.main.async { self.downloadProgress = p }
            }
            await MainActor.run {
                isDownloading = false
                onReloadNeeded()
                if playAfter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onPlay()
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onSelect()
                    }
                }
            }
        } catch {
            await MainActor.run { isDownloading = false }
        }
    }
}
