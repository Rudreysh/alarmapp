import Foundation
import UIKit

struct WallpaperItem: Identifiable, Equatable {
    let id: String
    let displayName: String
    let source: WallpaperSource
}

struct WallpaperCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let emoji: String?
    let items: [WallpaperItem]
}

enum WallpaperSource: Equatable {
    case bundle(category: String, filename: String, url: URL)
    case userPhoto(url: URL)

    var url: URL {
        switch self {
        case .bundle(_, _, let url):
            return url
        case .userPhoto(let url):
            return url
        }
    }
}

struct WallpaperRef: Identifiable, Equatable {
    let id: String
    let displayName: String
    let source: WallpaperSource

    func image() -> UIImage? {
        UIImage(contentsOfFile: source.url.path)
    }
}
