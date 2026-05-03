import SwiftUI
import Combine

struct QuickAlarmPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var iconName: String
    var colorKey: String
    var title: String
    var minutes: Int
    var seconds: Int

    init(
        id: UUID = UUID(),
        iconName: String,
        colorKey: String,
        title: String,
        minutes: Int,
        seconds: Int = 0
    ) {
        self.id = id
        self.iconName = iconName
        self.colorKey = colorKey
        self.title = title
        self.minutes = max(0, minutes)
        self.seconds = max(0, min(59, seconds))
    }

    var timeLabel: String {
        if minutes >= 60 && seconds == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hr" : "\(hours) hrs"
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

class QuickAlarmViewModel: ObservableObject {
    @Published var minutes: Int = 0
    @Published var seconds: Int = 0
    @Published var alarmName: String
    @Published var alarmEmoji: String
    @Published var selectedSoundId: String
    @Published var selectedWallpaperId: String
    @Published var volume: Float
    @Published var vibrateEnabled: Bool = true
    @Published var bypassSilentMode: Bool = true
    
    // Accountability Penalty
    @Published var accountabilityEnabled: Bool
    @Published var blockAppsEnabled: Bool
    @Published var penaltyEnabled: Bool
    @Published var penaltyAmountEuro: Int
    @Published var shutdownProtectionEnabled: Bool
    
    // New Settings
    @Published var gentleWakeUpSeconds: Int = 0
    @Published var wakeUpCheckEnabled: Bool = false
    @Published var timeZoneMode: AlarmTimeZoneMode = .local
    @Published var timeZoneIdentifier: String? = nil
    @Published var timeZoneCity: String? = nil
    @Published var dailyMotivationEnabled: Bool = false
    @Published var visualOutputSettings: AlarmVisualOutputSettings
    @Published var presets: [QuickAlarmPreset] = []
    @Published var selectedPresetIDs: Set<UUID> = []
    
    // For UI State
    @Published var fireDateString: String = ""
    
    var totalSeconds: Int {
        return minutes * 60 + seconds
    }
    
    private var timer: Timer?
    private let soundPlayer = SoundPlayer()
    private let settingsStore = SettingsStore.shared
    private let presetsStorageKey = "quick_alarm_presets_v1"
    private static let emojiIconPrefix = "emoji:"
    private let customPresetIconPool = ["timer", "clock.fill", "bolt.fill", "moon.zzz.fill", "target"]
    private let customPresetColorPool = ["teal", "blue", "indigo", "purple", "green", "orange"]
    private let editingAlarm: Alarm?
    
    init(existingAlarm: Alarm? = nil, defaults: AppPreferences = AppPreferences()) {
        self.editingAlarm = existingAlarm
        self.alarmName = existingAlarm?.name ?? ""
        self.alarmEmoji = existingAlarm?.emoji ?? "⚡️"
        self.selectedSoundId = existingAlarm?.soundName ?? defaults.onboardingSoundName
        self.selectedWallpaperId = existingAlarm?.wallpaperId ?? (settingsStore.alarmWallpaperId.isEmpty ? defaults.onboardingWallpaperId : settingsStore.alarmWallpaperId)
        self.volume = existingAlarm?.soundVolume ?? defaults.onboardingSoundVolume
        self.accountabilityEnabled = existingAlarm.map { $0.enforcementMode != .none } ?? settingsStore.accountabilityEnabled
        self.blockAppsEnabled = existingAlarm?.blockAppsEnabled ?? false
        self.penaltyEnabled = existingAlarm?.penaltyEnabled ?? settingsStore.penaltyEnabled
        self.penaltyAmountEuro = existingAlarm?.penaltyAmountEuro ?? settingsStore.penaltyAmountEuro
        self.shutdownProtectionEnabled = existingAlarm?.shutdownProtectionEnabled ?? settingsStore.preventPowerOffEnabled
        self.bypassSilentMode = existingAlarm?.bypassSilentMode ?? settingsStore.alarmRingInSilentModeEnabled
        self.dailyMotivationEnabled = existingAlarm?.dailyMotivationEnabled ?? settingsStore.alarmDailyMotivationEnabled
        self.visualOutputSettings = existingAlarm?.visualOutputSettings ?? settingsStore.alarmVisualOutputSettings
        self.gentleWakeUpSeconds = existingAlarm?.gentleWakeUpSeconds ?? 0
        self.wakeUpCheckEnabled = existingAlarm?.wakeUpCheckEnabled ?? false
        self.timeZoneMode = existingAlarm?.timeZoneMode ?? .local
        self.timeZoneIdentifier = existingAlarm?.timeZoneIdentifier
        self.timeZoneCity = existingAlarm?.timeZoneCity
        self.presets = Self.loadStoredPresets(forKey: presetsStorageKey) ?? Self.defaultPresets
        if let existingAlarm {
            applyExistingAlarmTime(existingAlarm)
        } else {
            updateDateString()
        }
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

    func setPreset(_ preset: QuickAlarmPreset) {
        setPreset(minutes: preset.minutes, seconds: preset.seconds)
    }

    func togglePresetSelection(_ preset: QuickAlarmPreset) {
        if selectedPresetIDs.contains(preset.id) {
            selectedPresetIDs.remove(preset.id)
        } else {
            selectedPresetIDs.insert(preset.id)
            // Keep main timer preview aligned to the latest selection.
            setPreset(preset)
        }
    }

    func clearPresetSelections() {
        selectedPresetIDs.removeAll()
    }

    func addCustomPreset(title: String, minutes: Int, seconds: Int, emoji: String? = nil) {
        let clampedMinutes = max(0, minutes)
        let clampedSeconds = max(0, min(59, seconds))
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "without name" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackIcon = customPresetIconPool[presets.count % customPresetIconPool.count]
        let icon = normalizedPresetIcon(rawEmoji: emoji, fallbackSymbol: fallbackIcon)
        let color = customPresetColorPool[presets.count % customPresetColorPool.count]
        let preset = QuickAlarmPreset(iconName: icon, colorKey: color, title: safeTitle, minutes: clampedMinutes, seconds: clampedSeconds)
        presets.append(preset)
        persistPresets()
    }

    func updatePreset(id: UUID, title: String, minutes: Int, seconds: Int, emoji: String? = nil) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? presets[index].title : title.trimmingCharacters(in: .whitespacesAndNewlines)
        presets[index].title = safeTitle
        presets[index].minutes = max(0, minutes)
        presets[index].seconds = max(0, min(59, seconds))
        if let emoji {
            presets[index].iconName = normalizedPresetIcon(rawEmoji: emoji, fallbackSymbol: presets[index].iconName)
        }
        persistPresets()
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        if presets.isEmpty {
            presets = Self.defaultPresets
        }
        persistPresets()
    }

    func resetPresetsToDefault() {
        presets = Self.defaultPresets
        persistPresets()
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

    private func applyExistingAlarmTime(_ alarm: Alarm) {
        let now = Date()
        let remainingSeconds: Int
        if let next = AlarmStore.nextFireDate(for: alarm, from: now) {
            remainingSeconds = max(1, Int(next.timeIntervalSince(now)))
        } else {
            remainingSeconds = 60
        }
        minutes = remainingSeconds / 60
        seconds = remainingSeconds % 60
        updateDateString()
    }
    
    func save(store: AlarmStore, scheduler: AlarmSchedulerProtocol) {
        if editingAlarm == nil, !selectedPresetIDs.isEmpty {
            let selectedPresets = presets.filter { selectedPresetIDs.contains($0.id) }
            let now = Date()
            for (index, preset) in selectedPresets.enumerated() {
                let finalSeconds = max(1, (preset.minutes * 60) + preset.seconds)
                let alarm = buildAlarm(
                    finalSeconds: finalSeconds,
                    id: UUID(),
                    createdAt: now.addingTimeInterval(TimeInterval(index)),
                    nameOverride: preset.title
                )
                store.add(alarm)
                DispatchQueue.global(qos: .utility).async {
                    scheduler.schedule(alarm: alarm)
                }
            }
            return
        }

        // Validation: If 0, bump to 1 minute
        let finalSeconds = totalSeconds == 0 ? 60 : totalSeconds
        let alarmId = editingAlarm?.id ?? UUID()
        let createdAt = editingAlarm?.createdAt ?? Date()
        let alarm = buildAlarm(finalSeconds: finalSeconds, id: alarmId, createdAt: createdAt)
        
        if editingAlarm == nil {
            print("[QuickAlarm] Saving alarm for +\(finalSeconds) sec (at: \(alarm.timeString))")
            store.add(alarm)
        } else {
            print("[QuickAlarm] Updating alarm \(alarm.id) for +\(finalSeconds) sec (at: \(alarm.timeString))")
            store.update(alarm)
        }
        
        // Scheduling can be expensive (sound staging + multiple notification requests).
        // Keep it off main so Save-to-dismiss stays responsive.
        DispatchQueue.global(qos: .utility).async {
            scheduler.schedule(alarm: alarm)
        }
    }

    private func buildAlarm(
        finalSeconds: Int,
        id: UUID,
        createdAt: Date,
        nameOverride: String? = nil
    ) -> Alarm {
        let fireDate = Date().addingTimeInterval(TimeInterval(finalSeconds))
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: fireDate)
        let shouldBlockApps = blockAppsEnabled
        let enforcementMode: EnforcementMode = shouldBlockApps ? .blockApps : .none

        let normalizedName = nameOverride
            ?? alarmName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = normalizedName.isEmpty ? "Quick Alarm" : normalizedName
        let resolvedEmoji = alarmEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "⚡️"
            : alarmEmoji

        return Alarm(
            id: id,
            type: .quick,
            name: resolvedName,
            emoji: resolvedEmoji,
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            second: comps.second ?? 0,
            isDaily: editingAlarm?.isDaily ?? false,
            repeatMask: editingAlarm?.repeatMask ?? 0,
            enabled: true,
            wakeUpCheckEnabled: wakeUpCheckEnabled,
            soundName: selectedSoundId,
            soundVolume: volume,
            vibrateEnabled: vibrateEnabled,
            gentleWakeUpSeconds: gentleWakeUpSeconds,
            timeReminderEnabled: editingAlarm?.timeReminderEnabled ?? false,
            weatherReminderEnabled: editingAlarm?.weatherReminderEnabled ?? false,
            labelReminderEnabled: editingAlarm?.labelReminderEnabled ?? false,
            extraLoudEnabled: editingAlarm?.extraLoudEnabled ?? false,
            bypassSilentMode: bypassSilentMode,
            timeZoneMode: timeZoneMode,
            timeZoneIdentifier: timeZoneIdentifier,
            timeZoneCity: timeZoneCity,
            snoozeMinutes: editingAlarm?.snoozeMinutes ?? 5,
            snoozeSeconds: editingAlarm?.snoozeSeconds ?? 0,
            snoozeCount: editingAlarm?.snoozeCount ?? 3,
            wallpaperId: selectedWallpaperId,
            dailyMotivationEnabled: dailyMotivationEnabled,
            visualOutputSettings: AlarmVisualOutputSettings.migratedFromLegacy(
                wallpaperId: selectedWallpaperId,
                dailyMotivationEnabled: dailyMotivationEnabled
            ),
            createdAt: createdAt,
            isSkippedOnce: false,
            missions: editingAlarm?.missions ?? [],
            enforcementMode: enforcementMode,
            blockAppsEnabled: shouldBlockApps,
            blockedSelectionData: editingAlarm?.blockedSelectionData ?? settingsStore.blockedAppsSelectionData,
            penaltyEnabled: editingAlarm?.penaltyEnabled ?? false,
            penaltyAmountEuro: penaltyAmountEuro,
            penaltyStrategy: editingAlarm?.penaltyStrategy ?? .credits,
            penaltyRules: editingAlarm?.penaltyRules ?? .default,
            lastPenaltyEventAt: editingAlarm?.lastPenaltyEventAt,
            penaltyEventLog: editingAlarm?.penaltyEventLog ?? [],
            shutdownProtectionEnabled: shutdownProtectionEnabled,
            shutdownAttemptLog: editingAlarm?.shutdownAttemptLog ?? []
        )
    }

    private func normalizedPresetIcon(rawEmoji: String?, fallbackSymbol: String) -> String {
        let candidate = rawEmoji?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !candidate.isEmpty else { return fallbackSymbol }
        guard let firstChar = candidate.first else { return fallbackSymbol }
        return Self.emojiIconPrefix + String(firstChar)
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: presetsStorageKey)
    }

    private static func loadStoredPresets(forKey key: String) -> [QuickAlarmPreset]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        guard let decoded = try? JSONDecoder().decode([QuickAlarmPreset].self, from: data) else { return nil }
        return decoded.isEmpty ? nil : decoded
    }

    static let defaultPresets: [QuickAlarmPreset] = [
        QuickAlarmPreset(iconName: "1.circle", colorKey: "orange", title: "Super Fast", minutes: 1, seconds: 0),
        QuickAlarmPreset(iconName: "5.circle", colorKey: "yellow", title: "Short Nap", minutes: 5, seconds: 0),
        QuickAlarmPreset(iconName: "10.circle", colorKey: "green", title: "Coffee Break", minutes: 10, seconds: 0),
        QuickAlarmPreset(iconName: "moon.zzz.fill", colorKey: "teal", title: "Quick Rest", minutes: 15, seconds: 0),
        QuickAlarmPreset(iconName: "book.fill", colorKey: "blue", title: "Reading", minutes: 30, seconds: 0),
        QuickAlarmPreset(iconName: "brain.head.profile", colorKey: "indigo", title: "Deep Focus", minutes: 60, seconds: 0)
    ]
}
