import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer

struct SoundPickerView: View {
    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var sounds: [SoundAsset] = []
    @State private var selectedTab: SoundCategory = .trending
    
    // Add Logic
    @State private var showMusicPicker = false
    @State private var showSpotifyPicker = false
    @State private var showAddSheet = false
    @State private var showRecorder = false
    @State private var showFileImporter = false
    private let customSoundService = CustomSoundService()
    private let spotifyService = SpotifyService()

    private let repository = SoundCatalogRepository()
    @ObservedObject private var assetManager = AssetManager.shared

    @ObservedObject var soundPlayer: SoundPreviewPlayer
    
    // Fallback init for previews if needed, but primarily intended to be injected
    init(selectedSound: Binding<String>, soundPlayer: SoundPreviewPlayer = SoundPreviewPlayer()) {
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
                
                // Search Stub (User image 2 shows "Request the sound I want")
                // I won't implement full search request logic, just the visual stub
                Button(action: {
                    // Placeholder
                }) {
                    HStack {
                        Text("🥁🎤🎹 Request the sound I want")
                            .font(.subheadline)
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding()
                    .background(Colors.cardSurface)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                // Categories (Tabs)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SoundCategory.order) { category in
                            CategoryPill(
                                category: category,
                                isSelected: selectedTab == category
                            ) {
                                selectedTab = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
                
                // List
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Show current category header and items
                        // Or Filter logic: Just show items for selected tab
                        
                        // Header for section
                        HStack(spacing: 8) {
                            Text(selectedTab.emoji ?? "")
                            Text(selectedTab.title)
                                .font(.headline)
                                .foregroundColor(Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            if selectedTab == .cloud {
                                // REMOTE SOUNDS LIST
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
                                // REMOTE SOUNDS UI with SECTIONS & SCROLL ANCHOR
                                ScrollViewReader { proxy in
                                    // 1. Top Category Pills
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(assetManager.remoteSoundsByCategory, id: \.category) { section in
                                                Button(action: {
                                                    withAnimation {
                                                        proxy.scrollTo(section.category, anchor: .top)
                                                    }
                                                }) {
                                                    Text(section.category)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal, 16)
                                                        .background(Colors.cardSurface)
                                                        .foregroundColor(Colors.textPrimary)
                                                        .cornerRadius(20)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .stroke(Colors.cardStroke, lineWidth: 1)
                                                        )
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.bottom, 8)
                                    }

                                    // 2. Vertical Sections
                                    ScrollView {
                                        VStack(spacing: 24) {
                                            ForEach(assetManager.remoteSoundsByCategory, id: \.category) { section in
                                                VStack(alignment: .leading, spacing: 12) {
                                                    // Section Header
                                                    Text(section.category)
                                                        .font(.headline)
                                                        .foregroundColor(Colors.textPrimary)
                                                        .padding(.horizontal)
                                                        .id(section.category) // Anchor
                                                    
                                                    // Items
                                                    ForEach(section.sounds) { remoteSound in
                                                        RemoteSoundRow(
                                                            remoteSound: remoteSound,
                                                            isSelected: selectedSound == remoteSound.title,
                                                            isPlaying: soundPlayer.isPlaying && soundPlayer.playingResourceName == remoteSound.title,
                                                            onSelect: {
                                                                if let url = assetManager.localURL(for: remoteSound.filename) {
                                                                    selectedSound = remoteSound.title
                                                                    togglePlay(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud))
                                                                } else {
                                                                    Task {
                                                                        do {
                                                                            let url = try await assetManager.downloadAsset(from: remoteSound.url, filename: remoteSound.filename)
                                                                            await MainActor.run {
                                                                                loadSounds()
                                                                                selectedSound = remoteSound.title
                                                                                togglePlay(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud))
                                                                            }
                                                                        } catch {
                                                                            print("Failed to download: \(error)")
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        )
                                                        
                                                        Divider()
                                                            .background(Colors.cardStroke)
                                                            .padding(.leading, 16)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.bottom, 100)
                                    }
                            }
                        }
                    } else {
                                // LOCAL SOUNDS
                                ForEach(filteredSounds) { sound in
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
                        Circle()
                            .fill(Color.white)
                            .frame(width: 56, height: 56)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            .overlay(
                                ZStack {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 24, weight: .regular))
                                        .foregroundColor(.black)
                                    
                                    // Plus badge
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(3)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            )
                    }
                    .padding(24)
                }
            }
        }
        .onAppear {
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
        // Removed fileImporter since user specifically requested Apple Music
        // .fileImporter(...)
    }
    
    private var filteredSounds: [SoundAsset] {
        sounds.filter { $0.category == selectedTab }
    }
    
    private func loadSounds() {
        sounds = repository.loadAllSounds()
    }
    
    private func togglePlay(sound: SoundAsset) {
        if soundPlayer.isPlaying && soundPlayer.playingResourceName == sound.title {
            print("[SoundPicker] Stop preview: \(sound.title)")
            soundPlayer.stop()
        } else {
            print("[SoundPicker] Start preview: \(sound.title)")
            soundPlayer.play(resourceName: sound.title, volume: 1.0)
        }
    }
}

// Subviews
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
            .background(isSelected ? Color.white : Colors.cardSurface)
            .foregroundColor(isSelected ? .black : Colors.textPrimary)
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
    }
    
    private var isSpotifyTrack: Bool {
        sound.category == .spotify && (
            sound.fileURL.absoluteString.contains("open.spotify.com") ||
            sound.fileURL.absoluteString.hasPrefix("spotify:")
        )
    }
    
    var body: some View {
        Button(action: { onAction(.select) }) {
            HStack(spacing: 16) {
                // Radio
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
                
                // Play Button
                Button(action: { onAction(.play) }) {
                    if isBuffering {
                        ProgressView()
                            .tint(Colors.textPrimary)
                            .scaleEffect(0.8)
                    } else if isPlaying {
                        Image(systemName: "stop.fill")
                            .foregroundColor(Colors.textPrimary)
                    } else if isSpotifyTrack {
                        // Spotify-style play icon
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                    } else {
                        Image(systemName: "play.fill")
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
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
                            Text("Import from Apple Music") // Text per user image
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
                        .foregroundColor(Colors.textPrimary) // Usually white
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
    let onSelect: () -> Void
    
    @State private var isDownloading = false
    @State private var isDownloaded = false
    
    var body: some View {
        Button(action: {
            if !isDownloading {
                // If not downloaded, trigger download
                if !isDownloaded {
                    isDownloading = true
                }
                onSelect()
            }
        }) {
            HStack(spacing: 16) {
                // Icon: Cloud or Check
                ZStack {
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else if isDownloaded {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundColor(Colors.accentTeal)
                            .font(.system(size: 22))
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(Colors.textSecondary)
                            .font(.system(size: 22))
                    }
                }
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(remoteSound.title)
                        .font(.body)
                        .foregroundColor(Colors.textPrimary)
                    
                    Text(isDownloaded ? "Downloaded" : "Tap to download")
                        .font(.caption2)
                        .foregroundColor(Colors.textTertiary)
                }
                
                Spacer()
                
                // Play Button (only if downloaded)
                if isDownloaded {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .foregroundColor(Colors.textSecondary)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
        .onAppear {
            checkStatus()
        }
        // Assuming parent view triggers redraw or we can observe asset manager
        .onChange(of: AssetManager.shared.remoteSounds) { _ in
            checkStatus() // Recheck if list reloads or cache updates
        }
        // Also need to check when download completes. 
        // The parent view's onSelect updates the UI, but ideally we observe file existence.
    }
    
    private func checkStatus() {
        isDownloaded = AssetManager.shared.fileExists(filename: remoteSound.filename)
        if isDownloaded { isDownloading = false }
    }
}
