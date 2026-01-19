import SwiftUI
import Combine

class QuickAlarmViewModel: ObservableObject {
    @Published var minutes: Int = 0
    @Published var selectedSoundId: String
    @Published var selectedWallpaperId: String
    @Published var volume: Float
    @Published var vibrateEnabled: Bool = true
    
    // For UI State
    @Published var fireDateString: String = ""
    
    private var timer: Timer?
    private let soundPlayer = SoundPlayer() // Assuming SoundPlayer allows one-off play
    // Assuming we can access the repository externally or pass it in later. 
    // In actual pattern, might want a Service.
    
    init(defaults: AppPreferences = AppPreferences()) {
        self.selectedSoundId = defaults.onboardingSoundName
        self.selectedWallpaperId = defaults.onboardingWallpaperId
        self.volume = defaults.onboardingSoundVolume
        updateDateString()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func setPreset(_ value: Int) {
        if value >= 60 && value % 60 == 0 {
             // Handle "1 hours" button -> 60 min. The button probably sends 60.
        }
        minutes = value
        updateDateString()
    }
    
    func reset() {
        minutes = 0
        updateDateString()
    }
    
    private func updateDateString() {
        if minutes == 0 {
             // For 0, we can either look current time (ring now?) but design shows "Ring at HH:MM PM" 
             // Defaulting to "Ring at [Now]" if 0
        }
        
        let triggerDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        fireDateString = TimeFormatters.formattedTime24Hour(date: triggerDate)
    }
    
    private func startTimer() {
        // Keep "Ring at..." updated every minute or so
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateDateString()
        }
    }
    
    func save(store: AlarmStore, scheduler: AlarmSchedulerProtocol) {
        // Validation: If 0, bump to 1
        let finalMinutes = minutes == 0 ? 1 : minutes
        
        // Calculate fire date
        let fireDate = Date().addingTimeInterval(TimeInterval(finalMinutes * 60))
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: fireDate)
        
        let alarmId = UUID()
        let alarm = Alarm(
            id: alarmId,
            type: .quick,
            name: "Quick Alarm",
            emoji: "⚡️",
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
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
            snoozeMinutes: 5,
            snoozeCount: 3,
            wallpaperId: selectedWallpaperId,
            createdAt: Date()
        )
        
        print("[QuickAlarm] Saving alarm for +\(finalMinutes) min (at: \(alarm.timeString))")
        store.add(alarm)
        
        // Logic for "One-time" scheduling with robust scheduler
        // Note: The new AlarmScheduler handles dates intelligently.
        scheduler.schedule(alarm: alarm)
    }
}
