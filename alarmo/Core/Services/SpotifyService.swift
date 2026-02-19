import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import Security

// MARK: - Models

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

// MARK: - Service

final class SpotifyService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var tracks: [SpotifyTrack] = []
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var errorMessage: String? = nil
    
    // Credentials
    private let clientID = "7b1704d0168f478cb1c72af80d832d94"
    private let redirectURI = "alarmo-spotify://callback"
    private let authEndpoint = "https://accounts.spotify.com/authorize"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"
    
    // Keys for persistence
    private let accessTokenKey = "spotify.accessToken"
    private let refreshTokenKey = "spotify.refreshToken"
    private let savedTracksKey = "SavedSpotifyTracks"
    
    private var codeVerifier: String?
    private var authSession: ASWebAuthenticationSession?
    
    override init() {
        super.init()
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if UserDefaults.standard.string(forKey: accessTokenKey) != nil {
            self.isAuthenticated = true
            print("[SpotifyService] Restored session from stored token")
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        self.isAuthenticated = false
        self.tracks = []
        self.playlists = []
        self.errorMessage = nil
        print("[SpotifyService] Logged out. Cleared all tokens.")
    }
    
    // MARK: - URL Encoding Helper
    
    /// Properly builds a x-www-form-urlencoded body from key-value pairs.
    /// This is CRITICAL - raw string interpolation does NOT encode special characters
    /// like :// in redirect_uri, which causes Spotify to reject or misprocess the request.
    private func buildFormBody(from params: [(String, String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        // URLComponents.query percent-encodes values properly
        return components.query?.data(using: .utf8)
    }
    
    // MARK: - Authorization Flow (PKCE)
    
    @MainActor
    func login() async -> Bool {
        // Clear only tokens, not UI state (avoid triggering re-render during login)
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        
        // 1. Generate PKCE Verifier and Challenge
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)
        
        print("[SpotifyService] PKCE Verifier length: \(verifier.count)")
        print("[SpotifyService] PKCE Challenge: \(challenge.prefix(10))...")
        
        // 2. Build Auth URL
        let scopes = "user-library-read user-read-private user-read-email playlist-read-private playlist-read-collaborative user-modify-playback-state user-read-playback-state streaming"
        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "show_dialog", value: "true") // Force re-consent
        ]
        
        guard let authURL = components.url else {
            print("[SpotifyService] Failed to build auth URL")
            return false
        }
        
        print("[SpotifyService] Auth URL: \(authURL.absoluteString.prefix(100))...")
        
        // 3. Start Authentication Session
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "alarmo-spotify") { [weak self] callbackURL, error in
                // Clear retained session
                self?.authSession = nil
                
                if let error = error {
                    print("[SpotifyService] Auth Error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("[SpotifyService] No callback URL received")
                    continuation.resume(returning: false)
                    return
                }
                
                print("[SpotifyService] Callback received: \(callbackURL.absoluteString.prefix(80))...")
                
                guard let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems else {
                    print("[SpotifyService] No query items in callback")
                    continuation.resume(returning: false)
                    return
                }
                
                // Check for error in callback
                if let errorParam = queryItems.first(where: { $0.name == "error" })?.value {
                    print("[SpotifyService] Spotify returned error: \(errorParam)")
                    Task { @MainActor in
                        self?.errorMessage = "Spotify error: \(errorParam)"
                    }
                    continuation.resume(returning: false)
                    return
                }
                
                guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                    print("[SpotifyService] No authorization code in callback")
                    continuation.resume(returning: false)
                    return
                }
                
                print("[SpotifyService] Got authorization code: \(code.prefix(10))...")
                
                // 4. Exchange Code for Token
                Task {
                    let success = await self?.exchangeCodeForToken(code: code) ?? false
                    await MainActor.run {
                        self?.isAuthenticated = success
                        if !success {
                            self?.errorMessage = "Token exchange failed. Check Xcode console."
                        }
                    }
                    continuation.resume(returning: success)
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Use shared session for stability
            
            // CRITICAL: Retain the session to prevent ARC from deallocating it
            self.authSession = session
            
            session.start()
        }
    }
    
    private func exchangeCodeForToken(code: String) async -> Bool {
        guard let verifier = self.codeVerifier else {
            print("[SpotifyService] No code verifier available!")
            return false
        }
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // CRITICAL FIX: Use proper URL encoding for the POST body.
        // Previously, redirect_uri was sent as "alarmo-spotify://callback" without encoding,
        // which corrupted the request. URLComponents.query properly encodes all values.
        let params: [(String, String)] = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirectURI),
            ("client_id", clientID),
            ("code_verifier", verifier)
        ]
        
        request.httpBody = buildFormBody(from: params)
        
        print("[SpotifyService] Exchanging code for token...")
        print("[SpotifyService] POST body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "nil")")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let responseBody = String(data: data, encoding: .utf8) ?? "No body"
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[SpotifyService] Token exchange status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("[SpotifyService] Token exchange FAILED: \(responseBody)")
                    await MainActor.run {
                        self.errorMessage = "Token exchange error \(httpResponse.statusCode)"
                    }
                    return false
                }
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                guard let token = json["access_token"] as? String else {
                    print("[SpotifyService] No access_token in response: \(responseBody)")
                    return false
                }
                
                let refreshToken = json["refresh_token"] as? String
                let scope = json["scope"] as? String ?? "none"
                let expiresIn = json["expires_in"] as? Int ?? 0
                
                print("[SpotifyService] ✅ Token obtained!")
                print("[SpotifyService]   Scopes granted: \(scope)")
                print("[SpotifyService]   Expires in: \(expiresIn)s")
                print("[SpotifyService]   Has refresh token: \(refreshToken != nil)")
                
                // Verify required scopes were granted
                let requiredScopes = ["user-library-read", "user-modify-playback-state"]
                let missingScopes = requiredScopes.filter { !scope.contains($0) }
                
                if !missingScopes.isEmpty {
                    print("[SpotifyService] ⚠️ WARNING: Missing scopes: \(missingScopes.joined(separator: ", "))")
                    await MainActor.run {
                        self.errorMessage = "Spotify did not grant required permissions. Please logout and reconnect."
                    }
                    return false
                }
                
                UserDefaults.standard.set(token, forKey: accessTokenKey)
                if let refresh = refreshToken {
                    UserDefaults.standard.set(refresh, forKey: refreshTokenKey)
                }
                return true
            }
        } catch {
            print("[SpotifyService] Token request network error: \(error)")
        }
        return false
    }
    
    // MARK: - API Calls
    
    func fetchUserTracks() async {
        print("[SpotifyService] Fetching user tracks...")
        guard let token = UserDefaults.standard.string(forKey: accessTokenKey) else {
            print("[SpotifyService] No access token. Cannot fetch.")
            return
        }
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/tracks?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[SpotifyService] Tracks response: \(httpResponse.statusCode)")
                
                // 401 -> Try refresh
                if httpResponse.statusCode == 401 {
                    print("[SpotifyService] Token expired. Attempting refresh...")
                    if await refreshAccessToken() {
                        await fetchUserTracks()
                        return
                    } else {
                        await MainActor.run {
                            self.logout()
                            self.errorMessage = "Session expired. Please log in again."
                        }
                        return
                    }
                }
                
                // 403 -> Permission denied (Do NOT logout - that causes an infinite loop!)
                if httpResponse.statusCode == 403 {
                    let body = String(data: data, encoding: .utf8) ?? "No body"
                    print("[SpotifyService] 403 Forbidden. Raw response: \(body)")
                    
                    await MainActor.run {
                        // Keep authenticated state so user sees the error, not the login loop
                        self.errorMessage = "⚠️ Spotify 403: Your Spotify email must be added to the Developer Dashboard → Settings → User Management. Add your email there and tap Logout then reconnect."
                    }
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    let body = String(data: data, encoding: .utf8) ?? "No body"
                    print("[SpotifyService] Unexpected status \(httpResponse.statusCode): \(body)")
                    await MainActor.run {
                        self.errorMessage = "Spotify Error: \(httpResponse.statusCode)"
                    }
                    return
                }
            }
            
            let result = try JSONDecoder().decode(SpotifyLibraryResponse.self, from: data)
            
            await MainActor.run {
                print("[SpotifyService] ✅ Decoded \(result.items.count) tracks")
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
                self.errorMessage = nil
            }
        } catch {
            print("[SpotifyService] Fetch tracks error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load tracks: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchUserPlaylists() async {
        guard let token = UserDefaults.standard.string(forKey: accessTokenKey) else { return }
        
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists?limit=20")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    if await refreshAccessToken() {
                        await fetchUserPlaylists()
                        return
                    } else {
                        await MainActor.run { self.logout() }
                        return
                    }
                }
                if httpResponse.statusCode == 403 {
                    print("[SpotifyService] Playlist fetch 403")
                    return // Don't logout twice if tracks already triggered it
                }
            }
            
            let result = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            await MainActor.run {
                self.playlists = result.items.map { item in
                    SpotifyPlaylist(id: item.id, name: item.name, imageURL: item.images.first?.url, uri: item.uri)
                }
            }
        } catch {
            print("[SpotifyService] Fetch playlists error: \(error)")
        }
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            print("[SpotifyService] No refresh token available")
            return false
        }
        
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // CRITICAL FIX: Use proper URL encoding
        let params: [(String, String)] = [
            ("grant_type", "refresh_token"),
            ("refresh_token", refreshToken),
            ("client_id", clientID)
        ]
        
        request.httpBody = buildFormBody(from: params)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newToken = json["access_token"] as? String {
                    
                    UserDefaults.standard.set(newToken, forKey: accessTokenKey)
                    if let newRefresh = json["refresh_token"] as? String {
                        UserDefaults.standard.set(newRefresh, forKey: refreshTokenKey)
                    }
                    print("[SpotifyService] ✅ Token refreshed")
                    return true
                }
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[SpotifyService] Refresh failed: \(body)")
            }
        } catch {
            print("[SpotifyService] Refresh error: \(error)")
        }
        return false
    }
    
    // MARK: - Local Storage
    
    func saveSpotifyTrackAsSound(track: SpotifyTrack) {
        var savedSpotifyTracks = UserDefaults.standard.dictionary(forKey: savedTracksKey) as? [String: [String: String]] ?? [:]
        savedSpotifyTracks[track.name] = [
            "id": track.id,
            "artist": track.artist,
            "uri": track.uri,
            "previewUrl": track.previewUrl ?? "",
            "albumArtUrl": track.albumArtUrl ?? ""
        ]
        UserDefaults.standard.set(savedSpotifyTracks, forKey: savedTracksKey)
        print("[SpotifyService] Saved track: \(track.name) (preview: \(track.previewUrl != nil ? "yes" : "no"))")
        
        // If preview URL exists, download and cache the audio file locally.
        // This allows direct in-app playback without Spotify API or app switching!
        if let previewUrlString = track.previewUrl, !previewUrlString.isEmpty,
           let previewURL = URL(string: previewUrlString) {
            Task {
                await cachePreviewAudio(trackId: track.id, trackName: track.name, from: previewURL)
            }
        }
    }
    
    /// Downloads a preview audio file and saves it locally for direct playback.
    private func cachePreviewAudio(trackId: String, trackName: String, from url: URL) async {
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cacheDir = documentsURL.appendingPathComponent("SpotifyPreviewCache")
            
            // Create cache directory if needed
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            let destination = cacheDir.appendingPathComponent("\(trackId).mp3")
            
            // Skip if already cached
            if FileManager.default.fileExists(atPath: destination.path) {
                print("[SpotifyService] Preview already cached: \(trackName)")
                return
            }
            
            print("[SpotifyService] 📥 Downloading preview for: \(trackName)")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                try data.write(to: destination)
                print("[SpotifyService] ✅ Preview cached: \(trackName) (\(data.count / 1024)KB)")
            } else {
                print("[SpotifyService] ❌ Preview download failed for: \(trackName)")
            }
        } catch {
            print("[SpotifyService] ❌ Preview cache error: \(error)")
        }
    }
    
    func loadSavedSpotifySounds() -> [SoundAsset] {
        let savedSpotifyTracks = UserDefaults.standard.dictionary(forKey: savedTracksKey) as? [String: [String: String]] ?? [:]
        return savedSpotifyTracks.compactMap { (name, data) in
            guard let id = data["id"] else { return nil }
            
            let uri = data["uri"] ?? ""
            
            // Priority 1: Use cached preview file (plays directly, no API needed!)
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let cachedFile = documentsURL.appendingPathComponent("SpotifyPreviewCache/\(id).mp3")
                if FileManager.default.fileExists(atPath: cachedFile.path) {
                    return SoundAsset(id: id, title: name, fileURL: cachedFile, category: .spotify)
                }
            }
            
            // Priority 2: Use Spotify URI (Web API playback or fallback alarm)
            if !uri.isEmpty {
                let trackID = uri.replacingOccurrences(of: "spotify:track:", with: "")
                let soundURL = URL(string: "https://open.spotify.com/track/\(trackID)")!
                return SoundAsset(id: id, title: name, fileURL: soundURL, category: .spotify)
            }
            
            return nil
        }
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - API Response Models

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

// MARK: - Authentication Context

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first ?? ASPresentationAnchor()
    }
}
