import Foundation
import UIKit

struct WallpaperItem: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
    let category: String
    let source: WallpaperSource
}

struct WallpaperCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [WallpaperItem]
}

enum WallpaperSource: Equatable {
    case bundle(url: URL)
    case userPhoto(url: URL)
    case remote(url: URL)

    var url: URL {
        switch self {
        case .bundle(let url):
            return url
        case .userPhoto(let url):
            return url
        case .remote(let url):
            return url
        }
    }
}

struct WallpaperRef: Identifiable, Equatable {
    let id: String
    let title: String
    let source: WallpaperSource

    func image() -> UIImage? {
        UIImage(contentsOfFile: source.url.path)
    }
}
