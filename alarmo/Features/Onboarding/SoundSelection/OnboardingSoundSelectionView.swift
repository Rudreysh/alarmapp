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
                            playingId: viewModel.nowPlayingSoundId
                        ) { sound in
                            viewModel.tapSound(sound, volume: onboardingViewModel.state.selectedVolume)
                            onboardingViewModel.setSelectedSound(sound)
                        }
                        .padding(.horizontal, Spacing.l)
                    }
                }

                Spacer()
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
            HStack(spacing: Spacing.s) {
                ForEach(categories) { category in
                    let isSelected = category == selected
                    Text(pillTitle(category))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(isSelected ? Colors.bgSecondary : Colors.cardSurface)
                        .clipShape(Capsule())
                        .onTapGesture { onSelect(category) }
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

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sounds) { sound in
                OnboardingSoundRow(
                    title: sound.title,
                    isSelected: sound.id == selectedId,
                    isPlaying: sound.id == playingId
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelect(sound) }

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

    var body: some View {
        HStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Colors.accentTeal : Colors.textTertiary, lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Colors.accentTeal)
                        .frame(width: 8, height: 8)
                }
            }

            Text(title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isPlaying {
                WaveformAnimation(color: Colors.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }
}
