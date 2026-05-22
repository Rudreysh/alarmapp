import Foundation

enum SoundConfig {
    
    struct SoundDefinition {
        let filename: String
    }
    
    static let sounds: [SoundDefinition] = [
        SoundDefinition(filename: "Addams Family.mp3"),
        SoundDefinition(filename: "Alan Jackson Remix.mp3"),
        SoundDefinition(filename: "Batman Beyond.mp3"),
        SoundDefinition(filename: "Beverly Hillbillies.mp3"),
        SoundDefinition(filename: "Fantasmic Ending.mp3"),
        SoundDefinition(filename: "Om Devotional.mp3"),
        SoundDefinition(filename: "Om Namah Shivay Mantra.mp3"),
        SoundDefinition(filename: "On Me.mp3")
    ]
}
