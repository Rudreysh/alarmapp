import Foundation

struct AlarmDraft: Equatable {
    var name: String = ""
    var emoji: String = "🌞"
    var hour: Int
    var minute: Int
    var second: Int = 0
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
    var bypassSilentMode: Bool = true
    var timeZoneMode: AlarmTimeZoneMode = .local
    var timeZoneIdentifier: String?
    var timeZoneCity: String?
    var snoozeMinutes: Int = 5
    var snoozeSeconds: Int = 0
    var snoozeCount: Int = 3
    var wallpaperId: String = "default"
    var dailyMotivationEnabled: Bool = false
    var missions: [AlarmMission] = []
    
    // Accountability Shield
    var accountabilityEnabled: Bool = false
    var blockAppsEnabled: Bool = false
    var blockedSelectionData: Data?
    var penaltyEnabled: Bool = false
    var penaltyAmountEuro: Int = 1
    var penaltyRules: PenaltyRules = .default

    init(defaultHour: Int, defaultMinute: Int, defaultSecond: Int = 0, defaultRepeatMask: Int, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.hour = defaultHour
        self.minute = defaultMinute
        self.second = defaultSecond
        self.selectedWeekdays = Set(RepeatMask.weekdays(from: defaultRepeatMask))
        self.isDaily = defaultRepeatMask == RepeatMask.allDays
        self.soundName = defaultSoundName.isEmpty ? "Orkney" : defaultSoundName
        self.soundVolume = defaultSoundVolume
        self.wallpaperId = Self.resolveWallpaperId(defaultWallpaperId)
    }

    private static func resolveWallpaperId(_ id: String) -> String {
        if !id.isEmpty, id != "default" {
            return id
        }
        if let firstCategory = WallpaperConfig.categories.first,
           let firstFilename = firstCategory.imageNames.first {
            return "\(firstCategory.id)-\(firstFilename)"
        }
        return "default"
    }
}
