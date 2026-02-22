import Foundation
import UIKit
import Combine

enum AssetError: Error {
    case networkError(Error)
    case invalidURL
    case diskWriteError(Error)
    case notFound
}

final class AssetManager: ObservableObject {
    static let shared = AssetManager()
    
    // Replace with your actual GitHub Raw URL
    // Example: "https://raw.githubusercontent.com/username/repo/main/catalog.json"
    private var catalogURL: URL?
    
    @Published var remoteSounds: [RemoteSound] = []
    @Published var remoteWallpapers: [RemoteWallpaperCategory] = []
    @Published var isLoadingCatalog: Bool = false
    
    /// Helper to get sounds grouped by category for sectioned UI
    var remoteSoundsByCategory: [(category: String, sounds: [RemoteSound])] {
        let grouped = Dictionary(grouping: remoteSounds, by: { $0.category })
        return grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
    
    private let fileManager = FileManager.default
    private lazy var assetDirectory: URL = {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0]
        let assetDir = appSupport.appendingPathComponent("Assets", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: assetDir, withIntermediateDirectories: true)
        return assetDir
    }()
    
    // MARK: - Persistence
    
    private var catalogCacheURL: URL {
        assetDirectory.appendingPathComponent("catalog.json")
    }
    
    /// Save current catalog to disk for offline access
    private func saveCatalogCache() {
        let catalog = AssetCatalogRequest(version: 1, wallpapers: remoteWallpapers, sounds: remoteSounds)
        if let data = try? JSONEncoder().encode(catalog) {
            try? data.write(to: catalogCacheURL)
        }
    }
    
    /// Load cached catalog from disk
    func loadCachedCatalog() {
        if let data = try? Data(contentsOf: catalogCacheURL),
           let catalog = try? JSONDecoder().decode(AssetCatalogRequest.self, from: data) {
            self.remoteSounds = catalog.sounds
            self.remoteWallpapers = catalog.wallpapers
            print("📦 AssetManager: Loaded cached catalog with \(remoteSounds.count) sounds.")
        }
    }
    
    // MARK: - Asset Management (Sounds & Wallpapers)
    
    /// Check if a remote asset is already downloaded locally
    func fileExists(filename: String) -> Bool {
        let localURL = assetDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: localURL.path)
    }
    
    /// Returns the local URL if downloaded, otherwise returns nil
    func localURL(for filename: String) -> URL? {
        let url = assetDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
    
    /// Download a remote file (sound or image) and save it locally
    /// Returns the local file URL on success
    func downloadAsset(from url: URL, filename: String, progress: ((Double) -> Void)? = nil) async throws -> URL {
        let destination = assetDirectory.appendingPathComponent(filename)
        
        // Return existing if already there (simple caching)
        if fileManager.fileExists(atPath: destination.path) {
            progress?(1.0)
            return destination
        }
        
        print("📥 AssetManager: Downloading \(filename)...")
        
        // Use async bytes to track progress
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ AssetManager: Download failed for \(url.absoluteString) with status: \(status)")
            throw AssetError.invalidURL
        }
        
        let totalSize = httpResponse.expectedContentLength
        var data = Data()
        if totalSize > 0 {
            data.reserveCapacity(Int(totalSize))
        }
        
        var downloadedBytes: Int64 = 0
        
        for try await byte in bytes {
            data.append(byte)
            downloadedBytes += 1
            
            if totalSize > 0 {
                let p = Double(downloadedBytes) / Double(totalSize)
                // Report progress periodically or on every byte (might be too frequent, but usually okay for small files)
                if downloadedBytes % 1024 == 0 || downloadedBytes == totalSize {
                    progress?(p)
                }
            }
        }
        
        try data.write(to: destination)
        print("✅ AssetManager: Saved \(filename)")
        saveCatalogCache() // Update cache since we have new files
        return destination
    }

    // MARK: - Catalog Fetching
    
    func fetchCatalog() async {
        // Load cache first for immediate UI
        loadCachedCatalog()
        
        guard let url = catalogURL else { 
            print("❌ AssetManager: No Catalog URL set.")
            return 
        }
        
        await MainActor.run { self.isLoadingCatalog = true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let catalog = try JSONDecoder().decode(AssetCatalogRequest.self, from: data)
            
            await MainActor.run {
                self.remoteSounds = catalog.sounds
                self.remoteWallpapers = catalog.wallpapers
                self.isLoadingCatalog = false
            }
            saveCatalogCache()
            print("✅ AssetManager: Updated catalog with \(catalog.sounds.count) sounds and \(catalog.wallpapers.count) wallpaper categories.")
        } catch {
            print("❌ AssetManager: Failed to fetch catalog. \(error)")
            await MainActor.run { self.isLoadingCatalog = false }
        }
    }
    
    // Configuration
    func configure(catalogURL: String) {
        self.catalogURL = URL(string: catalogURL)
    }
}
