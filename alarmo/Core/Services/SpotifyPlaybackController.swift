import Foundation

/// Controls Spotify playback via the Web API — NEVER opens the Spotify app.
///
/// How it works:
/// 1. Our app sends HTTP API calls to Spotify's servers
/// 2. Spotify's servers tell the user's Spotify app what to play
/// 3. Audio plays through the Spotify app's audio session on the device speakers
/// 4. If Spotify can't play (no device, not Premium), returns false → caller uses fallback
///
/// IMPORTANT: This controller NEVER calls UIApplication.shared.open() or switches apps.
/// The user always stays in Awayk. If Spotify playback fails, the fallback alarm sounds.
///
/// Requirements:
/// - User must have Spotify Premium (Free accounts can't use playback control API)
/// - Spotify app must be installed and recently used (so it registers as a device)
/// - Access token must include `user-modify-playback-state` scope
final class SpotifyPlaybackController {
    
    static let shared = SpotifyPlaybackController()
    
    private let apiBase = "https://api.spotify.com/v1"
    private let accessTokenKey = "spotify.accessToken"
    
    private var accessToken: String? {
        UserDefaults.standard.string(forKey: accessTokenKey)
    }
    
    // MARK: - Public API
    
    /// Play a Spotify track by URI (e.g. "spotify:track:6HpglW7kN0K3sNZmzupFcL")
    /// Returns true if playback was started successfully via the Web API.
    /// Returns false if it can't play — caller should use fallback alarm sound.
    /// NEVER switches to the Spotify app.
    func playTrack(uri: String) async -> Bool {
        print("[SpotifyPlayback] Attempting to play: \(uri)")
        
        guard let token = accessToken else {
            print("[SpotifyPlayback] ❌ No access token available. Use fallback.")
            return false
        }
        
        // Step 1: Check for active devices
        let devices = await getAvailableDevices(token: token)
        print("[SpotifyPlayback] Found \(devices.count) device(s)")
        
        for device in devices {
            print("[SpotifyPlayback]   → \(device.name) (type: \(device.type), active: \(device.isActive))")
        }
        
        // Step 2: Find or activate a device (NO app switching!)
        var targetDeviceId: String?
        
        // Prefer the active device
        if let active = devices.first(where: { $0.isActive }) {
            targetDeviceId = active.id
            print("[SpotifyPlayback] Using active device: \(active.name)")
        }
        // Try any smartphone device
        else if let phone = devices.first(where: { $0.type.lowercased() == "smartphone" }) {
            targetDeviceId = phone.id
            print("[SpotifyPlayback] Activating smartphone: \(phone.name)")
            await transferPlayback(to: phone.id, token: token)
        }
        // Use any available device
        else if let any = devices.first {
            targetDeviceId = any.id
            print("[SpotifyPlayback] Activating device: \(any.name)")
            await transferPlayback(to: any.id, token: token)
        }
        // No devices found — can't play via API. Return false for fallback.
        else {
            print("[SpotifyPlayback] ❌ No Spotify devices available. Use fallback alarm.")
            print("[SpotifyPlayback] ℹ️ Tip: Open Spotify once before setting alarm so it registers as a device.")
            return false
        }
        
        // Step 3: Start playback via Web API
        let success = await startPlayback(uri: uri, deviceId: targetDeviceId, token: token)
        
        if success {
            print("[SpotifyPlayback] ✅ Playback started for: \(uri)")
        } else {
            print("[SpotifyPlayback] ❌ API playback failed. Use fallback alarm.")
        }
        
        return success
    }
    
    /// Play a track by its Spotify track ID (not the full URI)
    func playTrackById(_ trackId: String) async -> Bool {
        return await playTrack(uri: "spotify:track:\(trackId)")
    }
    
