import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer

struct SoundPickerView: View {
    private enum TopTab: Hashable, Identifiable {
        case category(SoundCategory)
        case downloadable(String)

        var id: String {
            switch self {
            case .category(let category): return "cat:\(category.id)"
            case .downloadable(let name): return "cloud:\(name.lowercased())"
            }
        }

        var title: String {
            switch self {
            case .category(let category): return category.title
            case .downloadable(let name): return name
            }
        }

        var emoji: String? {
            switch self {
            case .category(let category): return category.emoji
            case .downloadable: return nil
            }
        }
    }

    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var sounds: [SoundAsset] = []
    @State private var selectedTab: SoundCategory = .alarmTone
    @State private var selectedCloudCategory: String? = nil
    
    // Add Logic
    @State private var showMusicPicker = false
    @State private var showSpotifyPicker = false
    @State private var showAddSheet = false
    @State private var showRecorder = false
    @State private var showFileImporter = false
    @State private var renameTargetSound: SoundAsset?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    @State private var deleteTargetSound: SoundAsset?
    @State private var showDeleteConfirmation = false
    private let customSoundService = CustomSoundService()
    private let spotifyService = SpotifyService()

    private let repository = SoundCatalogRepository()
    @ObservedObject private var assetManager = AssetManager.shared

    @ObservedObject var soundPlayer: SoundPreviewPlayer
    
    private var downloadableSections: [(category: String, sounds: [RemoteSound])] {
        assetManager.remoteSoundsByCategory.filter { 
            let cat = $0.category.lowercased()
            return cat != "alarm" && cat != "focus"
        }
    }

    private var topTabs: [TopTab] {
        var tabs: [TopTab] = [.category(.favorites), .category(.alarmTone), .category(.focus)]
        tabs += downloadableSections.map { .downloadable($0.category) }
        tabs += [.category(.custom), .category(.spotify)]
        return tabs
    }

    private var currentCloudCategory: String {
        if let selectedCloudCategory,
           downloadableSections.contains(where: { $0.category == selectedCloudCategory }) {
            return selectedCloudCategory
        }
        return downloadableSections.first?.category ?? ""
    }

    private func isTopTabSelected(_ tab: TopTab) -> Bool {
        switch tab {
        case .category(let category):
            return selectedTab == category
        case .downloadable(let name):
            return selectedTab == .cloud && currentCloudCategory == name
        }
    }

    private func selectTopTab(_ tab: TopTab) {
        switch tab {
        case .category(let category):
            selectedTab = category
        case .downloadable(let name):
            selectedTab = .cloud
            selectedCloudCategory = name
        }
    }
    
