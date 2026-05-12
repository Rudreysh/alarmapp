import Foundation
import UIKit
import Combine

enum AssetError: Error {
    case networkError(Error)
    case invalidURL
    case httpStatus(Int, URL)
    case diskWriteError(Error)
    case notFound
    case cancelled
}

final class AssetManager: ObservableObject {
    static let shared = AssetManager()

    private var catalogURL: URL?
    private let catalogSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    private let downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    @Published var remoteSounds: [RemoteSound] = []
    @Published var remoteWallpapers: [RemoteWallpaperCategory] = []
    @Published var isLoadingCatalog: Bool = false

    /// Active download tasks keyed by filename for cancellation
    @Published private(set) var activeDownloads: Set<String> = []
    private var downloadTasks: [String: Task<URL, Error>] = [:]
    private let downloadTasksLock = NSLock()
    private let prefetchLock = NSLock()
    private var prefetchInProgress = false

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

    private func prefetchDefaultAlarmSoundsIfNeeded() {
        let alarmSounds = remoteSounds.filter { $0.category.caseInsensitiveCompare("Alarm") == .orderedSame }
        guard !alarmSounds.isEmpty else { return }

        prefetchLock.lock()
        if prefetchInProgress {
            prefetchLock.unlock()
            print("🎵 AssetManager: Prefetch already in progress — skipping duplicate trigger.")
            return
        }
        prefetchInProgress = true
        prefetchLock.unlock()

        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                self.prefetchLock.lock()
                self.prefetchInProgress = false
                self.prefetchLock.unlock()
            }
            let missing = alarmSounds.filter { !self.fileExists(filename: $0.filename) }
            guard !missing.isEmpty else {
                print("🎵 AssetManager: All default alarm sounds already downloaded (\(alarmSounds.count)).")
                return
            }

