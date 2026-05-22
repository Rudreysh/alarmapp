import SwiftUI
import PhotosUI

struct WallpaperPickerView: View {
    @Binding var selectedId: String

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [WallpaperCategory] = []
    @State private var items: [WallpaperItem] = []
    @State private var selectedCategory: String = "all" // "all", "my_photos", or category.id
    @State private var activeAllSectionCategory: String = "my_photos"
    @State private var suppressAutoSectionSync = false
    @State private var lockAllTabHighlight = false
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    private let loader = BundleWallpaperCatalogLoader()
    private let fileStorage = LocalFileStorageService()

    private var categoryPills: [(id: String, title: String)] {
        [("all", "All"), ("my_photos", "My Photos")] + categories.map { ($0.id, $0.title) }
    }

    private var allSections: [(id: String, title: String, items: [WallpaperItem])] {
        var sections: [(id: String, title: String, items: [WallpaperItem])] = []
        let photos = items.filter { $0.category == "my_photos" }
        if !photos.isEmpty {
            sections.append((id: "my_photos", title: "My Photos", items: photos))
        }
        for category in categories {
            let sectionItems = items.filter { $0.category == category.id }
            if !sectionItems.isEmpty {
                sections.append((id: category.id, title: category.title, items: sectionItems))
            }
        }
        return sections
    }

    private func isCategorySelected(_ categoryID: String) -> Bool {
        if selectedCategory == "all" {
            if lockAllTabHighlight {
                return categoryID == "all"
            }
            return categoryID == activeAllSectionCategory
        }
        return selectedCategory == categoryID
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Alarm wallpaper")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                ScrollViewReader { sectionProxy in
                    ScrollViewReader { tabsProxy in
                        // Category Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categoryPills, id: \.id) { pill in
                                    WallpaperCategoryPill(
                                        title: pill.title,
                                        isSelected: isCategorySelected(pill.id)
                                    ) {
                                        if selectedCategory == "all", pill.id != "all" {
                                            lockAllTabHighlight = false
                                            scrollToWallpaperSection(pill.id, proxy: sectionProxy)
                                        } else {
                                            selectedCategory = pill.id
                                            if pill.id == "all" {
                                                lockAllTabHighlight = true
                                                activeAllSectionCategory = allSections.first?.id ?? "my_photos"
                                            } else {
                                                lockAllTabHighlight = false
                                            }
                                        }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            tabsProxy.scrollTo(pill.id, anchor: .center)
                                        }
                                    }
                                    .id(pill.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .onChange(of: activeAllSectionCategory) { _, newValue in
                                guard selectedCategory == "all" else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabsProxy.scrollTo(newValue, anchor: .center)
                                }
                            }
                        }
                        .padding(.bottom, 20)

