import Foundation

enum SoundConfig {
    
    struct SoundDefinition {
        let filename: String
    }
    
    static let sounds: [SoundDefinition] = [
        SoundDefinition(filename: "addams_family.mp3"),
        SoundDefinition(filename: "alan_jackson_remix.mp3"),
        SoundDefinition(filename: "batman_beyond.mp3"),
        SoundDefinition(filename: "beverly_hillbillies.mp3"),
        SoundDefinition(filename: "fantasmic_ending.mp3"),
        SoundDefinition(filename: "om-devotional-15402.mp3"),
        SoundDefinition(filename: "om-namah-shivay-mantra-tone-57609.mp3"),
        SoundDefinition(filename: "on_me.mp3")
    ]
}
