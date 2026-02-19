import SwiftUI
import PhotosUI

struct WallpaperPickerView: View {
    @Binding var selectedId: String

    @Environment(\.dismiss) private var dismiss
    @State private var items: [WallpaperItem] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    private let loader = BundleWallpaperCatalogLoader()
    private let fileStorage = LocalFileStorageService()

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
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
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Custom")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal, Spacing.l)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Colors.cardSurface)
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Colors.accentTeal)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Choose from iPhone library")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Colors.textPrimary)
                                    Text("Select any photo as alarm wallpaper")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(Colors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Colors.cardSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                            )
                            .padding(.horizontal, Spacing.l)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(items) { item in
                            Button(action: {
                                selectedId = item.id
                            }) {
                                ZStack {
                                    if let image = WallpaperImageResolver.resolveImage(for: item.id) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                                    }
                                    if selectedId == item.id {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.accentRed, lineWidth: 2)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                            .background(Circle().fill(Colors.accentRed))
                                            .offset(x: 32, y: -32)
                                    }
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedId == item.id ? Colors.accentRed : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    PrimaryButton(title: "Select") {
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
                }
            }
        }
        .onAppear {
            items = (try? loader.loadCategories().flatMap(\.items)) ?? []
            let userPhotos = WallpaperImageResolver.loadUserPhotoItems()
            if !userPhotos.isEmpty {
                items = userPhotos + items.filter { $0.category != "my_photos" }
            }

            if let selectedURL = WallpaperSelectionID.userPhotoURL(from: selectedId),
               FileManager.default.fileExists(atPath: selectedURL.path) {
                let selectedItem = WallpaperItem(
                    id: WallpaperSelectionID.makeUserPhotoID(from: selectedURL),
                    title: "My Photo",
                    url: selectedURL,
                    category: "my_photos",
                    source: .userPhoto(url: selectedURL)
                )
                if !items.contains(where: { $0.id == selectedItem.id }) {
                    items.insert(selectedItem, at: 0)
                }
            }

            if selectedId == "default", let first = items.first?.id {
                selectedId = first
            }
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

        items.removeAll(where: { $0.id == id })
        items.insert(newItem, at: 0)
        selectedId = id
    }
}
