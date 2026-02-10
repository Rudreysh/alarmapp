import SwiftUI
import Combine

class CreateHabitAlarmViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var emoji: String = "🍗" // Default from screenshot
    @Published var hour: Int
    @Published var minute: Int
    @Published var second: Int = 0
    @Published var isDaily: Bool = true
    @Published var selectedWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    @Published var soundName: String = "Orkney"
    @Published var soundVolume: Float = 1.0
    @Published var vibrateEnabled: Bool = true
    @Published var gentleWakeUpSeconds: Int = 30
    @Published var bypassSilentMode: Bool = true
    @Published var timeZoneMode: AlarmTimeZoneMode = .local
    @Published var timeZoneIdentifier: String?
    @Published var timeZoneCity: String?
    
    @Published var timeReminderEnabled: Bool = false
    @Published var weatherReminderEnabled: Bool = false
    @Published var labelReminderEnabled: Bool = false
    @Published var extraLoudEnabled: Bool = false
    
    @Published var snoozeMinutes: Int = 5
    @Published var snoozeCount: Int = 3
    @Published var wallpaperId: String
    @Published var wakeUpCheckEnabled: Bool = false
    @Published var missions: [AlarmMission] = []
    
    // Accountability Shield
    @Published var accountabilityEnabled: Bool = false
    @Published var blockAppsEnabled: Bool = false
    @Published var penaltyEnabled: Bool = false
    @Published var penaltyAmountEuro: Int = 1
    
    // Reminder Feature
    @Published var reminderEnabled: Bool = false
    @Published var reminderIntervalMinutes: Int = 20
    @Published var reminderDurationSeconds: Int = 20
    @Published var reminderStartTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var reminderEndTime: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    
    @Published var ringInText: String = ""
    
    let defaultSoundName: String
    
    init(defaultHour: Int, defaultMinute: Int, defaultSecond: Int = 0, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.hour = defaultHour
        self.minute = defaultMinute
        self.second = defaultSecond
        self.soundName = defaultSoundName
        self.soundVolume = defaultSoundVolume
        self.defaultSoundName = defaultSoundName
        self.wallpaperId = AlarmDraft(defaultHour: defaultHour, defaultMinute: defaultMinute, defaultRepeatMask: RepeatMask.allDays, defaultSoundName: defaultSoundName, defaultSoundVolume: defaultSoundVolume, defaultWallpaperId: defaultWallpaperId).wallpaperId
        let settings = SettingsStore.shared
        self.accountabilityEnabled = settings.accountabilityEnabled
        self.blockAppsEnabled = settings.blockAppsEnabled
        self.penaltyEnabled = settings.penaltyEnabled
        self.penaltyAmountEuro = settings.penaltyAmountEuro
        
        updateRingInText()
    }
    
    func toggleDaily() {
        isDaily.toggle()
        if isDaily {
            selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]
        }
        updateRingInText()
    }
    
    func toggleWeekday(_ day: Int) {
        if isDaily {
            isDaily = false
            // Keep all selected when moving from Daily to Custom, then toggle the clicked day
            selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]
        }
        
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
        
        // Auto-check Daily if all 7 selected
        isDaily = selectedWeekdays.count == 7
        
        updateRingInText()
    }
    
    func updateRingInText() {
        let alarm = Alarm(
            id: UUID(),
            type: .habit,
            name: name,
            emoji: emoji,
            hour: hour,
            minute: minute,
            second: second,
            isDaily: isDaily,
            repeatMask: repeatMask(),
            enabled: true,
            wakeUpCheckEnabled: wakeUpCheckEnabled,
            soundName: soundName,
            soundVolume: soundVolume,
            vibrateEnabled: vibrateEnabled,
            gentleWakeUpSeconds: gentleWakeUpSeconds,
            timeReminderEnabled: timeReminderEnabled,
            weatherReminderEnabled: weatherReminderEnabled,
            labelReminderEnabled: labelReminderEnabled,
            extraLoudEnabled: extraLoudEnabled,
            bypassSilentMode: bypassSilentMode,
            timeZoneMode: timeZoneMode,
            timeZoneIdentifier: timeZoneIdentifier,
            timeZoneCity: timeZoneCity,
            snoozeMinutes: snoozeMinutes,
            snoozeCount: snoozeCount,
            wallpaperId: wallpaperId,
            createdAt: Date(),
            missions: missions
        )
        
        let now = Date()
        guard let target = AlarmStore.nextFireDate(for: alarm, from: now) else {
            ringInText = "Not scheduled"
            return
        }
        
        let diff = Int(target.timeIntervalSince(now))
        if diff < 60 {
            ringInText = "Ring in less than a minute"
        } else {
            let days = diff / 86400
            let hours = (diff % 86400) / 3600
            let minutes = (diff % 3600) / 60
            
            if days > 0 {
                ringInText = "Ring in \(days)d \(hours)h \(minutes)m"
            } else if hours > 0 {
                ringInText = "Ring in \(hours)h \(minutes)m"
            } else {
                ringInText = "Ring in \(minutes)m"
            }
        }
    }
    
    func repeatMask() -> Int {
        if isDaily { return RepeatMask.allDays }
        return RepeatMask.mask(from: Array(selectedWeekdays))
    }
    
    func addMission(_ mission: AlarmMission) {
        if missions.count < 4 {
            missions.append(mission)
        }
    }
    
    func removeMission(at index: Int) {
        missions.remove(at: index)
    }
    
    var reminderSummary: AttributedString {
        let habitName = name.isEmpty ? "your habit" : name
        
        var string = AttributedString("I want to ")
        
        var habitAttr = AttributedString(habitName)
        habitAttr.foregroundColor = Colors.accentTeal
        habitAttr.underlineStyle = .single
        string.append(habitAttr)
        
        string.append(AttributedString(" every "))
        
        var intervalAttr = AttributedString("\(reminderIntervalMinutes) minutes")
        intervalAttr.foregroundColor = Colors.accentTeal
        string.append(intervalAttr)
        
        string.append(AttributedString(" for "))
        
        var durationAttr = AttributedString("\(reminderDurationSeconds) seconds")
        durationAttr.foregroundColor = Colors.accentTeal
        string.append(durationAttr)
        
        string.append(AttributedString("."))
        
        return string
    }
}
