import Foundation
import Combine

final class CreateWakeUpAlarmViewModel: ObservableObject {
    @Published var draft: AlarmDraft
    @Published var soundProgress: Double = 0.0
    @Published var cycleToLocal: Bool = false
    private var cycleTimer: AnyCancellable?

    init(defaultHour: Int, defaultMinute: Int, defaultSecond: Int = 0, defaultRepeatMask: Int, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.draft = AlarmDraft(
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            defaultSecond: defaultSecond,
            defaultRepeatMask: defaultRepeatMask,
            defaultSoundName: defaultSoundName,
            defaultSoundVolume: defaultSoundVolume,
            defaultWallpaperId: defaultWallpaperId
        )
        let settings = SettingsStore.shared
        if !settings.alarmWallpaperId.isEmpty {
            draft.wallpaperId = settings.alarmWallpaperId
        }
        draft.bypassSilentMode = settings.alarmRingInSilentModeEnabled
        draft.dailyMotivationEnabled = settings.alarmDailyMotivationEnabled
        draft.visualOutputSettings = settings.alarmVisualOutputSettings
        if draft.timeZoneMode == .custom {
            startCycling()
        }
    }

    init(alarm: Alarm) {
        var draft = AlarmDraft(
            defaultHour: alarm.hour,
            defaultMinute: alarm.minute,
            defaultSecond: alarm.second,
            defaultRepeatMask: alarm.repeatMask,
            defaultSoundName: alarm.soundName,
            defaultSoundVolume: alarm.soundVolume,
            defaultWallpaperId: alarm.wallpaperId
        )
        draft.dailyMotivationEnabled = alarm.dailyMotivationEnabled
        draft.visualOutputSettings = alarm.visualOutputSettings
        draft.name = alarm.name
        draft.emoji = alarm.emoji
        draft.enabled = alarm.enabled
        draft.isDaily = alarm.isDaily
        draft.selectedWeekdays = Set(RepeatMask.weekdays(from: alarm.repeatMask))
        draft.wakeUpCheckEnabled = alarm.wakeUpCheckEnabled
        draft.vibrateEnabled = alarm.vibrateEnabled
        draft.gentleWakeUpSeconds = alarm.gentleWakeUpSeconds
        draft.timeReminderEnabled = alarm.timeReminderEnabled
        draft.weatherReminderEnabled = alarm.weatherReminderEnabled
        draft.labelReminderEnabled = alarm.labelReminderEnabled
        draft.extraLoudEnabled = alarm.extraLoudEnabled
        draft.bypassSilentMode = alarm.bypassSilentMode
        draft.timeZoneMode = alarm.timeZoneMode
        draft.timeZoneIdentifier = alarm.timeZoneIdentifier
        draft.timeZoneCity = alarm.timeZoneCity
        draft.snoozeMinutes = alarm.snoozeMinutes
        draft.snoozeSeconds = alarm.snoozeSeconds
        draft.snoozeCount = alarm.snoozeCount
        draft.missions = alarm.missions
        draft.accountabilityEnabled = alarm.enforcementMode != .none
        draft.blockAppsEnabled = alarm.blockAppsEnabled
        draft.blockedSelectionData = alarm.blockedSelectionData
        draft.penaltyEnabled = alarm.penaltyEnabled
        draft.penaltyAmountEuro = alarm.penaltyAmountEuro
        draft.penaltyRules = alarm.penaltyRules
        self.draft = draft
        if draft.timeZoneMode == .custom {
            startCycling()
        }
    }
    
    func addMission(_ mission: AlarmMission) {
        if draft.missions.count < 4 {
            draft.missions.append(mission)
        }
    }
    
    func removeMission(at index: Int) {
        draft.missions.remove(at: index)
    }

    var ringInText: String {
        let now = Date()
        guard let next = nextFireDate(from: now) else {
            return "Not scheduled"
        }
        
        let diff = Int(next.timeIntervalSince(now))
        if diff < 60 {
            return "Ring in less than a minute"
        }
        
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        
        if days > 0 {
            return "Ring in \(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "Ring in \(hours)h \(minutes)m"
        } else {
            return "Ring in \(minutes)m"
        }
    }

    func toggleDaily() {
        draft.isDaily.toggle()
        if draft.isDaily {
            draft.selectedWeekdays = Set(1...7)
        }
    }

    func toggleWeekday(_ weekday: Int) {
        if draft.isDaily {
            draft.isDaily = false
            draft.selectedWeekdays = Set(1...7)
        }
        
        if draft.selectedWeekdays.contains(weekday) {
            draft.selectedWeekdays.remove(weekday)
        } else {
            draft.selectedWeekdays.insert(weekday)
        }
        
        draft.isDaily = draft.selectedWeekdays.count == 7
    }

    func nextFireDate(from date: Date) -> Date? {
        // Use the unified logic in AlarmStore to avoid duplicate bugs
        let tempAlarm = Alarm(
            id: UUID(),
            name: draft.name,
            emoji: draft.emoji,
            hour: draft.hour,
            minute: draft.minute,
            second: draft.second,
            isDaily: draft.isDaily,
            repeatMask: repeatMask(),
            enabled: true,
            wakeUpCheckEnabled: draft.wakeUpCheckEnabled,
            soundName: draft.soundName,
            soundVolume: draft.soundVolume,
            vibrateEnabled: draft.vibrateEnabled,
            gentleWakeUpSeconds: draft.gentleWakeUpSeconds,
            timeReminderEnabled: draft.timeReminderEnabled,
            weatherReminderEnabled: draft.weatherReminderEnabled,
            labelReminderEnabled: draft.labelReminderEnabled,
            extraLoudEnabled: draft.extraLoudEnabled,
            timeZoneMode: draft.timeZoneMode,
            timeZoneIdentifier: draft.timeZoneIdentifier,
            timeZoneCity: draft.timeZoneCity,
            snoozeMinutes: draft.snoozeMinutes,
            snoozeSeconds: draft.snoozeSeconds,
            snoozeCount: draft.snoozeCount,
            wallpaperId: draft.wallpaperId,
            dailyMotivationEnabled: draft.dailyMotivationEnabled,
            visualOutputSettings: draft.visualOutputSettings,
            createdAt: Date()
        )
        
        return AlarmStore.nextFireDate(for: tempAlarm, from: date)
    }

    func repeatMask() -> Int {
        if draft.isDaily { return RepeatMask.allDays }
        return RepeatMask.mask(from: Array(draft.selectedWeekdays))
    }

    func startCycling() {
        cycleTimer?.cancel()
        cycleTimer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Use standard SwiftUI animation if possible or just toggle
                self?.cycleToLocal.toggle()
            }
    }
    
    func stopCycling() {
        cycleTimer?.cancel()
        cycleTimer = nil
        cycleToLocal = false
    }
}
