import SwiftUI

struct OnboardingSoundSelectionView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    let onNext: () -> Void

    @State private var selectedSoundName: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // Reuse the exact picker used in Create/Edit Alarm.
            SoundPickerView(selectedSound: $selectedSoundName)

            PrimaryButton(title: "Next", style: .blueGlass) {
                syncSelectionBackToOnboarding()
                onNext()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .onAppear {
            if selectedSoundName.isEmpty {
                selectedSoundName = onboardingViewModel.state.selectedSoundName ?? "Cockpit Alert"
            }
            syncSelectionBackToOnboarding()
        }
        .onChange(of: selectedSoundName) { _, _ in
            syncSelectionBackToOnboarding()
        }
    }

    private func syncSelectionBackToOnboarding() {
        let trimmed = selectedSoundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = normalize(trimmed)
        let repository = SoundCatalogRepository()
        let allLocal = repository.loadAllSounds()

        if let local = allLocal.first(where: { normalize($0.title) == normalized }) {
            onboardingViewModel.setSelectedSound(local)
            return
        }

        if let remote = AssetManager.shared.remoteSounds.first(where: { normalize($0.title) == normalized }) {
            let localURL = AssetManager.shared.localURL(for: remote.filename) ?? remote.url
            let category: SoundCategory = AssetManager.shared.localURL(for: remote.filename) != nil ? .downloads : .cloud
            let fallback = SoundAsset(id: remote.id, title: remote.title, fileURL: localURL, category: category)
            onboardingViewModel.setSelectedSound(fallback)
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }
}
