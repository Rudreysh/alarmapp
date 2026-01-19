import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer

struct SoundPickerView: View {
    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var sounds: [SoundAsset] = []
    @State private var nowPlaying: String? = nil
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
    @StateObject private var audioPlayer = AudioPreviewPlayer()

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
                            ForEach(filteredSounds) { sound in
                                SoundRow(
                                    sound: sound,
                                    isSelected: selectedSound == sound.title,
                                    isPlaying: nowPlaying == sound.title,
                                    isBuffering: nowPlaying == sound.title && audioPlayer.isBuffering
                                ) { action in
                                    switch action {
                                    case .select:
                                        selectedSound = sound.title
                                        // Play on select? Usually yes.
                                        togglePlay(sound: sound)
                                    case .play:
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
            audioPlayer.stop()
            nowPlaying = nil
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
                    do {
                        try customSoundService.saveImportedFile(from: url, name: title)
                        loadSounds()
                        selectedTab = .custom
                    } catch {
                        print("Error importing music: \(error)")
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
        if nowPlaying == sound.title {
            audioPlayer.stop()
            nowPlaying = nil
        } else {
            audioPlayer.stop() // Stop previous
            audioPlayer.play(url: sound.fileURL, volume: 1.0, fadeIn: false)
            nowPlaying = sound.title
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
