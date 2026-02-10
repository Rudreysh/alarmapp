import SwiftUI
import Combine

class QuickAlarmViewModel: ObservableObject {
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    @Published var selectedSoundId: String
    @Published var selectedWallpaperId: String
    @Published var volume: Float
    @Published var vibrateEnabled: Bool = true
    @Published var bypassSilentMode: Bool = true
    
    // Accountability Shield
    @Published var accountabilityEnabled: Bool
    @Published var blockAppsEnabled: Bool
    @Published var penaltyEnabled: Bool
    @Published var penaltyAmountEuro: Int
    
    // For UI State
    @Published var fireDateString: String = ""
    
    var totalSeconds: Int {
        return minutes * 60 + seconds
    }
    
    private var timer: Timer?
    private let soundPlayer = SoundPlayer()
    private let settingsStore = SettingsStore.shared
    
    init(defaults: AppPreferences = AppPreferences()) {
        self.selectedSoundId = defaults.onboardingSoundName
        self.selectedWallpaperId = defaults.onboardingWallpaperId
        self.volume = defaults.onboardingSoundVolume
        self.accountabilityEnabled = settingsStore.accountabilityEnabled
        self.blockAppsEnabled = settingsStore.blockAppsEnabled
        self.penaltyEnabled = settingsStore.penaltyEnabled
        self.penaltyAmountEuro = settingsStore.penaltyAmountEuro
        updateDateString()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func setPreset(minutes: Int, seconds: Int = 0) {
        self.minutes = minutes
        self.seconds = seconds
        updateDateString()
    }
    
    func reset() {
        minutes = 0
        seconds = 0
        updateDateString()
    }
    
    private func updateDateString() {
        let totalSec = totalSeconds
        if totalSec == 0 {
            fireDateString = TimeFormatters.formattedTime24Hour(date: Date())
            return
        }
        
        let triggerDate = Date().addingTimeInterval(TimeInterval(totalSec))
        fireDateString = TimeFormatters.formattedTime24Hour(date: triggerDate)
    }
    
    private func startTimer() {
        // Keep "Ring at..." updated every minute or so
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateDateString()
        }
    }
    
    func save(store: AlarmStore, scheduler: AlarmSchedulerProtocol) {
        // Validation: If 0, bump to 1 minute
        let finalSeconds = totalSeconds == 0 ? 60 : totalSeconds
        
        // Calculate fire date
        let fireDate = Date().addingTimeInterval(TimeInterval(finalSeconds))
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
        
        var alarmPenaltyRules = settingsStore.penaltyRules
        // Alarm penalty in this mode is snooze-threshold based.
        alarmPenaltyRules.alarmMissionFailTriggersPenalty = false

        let alarmId = UUID()
        let alarm = Alarm(
            id: alarmId,
            type: .quick,
            name: "Quick Alarm",
            emoji: "⚡️",
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            second: comps.second ?? 0,
            isDaily: false,
            repeatMask: 0,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: selectedSoundId,
            soundVolume: volume,
            vibrateEnabled: vibrateEnabled,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            bypassSilentMode: bypassSilentMode,
            snoozeMinutes: 5,
            snoozeCount: 3,
            wallpaperId: selectedWallpaperId,
            createdAt: Date(),
            enforcementMode: accountabilityEnabled
                ? (blockAppsEnabled && penaltyEnabled
                    ? .blockAppsAndPenalty
                    : (blockAppsEnabled ? .blockApps : .penaltyOnly))
                : .none,
            blockAppsEnabled: accountabilityEnabled && blockAppsEnabled,
            blockedSelectionData: settingsStore.blockedAppsSelectionData,
            penaltyEnabled: accountabilityEnabled && penaltyEnabled,
            penaltyAmountEuro: penaltyAmountEuro,
            penaltyStrategy: .credits,
            penaltyRules: alarmPenaltyRules
        )
        
        print("[QuickAlarm] Saving alarm for +\(finalSeconds) sec (at: \(alarm.timeString))")
        store.add(alarm)
        
        // Logic for "One-time" scheduling with robust scheduler
        // Note: The new AlarmScheduler handles dates intelligently.
        scheduler.schedule(alarm: alarm)
    }
}
