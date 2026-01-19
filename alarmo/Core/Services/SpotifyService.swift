import Foundation
import Combine
import AuthenticationServices

struct SpotifyTrack: Identifiable, Codable {
    let id: String
    let name: String
    let artist: String
    let albumArtUrl: String?
    let uri: String
    let previewUrl: String?
}

struct SpotifyPlaylist: Identifiable, Codable {
    let id: String
    let name: String
    let imageURL: String?
    let uri: String
}

final class SpotifyService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var tracks: [SpotifyTrack] = []
    @Published var playlists: [SpotifyPlaylist] = []
    
    // Developer placeholders - User MUST register at developer.spotify.com
    // And add "alarmo-spotify://callback" to Redirect URIs
    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let redirectURI = "alarmo-spotify://callback"
    private let authEndpoint = "https://accounts.spotify.com/authorize"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"
    
    private var accessToken: String?
    private var refreshToken: String?
    
    // PKCE helper (Simplified for this implementation)
    private let codeVerifier = "code_verifier_string_at_least_43_chars_long_1234567890"
    private let codeChallenge = "code_challenge_string" // In real app, this is SHA256 of verifier

    @MainActor
    func login() async -> Bool {
        let scopes = "user-library-read user-read-private user-read-email"
        let authURLString = "\(authEndpoint)?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&code_challenge_method=S256&code_challenge=\(codeChallenge)"
        
        guard let authURL = URL(string: authURLString) else { return false }
        
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "alarmo-spotify") { callbackURL, error in
                if let error = error {
                    print("[SpotifyService] Auth Error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(returning: false)
                    return
                }
                
                Task {
                    let success = await self.exchangeCodeForToken(code: code)
                    DispatchQueue.main.async {
                        self.isAuthenticated = success
                    }
                    continuation.resume(returning: success)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
    
    private func exchangeCodeForToken(code: String) async -> Bool {
        // NOTE: In a production app, you'd use PKCE properly or a secure backend.
        // This is the standard mobile flow template.
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                self.accessToken = token
                self.refreshToken = json["refresh_token"] as? String
                return true
            }
        } catch {
            print("[SpotifyService] Token exchange failed: \(error)")
        }
        return false
    }
    
    func fetchUserTracks() async {
        guard let token = accessToken else { return }
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/tracks?limit=30")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[SpotifyService] API Error: \(response)")
                return
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(SpotifyLibraryResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.tracks = result.items.map { item in
                    SpotifyTrack(
                        id: item.track.id,
                        name: item.track.name,
                        artist: item.track.artists.first?.name ?? "Unknown",
                        albumArtUrl: item.track.album.images.first?.url,
                        uri: item.track.uri,
                        previewUrl: item.track.preview_url
                    )
                }
            }
        } catch {
            print("[SpotifyService] Fetch tracks failed: \(error)")
        }
    }

    func fetchUserPlaylists() async {
        guard let token = accessToken else { return }
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists?limit=20")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let result = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            DispatchQueue.main.async {
                self.playlists = result.items.map { item in
                    SpotifyPlaylist(id: item.id, name: item.name, imageURL: item.images.first?.url, uri: item.uri)
                }
            }
        } catch {
            print("[SpotifyService] Fetch playlists failed: \(error)")
        }
    }
    
    // ... rest of the saving methods (kept the same)
    func saveSpotifyTrackAsSound(track: SpotifyTrack) {
        let userDefaults = UserDefaults.standard
        var savedSpotifyTracks = userDefaults.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        savedSpotifyTracks[track.name] = [
            "id": track.id,
            "artist": track.artist,
            "uri": track.uri,
            "previewUrl": track.previewUrl ?? ""
        ]
        userDefaults.set(savedSpotifyTracks, forKey: "SavedSpotifyTracks")
    }
    
    func loadSavedSpotifySounds() -> [SoundAsset] {
        let userDefaults = UserDefaults.standard
        let savedSpotifyTracks = userDefaults.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        return savedSpotifyTracks.compactMap { (name, data) in
            let urlString = data["previewUrl"] ?? ""
            guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
            return SoundAsset(id: data["id"] ?? UUID().uuidString, title: name, fileURL: url, category: .spotify)
        }
    }
}

// API Models
extension SpotifyService {
    struct APIImage: Codable { let url: String }
    struct APIArtist: Codable { let name: String }
    struct APIAlbum: Codable { let images: [APIImage] }

    struct SpotifyLibraryResponse: Codable {
        let items: [LibraryItem]
        struct LibraryItem: Codable {
            let track: APITrack
        }
        struct APITrack: Codable {
            let id: String
            let name: String
            let uri: String
            let preview_url: String?
            let artists: [APIArtist]
            let album: APIAlbum
        }
    }

    struct SpotifyPlaylistsResponse: Codable {
        let items: [APIPlaylist]
        struct APIPlaylist: Codable {
            let id: String
            let name: String
            let uri: String
            let images: [APIImage]
        }
    }
}

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
