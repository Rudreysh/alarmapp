import Foundation

protocol FileStorageService {
    func saveImageData(_ data: Data, fileExtension: String) throws -> URL
}

struct LocalFileStorageService: FileStorageService {
    let fileManager: FileManager
    let baseURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    init(baseURL: URL, fileManager: FileManager = .default) {
        self.baseURL = baseURL
        self.fileManager = fileManager
    }

    func saveImageData(_ data: Data, fileExtension: String) throws -> URL {
        let directory = baseURL.appendingPathComponent("wallpapers", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + fileExtension
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
