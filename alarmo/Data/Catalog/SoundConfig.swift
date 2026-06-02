import Foundation

enum SoundConfig {
    
    struct SoundDefinition {
        let filename: String
    }
    
    static let sounds: [SoundDefinition] = [
        // Guaranteed bundled alarm tones — always available, no download required.
        // The previous list referenced cloud-only MP3s that are not in the bundle,
        // causing "Loaded 0 sounds" and missing-file warnings on every launch.
        SoundDefinition(filename: "Default Alarm.caf"),
        SoundDefinition(filename: "Clock Alarm.caf"),
        SoundDefinition(filename: "Cockpit Alert.caf"),
        SoundDefinition(filename: "Alarm.caf"),
        SoundDefinition(filename: "bbc_electronic.caf"),
    ]
}
