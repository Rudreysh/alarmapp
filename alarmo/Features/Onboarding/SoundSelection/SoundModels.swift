import Foundation

struct SoundAsset: Identifiable, Equatable {
    let id: String
    let title: String
    let fileURL: URL
    let category: SoundCategory
    var isStarred: Bool = false
}

struct SoundCategory: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let emoji: String?

    static let favorites = SoundCategory(id: "favorites", title: "Favorites", emoji: "⭐")
    static let alarmTone = SoundCategory(id: "alarm_tone", title: "Alarm tone", emoji: "🔔")
    static let focus     = SoundCategory(id: "focus",      title: "Focus",      emoji: "🧘")
    static let loud      = SoundCategory(id: "loud",       title: "Loud",       emoji: "🔊")
    static let classic   = SoundCategory(id: "classic",    title: "Classic",    emoji: "📻")
    static let custom    = SoundCategory(id: "custom",     title: "My Sounds",  emoji: "🎙️")
    static let spotify   = SoundCategory(id: "spotify",    title: "Spotify",    emoji: "🎵")
    static let cloud     = SoundCategory(id: "cloud",      title: "Downloadable", emoji: "☁️")
    static let downloads = SoundCategory(id: "downloads",  title: "Downloads",  emoji: "⬇️")

    /// Downloadable is intentionally 2nd (after Alarm tone).
    static let order: [SoundCategory] = [.favorites, .alarmTone, .focus, .cloud, .downloads, .loud, .classic, .custom, .spotify]
}
