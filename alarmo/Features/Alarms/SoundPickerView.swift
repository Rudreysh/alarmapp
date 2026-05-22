import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer

struct SoundPickerView: View {
    private enum TopTab: Hashable, Identifiable {
        case all
        case category(SoundCategory)
        case downloadable(String)

        var id: String {
            switch self {
            case .all: return "all"
            case .category(let category): return "cat:\(category.id)"
            case .downloadable(let name): return "cloud:\(name.lowercased())"
            }
        }

        var title: String {
            switch self {
            case .all: return "All Sounds"
            case .category(let category): return category.title
            case .downloadable(let name): return name
            }
        }

        var emoji: String? {
            switch self {
            case .all: return "🎵"
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
    @State private var showAllSounds = true
    @State private var activeAllSectionTab: TopTab = .category(.alarmTone)
    @State private var suppressAutoSectionSync = false
    @State private var lockAllTabHighlight = false
    
    // Add Logic
    @State private var showMusicPicker = false
    @State private var showAddSheet = false
    @State private var showRecorder = false
    @State private var showFileImporter = false
    @State private var renameTargetSound: SoundAsset?
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    @State private var deleteTargetSound: SoundAsset?
    @State private var showDeleteConfirmation = false
    private let customSoundService = CustomSoundService()
    // TODO: Re-enable Spotify import flow when this option is brought back.
    // private let spotifyService = SpotifyService()

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
        var tabs: [TopTab] = [.all, .category(.favorites), .category(.alarmTone), .category(.focus)]
        tabs += downloadableSections.map { .downloadable($0.category) }
        tabs += [.category(.downloads), .category(.custom), .category(.spotify)]
        return tabs
    }

    private var allSoundSectionsWithTabs: [(tab: TopTab, title: String, sounds: [SoundAsset])] {
        let localSections: [(TopTab, String, [SoundAsset])] = [
            (.category(.alarmTone), "Alarm Tone", sounds.filter { $0.category == .alarmTone || $0.category == .loud || $0.category == .classic }),
            (.category(.focus), "Focus", sounds.filter { $0.category == .focus }),
            (.category(.downloads), "Downloads", downloadedSounds),
            (.category(.custom), "Custom", sounds.filter { $0.category == .custom }),
            (.category(.spotify), "Spotify", sounds.filter { $0.category == .spotify })
        ]

        let cloudSections: [(TopTab, String, [SoundAsset])] = downloadableSections.map { section in
            let mapped = section.sounds.map { remote in
                SoundAsset(
                    id: remote.id,
                    title: remote.title,
                    fileURL: remote.url,
                    category: .cloud,
                    isStarred: sounds.first(where: { $0.id == remote.id })?.isStarred ?? false
                )
            }
            return (.downloadable(section.category), section.category, mapped)
        }

        return (localSections + cloudSections)
            .map { (tab: $0.0, title: $0.1, sounds: $0.2) }
            .filter { !$0.sounds.isEmpty }
    }

    private var currentCloudCategory: String {
        if let selectedCloudCategory,
           downloadableSections.contains(where: { $0.category == selectedCloudCategory }) {
            return selectedCloudCategory
        }
        return downloadableSections.first?.category ?? ""
    }

    private func isTopTabSelected(_ tab: TopTab) -> Bool {
        if showAllSounds {
            if lockAllTabHighlight {
                if case .all = tab { return true }
                return false
            }
            return tab == activeAllSectionTab
        }
        switch tab {
        case .all:
            return false
        case .category(let category):
            return !showAllSounds && selectedTab == category
        case .downloadable(let name):
            return !showAllSounds && selectedTab == .cloud && currentCloudCategory == name
        }
    }

    private func selectTopTab(_ tab: TopTab, proxy: ScrollViewProxy? = nil) {
        switch tab {
        case .all:
            showAllSounds = true
            lockAllTabHighlight = true
            activeAllSectionTab = allSoundSectionsWithTabs.first?.tab ?? .category(.alarmTone)
        case .category(let category):
            lockAllTabHighlight = false
            if showAllSounds, let proxy {
                scrollToAllSection(for: tab, proxy: proxy)
            } else {
                showAllSounds = false
                selectedTab = category
            }
        case .downloadable(let name):
            lockAllTabHighlight = false
            if showAllSounds, let proxy {
                scrollToAllSection(for: tab, proxy: proxy)
            } else {
                showAllSounds = false
                selectedTab = .cloud
                selectedCloudCategory = name
            }
        }
    }
    
    // Fallback init for previews if needed
    init(selectedSound: Binding<String>, soundPlayer: SoundPreviewPlayer = SoundPreviewPlayer.shared) {
        _selectedSound = selectedSound
        _soundPlayer = ObservedObject(wrappedValue: soundPlayer)
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
                    Button(action: {
                        soundPlayer.stop()
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.accentTeal)
                    }
                        
                }
                .padding()
                
                
                ScrollViewReader { listProxy in
                    ScrollViewReader { tabsProxy in
                        // Categories (Tabs)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(topTabs) { tab in
                                    TopTabPill(
                                        title: tab.title,
                                        emoji: tab.emoji,
                                        isSelected: isTopTabSelected(tab),
                                        isPlaying: isPlayingInCategory(tab)
                                    ) {
                                        selectTopTab(tab, proxy: listProxy)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            tabsProxy.scrollTo(tab.id, anchor: .center)
                                        }
                                    }
                                    .id(tab.id)
                                }
                            }
                            .padding(.horizontal)
                            .onChange(of: activeAllSectionTab) { _, newValue in
                                guard showAllSounds else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    tabsProxy.scrollTo(newValue.id, anchor: .center)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                
                        // List
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {

                            VStack(spacing: 0) {
                                if showAllSounds {
                                    VStack(alignment: .leading, spacing: 22) {
                                        ForEach(Array(allSoundSectionsWithTabs.enumerated()), id: \.offset) { _, section in
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text(section.title)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(Colors.textSecondary)
                                                    .padding(.horizontal)

                                                VStack(spacing: 0) {
                                                    ForEach(Array(section.sounds.enumerated()), id: \.element.id) { index, sound in
                                                        SoundRow(
                                                            sound: sound,
                                                            isSelected: selectedSound == sound.title,
                                                            isPlaying: isSoundPlaying(named: sound.title),
                                                            isBuffering: isSoundBuffering(named: sound.title)
                                                        ) { action in
                                                            switch action {
                                                            case .select, .play:
                                                                selectedSound = sound.title
                                                                if sound.category == .cloud && !sound.fileURL.isFileURL {
                                                                    let remote = RemoteSound(
                                                                        id: sound.id,
                                                                        filename: sound.fileURL.lastPathComponent,
                                                                        title: sound.title,
                                                                        category: section.title,
                                                                        url: sound.fileURL,
                                                                        isPremium: false
                                                                    )
                                                                    if let url = assetManager.localURL(for: remote.filename) {
                                                                        togglePlay(sound: SoundAsset(id: sound.id, title: sound.title, fileURL: url, category: .cloud, isStarred: sound.isStarred))
                                                                    } else {
                                                                        downloadAndPlay(remoteSound: remote)
                                                                    }
                                                                } else {
                                                                    togglePlay(sound: sound)
                                                                }
                                                            case .toggleStar:
                                                                toggleStar(sound: sound)
                                                            }
                                                        }

                                                        if index < section.sounds.count - 1 {
                                                            Divider()
                                                                .background(Colors.cardStroke)
                                                                .padding(.leading, 56)
                                                        }
                                                    }
                                                }
                                                .background(Colors.cardSurface.opacity(0.3))
                                                .cornerRadius(16)
                                                .padding(.horizontal)
                                            }
                                            .id("all-section-\(section.tab.id)")
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: AllSoundsSectionOffsetPreferenceKey.self,
                                                        value: ["all-section-\(section.tab.id)": geo.frame(in: .named("allSoundsScroll")).minY]
                                                    )
                                                }
                                            )
                                        }
                                    }
                                } else if selectedTab == .cloud {
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
                                                    let isDownloaded = assetManager.fileExists(filename: remoteSound.filename)
                                                    
                                                    if isDownloaded {
                                                        SwipeableSoundRow(onDelete: {
                                                            assetManager.deleteLocalFile(filename: remoteSound.filename)
                                                            if isCurrentPlayingResource(named: remoteSound.title) { soundPlayer.stop() }
                                                            loadSounds()
                                                        }) {
                                                            RemoteSoundRow(
                                                                remoteSound: remoteSound,
                                                                isSelected: selectedSound == remoteSound.title,
                                                                isPlaying: isSoundPlaying(named: remoteSound.title),
                                                                isBuffering: isSoundBuffering(named: remoteSound.title),
                                                                isStarred: isStarred,
                                                                onSelect: {
                                                                    loadSounds()
                                                                    selectedSound = remoteSound.title
                                                                    if let url = assetManager.localURL(for: remoteSound.filename) {
                                                                        togglePlay(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud))
                                                                    } else {
                                                                        downloadAndPlay(remoteSound: remoteSound)
                                                                    }
                                                                },
                                                                onPreview: {
                                                                    if isSoundPlaying(named: remoteSound.title) {
                                                                        soundPlayer.stop()
                                                                    } else {
                                                                        soundPlayer.playStreamURL(remoteSound.url, resourceName: remoteSound.title)
                                                                    }
                                                                },
                                                                onToggleStar: {
                                                                    toggleStar(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: remoteSound.url, category: .cloud, isStarred: isStarred))
                                                                }
                                                            )
                                                        }
                                                    } else {
                                                        RemoteSoundRow(
                                                            remoteSound: remoteSound,
                                                            isSelected: selectedSound == remoteSound.title,
                                                            isPlaying: isSoundPlaying(named: remoteSound.title),
                                                            isBuffering: isSoundBuffering(named: remoteSound.title),
                                                            isStarred: isStarred,
                                                            onSelect: {
                                                                loadSounds()
                                                                selectedSound = remoteSound.title
                                                                if let url = assetManager.localURL(for: remoteSound.filename) {
                                                                    togglePlay(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: url, category: .cloud))
                                                                } else {
                                                                    downloadAndPlay(remoteSound: remoteSound)
                                                                }
                                                            },
                                                            onPreview: {
                                                                if isSoundPlaying(named: remoteSound.title) {
                                                                    soundPlayer.stop()
                                                                } else {
                                                                    soundPlayer.playStreamURL(remoteSound.url, resourceName: remoteSound.title)
                                                                }
                                                            },
                                                            onToggleStar: {
                                                                toggleStar(sound: SoundAsset(id: remoteSound.id, title: remoteSound.title, fileURL: remoteSound.url, category: .cloud, isStarred: isStarred))
                                                            }
                                                        )
                                                    }

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
                                                        isPlaying: isSoundPlaying(named: sound.title),
                                                        isBuffering: isSoundBuffering(named: sound.title)
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
                                            let isRemote = !sound.fileURL.isFileURL
                                            
                                            if isRemote {
                                                let remoteSound = RemoteSound(
                                                    id: sound.id,
                                                    filename: sound.fileURL.lastPathComponent,
                                                    title: sound.title,
                                                    category: sound.category.title,
                                                    url: sound.fileURL,
                                                    isPremium: false
                                                )
                                                
                                                let isDownloaded = assetManager.fileExists(filename: sound.fileURL.lastPathComponent)
                                                
                                                if isDownloaded {
                                                    SwipeableSoundRow(onDelete: {
                                                        assetManager.deleteLocalFile(filename: sound.fileURL.lastPathComponent)
                                                        if isCurrentPlayingResource(named: sound.title) { soundPlayer.stop() }
                                                        loadSounds()
                                                    }) {
                                                        RemoteSoundRow(
                                                            remoteSound: remoteSound,
                                                            isSelected: selectedSound == sound.title,
                                                            isPlaying: isSoundPlaying(named: sound.title),
                                                            isBuffering: isSoundBuffering(named: sound.title),
                                                            isStarred: sound.isStarred,
                                                            onSelect: {
                                                                selectedSound = sound.title
                                                                if let url = assetManager.localURL(for: sound.fileURL.lastPathComponent) {
                                                                    let asset = SoundAsset(id: sound.id, title: sound.title, fileURL: url, category: sound.category)
                                                                    togglePlay(sound: asset)
                                                                } else {
                                                                    let remote = RemoteSound(
                                                                        id: sound.id,
                                                                        filename: sound.fileURL.lastPathComponent,
                                                                        title: sound.title,
                                                                        category: sound.category.title,
                                                                        url: sound.fileURL,
                                                                        isPremium: false
                                                                    )
                                                                    downloadAndPlay(remoteSound: remote)
                                                                }
                                                            },
                                                            onPreview: {
                                                                if isSoundPlaying(named: sound.title) {
                                                                    soundPlayer.stop()
                                                                } else {
                                                                    soundPlayer.playStreamURL(sound.fileURL, resourceName: sound.title)
                                                                }
                                                            },
                                                            onToggleStar: {
                                                                toggleStar(sound: sound)
                                                            }
                                                        )
                                                    }
                                                } else {
                                                    RemoteSoundRow(
                                                        remoteSound: remoteSound,
                                                        isSelected: selectedSound == sound.title,
                                                        isPlaying: isSoundPlaying(named: sound.title),
                                                        isBuffering: isSoundBuffering(named: sound.title),
                                                        isStarred: sound.isStarred,
                                                        onSelect: {
                                                            selectedSound = sound.title
                                                            if let url = assetManager.localURL(for: sound.fileURL.lastPathComponent) {
                                                                let asset = SoundAsset(id: sound.id, title: sound.title, fileURL: url, category: sound.category)
                                                                togglePlay(sound: asset)
                                                            } else {
                                                                let remote = RemoteSound(
                                                                    id: sound.id,
                                                                    filename: sound.fileURL.lastPathComponent,
                                                                    title: sound.title,
                                                                    category: sound.category.title,
                                                                    url: sound.fileURL,
                                                                    isPremium: false
                                                                )
                                                                downloadAndPlay(remoteSound: remote)
                                                            }
                                                        },
                                                        onPreview: {
                                                            if isSoundPlaying(named: sound.title) {
                                                                soundPlayer.stop()
                                                            } else {
                                                                soundPlayer.playStreamURL(sound.fileURL, resourceName: sound.title)
                                                            }
                                                        },
                                                        onToggleStar: {
                                                            toggleStar(sound: sound)
                                                        }
                                                    )
                                                }
                                            } else {
                                                SoundRow(
                                                    sound: sound,
                                                    isSelected: selectedSound == sound.title,
                                                    isPlaying: isSoundPlaying(named: sound.title),
                                                    isBuffering: isSoundBuffering(named: sound.title)
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
                        .coordinateSpace(name: "allSoundsScroll")
                        .onPreferenceChange(AllSoundsSectionOffsetPreferenceKey.self) { offsets in
                            guard showAllSounds, !suppressAutoSectionSync else { return }
                            guard let next = currentlyVisibleAllSectionTab(offsets: offsets) else { return }
                            lockAllTabHighlight = false
                            if next != activeAllSectionTab {
                                activeAllSectionTab = next
                            }
                        }
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
            activeAllSectionTab = allSoundSectionsWithTabs.first?.tab ?? .category(.alarmTone)
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
        // TODO: Re-enable Spotify picker sheet when Spotify import is restored.
        // .sheet(isPresented: $showSpotifyPicker) {
        //     SpotifyPickerView(isPresented: $showSpotifyPicker) { track in
        //         spotifyService.saveSpotifyTrackAsSound(track: track)
        //         loadSounds()
        //         selectedTab = .spotify
        //     }
        // }
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
        if showAllSounds {
            return sounds
        }
        if selectedTab == .favorites {
            return sounds.filter { $0.isStarred }
        }
        if selectedTab == .alarmTone {
            return sounds.filter { $0.category == .alarmTone || $0.category == .loud || $0.category == .classic }
        }
        if selectedTab == .downloads {
            return downloadedSounds
        }
        return sounds.filter { $0.category == selectedTab }
    }

    private var downloadedSounds: [SoundAsset] {
        let starredByID = Dictionary(uniqueKeysWithValues: sounds.map { ($0.id, $0.isStarred) })
        let downloaded = assetManager.remoteSounds.compactMap { remote -> SoundAsset? in
            guard let localURL = assetManager.localURL(for: remote.filename) else { return nil }
            return SoundAsset(
                id: remote.id,
                title: remote.title,
                fileURL: localURL,
                category: .downloads,
                isStarred: starredByID[remote.id] ?? false
            )
        }
        return downloaded.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    private func isCurrentPlayingResource(named title: String) -> Bool {
        guard let playing = soundPlayer.playingResourceName else { return false }
        return normalizedTitle(playing) == normalizedTitle(title)
    }

    private func isSoundPlaying(named title: String) -> Bool {
        soundPlayer.isPlaying && isCurrentPlayingResource(named: title)
    }

    private func isSoundBuffering(named title: String) -> Bool {
        soundPlayer.isBuffering && isCurrentPlayingResource(named: title)
    }
    
    private func isPlayingInCategory(_ tab: TopTab) -> Bool {
        guard soundPlayer.isPlaying else { return false }
        guard let playing = soundPlayer.playingResourceName else { return false }
        
        switch tab {
        case .all:
            return sounds.contains(where: { normalizedTitle($0.title) == normalizedTitle(playing) }) ||
                assetManager.remoteSounds.contains(where: { normalizedTitle($0.title) == normalizedTitle(playing) })
        case .category(let category):
            if category == .downloads {
                return downloadedSounds.contains(where: { normalizedTitle($0.title) == normalizedTitle(playing) })
            }
            if category == .alarmTone {
                if let playingAsset = sounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) }) {
                    return playingAsset.category == .alarmTone || playingAsset.category == .loud || playingAsset.category == .classic
                }
            } else if category == .favorites {
                return sounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) })?.isStarred == true
            } else {
                return sounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) })?.category == category
            }
        case .downloadable(let name):
             if let cloudSound = assetManager.remoteSounds.first(where: { normalizedTitle($0.title) == normalizedTitle(playing) }) {
                 return cloudSound.category.caseInsensitiveCompare(name) == .orderedSame
             }
        }
        return false
    }
    
    private func loadSounds() {
        sounds = repository.loadAllSounds()
    }
    
    private func togglePlay(sound: SoundAsset) {
        if isSoundPlaying(named: sound.title) {
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

    private func downloadAndPlay(remoteSound: RemoteSound) {
        Task {
            do {
                let localURL = try await assetManager.downloadAsset(
                    from: remoteSound.url,
                    filename: remoteSound.filename
                )
                await MainActor.run {
                    loadSounds()
                    let downloadedAsset = SoundAsset(
                        id: remoteSound.id,
                        title: remoteSound.title,
                        fileURL: localURL,
                        category: .downloads
                    )
                    togglePlay(sound: downloadedAsset)
                }
            } catch {
                print("❌ Cloud sound download failed: \(error)")
            }
        }
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
            if isSoundPlaying(named: target.title) {
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
            if isSoundPlaying(named: target.title) {
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

    private func scrollToAllSection(for tab: TopTab, proxy: ScrollViewProxy) {
        suppressAutoSectionSync = true
        activeAllSectionTab = tab
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo("all-section-\(tab.id)", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            suppressAutoSectionSync = false
        }
    }

    private func currentlyVisibleAllSectionTab(offsets: [String: CGFloat]) -> TopTab? {
        let sections = allSoundSectionsWithTabs.map { ($0.tab, "all-section-\($0.tab.id)") }
        let candidates = sections.compactMap { tab, id -> (tab: TopTab, y: CGFloat)? in
            guard let y = offsets[id] else { return nil }
            return (tab, y)
        }
        guard !candidates.isEmpty else { return nil }

        if let topVisible = candidates.filter({ $0.y >= 0 }).min(by: { $0.y < $1.y }) {
            return topVisible.tab
        }
        return candidates
            .filter { $0.y < 0 }
            .max(by: { $0.y < $1.y })?
            .tab
    }
}

private struct AllSoundsSectionOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String : CGFloat], nextValue: () -> [String : CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// Subviews
private struct TopTabPill: View {
    let title: String
    let emoji: String?
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.caption)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                if isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white : Colors.accentTeal)
                }
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
    // TODO: Re-add Spotify action when Spotify import is enabled again.
    
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
                    
                    // TODO: Re-enable this Spotify row when Spotify import returns.
                    
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
            .contentShape(Rectangle())
            .onTapGesture {
                if !isDownloaded && !isDownloading {
                    startDownload()
                }
            }

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
                        Text("Tap ▶ to preview  ·\n↓ to download")
                            .foregroundColor(Colors.textTertiary)
                    }
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if isDownloaded { onSelect() }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)

            // ── Buttons HStack ─────────────────────────────────────────
            HStack(spacing: 16) {
                // ── Star ──
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                        onToggleStar()
                    }
                }) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundColor(isStarred ? .yellow : Colors.textTertiary)
                        .scaleEffect(isStarred ? 1.15 : 1.0)
                        .contentShape(Rectangle())
                }

                // ── Download / Cancel button ──
                if isDownloading {
                    Button(action: {
                        Task { await AssetManager.shared.cancelDownload(filename: remoteSound.filename) }
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(oceanBlue.opacity(0.85))
                            .contentShape(Rectangle())
                    }
                } else if !isDownloaded {
                    Button(action: { startDownload() }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(oceanBlue)
                            .background(Circle().fill(Colors.bgPrimary))
                            .contentShape(Rectangle())
                    }
                }

                // ── Preview / Play / Stop button ──
                Button(action: {
                    if isDownloaded {
                        onSelect()
                    } else if !isDownloading {
                        onPreview()
                    }
                }) {
                    ZStack {
                        if isBuffering {
                            ProgressView().tint(oceanBlue).scaleEffect(0.8)
                        } else if isPlaying {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDownloaded ? Colors.textPrimary : oceanBlue)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDownloaded ? Colors.textSecondary : oceanBlue)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                }
            }
            .padding(.trailing, 16)
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
