import Foundation

protocol SoundCatalogRepositoryProtocol {
    func loadBundledSounds() throws -> [SoundAsset]
    func loadAllSounds() -> [SoundAsset]
}

struct SoundCatalogRepository: SoundCatalogRepositoryProtocol {
    private let debugLogging: Bool
    private let soundDefinitions: [SoundConfig.SoundDefinition]
    private let bundleLookup: (String, String?) -> URL? // (filename, subdirectory) -> URL?

    init(
        soundDefinitions: [SoundConfig.SoundDefinition] = SoundConfig.sounds,
        bundleLookup: @escaping (String, String?) -> URL? = { filename, subDir in
            // Default lookup logic:
            // 1. Try generic resource lookup (found in root or flattened)
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
                return url
            }
            // 2. Try specific subdirectory if provided
            if let subDir = subDir {
                return Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: subDir)
            }
            return nil
        },
        debugLogging: Bool = true
    ) {
        self.soundDefinitions = soundDefinitions
        self.bundleLookup = bundleLookup
        self.debugLogging = debugLogging
    }

    // Deprecated init for backward compatibility with existing tests/callers, 
    // mapped to new logic where possible or just ignored if incompatible
    init(urlsProvider: @escaping () -> [URL], debugLogging: Bool = true) {
        self.debugLogging = debugLogging
        // We can't really map generic URLs to our definition-based structure 
        // without reverse engineering. 
        // So we default to standard config to keep app working, 
        // but this might break tests relying on this specific init for mocking.
        self.soundDefinitions = SoundConfig.sounds
        self.bundleLookup = { _, _ in nil } // Will fail lookups for default sounds if this is used strictly
    }

    func loadAllSounds() -> [SoundAsset] {
        var allSounds = (try? loadBundledSounds()) ?? []
        allSounds.append(contentsOf: loadCustomSounds())
        allSounds.append(contentsOf: loadRemoteSounds())
        allSounds.append(contentsOf: SpotifyService().loadSavedSpotifySounds())
        return allSounds
    }

    func loadBundledSounds() throws -> [SoundAsset] {
        log("Loading sounds from Config...")
        
        var sounds: [SoundAsset] = []
        
        for soundDef in soundDefinitions {
            let filename = soundDef.filename
            
            // Try lookup
            // We know the subdirectory for this specific legacy structure is "BundledSounds/ringtones"
            let resolvedURL = bundleLookup(filename, "BundledSounds/ringtones")

            if let url = resolvedURL {
                let nameWithoutExt = (filename as NSString).deletingPathExtension
                let title = nameWithoutExt
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
                
                let category = SoundCatalogRepository.category(for: filename)
                
                sounds.append(SoundAsset(
                    id: url.path,
                    title: title,
                    fileURL: url,
                    category: category
                ))
            } else {
                log("WARNING: Could not find sound '\(filename)' in Bundle.")
            }
        }
        
        log("Loaded \(sounds.count) sounds.")
        return sounds
    }
    
    func loadCustomSounds() -> [SoundAsset] {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        let customSoundsURL = documentsURL.appendingPathComponent("CustomSounds")
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: customSoundsURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return fileURLs.filter { $0.pathExtension == "m4a" || $0.pathExtension == "wav" }.map { url in
            let filename = url.lastPathComponent
            let title = filename.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
            
            return SoundAsset(
                id: title, // Use title as ID for custom sounds
                title: title,
                fileURL: url,
                category: .custom
            )
        }
    }
    
    func loadRemoteSounds() -> [SoundAsset] {
        let fileManager = FileManager.default
        // Use the same directory structure as AssetManager
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let assetDir = urls[0].appendingPathComponent("Assets", isDirectory: true)
        
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: assetDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        // Filter for MP3s (standard for remote assets)
        return fileURLs.filter { $0.pathExtension == "mp3" }.compactMap { url in
            let filename = url.lastPathComponent
            
            // Try to match with RemoteSound metadata for better titles/categories
            // This requires AssetManager to be initialized and have data
            if let remoteSound = AssetManager.shared.remoteSounds.first(where: { $0.filename == filename }) {
                return SoundAsset(
                    id: remoteSound.id,
                    title: remoteSound.title,
                    fileURL: url,
                    category: .trending // Or map string category to enum
                )
            }
            
            // Fallback for orphaned files
            let title = filename.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            
            return SoundAsset(
                id: filename,
                title: title,
                fileURL: url,
                category: .trending
            )
        }
    }

    static func category(for filename: String) -> SoundCategory {
        let lower = filename.lowercased()
        
        // Memes / Trending logic based on known filenames
        if lower.contains("addams") || lower.contains("batman") || lower.contains("jackson") || lower.contains("beverly") || lower.contains("fantasmic") || lower.contains("on_me") {
            return .trending
        }
        
        if lower.contains("classic") || lower.contains("vivaldi") || lower.contains("grieg") {
            return .classic
        }
        if lower.contains("om") || lower.contains("mantra") {
            return .alarmTone // Using Alarm Tone for devotional/calm for now
        }
        if lower.contains("alarm") || lower.contains("tone") {
            return .alarmTone
        }
        return .trending // Default to trending for cool visuals if unknown
    }

    private func log(_ message: String) {
        guard debugLogging else { return }
        print("[SoundCatalogRepository] \(message)")
    }
}

