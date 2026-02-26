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
    static let alarmTone = SoundCategory(id: "alarm_tone", title: "Alarm tone", emoji: nil)
    static let loud      = SoundCategory(id: "loud",       title: "Loud",       emoji: nil)
    static let classic   = SoundCategory(id: "classic",    title: "Classic",    emoji: nil)
    static let custom    = SoundCategory(id: "custom",     title: "My Sounds",  emoji: nil)
    static let spotify   = SoundCategory(id: "spotify",    title: "Spotify",    emoji: nil)
    static let cloud     = SoundCategory(id: "cloud",      title: "Downloadable", emoji: nil)

    /// Downloadable is intentionally 2nd (after Alarm tone).
    static let order: [SoundCategory] = [.favorites, .alarmTone, .cloud, .loud, .classic, .custom, .spotify]
}