            print("🎵 AssetManager: Prefetching \(missing.count)/\(alarmSounds.count) default alarm sounds...")
            for sound in missing {
                do {
                    _ = try await self.downloadAsset(from: sound.url, filename: sound.filename)
                } catch AssetError.cancelled {
                    print("⚠️ AssetManager: Alarm prefetch cancelled for \(sound.filename)")
                } catch {
                    print("⚠️ AssetManager: Alarm prefetch failed for \(sound.filename): \(error)")
                }
            }
        }
    }

    func loadCachedCatalog() {
        if let data = try? Data(contentsOf: catalogCacheURL),
           let catalog = try? JSONDecoder().decode(AssetCatalogRequest.self, from: data) {
            self.remoteSounds = catalog.sounds
            self.remoteWallpapers = catalog.wallpapers
            print("📦 AssetManager: Loaded cached catalog with \(remoteSounds.count) sounds.")
            prefetchDefaultAlarmSoundsIfNeeded()
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
        downloadTasksLock.lock()
        let task = downloadTasks[filename]
        downloadTasks.removeValue(forKey: filename)
        downloadTasksLock.unlock()
        task?.cancel()
        activeDownloads.remove(filename)
        deleteLocalFile(filename: filename)
        print("🚫 AssetManager: Cancelled download and removed \(filename)")
    }
    
    func getDownloadsSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: assetDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var size: Int64 = 0
        for file in files {
            if file.lastPathComponent == "catalog.json" { continue }
            if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
               let fileSize = attrs[.size] as? Int64 {
                size += fileSize
            }
        }
        return size
    }

    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func clearAllDownloads() {
        guard let files = try? fileManager.contentsOfDirectory(at: assetDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            if file.lastPathComponent == "catalog.json" { continue }
            try? fileManager.removeItem(at: file)
        }
        print("🗑️ AssetManager: Cleared all downloaded assets")
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
        if let existing = existingDownloadTask(for: filename) {
            return try await existing.value
        }

        await MainActor.run { activeDownloads.insert(filename) }

        let task = Task<URL, Error> {
            defer {
                Task { @MainActor in
                    self.activeDownloads.remove(filename)
                }
                self.removeDownloadTask(for: filename)
            }

            print("📥 AssetManager: Downloading \(filename)...")
            let candidateURLs = self.downloadCandidateURLs(primary: url, filename: filename)
            var lastError: Error?

            for candidate in candidateURLs {
                let maxAttempts = 3
                for attempt in 1...maxAttempts {
                    do {
                        let localURL = try await self.streamDownload(
                            from: candidate,
                            destination: destination,
                            progress: progress
                        )
                        self.saveCatalogCache()
                        return localURL
                    } catch let error as URLError where error.code == .timedOut {
                        lastError = error
                        if attempt < maxAttempts {
                            let backoff = UInt64(attempt) * 1_000_000_000
                            print("⚠️ AssetManager: Timeout for \(candidate.lastPathComponent) attempt \(attempt)/\(maxAttempts). Retrying...")
                            try await Task.sleep(nanoseconds: backoff)
                            continue
                        }
                    } catch AssetError.httpStatus(let status, let failedURL) where status == 404 && candidate != candidateURLs.last {
                        lastError = AssetError.httpStatus(status, failedURL)
                        print("⚠️ AssetManager: 404 for \(failedURL.lastPathComponent). Trying fallback URL variant...")
                        break
                    } catch {
                        lastError = error
                        break
                    }
                }
            }

            throw lastError ?? AssetError.invalidURL
        }

        setDownloadTask(task, for: filename)

        do {
            return try await task.value
        } catch is CancellationError {
            // Ensure partial file is removed
            try? fileManager.removeItem(at: destination)
            throw AssetError.cancelled
        }
    }

    private func streamDownload(
        from remoteURL: URL,
        destination: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 45

        let (bytes, response) = try await downloadSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ AssetManager: Download failed for \(remoteURL.absoluteString) with status: \(status)")
            throw AssetError.httpStatus(status, remoteURL)
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
        print("✅ AssetManager: Saved \(destination.lastPathComponent)")
        return destination
    }

    private func downloadCandidateURLs(primary: URL, filename: String) -> [URL] {
        var candidates: [URL] = [primary]
        guard filename.contains("_") else { return candidates }

        let altName = filename.replacingOccurrences(of: "_", with: " ")
        if altName == filename { return candidates }

        if var components = URLComponents(url: primary, resolvingAgainstBaseURL: false) {
            let encodedAlt = altName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? altName
            let encodedCurrent = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
            components.percentEncodedPath = components.percentEncodedPath.replacingOccurrences(of: encodedCurrent, with: encodedAlt)
            if let altURL = components.url, altURL != primary {
                candidates.append(altURL)
            }
        }
        return candidates
    }

    private func existingDownloadTask(for filename: String) -> Task<URL, Error>? {
        downloadTasksLock.lock()
        defer { downloadTasksLock.unlock() }
        return downloadTasks[filename]
    }

    private func setDownloadTask(_ task: Task<URL, Error>, for filename: String) {
        downloadTasksLock.lock()
        downloadTasks[filename] = task
        downloadTasksLock.unlock()
    }

    private func removeDownloadTask(for filename: String) {
        downloadTasksLock.lock()
        downloadTasks.removeValue(forKey: filename)
        downloadTasksLock.unlock()
    }

    // MARK: - Catalog Fetching

    private func cacheBustedCatalogURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "_cb" }
        items.append(URLQueryItem(name: "_cb", value: String(Int(Date().timeIntervalSince1970))))
        components.queryItems = items
        return components.url ?? url
    }

    func fetchCatalog() async {
        if remoteSounds.isEmpty && remoteWallpapers.isEmpty {
            loadCachedCatalog()
        }

        guard let url = catalogURL else {
            print("❌ AssetManager: No Catalog URL set.")
            return
        }

        let started = await MainActor.run { () -> Bool in
            if self.isLoadingCatalog { return false }
            self.isLoadingCatalog = true
            return true
        }
        guard started else { return }

        do {
            let fetchURL = cacheBustedCatalogURL(from: url)
            var request = URLRequest(url: fetchURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await catalogSession.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }

            let catalog = try JSONDecoder().decode(AssetCatalogRequest.self, from: data)
            await MainActor.run {
                self.remoteSounds = catalog.sounds
                self.remoteWallpapers = catalog.wallpapers
                self.isLoadingCatalog = false
            }
            saveCatalogCache()
            let categories = Set(catalog.sounds.map(\.category)).sorted()
            print("✅ AssetManager: Updated catalog with \(catalog.sounds.count) sounds and \(catalog.wallpapers.count) wallpaper categories. Sound categories: \(categories)")
            prefetchDefaultAlarmSoundsIfNeeded()
        } catch {
            print("❌ AssetManager: Failed to fetch catalog. \(error)")
            await MainActor.run { self.isLoadingCatalog = false }
        }
    }

    func configure(catalogURL: String) {
        self.catalogURL = URL(string: catalogURL)
    }
}