    /// Pause current playback
    func pause() async -> Bool {
        guard let token = accessToken else { return false }
        
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player/pause")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let success = http.statusCode == 204 || http.statusCode == 200
                print("[SpotifyPlayback] Pause: \(success ? "✅" : "❌") (\(http.statusCode))")
                return success
            }
        } catch {
            print("[SpotifyPlayback] Pause error: \(error)")
        }
        return false
    }
    
    /// Resume current playback
    func resume() async -> Bool {
        guard let token = accessToken else { return false }
        
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player/play")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return http.statusCode == 204 || http.statusCode == 200
            }
        } catch {
            print("[SpotifyPlayback] Resume error: \(error)")
        }
        return false
    }
    
    /// Set playback volume (0-100)
    func setVolume(_ percent: Int) async {
        guard let token = accessToken else { return }
        let clamped = max(0, min(100, percent))
        
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player/volume?volume_percent=\(clamped)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[SpotifyPlayback] Volume \(clamped)%: \(http.statusCode)")
            }
        } catch {
            print("[SpotifyPlayback] Volume error: \(error)")
        }
    }
    
    /// Get current playback state
    func getCurrentPlayback() async -> PlaybackState? {
        guard let token = accessToken else { return nil }
        
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let isPlaying = json["is_playing"] as? Bool ?? false
                    let progressMs = json["progress_ms"] as? Int ?? 0
                    
                    var trackName: String?
                    var trackUri: String?
                    if let item = json["item"] as? [String: Any] {
                        trackName = item["name"] as? String
                        trackUri = item["uri"] as? String
                    }
                    
                    return PlaybackState(
                        isPlaying: isPlaying,
                        progressMs: progressMs,
                        trackName: trackName,
                        trackUri: trackUri
                    )
                }
            }
        } catch {
            print("[SpotifyPlayback] Get playback error: \(error)")
        }
        return nil
    }
    
    // MARK: - Models
    
    struct SpotifyDevice {
        let id: String
        let name: String
        let type: String
        let isActive: Bool
    }
    
    struct PlaybackState {
        let isPlaying: Bool
        let progressMs: Int
        let trackName: String?
        let trackUri: String?
    }
    
    // MARK: - Private Helpers
    
    private func getAvailableDevices(token: String) async -> [SpotifyDevice] {
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player/devices")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse {
                print("[SpotifyPlayback] Devices API status: \(http.statusCode)")
                
                if http.statusCode == 403 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("[SpotifyPlayback] 403 on devices (Premium required?): \(body)")
                    return []
                }
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devicesList = json["devices"] as? [[String: Any]] {
                return devicesList.compactMap { device in
                    guard let id = device["id"] as? String,
                          let name = device["name"] as? String,
                          let type = device["type"] as? String else { return nil }
                    let isActive = device["is_active"] as? Bool ?? false
                    return SpotifyDevice(id: id, name: name, type: type, isActive: isActive)
                }
            }
        } catch {
            print("[SpotifyPlayback] Devices error: \(error)")
        }
        return []
    }
    
    private func startPlayback(uri: String, deviceId: String?, token: String) async -> Bool {
        var urlString = "\(apiBase)/me/player/play"
        if let deviceId = deviceId {
            urlString += "?device_id=\(deviceId)"
        }
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body — play as a single track on repeat
        let body: [String: Any] = [
            "uris": [uri],
            "position_ms": 0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let success = http.statusCode == 204 || http.statusCode == 200
                if !success {
                    let responseBody = String(data: data, encoding: .utf8) ?? ""
                    print("[SpotifyPlayback] Play failed (\(http.statusCode)): \(responseBody)")
                    
                    if http.statusCode == 403 {
                        print("[SpotifyPlayback] ⚠️ Playback control requires Spotify Premium")
                    }
                    if http.statusCode == 404 {
                        print("[SpotifyPlayback] ⚠️ No active Spotify device found")
                    }
                }
                return success
            }
        } catch {
            print("[SpotifyPlayback] Play error: \(error)")
        }
        return false
    }
    
    private func transferPlayback(to deviceId: String, token: String) async {
        var request = URLRequest(url: URL(string: "\(apiBase)/me/player")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "device_ids": [deviceId],
            "play": false
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[SpotifyPlayback] Transfer playback: \(http.statusCode)")
            }
        } catch {
            print("[SpotifyPlayback] Transfer error: \(error)")
        }
    }
}
