import SwiftUI

struct OnboardingWallpaperSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    @State private var selectedWallpaperId: String = "default"
    private let loader = BundleWallpaperCatalogLoader()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Reuse the exact picker used in Create/Edit Alarm.
            WallpaperPickerView(selectedId: $selectedWallpaperId)

            PrimaryButton(title: "Next", style: .blueGlass) {
                syncSelectionBackToOnboarding()
                onNext()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .onAppear {
            if let existing = viewModel.state.selectedWallpaper?.id {
                selectedWallpaperId = existing
            }
            syncSelectionBackToOnboarding()
        }
        .onChange(of: selectedWallpaperId) { _, _ in
            syncSelectionBackToOnboarding()
        }
    }

    private func syncSelectionBackToOnboarding() {
        // User photo selection
        if let userURL = WallpaperSelectionID.userPhotoURL(from: selectedWallpaperId),
           FileManager.default.fileExists(atPath: userURL.path) {
            let item = WallpaperItem(
                id: selectedWallpaperId,
                title: "My Photo",
                url: userURL,
                category: "my_photos",
                source: .userPhoto(url: userURL)
            )
            viewModel.selectWallpaper(item)
            return
        }

        // Catalog/bundled/remote selection
        if let categories = try? loader.loadCategories() {
            for category in categories {
                if let item = category.items.first(where: { $0.id == selectedWallpaperId }) {
                    viewModel.selectWallpaper(item)
                    return
                }
            }
            if selectedWallpaperId == "default", let first = categories.first?.items.first {
                viewModel.selectWallpaper(first)
            }
        }
    }
}
