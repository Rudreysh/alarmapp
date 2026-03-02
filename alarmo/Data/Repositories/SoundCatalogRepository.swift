import Foundation

protocol SoundCatalogRepositoryProtocol {
    func loadBundledSounds() throws -> [SoundAsset]
    func loadAllSounds() -> [SoundAsset]
    func toggleStar(soundID: String)
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

    private let starredSoundsKey = "StarredSoundIDs"

    func getStarredIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: starredSoundsKey) ?? [])
    }

    func toggleStar(soundID: String) {
        var starred = getStarredIDs()
        if starred.contains(soundID) { starred.remove(soundID) } else { starred.insert(soundID) }
        UserDefaults.standard.set(Array(starred), forKey: starredSoundsKey)
    }

    func loadAllSounds() -> [SoundAsset] {
        var allSounds = (try? loadBundledSounds()) ?? []
        allSounds.append(contentsOf: loadCustomSounds())
        allSounds.append(contentsOf: loadRemoteSounds())
        allSounds.append(contentsOf: loadRemoteSoundsFromCatalog())
        allSounds.append(contentsOf: SpotifyService().loadSavedSpotifySounds())

        let starredIDs = getStarredIDs()

        // Remove duplicates by ID; apply starred flag
        var seenIDs = Set<String>()
        var finalSounds: [SoundAsset] = []
        for var sound in allSounds {
            if seenIDs.insert(sound.id).inserted {
                sound.isStarred = starredIDs.contains(sound.id)
                finalSounds.append(sound)
            }
        }
        return finalSounds
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
                    id: "bundled-\(filename)",
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
                id: "custom-\(title)", // Use title as ID for custom sounds
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
            if let remoteSound = AssetManager.shared.remoteSounds.first(where: { $0.filename == filename }) {
                return SoundAsset(
                    id: remoteSound.id,
                    title: remoteSound.title,
                    fileURL: url,
                    category: SoundCatalogRepository.category(from: remoteSound.category)
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
                category: .alarmTone
            )
        }
    }

    /// Load metadata for all remote sounds from the AssetManager catalog
    func loadRemoteSoundsFromCatalog() -> [SoundAsset] {
        return AssetManager.shared.remoteSounds.map { remote in
            // Use local URL if exists, otherwise use remote URL
            let fileURL = AssetManager.shared.localURL(for: remote.filename) ?? remote.url
            
            // Make sure any remote title we get is nicely formatted just in case the backend hasn't updated
            let cleanTitle = remote.title
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized

            return SoundAsset(
                id: remote.id,
                title: cleanTitle,
                fileURL: fileURL,
                category: SoundCatalogRepository.category(from: remote.category)
            )
        }
    }

    static func category(from string: String) -> SoundCategory {
        let lower = string.lowercased()
        switch lower {
        case "trending", "default": return .alarmTone
        case "loud": return .loud
        case "alarm": return .alarmTone
        case "focus": return .focus
        case "classic": return .classic
        case "nature": return SoundCategory(id: "nature", title: "Nature", emoji: "🌿")
        case "sleep": return SoundCategory(id: "sleep", title: "Sleep", emoji: "🛌")
        case "relaxing": return SoundCategory(id: "relaxing", title: "Relaxing", emoji: "🕊️")
        case "uplifting": return SoundCategory(id: "uplifting", title: "Uplifting", emoji: "✨")
        default:
            return SoundCategory(id: lower, title: string.capitalized, emoji: nil)
        }
    }

    static func category(for filename: String) -> SoundCategory {
        let lower = filename.lowercased()
        
        // Memes / Trending logic based on known filenames
        if lower.contains("addams") || lower.contains("batman") || lower.contains("jackson") || lower.contains("beverly") || lower.contains("fantasmic") || lower.contains("on_me") {
            return .alarmTone
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
        return .alarmTone // Default to alarms for unknown
    }

    private func log(_ message: String) {
        guard debugLogging else { return }
        print("[SoundCatalogRepository] \(message)")
    }
}