    // Fallback init for previews if needed
    init(selectedSound: Binding<String>, soundPlayer: SoundPreviewPlayer = SoundPreviewPlayer.shared) {
        _selectedSound = selectedSound
        self.soundPlayer = soundPlayer
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                    Spacer()
                    Text("Sound")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    // Balance spacer
                     Image(systemName: "chevron.left").opacity(0)
                        
                }
                .padding()
                
                
                // Categories (Tabs)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(topTabs) { tab in
                            TopTabPill(
                                title: tab.title,
                                emoji: tab.emoji,
                                isSelected: isTopTabSelected(tab)
                            ) {
                                selectTopTab(tab)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
                
                // List
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        VStack(spacing: 0) {
                            if selectedTab == .cloud {
                                // REMOTE SOUNDS LIST (category selected from top tabs)
                                if assetManager.isLoadingCatalog {
                                    ProgressView("Loading valid sounds...")
                                        .padding()
                                } else if assetManager.remoteSounds.isEmpty {
                                    VStack(spacing: 12) {
                                        Text("No downloadable sounds found.")
                                            .foregroundColor(Colors.textSecondary)
                                        Button("Refresh Catalog") {
                                            Task { await assetManager.fetchCatalog() }
                                        }
                                        .font(.caption)
                                        .foregroundColor(Colors.accentTeal)
                                    }
                                    .padding()
                                    .onAppear {
                                        if assetManager.remoteSounds.isEmpty {
                                            Task { await assetManager.fetchCatalog() }
                                        }
                                    }
                                } else {
                                    VStack(spacing: 12) {
                                        if let section = downloadableSections.first(where: { $0.category == currentCloudCategory }) {
                                            VStack(spacing: 0) {
                                                ForEach(section.sounds) { remoteSound in
                                                    let isStarred = sounds.first(where: { $0.id == remoteSound.id })?.isStarred ?? false
                                                    RemoteSoundRow(
                                                        remoteSound: remoteSound,
                                                        isSelected: selectedSound == remoteSound.title,
                                                        isPlaying: soundPlayer.isPlaying && soundPlayer.playingResourceName == remoteSound.title,
                                                        isBuffering: soundPlayer.isBuffering && soundPlayer.playingResourceName == remoteSound.title,
                                                        isStarred: isStarred,
                                                        onSelect: {
                                                            loadSounds()
                                                            selectedSound = remoteSound.title
                                                            if let url = assetManager.localURL(for: remoteSound.filename) {
                                                                togglePlay(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud))
                                                            }
                                                        },
                                                        onPreview: {
                                                            if soundPlayer.isPlaying && soundPlayer.playingResourceName == remoteSound.title {
                                                                soundPlayer.stop()
                                                            } else {
                                                                soundPlayer.playStreamURL(remoteSound.url, resourceName: remoteSound.title)
                                                            }
                                                        },
                                                        onToggleStar: {
                                                            toggleStar(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: remoteSound.url, category: .cloud, isStarred: isStarred))
                                                        }
                                                    )

                                                    Divider()
                                                        .background(Colors.cardStroke)
                                                        .padding(.leading, 16)
                                                }
                                            }
                                            .background(Colors.cardSurface.opacity(0.3))
                                            .cornerRadius(16)
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            } else {
                                // LOCAL & FAVORITES SOUNDS
                                if selectedTab == .favorites && filteredSounds.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "star.slash")
                                            .font(.system(size: 40))
                                            .foregroundColor(Colors.textTertiary)
                                        Text("No favorites yet")
                                            .font(.headline)
                                            .foregroundColor(Colors.textPrimary)
                                        Text("Tap the star on any sound to add it to your favorites for quick access.")
                                            .font(.subheadline)
                                            .foregroundColor(Colors.textSecondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                    }
                                    .padding(.vertical, 60)
                                } else {
                                    ForEach(filteredSounds) { sound in
                                        if sound.category == .custom {
                                            SwipeableSoundRow(
                                                onRename: { beginRename(sound) },
                                                onDelete: { beginDelete(sound) }
                                            ) {
                                                    SoundRow(
                                                        sound: sound,
                                                        isSelected: selectedSound == sound.title,
                                                        isPlaying: soundPlayer.isPlaying && soundPlayer.playingResourceName == sound.title,
                                                        isBuffering: soundPlayer.isBuffering && soundPlayer.playingResourceName == sound.title
                                                    ) { action in
                                                        switch action {
                                                        case .select:
                                                            selectedSound = sound.title
                                                            togglePlay(sound: sound)
                                                        case .play:
                                                            selectedSound = sound.title
                                                            print("[SoundPicker] Play tapped -> selectedSound set to \(sound.title)")
                                                            togglePlay(sound: sound)
                                                        case .toggleStar:
                                                            toggleStar(sound: sound)
                                                        }
                                                    }
                                                .background(
                                                    LinearGradient(
                                                        colors: [Colors.cardSurface, Colors.bgPrimary],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .cornerRadius(12)
                                            }
                                            .contextMenu {
                                                Button {
                                                    beginRename(sound)
                                                } label: {
                                                    Label("Rename", systemImage: "pencil")
                                                }
                                                
                                                Button(role: .destructive) {
                                                    beginDelete(sound)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        } else {
                                            SoundRow(
                                                sound: sound,
                                                isSelected: selectedSound == sound.title,
                                                isPlaying: soundPlayer.isPlaying && soundPlayer.playingResourceName == sound.title,
                                                isBuffering: soundPlayer.isBuffering && soundPlayer.playingResourceName == sound.title
                                            ) { action in
                                                switch action {
                                                case .select:
                                                    selectedSound = sound.title
                                                    togglePlay(sound: sound)
                                                case .play:
                                                    // Keep UI selection in sync with the currently previewing sound.
                                                    selectedSound = sound.title
                                                    print("[SoundPicker] Play tapped -> selectedSound set to \(sound.title)")
                                                    togglePlay(sound: sound)
                                                case .toggleStar:
                                                    toggleStar(sound: sound)
                                                }
                                            }
                                        }
                                        
                                        // Divider
                                        if sound != filteredSounds.last {
                                            Divider()
                                                .background(Colors.cardStroke)
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100) // Space for FAB
                    }
                }
            }
            
            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showAddSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.11, green: 0.20, blue: 0.34).opacity(0.95),
                                            Color(red: 0.06, green: 0.13, blue: 0.24).opacity(0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .background(.ultraThinMaterial, in: Circle())
                            
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Colors.accentTeal.opacity(0.85), Color.white.opacity(0.22)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundColor(Colors.accentTeal)
                            
                            // Plus badge
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Colors.accentTeal, Colors.accentBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 14, y: -14)
                        }
                        .frame(width: 56, height: 56)
                        .shadow(color: Colors.accentBlue.opacity(0.24), radius: 10, x: 0, y: 5)
                        .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
            loadSounds()
            // Stop any preview that might be playing from the previous screen
            soundPlayer.stop()
            Task { await assetManager.fetchCatalog() }
        }
        .onReceive(assetManager.$remoteSounds) { _ in
            loadSounds()
        }
        .onDisappear {
            // Optional: stop when leaving picker? 
            // User might want to keep hearing preview while going back?
            // "stop it while playing" was requested for the Play button.
            // When navigating back, usually we stop.
            soundPlayer.stop()
        }
        // Custom Sound Sheet
        .sheet(isPresented: $showAddSheet) {
            AddSoundSheet(
                onImport: {
                    #if targetEnvironment(simulator)
                    print("Apple Music import is not supported on the iOS Simulator. Please test on a physical device.")
                    // Optionally show an alert to user
                    #else
                    Task {
                        let granted = await customSoundService.checkMediaLibraryPermission()
                        if granted {
                             showAddSheet = false
                             // Delay to ensure the "AddSoundSheet" is fully dismissed 
                             // to avoid "detached view controller" issues
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                 showMusicPicker = true
                             }
                        } else {
                            print("Media Library permission denied or restricted.")
                        }
                    }
                    #endif
                },
                onRecord: {
                    showAddSheet = false
                    showRecorder = true
                },
                onSpotify: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showSpotifyPicker = true
                    }
                }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showMusicPicker) {
            MusicPicker(isPresented: $showMusicPicker) { item in
                // Handle item
                if let url = item.assetURL {
                    // Try to export/copy
                    let title = item.title ?? "Unknown Song"
                    Task {
                        do {
                            try await customSoundService.saveImportedFile(from: url, name: title)
                            await MainActor.run {
                                loadSounds()
                                selectedTab = .custom
                            }
                        } catch {
                            print("Error importing music: \(error)")
                        }
                    }
                } else {
                    print("No local asset URL for this item (cloud item?)")
                }
            }
        }
        .sheet(isPresented: $showSpotifyPicker) {
            SpotifyPickerView(isPresented: $showSpotifyPicker) { track in
                spotifyService.saveSpotifyTrackAsSound(track: track)
                loadSounds()
                selectedTab = .spotify
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            SoundRecorderView(isPresented: $showRecorder) {
                loadSounds() // Reload 
                selectedTab = .custom // Switch to custom to show it
            }
        }
        .alert("Rename Sound", isPresented: $showRenameAlert) {
            TextField("Sound Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTargetSound = nil
                renameText = ""
            }
            Button("Save") {
                commitRename()
            }
        } message: {
            Text("Enter a new name for this recorded sound.")
        }
        .alert("Delete Sound?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                deleteTargetSound = nil
            }
            Button("Delete", role: .destructive) {
                commitDelete()
            }
        } message: {
            Text("This sound will be removed permanently.")
        }
        // Removed fileImporter since user specifically requested Apple Music
        // .fileImporter(...)
    }
    
    private var filteredSounds: [SoundAsset] {
        if selectedTab == .favorites {
            return sounds.filter { $0.isStarred }
        }
        if selectedTab == .alarmTone {
            return sounds.filter { $0.category == .alarmTone || $0.category == .loud || $0.category == .classic }
        }
        return sounds.filter { $0.category == selectedTab }
    }
    
    private func loadSounds() {
        sounds = repository.loadAllSounds()
    }
    
    private func togglePlay(sound: SoundAsset) {
        if soundPlayer.isPlaying && soundPlayer.playingResourceName == sound.title {
            print("[SoundPicker] Stop preview: \(sound.title)")
            soundPlayer.stop()
        } else {
            print("[SoundPicker] Play tapped -> selectedSound set to \(sound.title)")
            soundPlayer.play(resourceName: sound.title, volume: 1.0)
        }
    }

    private func toggleStar(sound: SoundAsset) {
        repository.toggleStar(soundID: sound.id)
        loadSounds()
    }

    private func beginRename(_ sound: SoundAsset) {
        renameTargetSound = sound
        renameText = sound.title
        showRenameAlert = true
    }

    private func commitRename() {
        defer {
            renameTargetSound = nil
            renameText = ""
        }

        guard let target = renameTargetSound else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != target.title else { return }

        do {
            _ = try customSoundService.renameCustomSound(from: target.fileURL, to: trimmed)
            if soundPlayer.isPlaying && soundPlayer.playingResourceName == target.title {
                soundPlayer.stop()
            }
            if selectedSound == target.title {
                selectedSound = trimmed
            }
            loadSounds()
            selectedTab = .custom
        } catch {
            print("Failed to rename sound: \(error)")
        }
    }

    private func beginDelete(_ sound: SoundAsset) {
        deleteTargetSound = sound
        showDeleteConfirmation = true
    }

    private func commitDelete() {
        defer { deleteTargetSound = nil }
        guard let target = deleteTargetSound else { return }

        do {
            if soundPlayer.isPlaying && soundPlayer.playingResourceName == target.title {
                soundPlayer.stop()
            }
            try customSoundService.deleteCustomSound(at: target.fileURL)
            loadSounds()
            selectedTab = .custom
            if selectedSound == target.title {
                selectedSound = sounds.first?.title ?? selectedSound
            }
        } catch {
            print("Failed to delete sound: \(error)")
        }
    }
}

