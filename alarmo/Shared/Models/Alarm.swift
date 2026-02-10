import Foundation

enum AlarmType: String, Codable {
    case wakeUp
    case quick
    case habit
}

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID
    var type: AlarmType = .wakeUp
    var name: String
    var emoji: String
    var hour: Int
    var minute: Int
    var second: Int
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
    var bypassSilentMode: Bool = true // Default to true for alarms
    var timeZoneMode: AlarmTimeZoneMode = .local
    var timeZoneIdentifier: String?
    var timeZoneCity: String?
    var snoozeMinutes: Int
    var snoozeCount: Int
    var wallpaperId: String
    var createdAt: Date
    var isSkippedOnce: Bool
    var missions: [AlarmMission] = []
    
    // Accountability Shield
    var enforcementMode: EnforcementMode = .none
    var blockAppsEnabled: Bool = false
    var blockedSelectionData: Data?
    var penaltyEnabled: Bool = false
    var penaltyAmountEuro: Int = 1
    var penaltyStrategy: PenaltyStrategy = .credits
    var penaltyRules: PenaltyRules = .default
    var lastPenaltyEventAt: Date?
    var penaltyEventLog: [PenaltyEventRecord] = []
    
    // Habit Reminder
    var habitReminderEnabled: Bool = false
    var habitReminderInterval: Int = 20
    var habitReminderDuration: Int = 20
    var habitReminderStartTime: Date?
    var habitReminderEndTime: Date?

    var timeString: String {
        TimeFormatters.formattedTime(hour: hour, minute: minute)
    }

    var timeStringPrecision: String {
        TimeFormatters.formattedTimeWithSeconds(hour: hour, minute: minute, second: second)
    }
    
    // Manual Codable implementation to handle migration (missing 'type' = .wakeUp)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decodeIfPresent(AlarmType.self, forKey: .type) ?? .wakeUp
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        hour = try container.decode(Int.self, forKey: .hour)
        minute = try container.decode(Int.self, forKey: .minute)
        second = try container.decodeIfPresent(Int.self, forKey: .second) ?? 0
        isDaily = try container.decode(Bool.self, forKey: .isDaily)
        repeatMask = try container.decode(Int.self, forKey: .repeatMask)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        wakeUpCheckEnabled = try container.decode(Bool.self, forKey: .wakeUpCheckEnabled)
        soundName = try container.decode(String.self, forKey: .soundName)
        soundVolume = try container.decode(Float.self, forKey: .soundVolume)
        vibrateEnabled = try container.decode(Bool.self, forKey: .vibrateEnabled)
        gentleWakeUpSeconds = try container.decode(Int.self, forKey: .gentleWakeUpSeconds)
        timeReminderEnabled = try container.decode(Bool.self, forKey: .timeReminderEnabled)
        weatherReminderEnabled = try container.decode(Bool.self, forKey: .weatherReminderEnabled)
        labelReminderEnabled = try container.decode(Bool.self, forKey: .labelReminderEnabled)
        extraLoudEnabled = try container.decode(Bool.self, forKey: .extraLoudEnabled)
        bypassSilentMode = try container.decodeIfPresent(Bool.self, forKey: .bypassSilentMode) ?? true
        timeZoneMode = try container.decodeIfPresent(AlarmTimeZoneMode.self, forKey: .timeZoneMode) ?? .local
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
        timeZoneCity = try container.decodeIfPresent(String.self, forKey: .timeZoneCity)
        snoozeMinutes = try container.decode(Int.self, forKey: .snoozeMinutes)
        snoozeCount = try container.decode(Int.self, forKey: .snoozeCount)
        wallpaperId = try container.decode(String.self, forKey: .wallpaperId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isSkippedOnce = try container.decodeIfPresent(Bool.self, forKey: .isSkippedOnce) ?? false
        missions = try container.decodeIfPresent([AlarmMission].self, forKey: .missions) ?? []
        enforcementMode = try container.decodeIfPresent(EnforcementMode.self, forKey: .enforcementMode) ?? .none
        blockAppsEnabled = try container.decodeIfPresent(Bool.self, forKey: .blockAppsEnabled) ?? false
        blockedSelectionData = try container.decodeIfPresent(Data.self, forKey: .blockedSelectionData)
        penaltyEnabled = try container.decodeIfPresent(Bool.self, forKey: .penaltyEnabled) ?? false
        penaltyAmountEuro = min(10, max(1, try container.decodeIfPresent(Int.self, forKey: .penaltyAmountEuro) ?? 1))
        penaltyStrategy = try container.decodeIfPresent(PenaltyStrategy.self, forKey: .penaltyStrategy) ?? .credits
        penaltyRules = try container.decodeIfPresent(PenaltyRules.self, forKey: .penaltyRules) ?? .default
        lastPenaltyEventAt = try container.decodeIfPresent(Date.self, forKey: .lastPenaltyEventAt)
        penaltyEventLog = try container.decodeIfPresent([PenaltyEventRecord].self, forKey: .penaltyEventLog) ?? []
        habitReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .habitReminderEnabled) ?? false
        habitReminderInterval = try container.decodeIfPresent(Int.self, forKey: .habitReminderInterval) ?? 20
        habitReminderDuration = try container.decodeIfPresent(Int.self, forKey: .habitReminderDuration) ?? 20
        habitReminderStartTime = try container.decodeIfPresent(Date.self, forKey: .habitReminderStartTime)
        habitReminderEndTime = try container.decodeIfPresent(Date.self, forKey: .habitReminderEndTime)
    }
    
    // Memberwise init re-declaration needed because init(from:) removes the synthesized one
    init(
        id: UUID, 
        type: AlarmType = .wakeUp, 
        name: String, 
        emoji: String, 
        hour: Int, 
        minute: Int, 
        second: Int = 0,
        isDaily: Bool, 
        repeatMask: Int, 
        enabled: Bool, 
        wakeUpCheckEnabled: Bool, 
        soundName: String, 
        soundVolume: Float, 
        vibrateEnabled: Bool, 
        gentleWakeUpSeconds: Int, 
        timeReminderEnabled: Bool, 
        weatherReminderEnabled: Bool, 
        labelReminderEnabled: Bool, 
        extraLoudEnabled: Bool, 
        bypassSilentMode: Bool = true, 
        timeZoneMode: AlarmTimeZoneMode = .local,
        timeZoneIdentifier: String? = nil,
        timeZoneCity: String? = nil,
        snoozeMinutes: Int,  
        snoozeCount: Int, 
        wallpaperId: String, 
        createdAt: Date,
        isSkippedOnce: Bool = false,
        missions: [AlarmMission] = [],
        enforcementMode: EnforcementMode = .none,
        blockAppsEnabled: Bool = false,
        blockedSelectionData: Data? = nil,
        penaltyEnabled: Bool = false,
        penaltyAmountEuro: Int = 1,
        penaltyStrategy: PenaltyStrategy = .credits,
        penaltyRules: PenaltyRules = .default,
        lastPenaltyEventAt: Date? = nil,
        penaltyEventLog: [PenaltyEventRecord] = [],
        habitReminderEnabled: Bool = false,
        habitReminderInterval: Int = 20,
        habitReminderDuration: Int = 20,
        habitReminderStartTime: Date? = nil,
        habitReminderEndTime: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.hour = hour
        self.minute = minute
        self.second = second
        self.emoji = emoji
        self.isDaily = isDaily
        self.repeatMask = repeatMask
        self.enabled = enabled
        self.wakeUpCheckEnabled = wakeUpCheckEnabled
        self.soundName = soundName
        self.soundVolume = soundVolume
        self.vibrateEnabled = vibrateEnabled
        self.gentleWakeUpSeconds = gentleWakeUpSeconds
        self.timeReminderEnabled = timeReminderEnabled
        self.weatherReminderEnabled = weatherReminderEnabled
        self.labelReminderEnabled = labelReminderEnabled
        self.extraLoudEnabled = extraLoudEnabled
        self.bypassSilentMode = bypassSilentMode
        self.timeZoneMode = timeZoneMode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeZoneCity = timeZoneCity
        self.snoozeMinutes = snoozeMinutes
        self.snoozeCount = snoozeCount
        self.wallpaperId = wallpaperId
        self.createdAt = createdAt
        self.isSkippedOnce = isSkippedOnce
        self.missions = missions
        self.enforcementMode = enforcementMode
        self.blockAppsEnabled = blockAppsEnabled
        self.blockedSelectionData = blockedSelectionData
        self.penaltyEnabled = penaltyEnabled
        self.penaltyAmountEuro = min(10, max(1, penaltyAmountEuro))
        self.penaltyStrategy = penaltyStrategy
        self.penaltyRules = penaltyRules
        self.lastPenaltyEventAt = lastPenaltyEventAt
        self.penaltyEventLog = penaltyEventLog
        self.habitReminderEnabled = habitReminderEnabled
        self.habitReminderInterval = habitReminderInterval
        self.habitReminderDuration = habitReminderDuration
        self.habitReminderStartTime = habitReminderStartTime
        self.habitReminderEndTime = habitReminderEndTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(second, forKey: .second)
        try container.encode(isDaily, forKey: .isDaily)
        try container.encode(repeatMask, forKey: .repeatMask)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(wakeUpCheckEnabled, forKey: .wakeUpCheckEnabled)
        try container.encode(soundName, forKey: .soundName)
        try container.encode(soundVolume, forKey: .soundVolume)
        try container.encode(vibrateEnabled, forKey: .vibrateEnabled)
        try container.encode(gentleWakeUpSeconds, forKey: .gentleWakeUpSeconds)
        try container.encode(timeReminderEnabled, forKey: .timeReminderEnabled)
        try container.encode(weatherReminderEnabled, forKey: .weatherReminderEnabled)
        try container.encode(labelReminderEnabled, forKey: .labelReminderEnabled)
        try container.encode(extraLoudEnabled, forKey: .extraLoudEnabled)
        try container.encode(bypassSilentMode, forKey: .bypassSilentMode)
        try container.encode(timeZoneMode, forKey: .timeZoneMode)
        try container.encodeIfPresent(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try container.encodeIfPresent(timeZoneCity, forKey: .timeZoneCity)
        try container.encode(snoozeMinutes, forKey: .snoozeMinutes)
        try container.encode(snoozeCount, forKey: .snoozeCount)
        try container.encode(wallpaperId, forKey: .wallpaperId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isSkippedOnce, forKey: .isSkippedOnce)
        try container.encode(missions, forKey: .missions)
        try container.encode(enforcementMode, forKey: .enforcementMode)
        try container.encode(blockAppsEnabled, forKey: .blockAppsEnabled)
        try container.encodeIfPresent(blockedSelectionData, forKey: .blockedSelectionData)
        try container.encode(penaltyEnabled, forKey: .penaltyEnabled)
        try container.encode(min(10, max(1, penaltyAmountEuro)), forKey: .penaltyAmountEuro)
        try container.encode(penaltyStrategy, forKey: .penaltyStrategy)
        try container.encode(penaltyRules, forKey: .penaltyRules)
        try container.encodeIfPresent(lastPenaltyEventAt, forKey: .lastPenaltyEventAt)
        try container.encode(penaltyEventLog, forKey: .penaltyEventLog)
        try container.encode(habitReminderEnabled, forKey: .habitReminderEnabled)
        try container.encode(habitReminderInterval, forKey: .habitReminderInterval)
        try container.encode(habitReminderDuration, forKey: .habitReminderDuration)
        try container.encodeIfPresent(habitReminderStartTime, forKey: .habitReminderStartTime)
        try container.encodeIfPresent(habitReminderEndTime, forKey: .habitReminderEndTime)
    }
    
    func duplicate() -> Alarm {
        var copy = self
        copy.id = UUID()
        copy.createdAt = Date()
        copy.isSkippedOnce = false
        return copy
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, emoji, hour, minute, second, isDaily, repeatMask, enabled
        case wakeUpCheckEnabled, soundName, soundVolume, vibrateEnabled
        case gentleWakeUpSeconds, timeReminderEnabled, weatherReminderEnabled
        case labelReminderEnabled, extraLoudEnabled, bypassSilentMode, snoozeMinutes, snoozeCount
        case wallpaperId, createdAt, isSkippedOnce, missions
        case enforcementMode, blockAppsEnabled, blockedSelectionData
        case penaltyEnabled, penaltyAmountEuro, penaltyStrategy, penaltyRules
        case lastPenaltyEventAt, penaltyEventLog
        case habitReminderEnabled, habitReminderInterval, habitReminderDuration
        case habitReminderStartTime, habitReminderEndTime
        case timeZoneMode, timeZoneIdentifier, timeZoneCity
    }
}

enum AlarmTimeZoneMode: String, Codable {
    case local
    case custom
}
