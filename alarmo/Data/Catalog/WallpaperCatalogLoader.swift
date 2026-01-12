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
        
        log("Loaded \(categories.count) categories.")
        return categories
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
