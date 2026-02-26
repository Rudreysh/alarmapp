import Foundation
import UIKit
import Combine

enum AssetError: Error {
    case networkError(Error)
    case invalidURL
    case diskWriteError(Error)
    case notFound
    case cancelled
}

final class AssetManager: ObservableObject {
    static let shared = AssetManager()

    private var catalogURL: URL?

    @Published var remoteSounds: [RemoteSound] = []
    @Published var remoteWallpapers: [RemoteWallpaperCategory] = []
    @Published var isLoadingCatalog: Bool = false

    /// Active download tasks keyed by filename for cancellation
    @Published private(set) var activeDownloads: Set<String> = []
    private var downloadTasks: [String: Task<URL, Error>] = [:]

    var remoteSoundsByCategory: [(category: String, sounds: [RemoteSound])] {
        let grouped = Dictionary(grouping: remoteSounds, by: { $0.category })
        return grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    private let fileManager = FileManager.default
    private lazy var assetDirectory: URL = {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let assetDir = urls[0].appendingPathComponent("Assets", isDirectory: true)
        try? fileManager.createDirectory(at: assetDir, withIntermediateDirectories: true)
        return assetDir
    }()

    // MARK: - Persistence

    private var catalogCacheURL: URL {
        assetDirectory.appendingPathComponent("catalog.json")
    }

    private func saveCatalogCache() {
        let catalog = AssetCatalogRequest(version: 1, wallpapers: remoteWallpapers, sounds: remoteSounds)
        if let data = try? JSONEncoder().encode(catalog) {
            try? data.write(to: catalogCacheURL)
        }
    }

    func loadCachedCatalog() {
        if let data = try? Data(contentsOf: catalogCacheURL),
           let catalog = try? JSONDecoder().decode(AssetCatalogRequest.self, from: data) {
            self.remoteSounds = catalog.sounds
            self.remoteWallpapers = catalog.wallpapers
            print("📦 AssetManager: Loaded cached catalog with \(remoteSounds.count) sounds.")
        }
    }

    // MARK: - Asset Management

    func fileExists(filename: String) -> Bool {
        fileManager.fileExists(atPath: assetDirectory.appendingPathComponent(filename).path)
    }

    func localURL(for filename: String) -> URL? {
        let url = assetDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func isDownloading(filename: String) -> Bool {
        activeDownloads.contains(filename)
    }

    /// Delete a locally-downloaded file (for cancel-and-remove scenarios)
    func deleteLocalFile(filename: String) {
        let url = assetDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    /// Cancel an in-progress download and remove any partial file
    @MainActor
    func cancelDownload(filename: String) {
        downloadTasks[filename]?.cancel()
        downloadTasks.removeValue(forKey: filename)
        activeDownloads.remove(filename)
        deleteLocalFile(filename: filename)
        print("🚫 AssetManager: Cancelled download and removed \(filename)")
    }

    /// Download a remote file and save it locally.
    /// Returns the local file URL on success.
    /// Call `cancelDownload(filename:)` to abort.
    func downloadAsset(from url: URL, filename: String, progress: ((Double) -> Void)? = nil) async throws -> URL {
        let destination = assetDirectory.appendingPathComponent(filename)

        // Already downloaded
        if fileManager.fileExists(atPath: destination.path) {
            progress?(1.0)
            return destination
        }

        // If there's already a task for this file, await it
        if let existing = downloadTasks[filename] {
            return try await existing.value
        }

        await MainActor.run { activeDownloads.insert(filename) }

        let task = Task<URL, Error> {
            defer {
                Task { @MainActor in
                    self.activeDownloads.remove(filename)
                    self.downloadTasks.removeValue(forKey: filename)
                }
            }

            print("📥 AssetManager: Downloading \(filename)...")

            let (bytes, response) = try await URLSession.shared.bytes(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("❌ AssetManager: Download failed for \(url.absoluteString) with status: \(status)")
                throw AssetError.invalidURL
            }

            let totalSize = httpResponse.expectedContentLength
            var data = Data()
            if totalSize > 0 { data.reserveCapacity(Int(totalSize)) }
            var downloadedBytes: Int64 = 0

            for try await byte in bytes {
                try Task.checkCancellation()
                data.append(byte)
                downloadedBytes += 1
                if totalSize > 0 && (downloadedBytes % 8192 == 0 || downloadedBytes == totalSize) {
                    let p = Double(downloadedBytes) / Double(totalSize)
                    progress?(p)
                }
            }

            try Task.checkCancellation()
            try data.write(to: destination)
            print("✅ AssetManager: Saved \(filename)")
            self.saveCatalogCache()
            return destination
        }

        downloadTasks[filename] = task

        do {
            return try await task.value
        } catch is CancellationError {
            // Ensure partial file is removed
            try? fileManager.removeItem(at: destination)
            throw AssetError.cancelled
        }
    }

    // MARK: - Catalog Fetching

    func fetchCatalog() async {
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

    func configure(catalogURL: String) {
        self.catalogURL = URL(string: catalogURL)
    }
}
