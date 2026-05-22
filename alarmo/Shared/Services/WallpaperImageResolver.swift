import Foundation
import UIKit

/// Encodes/decodes wallpaper IDs for user-selected photos stored in app container.
enum WallpaperSelectionID {
    static let userPhotoPrefix = "userphoto:"

    static func makeUserPhotoID(from url: URL) -> String {
        let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        return userPhotoPrefix + encodedPath
    }

    static func userPhotoURL(from id: String) -> URL? {
        if id.hasPrefix(userPhotoPrefix) {
            let raw = String(id.dropFirst(userPhotoPrefix.count))
            let path = raw.removingPercentEncoding ?? raw
            return URL(fileURLWithPath: path)
        }

        // Backward compatibility: allow raw file URL/path IDs if ever persisted.
        if id.hasPrefix("file://"), let url = URL(string: id), url.isFileURL {
            return url
        }
        if id.hasPrefix("/") {
            return URL(fileURLWithPath: id)
        }

        return nil
    }
}

enum WallpaperImageResolver {
    static func resolveImage(for wallpaperId: String) -> UIImage? {
        // 1) User photo in app container.
        if let userURL = WallpaperSelectionID.userPhotoURL(from: wallpaperId),
           FileManager.default.fileExists(atPath: userURL.path),
           let image = UIImage(contentsOfFile: userURL.path) {
            return image
        }

        // 2) Catalog/bundled/remote-downloaded items.
        let loader = BundleWallpaperCatalogLoader(debugLogging: false)
        if let categories = try? loader.loadCategories() {
            if wallpaperId == "default", let first = categories.first?.items.first,
               let image = imageFromItem(first) {
                return image
            }
            for category in categories {
                if let item = category.items.first(where: { $0.id == wallpaperId }),
                   let image = imageFromItem(item) {
                    return image
                }
            }
        }

        // 3) Legacy direct bundle fallback.
        if let url = Bundle.main.url(forResource: wallpaperId, withExtension: nil, subdirectory: "BundledWallpapers"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        if let parsed = parsedWallpaperID(wallpaperId),
           let url = Bundle.main.url(forResource: parsed.filename, withExtension: nil, subdirectory: "BundledWallpapers/\(parsed.category)"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        if let url = Bundle.main.url(forResource: wallpaperId, withExtension: nil),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        return nil
    }

    static func loadUserPhotoItems() -> [WallpaperItem] {
        let storage = LocalFileStorageService()
        let directory = storage.baseURL.appendingPathComponent("wallpapers", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        return urls
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .map { url in
                WallpaperItem(
                    id: WallpaperSelectionID.makeUserPhotoID(from: url),
                    title: "My Photo",
                    url: url,
                    category: "my_photos",
                    source: .userPhoto(url: url)
                )
            }
    }

    private static func imageFromItem(_ item: WallpaperItem) -> UIImage? {
        if item.url.isFileURL {
            return UIImage(contentsOfFile: item.url.path)
        }
        return nil
    }

    private static func parsedWallpaperID(_ id: String) -> (category: String, filename: String)? {
        let parts = id.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        return (category: String(parts[0]), filename: String(parts[1]))
    }
}