// Subviews
private struct TopTabPill: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Colors.accentTeal : Colors.cardSurface)
            .foregroundColor(isSelected ? .white : Colors.textPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct CategoryPill: View {
    let category: SoundCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = category.emoji {
                    Text(emoji).font(.caption)
                }
                Text(category.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? Colors.accentTeal : Colors.cardSurface)
            .foregroundColor(isSelected ? .white : Colors.textPrimary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct SoundRow: View {
    let sound: SoundAsset
    let isSelected: Bool
    let isPlaying: Bool
    let isBuffering: Bool
    let onAction: (Action) -> Void
    
    enum Action {
        case select
        case play
        case toggleStar
    }
    
    private var isSpotifyTrack: Bool {
        sound.category == .spotify && (
            sound.fileURL.absoluteString.contains("open.spotify.com") ||
            sound.fileURL.absoluteString.hasPrefix("spotify:")
        )
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Selection Area
            HStack(spacing: 16) {
                // Radio icon
                Circle()
                    .strokeBorder(isSelected ? Colors.accentTeal : Colors.textTertiary, lineWidth: 2)
                    .background(Circle().fill(isSelected ? Colors.accentTeal : Color.clear))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(.body)
                        .foregroundColor(Colors.textPrimary)
                    
                    if isBuffering {
                        Text("Loading...")
                            .font(.caption2)
                            .foregroundColor(Colors.accentTeal)
                    } else if isSpotifyTrack {
                        Text("Opens in Spotify")
                            .font(.caption2)
                            .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onAction(.select)
            }
            .padding(.vertical, 12)
            .padding(.leading)
            
            // Star Button
            Button(action: {
                onAction(.toggleStar)
            }) {
                Image(systemName: sound.isStarred ? "star.fill" : "star")
                    .font(.system(size: 18))
                    .foregroundColor(sound.isStarred ? .yellow : Colors.textTertiary)
                    .frame(width: 44, height: 56)
                    .contentShape(Rectangle())
            }

            // Play Button Area (dedicated hit area)
            Button(action: {
                onAction(.play)
            }) {
                ZStack {
                    if isBuffering {
                        ProgressView()
                            .tint(Colors.textPrimary)
                            .scaleEffect(0.8)
                    } else if isPlaying {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textPrimary)
                    } else if isSpotifyTrack {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
            }
            .padding(.trailing, 4)
        }
    }
}

struct AddSoundSheet: View {
    var onImport: () -> Void
    var onRecord: () -> Void
    var onSpotify: () -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Text("Add my own")
                    .font(.title3.bold())
                    .foregroundColor(Colors.textPrimary)
                    .padding(24)
                
                VStack(spacing: 8) {
                    Button(action: onImport) {
                        HStack(spacing: 16) {
                            Image(systemName: "apple.logo") // Close enough for Apple Music
                                .font(.system(size: 20))
                            Text("Import from Apple Music")
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(Colors.textTertiary)
                        }
                        .foregroundColor(Colors.textPrimary)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onSpotify) {
                        HStack(spacing: 16) {
                            Image(systemName: "music.note.house.fill") // Placeholder for Spotify
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                            Text("Connect to Spotify")
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(Colors.textTertiary)
                        }
                        .foregroundColor(Colors.textPrimary)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onRecord) {
                        HStack(spacing: 16) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 20))
                            Text("Record")
                                .font(.body.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(Colors.textTertiary)
                        }
                        .foregroundColor(Colors.textPrimary)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

struct RemoteSoundRow: View {
    let remoteSound: RemoteSound
    let isSelected: Bool
    let isPlaying: Bool
    let isBuffering: Bool
    let isStarred: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onToggleStar: () -> Void

    @ObservedObject private var assetManager = AssetManager.shared
    @State private var downloadProgress: Double = 0.0

    init(
        remoteSound: RemoteSound,
        isSelected: Bool,
        isPlaying: Bool,
        isBuffering: Bool = false,
        isStarred: Bool = false,
        onSelect: @escaping () -> Void,
        onPreview: @escaping () -> Void = {},
        onToggleStar: @escaping () -> Void = {}
    ) {
        self.remoteSound = remoteSound
        self.isSelected = isSelected
        self.isPlaying = isPlaying
        self.isBuffering = isBuffering
        self.isStarred = isStarred
        self.onSelect = onSelect
        self.onPreview = onPreview
        self.onToggleStar = onToggleStar
    }

    private let oceanBlue = Color(red: 0.1, green: 0.5, blue: 0.9)

    private var isDownloaded: Bool { assetManager.fileExists(filename: remoteSound.filename) }
    private var isDownloading: Bool { assetManager.isDownloading(filename: remoteSound.filename) }

    var body: some View {
        HStack(spacing: 0) {
            // ── Left status icon ──────────────────────────────────────────
            ZStack {
                if isDownloading {
                    // Circular progress ring
                    ZStack {
                        Circle()
                            .stroke(Colors.textSecondary.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: downloadProgress)
                            .stroke(oceanBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: downloadProgress)
                    }
                    .frame(width: 24, height: 24)
                } else if isDownloaded {
                    Circle()
                        .strokeBorder(isSelected ? oceanBlue : Colors.textTertiary, lineWidth: 2)
                        .background(Circle().fill(isSelected ? oceanBlue : Color.clear))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .opacity(isSelected ? 1 : 0)
                        )
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundColor(oceanBlue.opacity(0.8))
                        .font(.system(size: 22))
                }
            }
            .frame(width: 24, height: 24)
            .padding(.leading, 16)

            // ── Title + subtitle ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text(remoteSound.title)
                    .font(.body)
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(1)

                Group {
                    if isDownloading {
                        Text("Downloading \(Int(downloadProgress * 100))%…")
                            .foregroundColor(oceanBlue)
                    } else if isBuffering {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.5).tint(oceanBlue)
                            Text("Buffering…").foregroundColor(oceanBlue)
                        }
                    } else if isPlaying && !isDownloaded {
                        Text("Streaming preview…").foregroundColor(oceanBlue)
                    } else if isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Downloaded · tap row or ▶ to play")
                        }
                        .foregroundColor(Colors.textTertiary)
                    } else {
                        Text("Tap ▶ to preview  ·  ↓ to download")
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if isDownloaded { onSelect() }
                // Tapping a non-downloaded row does nothing — user must use the play/download buttons
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)

            // ── Star ──────────────────────────────────────────────────────
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    onToggleStar()
                }
            }) {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .font(.system(size: 18))
                    .foregroundColor(isStarred ? .yellow : Colors.textTertiary)
                    .scaleEffect(isStarred ? 1.15 : 1.0)
                    .frame(width: 40, height: 56)
                    .contentShape(Rectangle())
            }

            // ── Download button (only if NOT downloaded and NOT downloading) ──
            if !isDownloaded && !isDownloading {
                Button(action: { startDownload() }) {
                    HStack(spacing: 4) {
                        Text("Get")
                            .font(.system(size: 12, weight: .bold))
                            .textCase(.uppercase)
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(oceanBlue)
                    .cornerRadius(12)
                }
                .padding(.trailing, 8)
            }

            // ── Cancel button (only while downloading) ────────────────────
            if isDownloading {
                Button(action: {
                    Task { await AssetManager.shared.cancelDownload(filename: remoteSound.filename) }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 40, height: 56)
                        .contentShape(Rectangle())
                }
            }

            // ── Preview / Play / Stop button ──────────────────────────────
            Button(action: {
                if isDownloaded {
                    onSelect()
                } else if !isDownloading {
                    onPreview()
                }
            }) {
                HStack(spacing: 6) {
                    if !isDownloaded && !isDownloading && !isPlaying && !isBuffering {
                        Text("Preview")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(oceanBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(oceanBlue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    ZStack {
                        if isBuffering {
                            ProgressView().tint(oceanBlue).scaleEffect(0.8)
                        } else if isPlaying {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDownloaded ? Colors.textPrimary : oceanBlue)
                        } else if !isDownloading {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDownloaded ? Colors.textSecondary : oceanBlue.opacity(0.85))
                        } else {
                            Color.clear
                        }
                    }
                }
                .frame(minWidth: 48, minHeight: 56)
                .contentShape(Rectangle())
            }
            .padding(.trailing, 4)
        }
    }

    private func startDownload() {
        Task {
            do {
                _ = try await AssetManager.shared.downloadAsset(
                    from: remoteSound.url,
                    filename: remoteSound.filename,
                    progress: { p in
                        Task { @MainActor in self.downloadProgress = p }
                    }
                )
                // After download, the published `fileExists` check in assetDirectory
                // will automatically refresh via @ObservedObject assetManager bindings
                await MainActor.run { self.downloadProgress = 0 }
            } catch AssetError.cancelled {
                await MainActor.run { self.downloadProgress = 0 }
            } catch {
                print("❌ Download failed: \(error)")
                await MainActor.run { self.downloadProgress = 0 }
            }
        }
    }
}
