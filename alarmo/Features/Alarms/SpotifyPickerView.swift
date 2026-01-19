import SwiftUI

struct SpotifyPickerView: View {
    @Binding var isPresented: Bool
    var onSelect: (SpotifyTrack) -> Void
    
    @StateObject private var spotifyService = SpotifyService()
    @State private var isLoading = false
    
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
                    
                    // Invisible spacer for balance
                    Button("Cancel") {}.opacity(0)
                }
                .padding()
                
                if !spotifyService.isAuthenticated {
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
                            .background(Color(red: 29/255, green: 185/255, blue: 84/255)) // Spotify Green
                            .foregroundColor(.black)
                            .cornerRadius(30)
                        }
                        .padding(.horizontal, 40)
                        .disabled(isLoading)
                    }
                    .padding(.top, 60)
                } else {
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

                        Section(header: Text("Your Liked Songs").foregroundColor(Colors.textSecondary)) {
                            ForEach(spotifyService.tracks) { track in
                                Button(action: {
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
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(4)

                                        VStack(alignment: .leading) {
                                            Text(track.name)
                                                .font(.body)
                                                .foregroundColor(Colors.textPrimary)
                                            Text(track.artist)
                                                .font(.caption)
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(Colors.accentTeal)
                                    }
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
    }
}
