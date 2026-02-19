import Foundation

// MARK: - Remote Catalog Structure

/// The top-level JSON structure hosted on GitHub
struct AssetCatalogRequest: Codable {
    let version: Int
    let wallpapers: [RemoteWallpaperCategory]
    let sounds: [RemoteSound]
}

// MARK: - Wallpapers

struct RemoteWallpaperCategory: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let items: [RemoteWallpaperItem]
}

struct RemoteWallpaperItem: Codable, Identifiable, Equatable {
    let id: String
    let filename: String // "mountain.jpg"
    let title: String    // "Mountain Sunrise"
    let url: URL         // "https://raw.githubusercontent.com/.../mountain.jpg"
    let thumbnail: URL?  // Optional smaller version
}

// MARK: - Sounds

struct RemoteSound: Codable, Identifiable, Equatable {
    let id: String
    let filename: String // "rain.mp3"
    let title: String    // "Gentle Rain"
    let category: String // "Nature"
    let url: URL         // "https://raw.githubusercontent.com/.../rain.mp3"
    let isPremium: Bool  // Future proofing
}
