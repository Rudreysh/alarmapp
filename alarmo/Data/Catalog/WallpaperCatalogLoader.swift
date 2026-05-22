import Foundation
import UIKit

protocol WallpaperCatalogLoader {
    func loadCategories() throws -> [WallpaperCategory]
}

struct BundleWallpaperCatalogLoader: WallpaperCatalogLoader {
    let debugLogging: Bool

    init(debugLogging: Bool = true) {
        self.debugLogging = debugLogging
    }
    
    // For backward compatibility/testing
    init(rootURL: URL, fileManager: FileManager = .default, debugLogging: Bool = true) {
        self.debugLogging = debugLogging
    }

    func loadCategories() throws -> [WallpaperCategory] {
        log("Loading wallpapers from Static Config...")
        
        var categories: [WallpaperCategory] = []

        for categoryDef in WallpaperConfig.categories {
            var items: [WallpaperItem] = []
            
            for filename in categoryDef.imageNames {
                // Try to find the file in the main bundle.
                // This lookup works whether the file is added as a Group (flattened) or Folder Reference.
                // We check multiple standard locations just to be safe.
                
                var resolvedURL: URL?
                let nameWithoutExt = (filename as NSString).deletingPathExtension
                let ext = (filename as NSString).pathExtension
                
                // 1. Try finding it anywhere in the bundle (Standard for Groups)
                if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
                    resolvedURL = url
                }
                
                // 2. Try specific path for Folder References
                if resolvedURL == nil, let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "BundledWallpapers/\(categoryDef.id)") {
                     resolvedURL = url
                }
                
                if let url = resolvedURL {
                    items.append(WallpaperItem(
                        id: "\(categoryDef.id)-\(filename)",
                        title: filename.displayNameFromFilename,
                        url: url,
                        category: categoryDef.id,
                        source: .bundle(url: url)
                    ))
                } else {
                    log("WARNING: Could not find image '\(filename)' in Bundle.")
                }
            }
            
            if !items.isEmpty {
                categories.append(WallpaperCategory(
                    id: categoryDef.id,
                    title: categoryDef.title,
                    items: items
                ))
            }
        }
        
        log("Loaded \(categories.count) bundled categories.")
        
        // Append Remote Categories
        let remoteCategories = AssetManager.shared.remoteWallpapers.map { remoteCat -> WallpaperCategory in
            let items = remoteCat.items.compactMap { remoteItem -> WallpaperItem? in
                // Check if already downloaded
                let normalizedFilename = remoteItem.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedFilename.isEmpty else { return nil }
                
                if let localURL = AssetManager.shared.localURL(for: normalizedFilename) {
                     return WallpaperItem(
                        id: remoteItem.id,
                        title: remoteItem.title,
                        url: localURL,
                        category: remoteCat.id,
                        source: .remote(url: localURL) // Treat as remote logic (or .bundle if we want synchronous loading)
                    )
                } else {
                    return WallpaperItem(
                        id: remoteItem.id,
                        title: remoteItem.title,
                        url: remoteItem.url,
                        category: remoteCat.id,
                        source: .remote(url: remoteItem.url)
                    )
                }
            }
            
            return WallpaperCategory(
                id: remoteCat.id,
                title: remoteCat.title,
                items: items
            )
        }
        
        // Merge categories
        var mergedCategories: [String: WallpaperCategory] = [:]
        
        // 1. Add Bundled Categories
        for category in categories {
            mergedCategories[category.id] = category
        }
        
        // 2. Merge Remote Categories
        for remoteCat in remoteCategories {
            if let existing = mergedCategories[remoteCat.id] {
                // Merge items, avoiding duplicates
                var existingItems = existing.items
                var existingKeys = Set(existingItems.map { itemDedupeKey($0) })
                
                for item in remoteCat.items {
                    let key = itemDedupeKey(item)
                    if !existingKeys.contains(key) {
                        existingItems.append(item)
                        existingKeys.insert(key)
                    }
                }
                
                mergedCategories[remoteCat.id] = WallpaperCategory(
                    id: existing.id,
                    title: existing.title, // Keep local title preference? Or remote? Keeping local.
                    items: existingItems
                )
            } else {
                mergedCategories[remoteCat.id] = remoteCat
            }
        }
        
        let finalCategories = mergedCategories.values
            .map { category in
                let dedupedItems = dedupe(items: category.items)
                return WallpaperCategory(id: category.id, title: category.title, items: dedupedItems)
            }
            .filter { !$0.items.isEmpty }
            .sorted { $0.title < $1.title }
        log("Total unique categories: \(finalCategories.count)")
        
        return finalCategories
    }

    private func dedupe(items: [WallpaperItem]) -> [WallpaperItem] {
        var seen = Set<String>()
        var out: [WallpaperItem] = []
        for item in items {
            let key = itemDedupeKey(item)
            if seen.insert(key).inserted {
                out.append(item)
            }
        }
        return out
    }

    private func itemDedupeKey(_ item: WallpaperItem) -> String {
        let filename = item.url.lastPathComponent.lowercased()
        return "\(item.category.lowercased())|\(filename)"
    }

    private func log(_ message: String) {
        guard debugLogging else { return }
        print("[WallpaperLoader] \(message)")
    }
}

private extension String {
    var displayNameFromFilename: String {
        let nameWithoutExt = (self as NSString).deletingPathExtension
        return nameWithoutExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
