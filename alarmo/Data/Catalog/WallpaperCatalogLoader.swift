import Foundation

protocol WallpaperCatalogLoader {
    func loadCategories() throws -> [WallpaperCategory]
}

struct BundleWallpaperCatalogLoader: WallpaperCatalogLoader {
    let rootURL: URL
    let fileManager: FileManager

    init?(bundle: Bundle = .main, fileManager: FileManager = .default) {
        let candidates: [URL?] = [
            bundle.url(forResource: "BundledWallpapers", withExtension: nil),
            bundle.resourceURL?.appendingPathComponent("BundledWallpapers"),
            bundle.resourceURL?.appendingPathComponent("Resources").appendingPathComponent("BundledWallpapers")
        ]

        guard let found = candidates.compactMap({ $0 }).first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }

        self.rootURL = found
        self.fileManager = fileManager
    }

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func loadCategories() throws -> [WallpaperCategory] {
        let categoryFolders = (try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath }) ?? []

        if !categoryFolders.isEmpty {
            return try categoryFolders.map { folderURL in
                let files = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                    .filter { $0.isImageFile }

                guard !files.isEmpty else {
                    return nil
                }

                let categoryName = folderURL.lastPathComponent
                let items = files.map { fileURL -> WallpaperItem in
                    let filename = fileURL.lastPathComponent
                    return WallpaperItem(
                        id: "\(categoryName)-\(filename)",
                        displayName: filename.displayNameFromFilename,
                        source: .bundle(category: categoryName, filename: filename, url: fileURL)
                    )
                }

                return WallpaperCategory(
                    id: categoryName,
                    title: categoryName.displayNameFromFilename,
                    emoji: nil,
                    items: items
                )
            }
            .compactMap { $0 }
            .sorted { $0.title < $1.title }
        }

        // Fallback: recurse any BundledWallpapers images even if the folder reference wasn't preserved.
        let images = try fileManager.recursiveImageFiles(at: rootURL)
        return Dictionary(grouping: images) { url in
            url.pathComponents.after("BundledWallpapers").first ?? "Wallpapers"
        }
        .map { key, values in
            let items = values.map { fileURL -> WallpaperItem in
                let filename = fileURL.lastPathComponent
                return WallpaperItem(
                    id: "\(key)-\(filename)",
                    displayName: filename.displayNameFromFilename,
                    source: .bundle(category: key, filename: filename, url: fileURL)
                )
            }
            return WallpaperCategory(
                id: key,
                title: key.displayNameFromFilename,
                emoji: nil,
                items: items
            )
        }
        .sorted { $0.title < $1.title }
    }
}

private extension URL {
    var isImageFile: Bool {
        let ext = pathExtension.lowercased()
        return ext == "jpg" || ext == "jpeg" || ext == "png"
    }
}

private extension String {
    var displayNameFromFilename: String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private extension FileManager {
    func recursiveImageFiles(at url: URL) throws -> [URL] {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { item in
            guard let fileURL = item as? URL, fileURL.isFileURL, fileURL.isImageFile else {
                return nil
            }
            return fileURL
        }
    }
}

private extension Array where Element == String {
    func after(_ component: String) -> [String] {
        guard let index = firstIndex(of: component) else { return [] }
        let next = index + 1
        guard next < count else { return [] }
        return Array(self[next...])
    }
}
