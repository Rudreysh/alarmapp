import SwiftUI

struct WallpaperThumbnailSmall: View {
    let id: String

    var body: some View {
        let image = loadImage(id)
        return Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: 44, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadImage(_ id: String) -> UIImage? {
        let loader = BundleWallpaperCatalogLoader(debugLogging: false)
        if let categories = try? loader.loadCategories() {
            if id == "default", let first = categories.first?.items.first {
                return UIImage(contentsOfFile: first.url.path)
            }
            for category in categories {
                if let item = category.items.first(where: { $0.id == id }) {
                    return UIImage(contentsOfFile: item.url.path)
                }
            }
        }
        if let url = Bundle.main.url(forResource: id, withExtension: nil, subdirectory: "BundledWallpapers") {
            return UIImage(contentsOfFile: url.path)
        }
        if let parsed = parsedWallpaper(id) {
            if let url = Bundle.main.url(forResource: parsed.filename, withExtension: nil, subdirectory: "BundledWallpapers/\(parsed.category)") {
                return UIImage(contentsOfFile: url.path)
            }
        }
        if let url = findWallpaperByFilename(id) {
            return UIImage(contentsOfFile: url.path)
        }
        if let fallback = fallbackImage() {
            return fallback
        }
        return nil
    }

    private func parsedWallpaper(_ id: String) -> (category: String, filename: String)? {
        let parts = id.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        return (category: String(parts[0]), filename: String(parts[1]))
    }

    private func findWallpaperByFilename(_ filename: String) -> URL? {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("BundledWallpapers") else { return nil }
        let fm = FileManager.default
        let target = filename.components(separatedBy: "-").last ?? filename
        guard let categories = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return nil }
        for category in categories {
            if let items = try? fm.contentsOfDirectory(at: category, includingPropertiesForKeys: nil) {
                if let match = items.first(where: { $0.lastPathComponent == target }) {
                    return match
                }
            }
        }
        return nil
    }

    private func fallbackImage() -> UIImage? {
        guard let firstCategory = WallpaperConfig.categories.first,
              let firstFilename = firstCategory.imageNames.first else { return nil }
        if let url = Bundle.main.url(forResource: firstFilename, withExtension: nil, subdirectory: "BundledWallpapers/\(firstCategory.id)") {
            return UIImage(contentsOfFile: url.path)
        }
        let nameWithoutExt = (firstFilename as NSString).deletingPathExtension
        let ext = (firstFilename as NSString).pathExtension
        if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}