                        // Grid
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if selectedCategory == "all" {
                                    ForEach(allSections, id: \.id) { section in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(section.title)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Colors.textSecondary)
                                                .padding(.horizontal, 2)

                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                                ForEach(section.items) { item in
                                                    wallpaperGridItem(item)
                                                }
                                            }
                                        }
                                        .id("wallpaper-section-\(section.id)")
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: WallpaperSectionOffsetPreferenceKey.self,
                                                    value: ["wallpaper-section-\(section.id)": geo.frame(in: .named("wallpaperScroll")).minY]
                                                )
                                            }
                                        )
                                    }
                                } else {
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                        ForEach(filteredItems) { item in
                                            wallpaperGridItem(item)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100) // Space for FAB
                        }
                        .coordinateSpace(name: "wallpaperScroll")
                        .onPreferenceChange(WallpaperSectionOffsetPreferenceKey.self) { offsets in
                            guard selectedCategory == "all", !suppressAutoSectionSync else { return }
                            guard let next = currentlyVisibleWallpaperSection(offsets: offsets) else { return }
                            lockAllTabHighlight = false
                            if next != activeAllSectionCategory {
                                activeAllSectionCategory = next
                            }
                        }
                    }
                }
            }
            
            // FAB for adding photos
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Circle()
                            .fill(Colors.accentTeal)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            loadWallpaperData()
            activeAllSectionCategory = allSections.first?.id ?? "my_photos"
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        saveSelectedPhoto(data: data)
                    }
                }
            }
        }
    }
    
    private var filteredItems: [WallpaperItem] {
        switch selectedCategory {
        case "all":
            return items
        case "my_photos":
            return items.filter { $0.category == "my_photos" }
        default:
            return items.filter { $0.category == selectedCategory }
        }
    }

    @ViewBuilder
    private func wallpaperGridItem(_ item: WallpaperItem) -> some View {
        Button(action: {
            selectedId = item.id
        }) {
            ZStack {
                WallpaperItemView(item: item)

                if selectedId == item.id {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Colors.accentRed, lineWidth: 3)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .background(Circle().fill(Colors.accentRed))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .aspectRatio(0.6, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func loadWallpaperData() {
        // Load categories
        let loadedCategories = (try? loader.loadCategories()) ?? []
        self.categories = loadedCategories
        
        // Flatten items for "All" view
        var allLoadedItems = loadedCategories.flatMap(\.items)
        allLoadedItems = dedupeItems(allLoadedItems)
        
        // Load User Photos
        let userPhotos = WallpaperImageResolver.loadUserPhotoItems()
        
        // Merge: User photos + Bundle/Remote items
        allLoadedItems = allLoadedItems.filter { $0.category != "my_photos" }
        
        self.items = dedupeItems(userPhotos + allLoadedItems)
        
        // If current selection is a user photo not in the list, add it temporarily
        if let selectedURL = WallpaperSelectionID.userPhotoURL(from: selectedId),
           FileManager.default.fileExists(atPath: selectedURL.path) {
            let id = WallpaperSelectionID.makeUserPhotoID(from: selectedURL)
             // Check if already in items
            if !self.items.contains(where: { $0.id == id }) {
                let selectedItem = WallpaperItem(
                    id: id,
                    title: "My Photo",
                    url: selectedURL,
                    category: "my_photos",
                    source: .userPhoto(url: selectedURL)
                )
                self.items.insert(selectedItem, at: 0)
            }
        }
    }

    private func saveSelectedPhoto(data: Data) {
        guard let url = try? fileStorage.saveImageData(data, fileExtension: "jpg") else { return }

        let id = WallpaperSelectionID.makeUserPhotoID(from: url)
        let newItem = WallpaperItem(
            id: id,
            title: "My Photo",
            url: url,
            category: "my_photos",
            source: .userPhoto(url: url)
        )

        // Add to items list
        items.insert(newItem, at: 0)
        
        // Select it
        selectedId = id
        
        // Switch to "My Photos" or "Top" so user sees it
        selectedCategory = "my_photos"
    }

    private func scrollToWallpaperSection(_ categoryID: String, proxy: ScrollViewProxy) {
        suppressAutoSectionSync = true
        activeAllSectionCategory = categoryID
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo("wallpaper-section-\(categoryID)", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            suppressAutoSectionSync = false
        }
    }

    private func currentlyVisibleWallpaperSection(offsets: [String: CGFloat]) -> String? {
        let sectionIDs = allSections.map { "wallpaper-section-\($0.id)" }
        let candidates = sectionIDs.compactMap { id -> (id: String, y: CGFloat)? in
            guard let y = offsets[id] else { return nil }
            return (id, y)
        }
        guard !candidates.isEmpty else { return nil }

        if let topVisible = candidates.filter({ $0.y >= 0 }).min(by: { $0.y < $1.y }) {
            return topVisible.id.replacingOccurrences(of: "wallpaper-section-", with: "")
        }
        return candidates
            .filter { $0.y < 0 }
            .max(by: { $0.y < $1.y })?
            .id
            .replacingOccurrences(of: "wallpaper-section-", with: "")
    }

    private func dedupeItems(_ items: [WallpaperItem]) -> [WallpaperItem] {
        var seen = Set<String>()
        var out: [WallpaperItem] = []
        for item in items {
            let key = "\(item.category.lowercased())|\(item.url.lastPathComponent.lowercased())"
            if seen.insert(key).inserted {
                out.append(item)
            }
        }
        return out
    }
}

private struct WallpaperSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String : CGFloat], nextValue: () -> [String : CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct WallpaperItemView: View {
    let item: WallpaperItem
    @State private var downloadedImage: UIImage?
    @State private var isDownloading = false
    @State private var downloadError = false
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Colors.cardSurface // Background placeholder
                
                if let image = resolveImage() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(
                            Group {
                                if item.category == "motivation" {
                                    VStack {
                                        AdaptiveQuoteText(
                                            quote: MotivationQuotes.dailyQuotes().first?.text ?? "Stay Motivated",
                                            maxWidth: max(proxy.size.width - 12, 80),
                                            maxLines: 3,
                                            maxFontSize: 8,
                                            minFontSize: 6,
                                            weight: .bold,
                                            truncateToMaxLines: true
                                        )
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 2)
                                            .padding(4)
                                    }
                                }
                            }
                        )
                } else {
                    // Loading / Download State
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if downloadError {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(Colors.textSecondary)
                    } else {
                        // Not downloaded yet, trigger download
                        Color.clear
                            .onAppear {
                                downloadIfNeeded()
                            }
                    }
                }
            }
        }
    }
    
    private func resolveImage() -> UIImage? {
        // 1. Try immediate synchronous resolve (Bundle or My Photo)
        if let image = WallpaperImageResolver.resolveImage(for: item.id) {
            return image
        }
        
        // 2. Try downloaded image in state
        if let downloaded = downloadedImage {
            return downloaded
        }
        
        // 3. Try checking local file system if it was just downloaded but not in memory yet
        if let localURL = AssetManager.shared.localURL(for: item.url.lastPathComponent),
           let image = UIImage(contentsOfFile: localURL.path) {
            return image
        }
        
        return nil
    }
    
    private func downloadIfNeeded() {
        // Only download if remote
        guard case .remote(let remoteURL) = item.source else { return }
        // And not already local
        guard AssetManager.shared.localURL(for: remoteURL.lastPathComponent) == nil else { return }
        
        isDownloading = true
        downloadError = false
        
        Task {
            do {
                let filename = remoteURL.lastPathComponent
                let localURL = try await AssetManager.shared.downloadAsset(from: remoteURL, filename: filename)
                
                // Update State
                await MainActor.run {
                    self.downloadedImage = UIImage(contentsOfFile: localURL.path)
                    self.isDownloading = false
                }
            } catch {
                print("Failed to download wallpaper: \(error)")
                await MainActor.run {
                    self.isDownloading = false
                    self.downloadError = true
                }
            }
        }
    }
}

// Local Component for Category Pill
private struct WallpaperCategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
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
    }
}
