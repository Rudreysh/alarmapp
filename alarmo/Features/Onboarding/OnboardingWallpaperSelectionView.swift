import SwiftUI
import PhotosUI

struct OnboardingWallpaperSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.m)

                Text("Choose your\nalarm wallpaper")
                    .screenTitle()
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, Spacing.m)
                
                // MAIN SCROLL READER
                ScrollViewReader { proxy in
                    
                    // 1. Top Category Pills (Sticky-ish)
                    if !viewModel.state.wallpaperCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.state.wallpaperCategories) { category in
                                    Button(action: {
                                        withAnimation {
                                            proxy.scrollTo(category.id, anchor: .top)
                                        }
                                    }) {
                                        Text(category.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Colors.cardSurface)
                                            .foregroundColor(Colors.textPrimary)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Colors.cardStroke, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.l)
                        }
                        .padding(.bottom, Spacing.m)
                    }

                    // 2. Main Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            if viewModel.state.wallpaperCategories.isEmpty {
                                Text("No bundled wallpapers found. Ensure BundledWallpapers is added as a folder reference and target membership is enabled.")
                                    .bodyText()
                                    .foregroundColor(Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, Spacing.l)
                            } else {
                                ForEach(viewModel.state.wallpaperCategories) { category in
                                    WallpaperCategorySection(category: category, selected: viewModel.state.selectedWallpaper) {
                                        viewModel.selectWallpaper($0)
                                    }
                                    .id(category.id) // Anchor for scrolling
                                }
                            }

                            VStack(alignment: .leading, spacing: Spacing.m) {
                                Text("My Photos")
                                    .cardTitle()
                                    .foregroundColor(Colors.textPrimary)

                                HStack {
                                    Spacer()
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        MyPhotosCard(isSelected: isUserPhotoSelected)
                                    }
                                    Spacer()
                                }
                            }
                            .id("my_photos")
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.bottom, Spacing.xl)
                    }
                }

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
                .opacity(viewModel.canProceedWallpaper ? 1 : 0.5)
                .disabled(!viewModel.canProceedWallpaper)
            }
        }
        .onAppear {
            viewModel.loadWallpapers()
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.saveUserPhoto(data: data, fileExtension: "jpg")
                }
            }
        }
    }

    private var isUserPhotoSelected: Bool {
        guard let selected = viewModel.state.selectedWallpaper else { return false }
        if case .userPhoto = selected.source { return true }
        return false
    }
}

private struct WallpaperCategorySection: View {
    let category: WallpaperCategory
    let selected: WallpaperRef?
    let onSelect: (WallpaperItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(category.title)
                .cardTitle()
                .foregroundColor(Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(category.items) { item in
                        WallpaperCard(item: item, isSelected: selected?.id == item.id)
                            .onTapGesture { onSelect(item) }
                    }
                }
            }
        }
    }
}

private struct WallpaperCard: View {
    let item: WallpaperItem
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if case .remote = item.source {
                    AsyncImage(url: item.url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Colors.cardSurface
                                ProgressView()
                            }
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Colors.cardSurface.overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(Colors.textSecondary)
                            )
                        @unknown default:
                            Colors.cardSurface
                        }
                    }
                } else if let image = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Colors.cardSurface
                }
            }
            .frame(width: 140, height: 200)
            .clipped()

            Text(item.title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
                .padding(Spacing.s)
                .background(
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .top)
                )
        }
        .frame(width: 140, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Radii.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
        )
        .appShadow(Shadows.card)
    }
}

private struct MyPhotosCard: View {
    let isSelected: Bool

    var body: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(Colors.bgSecondary)
                    .frame(width: 52, height: 52)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
            }

            Text("Choose\nfrom album")
                .bodyText()
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 170, height: 220)
        .background(Colors.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card)
                .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(Radii.card)
        .appShadow(Shadows.card)
    }
}
