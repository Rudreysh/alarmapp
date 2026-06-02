import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct OnboardingWallpaperSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategoryId: String?
    @State private var activeAllSectionCategoryId: String = "All"
    @State private var suppressAutoSectionSync = false
    @State private var lockAllTabHighlight = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Choose your\nalarm wallpaper")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)

                ProgressHeader(step: 2, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, 0)
                    .padding(.bottom, Spacing.xs)
                
                // MAIN CONTENT
                let activeCategoryId = selectedCategoryId ?? "All"
                
                // 1. Top Category Pills
                if !viewModel.state.wallpaperCategories.isEmpty {
                    ScrollViewReader { sectionProxy in
                        ScrollViewReader { tabsProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    let isAllSelected = selectedCategoryId == "All" && lockAllTabHighlight
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCategoryId = "All"
                                            lockAllTabHighlight = true
                                            activeAllSectionCategoryId = viewModel.state.wallpaperCategories.first?.id ?? "All"
                                        }
                                    }) {
                                        Text("All")
                                            .font(.system(size: 14, weight: .semibold))
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(isAllSelected ? Colors.accentTeal : Colors.cardSurface)
                                            .foregroundColor(isAllSelected ? .white : Colors.textPrimary)
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Colors.cardStroke, lineWidth: isAllSelected ? 0 : 1)
                                            )
                                    }
                                    .id("wall-cat-All")

                                    ForEach(viewModel.state.wallpaperCategories) { category in
                                        let isSelected = selectedCategoryId == "All"
                                            ? (!lockAllTabHighlight && category.id == activeAllSectionCategoryId)
                                            : (category.id == activeCategoryId)
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                lockAllTabHighlight = false
                                                selectedCategoryId = "All"
                                                scrollToWallpaperSection(category.id, proxy: sectionProxy)
                                            }
                                        }) {
                                            Text(category.title)
                                                .font(.system(size: 14, weight: .semibold))
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
                                        .id("wall-cat-\(category.id)")
                                    }
                                }
                                .padding(.horizontal, Spacing.l)
                                .onChange(of: activeAllSectionCategoryId) { _, newValue in
                                    guard selectedCategoryId == "All", !lockAllTabHighlight else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        tabsProxy.scrollTo("wall-cat-\(newValue)", anchor: .center)
                                    }
                                }
                            }
                            .padding(.bottom, Spacing.xs)

                            // 2. Main Content
                            ScrollView {
                                VStack(alignment: .leading, spacing: Spacing.l) {
                                    if viewModel.state.wallpaperCategories.isEmpty {
                                        Text("No bundled wallpapers found. Ensure BundledWallpapers is added as a folder reference and target membership is enabled.")
                                            .bodyText()
                                            .foregroundColor(Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.vertical, Spacing.l)
                                    } else if activeCategoryId == "All" {
                                        ForEach(viewModel.state.wallpaperCategories) { category in
                                            WallpaperCategorySection(category: category, selected: viewModel.state.selectedWallpaper) {
                                                viewModel.selectWallpaper($0)
                                            }
                                            .padding(.bottom, Spacing.xs)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: OnboardingWallpaperSectionOffsetPreferenceKey.self,
                                                        value: ["wallpaper-section-\(category.id)": geo.frame(in: .named("onboardingWallpaperScroll")).minY]
                                                    )
                                                }
                                            )
                                            .id("wallpaper-section-\(category.id)")
                                        }
                                        .transition(.opacity)
                                    } else if let category = viewModel.state.wallpaperCategories.first(where: { $0.id == activeCategoryId }) {
                                        WallpaperCategorySection(category: category, selected: viewModel.state.selectedWallpaper) {
                                            viewModel.selectWallpaper($0)
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    }

                                    VStack(alignment: .leading, spacing: Spacing.m) {
                                        Text("My Photos")
                                            .cardTitle()
                                            .foregroundColor(Colors.textPrimary)

                                        HStack {
                                            Spacer()
                                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                                MyPhotosCard(
                                                    isSelected: isUserPhotoSelected,
                                                    thumbnail: selectedUserPhotoImage
                                                )
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, Spacing.l)
                                .padding(.bottom, Spacing.m)
                            }
                            .coordinateSpace(name: "onboardingWallpaperScroll")
                            .onPreferenceChange(OnboardingWallpaperSectionOffsetPreferenceKey.self) { offsets in
                                guard selectedCategoryId == "All", !suppressAutoSectionSync else { return }
                                guard let next = currentlyVisibleWallpaperSection(offsets: offsets) else { return }
                                lockAllTabHighlight = false
                                if next != activeAllSectionCategoryId {
                                    activeAllSectionCategoryId = next
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, -8)
            .overlay(
                VStack {
                    Spacer()
                    PrimaryButton(title: "Next", style: .blueGlass) {
                        onNext()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l) // Add safe area-like padding
                }, alignment: .bottom
            )
        }
        .onAppear {
            viewModel.loadWallpapers()
            selectedCategoryId = "All"
            activeAllSectionCategoryId = viewModel.state.wallpaperCategories.first?.id ?? "All"
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                let fileExtension = preferredFileExtension(for: newItem)
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await viewModel.saveUserPhoto(data: data, fileExtension: fileExtension)
                }
                await MainActor.run { selectedItem = nil }
            }
        }
    }

    private var isUserPhotoSelected: Bool {
        guard let selected = viewModel.state.selectedWallpaper else { return false }
        if case .userPhoto = selected.source { return true }
        return false
    }

    private var selectedUserPhotoImage: UIImage? {
        guard let selected = viewModel.state.selectedWallpaper,
              case .userPhoto = selected.source else {
            return nil
        }
        return selected.image()
    }

    private func preferredFileExtension(for item: PhotosPickerItem) -> String {
        for contentType in item.supportedContentTypes {
            if let ext = contentType.preferredFilenameExtension,
               !ext.isEmpty {
                return ext
            }
        }
        return UTType.jpeg.preferredFilenameExtension ?? "jpg"
    }

    private func scrollToWallpaperSection(_ categoryID: String, proxy: ScrollViewProxy) {
        activeAllSectionCategoryId = categoryID
        suppressAutoSectionSync = true
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo("wallpaper-section-\(categoryID)", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            suppressAutoSectionSync = false
        }
    }

    private func currentlyVisibleWallpaperSection(offsets: [String: CGFloat]) -> String? {
        let sections = viewModel.state.wallpaperCategories.map { ($0.id, "wallpaper-section-\($0.id)") }
        let candidates = sections.compactMap { categoryID, id -> (categoryID: String, y: CGFloat)? in
            guard let y = offsets[id] else { return nil }
            return (categoryID, y)
        }
        let visible = candidates
            .filter { $0.y <= 120 }
            .max(by: { $0.y < $1.y }) ?? candidates.min(by: { $0.y < $1.y })
        return visible?.categoryID
    }
}

private struct OnboardingWallpaperSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct WallpaperCategorySection: View {
    let category: WallpaperCategory
    let selected: WallpaperRef?
    let onSelect: (WallpaperItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
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
            .frame(width: 132, height: 176)
            .clipped()

            Text(item.title)
                .bodyText()
                .foregroundColor(Colors.textPrimary)
                .padding(Spacing.s)
                .background(
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .top)
                )
        }
        .frame(width: 132, height: 176)
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
    let thumbnail: UIImage?

    var body: some View {
        ZStack {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Colors.cardSurface
                }
            }
            .frame(width: 170, height: 220)
            .clipped()

            if thumbnail != nil {
                LinearGradient(
                    colors: [Color.black.opacity(0.2), Color.black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            VStack(spacing: Spacing.m) {
                ZStack {
                    Circle()
                        .fill(thumbnail == nil ? Colors.bgSecondary : Color.black.opacity(0.35))
                        .frame(width: 52, height: 52)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(thumbnail == nil ? Colors.textPrimary : .white)
                }

                Text("Choose\nfrom album")
                    .bodyText()
                    .foregroundColor(thumbnail == nil ? Colors.textPrimary : .white)
                    .multilineTextAlignment(.center)
            }
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
