import Foundation

struct Alarm: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var hour: Int
    var minute: Int
    var isDaily: Bool
    var repeatMask: Int
    var enabled: Bool
    var wakeUpCheckEnabled: Bool
    var soundName: String
    var soundVolume: Float
    var vibrateEnabled: Bool
    var gentleWakeUpSeconds: Int
    var timeReminderEnabled: Bool
    var weatherReminderEnabled: Bool
    var labelReminderEnabled: Bool
    var extraLoudEnabled: Bool
    var snoozeMinutes: Int
    var snoozeCount: Int
    var wallpaperId: String
    var createdAt: Date

    var timeString: String {
        TimeFormatters.formattedTime(hour: hour, minute: minute)
    }
}
