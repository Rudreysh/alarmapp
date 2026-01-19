import SwiftUI
import Combine

class CreateHabitAlarmViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var emoji: String = "🍗" // Default from screenshot
    @Published var hour: Int
    @Published var minute: Int
    @Published var isDaily: Bool = true
    @Published var selectedWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    @Published var soundName: String = "Orkney"
    @Published var soundVolume: Float = 1.0
    @Published var vibrateEnabled: Bool = true
    @Published var gentleWakeUpSeconds: Int = 30
    
    @Published var timeReminderEnabled: Bool = false
    @Published var weatherReminderEnabled: Bool = false
    @Published var labelReminderEnabled: Bool = false
    @Published var extraLoudEnabled: Bool = false
    
    @Published var snoozeMinutes: Int = 5
    @Published var snoozeCount: Int = 3
    @Published var wallpaperId: String
    @Published var wakeUpCheckEnabled: Bool = false
    @Published var missions: [AlarmMission] = []
    
    @Published var ringInText: String = ""
    
    let defaultSoundName: String
    
    init(defaultHour: Int, defaultMinute: Int, defaultSoundName: String, defaultSoundVolume: Float, defaultWallpaperId: String) {
        self.hour = defaultHour
        self.minute = defaultMinute
        self.soundName = defaultSoundName
        self.soundVolume = defaultSoundVolume
        self.defaultSoundName = defaultSoundName
        self.wallpaperId = AlarmDraft(defaultHour: defaultHour, defaultMinute: defaultMinute, defaultRepeatMask: RepeatMask.allDays, defaultSoundName: defaultSoundName, defaultSoundVolume: defaultSoundVolume, defaultWallpaperId: defaultWallpaperId).wallpaperId
        
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
             selectedWeekdays = [] // First tap when DAILY -> clear others? Or start with full?
             // Usually UX: Uncheck Daily -> Keep all selected.
             // But if I tap a pill while Daily is ON, it should probably turn Daily OFF and Toggle that pill.
        }
        
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
        
        // Auto-check Daily if all 7 selected?
        if selectedWeekdays.count == 7 {
            isDaily = true
        } else {
            isDaily = false
        }
        
        updateRingInText()
    }
    
    func updateRingInText() {
        let calendar = Calendar.current
        let now = Date()
        var nextDate: Date?
        
        // Construct target components
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        if isDaily {
            nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        } else {
            // Find next matching weekday
            let sortedDays = selectedWeekdays.sorted()
            if sortedDays.isEmpty {
                ringInText = "Not scheduled"
                return
            }
            
            // Try to find next instance
            // We can iterate next 7 days and see if it matches
            for i in 0...7 {
                let candidate = calendar.date(byAdding: .day, value: i, to: now)!
                let candidateWeekday = calendar.component(.weekday, from: candidate)
                
                if sortedDays.contains(candidateWeekday) {
                     // Check time
                     let targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: candidate)!
                     if targetDate < now {
                         // If today but passed, continue to next week... NO, if today passed, we look at future days.
                         // But if we are iterating 0...7, day 0 is today.
                         // If day 0 matches weekday but time passed, we skip it.
                         // For subsequent days, any time is valid as it is in future.
                     } else {
                         nextDate = targetDate
                         break
                     }
                }
            }
        }
        
        guard let target = nextDate else {
            ringInText = "Scheduled for next week"
            return
        }
        
        let diff = target.timeIntervalSince(now)
        if diff < 60 {
            ringInText = "Ring in less than a minute"
        } else {
            let totalMinutes = Int(diff / 60)
            let h = totalMinutes / 60
            let m = totalMinutes % 60
            if h > 0 {
                ringInText = "Ring in \(h)hrs \(m)min"
            } else {
                ringInText = "Ring in \(m)min"
            }
        }
    }
    
    func repeatMask() -> Int {
        if isDaily { return RepeatMask.allDays }
        return RepeatMask.mask(from: Array(selectedWeekdays))
    }
    
    func addMission(_ mission: AlarmMission) {
        if missions.count < 5 {
            missions.append(mission)
        }
    }
    
    func removeMission(at index: Int) {
        missions.remove(at: index)
    }
}
