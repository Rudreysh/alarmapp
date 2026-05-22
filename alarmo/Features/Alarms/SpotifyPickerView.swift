import SwiftUI

struct SpotifyPickerView: View {
    @Binding var isPresented: Bool
    var onSelect: (SpotifyTrack) -> Void
    
    @StateObject private var spotifyService = SpotifyService()
    @State private var isLoading = false
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("Spotify Library")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    if spotifyService.isAuthenticated {
                        Button("Logout") {
                            spotifyService.logout()
                        }
                        .foregroundColor(.red)
                        .font(.subheadline)
                    } else {
                        Button("Cancel") {}.opacity(0)
                    }
                }
                .padding()
                
                if !spotifyService.isAuthenticated {
                    // Login View
                    VStack(spacing: 24) {
                        Image(systemName: "music.note.house.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                        
                        Text("Connect your Spotify account to use your favorite tracks as alarm sounds.")
                            .bodyText()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            Task {
                                isLoading = true
                                let success = await spotifyService.login()
                                if success {
                                    await spotifyService.fetchUserTracks()
                                    await spotifyService.fetchUserPlaylists()
                                }
                                isLoading = false
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Connect Spotify")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 29/255, green: 185/255, blue: 84/255))
                            .foregroundColor(.black)
                            .cornerRadius(30)
                        }
                        .padding(.horizontal, 40)
                        .disabled(isLoading)
                    }
                    .padding(.top, 60)
                } else {
                    // Error Message
                    if let error = spotifyService.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    // Search Bar
                    if !spotifyService.tracks.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Colors.textTertiary)
                            TextField("Search songs...", text: $searchText)
                                .foregroundColor(Colors.textPrimary)
                                .autocorrectionDisabled()
                        }
                        .padding(10)
                        .background(Colors.cardSurface)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    
                    // Song List
                    List {
                        if !spotifyService.playlists.isEmpty {
                            Section(header: Text("Your Playlists").foregroundColor(Colors.textSecondary)) {
                                ForEach(spotifyService.playlists) { playlist in
                                    HStack {
                                        if let url = playlist.imageURL, let imageUrl = URL(string: url) {
                                            AsyncImage(url: imageUrl) { image in
                                                image.resizable()
                                            } placeholder: {
                                                Color.gray
                                            }
                                            .frame(width: 40, height: 40)
                                            .cornerRadius(4)
                                        }
                                        
                                        Text(playlist.name)
                                            .font(.body)
                                            .foregroundColor(Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Colors.textSecondary)
                                    }
                                }
                            }
                        }

                        Section(header: Text("Your Liked Songs (\(filteredTracks.count))").foregroundColor(Colors.textSecondary)) {
                            ForEach(filteredTracks) { track in
                                Button(action: {
                                    // Allow selecting ANY song
                                    onSelect(track)
                                    isPresented = false
                                }) {
                                    HStack {
                                        AsyncImage(url: URL(string: track.albumArtUrl ?? "")) { image in
                                            image.resizable()
                                        } placeholder: {
                                            Image(systemName: "music.note")
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        .frame(width: 44, height: 44)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Colors.cardStroke, lineWidth: 1)
                                        )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.name)
                                                .font(.body)
                                                .foregroundColor(Colors.textPrimary)
                                                .lineLimit(1)
                                            Text(track.artist)
                                                .font(.caption)
                                                .foregroundColor(Colors.textSecondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        // Show preview badge if available
                                        if track.previewUrl != nil && !track.previewUrl!.isEmpty {
                                            Image(systemName: "waveform")
                                                .font(.caption)
                                                .foregroundColor(Color(red: 29/255, green: 185/255, blue: 84/255))
                                        }
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(Colors.accentTeal)
                                            .font(.title3)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .listRowBackground(Colors.cardSurface)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
                
                Spacer()
            }
        }
        .task {
            if spotifyService.isAuthenticated {
                await spotifyService.fetchUserTracks()
                await spotifyService.fetchUserPlaylists()
            }
        }
    }
    
    private var filteredTracks: [SpotifyTrack] {
        if searchText.isEmpty {
            return spotifyService.tracks
        }
        let query = searchText.lowercased()
        return spotifyService.tracks.filter {
            $0.name.lowercased().contains(query) || $0.artist.lowercased().contains(query)
        }
    }
}
