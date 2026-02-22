import SwiftUI
import PhotosUI

struct WallpaperPickerView: View {
    @Binding var selectedId: String

    @Environment(\.dismiss) private var dismiss
    @State private var categories: [WallpaperCategory] = []
    @State private var items: [WallpaperItem] = []
    @State private var selectedCategory: String = "all" // "all", "my_photos", or category.id
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    private let loader = BundleWallpaperCatalogLoader()
    private let fileStorage = LocalFileStorageService()

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

                // Category Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "All" Pill
                        WallpaperCategoryPill(title: "All", isSelected: selectedCategory == "all") {
                            selectedCategory = "all"
                        }
                        
                        // "My Photos" Pill
                        WallpaperCategoryPill(title: "My Photos", isSelected: selectedCategory == "my_photos") {
                            selectedCategory = "my_photos"
                        }
                        
                        // Dynamic Categories
                        ForEach(categories, id: \.id) { category in
                            WallpaperCategoryPill(title: category.title, isSelected: selectedCategory == category.id) {
                                selectedCategory = category.id
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)

                // Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(filteredItems) { item in
                            Button(action: {
                                selectedId = item.id
                            }) {
                                ZStack {
                                    // Image Content
                                    WallpaperItemView(item: item)
                                    
                                    // Selection Indicator
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for FAB
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
                                        Text("\"\(MotivationQuotes.dailyQuotes().first?.text ?? "Stay Motivated")\"")
                                            .font(.system(size: 8, weight: .bold, design: .serif))
                                            .italic()
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 2)
                                            .multilineTextAlignment(.center)
                                            .padding(4)
                                            .lineLimit(3)
                                            .minimumScaleFactor(0.5)
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
