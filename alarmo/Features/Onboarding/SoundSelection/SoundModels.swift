import Foundation

struct SoundAsset: Identifiable, Equatable {
    let id: String
    let title: String
    let fileURL: URL
    let category: SoundCategory
}

struct SoundCategory: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let emoji: String?

    static let loud = SoundCategory(id: "loud", title: "Loud", emoji: "💥")
    static let alarmTone = SoundCategory(id: "alarm_tone", title: "Alarm tone", emoji: "🔔")
    static let classic = SoundCategory(id: "classic", title: "Classic", emoji: "🎻")

    static let order: [SoundCategory] = [.loud, .alarmTone, .classic]
}
