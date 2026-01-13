import Foundation

struct AlarmDraft: Equatable {
    var name: String = ""
    var emoji: String = "🌞"
    var hour: Int
    var minute: Int
    var isDaily: Bool = true
    var selectedWeekdays: Set<Int>
    var enabled: Bool = true
    var wakeUpCheckEnabled: Bool = false
    var soundName: String = "Orkney"
    var soundVolume: Float = 0.8
    var vibrateEnabled: Bool = true
    var gentleWakeUpSeconds: Int = 30
    var timeReminderEnabled: Bool = false
    var weatherReminderEnabled: Bool = false
    var labelReminderEnabled: Bool = false
    var extraLoudEnabled: Bool = false
    var snoozeMinutes: Int = 5
    var snoozeCount: Int = 3
    var wallpaperId: String = "default"

    init(defaultHour: Int, defaultMinute: Int, defaultRepeatMask: Int, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.hour = defaultHour
        self.minute = defaultMinute
        self.selectedWeekdays = Set(RepeatMask.weekdays(from: defaultRepeatMask))
        self.isDaily = defaultRepeatMask == RepeatMask.allDays
        self.soundName = defaultSoundName.isEmpty ? "Orkney" : defaultSoundName
        self.soundVolume = defaultSoundVolume
        self.wallpaperId = defaultWallpaperId.isEmpty ? "default" : defaultWallpaperId
    }
}
