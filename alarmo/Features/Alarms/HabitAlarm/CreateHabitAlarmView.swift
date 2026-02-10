import SwiftUI

struct CreateHabitAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var notificationManager: NotificationManager
    let onClose: () -> Void
    
    @StateObject private var viewModel: CreateHabitAlarmViewModel
    @FocusState private var nameFocused: Bool
    
    @State private var showEmojiPicker = false
    @State private var showWakeUpCheck = false
    @State private var showSoundPicker = false
    @State private var showGentleWakeUpPicker = false
    @State private var showSnoozePicker = false
    @State private var showWallpaperPicker = false
    @State private var showTimeZonePicker = false
    @State private var showMissionSelection = false
    @State private var selectedMissionForConfig: AlarmMission?
    @State private var editingMissionIndex: Int?
    @State private var showAccountabilityInfo = false
    
    // Reminder Pickers
    @State private var showFrequencyPicker = false
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    
    // Services
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    @ObservedObject private var settingsStore = SettingsStore.shared
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    
    init(alarmStore: AlarmStore, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        let defaults = AppPreferences()
        _viewModel = StateObject(wrappedValue: CreateHabitAlarmViewModel(
            defaultHour: defaults.onboardingAlarmHour,
            defaultMinute: defaults.onboardingAlarmMinute,
            defaultSecond: defaults.onboardingAlarmSecond,
            defaultSoundName: defaults.onboardingSoundName,
            defaultSoundVolume: defaults.onboardingSoundVolume,
            defaultWallpaperId: defaults.onboardingWallpaperId
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Top Spacer for Header
                        Color.clear.frame(height: 12)

                        // 1. Digital Time Picker
                        DigitalTimeDisplay(
                            hour: $viewModel.hour,
                            minute: $viewModel.minute,
                            second: $viewModel.second
                        )
                        .padding(.top, 20)
                        
                        // Interactive Location Badge
                        Button(action: { showTimeZonePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.timeZoneMode == .custom ? "globe.americas.fill" : "location.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                
                                let cityName: String = {
                                    if viewModel.timeZoneMode == .custom, let id = viewModel.timeZoneIdentifier {
                                        return viewModel.timeZoneCity ?? id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
                                    }
                                    return "CURRENT LOCATION"
                                }()
                                
                                Text(cityName)
                                    .font(.system(size: 11, weight: .bold))
                                    .textCase(.uppercase)
                                    .kerning(1.0)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .opacity(0.5)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(viewModel.timeZoneMode == .custom ? Colors.accentTeal.opacity(0.12) : Colors.textSecondary.opacity(0.1))
                            )
                            .foregroundColor(viewModel.timeZoneMode == .custom ? Colors.accentTeal : Colors.textPrimary)
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.timeZoneMode == .custom ? Colors.accentTeal.opacity(0.2) : Colors.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 10)

                        // 2. Name & Emoji
                        HStack(spacing: Spacing.m) {
                            Button(action: { showEmojiPicker = true }) {
                                Text(viewModel.emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 44, height: 44)
                            }

                            TextField("Please fill in the alarm name", text: $viewModel.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .focused($nameFocused)

                            Button(action: { nameFocused = true }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                        
                        // 3. SETTINGS GROUPS

                        // Group A: Schedule
                        SectionHeader(title: "Schedule")
                        GroupedSettingsCard {
                            DaySelectionRow(
                                isDaily: $viewModel.isDaily,
                                selectedWeekdays: $viewModel.selectedWeekdays
                            )
                            
                            Divider()
                                .background(Color(white: 0.25))
                                .padding(.vertical, 4)
                            
                            MenuRow(
                                icon: "zzz",
                                title: "Snooze",
                                value: snoozeSummary
                            ) {
                                showSnoozePicker = true
                            }
                        }
                        
                        // Group B: Habit Reminder Feature (Specific to Habit Alarm)
                        SectionHeader(title: "Habit Reminder")
                        GroupedSettingsCard {
                            Toggle(isOn: $viewModel.reminderEnabled) {
                                Text("Active Reminders")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
                            
                            if viewModel.reminderEnabled {
                                Divider().padding(.leading, 16).opacity(0.3)
                                
                                MenuRow(
                                    icon: "timer",
                                    title: "Frequency",
                                    value: "\(viewModel.reminderIntervalMinutes) min"
                                ) {
                                    showFrequencyPicker = true
                                }
                                
                                Divider().padding(.leading, 52).opacity(0.3)
                                
                                MenuRow(
                                    icon: "clock.arrow.2.circlepath",
                                    title: "Active Window",
                                    value: "\(TimeFormatters.shortTime(viewModel.reminderStartTime)) - \(TimeFormatters.shortTime(viewModel.reminderEndTime))"
                                ) {
                                    showStartTimePicker = true 
                                }
                                
                                Text(viewModel.reminderSummary)
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                        }

                        // Group C: Missions
                        SectionHeader(title: "Wake Up Missions")
                        MissionSlotsView(
                            missions: viewModel.missions,
                            onAdd: {
                                editingMissionIndex = nil
                                showMissionSelection = true
                            },
                            onEdit: { index in
                                editingMissionIndex = index
                                showMissionSelection = true
                            },
                            onRemove: { index in
                                viewModel.removeMission(at: index)
                            }
                        )
                        .padding(.horizontal, 4)

                        // Group D: Sound & Behavior
                        SectionHeader(title: "Sound & Behavior")
                        GroupedSettingsCard {
                            MenuRow(
                                icon: "bell.fill",
                                title: "Alarm Sound",
                                value: viewModel.soundName
                            ) {
                                showSoundPicker = true
                            }
                            
                            Divider().padding(.leading, 52).opacity(0.3)
                            
                            MenuRow(
                                icon: "sun.max.fill",
                                title: "Gentle Wake-Up",
                                value: gentleWakeUpText
                            ) {
                                showGentleWakeUpPicker = true
                            }
                            
                            Divider().padding(.leading, 52).opacity(0.3)
                            
                            MenuRow(
                                icon: "checkmark.shield.fill",
                                title: "Wake-Up Check",
                                value: viewModel.wakeUpCheckEnabled ? "On" : "Off"
                            ) {
                                showWakeUpCheck = true
                            }
                        }

                        // Group E: Time Zone Anchor
                        SectionHeader(title: "Time Zone Anchor")
                        GroupedSettingsCard {
                            Toggle(isOn: Binding(
                                get: { viewModel.timeZoneMode == .custom },
                                set: { isOn in
                                    viewModel.timeZoneMode = isOn ? .custom : .local
                                    if isOn && viewModel.timeZoneIdentifier == nil {
                                        viewModel.timeZoneIdentifier = TimeZone.current.identifier
                                    }
                                }
                            )) {
                                Text("Anchor to Time Zone")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
                            
                            if viewModel.timeZoneMode == .custom {
                                Divider().padding(.leading, 16).opacity(0.3)
                                
                                MenuRow(
                                    icon: "globe",
                                    title: "Time Zone",
                                    value: viewModel.timeZoneCity ?? viewModel.timeZoneIdentifier ?? "Select"
                                ) {
                                    showTimeZonePicker = true
                                }
                                
                                Text("Alarm rings at \(timeZoneText)")
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                        }

                        // Group F: Accountability Shield
                        SectionHeader(title: "Accountability Shield")
                        GroupedSettingsCard {
                            Toggle(isOn: $viewModel.accountabilityEnabled) {
                                Text("Enable for this habit alarm")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()

                            if viewModel.accountabilityEnabled {
                                Divider().padding(.leading, 16).opacity(0.3)

                                Toggle(isOn: $viewModel.blockAppsEnabled) {
                                    Text("Lock phone while ringing")
                                        .foregroundColor(Colors.textPrimary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)

                                if viewModel.blockAppsEnabled {
                                    Divider().padding(.leading, 16).opacity(0.3)
                                    BlockedAppsSelectionView()
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                }

                                Divider().padding(.leading, 16).opacity(0.3)

                                Toggle(isOn: $viewModel.penaltyEnabled) {
                                    Text("Use penalty credits")
                                        .foregroundColor(Colors.textPrimary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)

                                if viewModel.penaltyEnabled {
                                    Divider().padding(.leading, 16).opacity(0.3)
                                    Stepper(
                                        "Penalty Amount (€\(viewModel.penaltyAmountEuro))",
                                        value: $viewModel.penaltyAmountEuro,
                                        in: 1...10
                                    )
                                    .foregroundColor(Colors.textPrimary)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                }

                                Text("Advanced penalty rules can be configured in Settings > Accountability Shield.")
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)

                                Button {
                                    showAccountabilityInfo = true
                                } label: {
                                    Text("How this works")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Colors.accentTeal)
                                        .padding(.horizontal)
                                        .padding(.bottom, 8)
                                }
                            }
                        }

                        // Group G: Wallpaper
                        SectionHeader(title: "Wallpaper")
                        GroupedSettingsCard {
                            MenuRow(
                                icon: "photo.fill",
                                title: "Wallpaper",
                                value: "Select",
                                thumbnail: resolvedWallpaperImage
                            ) {
                                showWallpaperPicker = true
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onClose)
                        .foregroundColor(Colors.textPrimary)
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Edit Alarm")
                            .font(.headline)
                            .foregroundColor(Colors.textPrimary)
                        Text(viewModel.ringInText)
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveAlarm()
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(Colors.accentTeal)
                    }
                }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                viewModel.emoji = emoji
                showEmojiPicker = false
            }
        }
        .sheet(isPresented: $showSoundPicker) {
            SoundPickerView(selectedSound: $viewModel.soundName)
        }
        .sheet(isPresented: $showGentleWakeUpPicker) {
            GentleWakeUpPickerView(
                selectedSeconds: $viewModel.gentleWakeUpSeconds,
                maxVolume: $viewModel.soundVolume,
                soundName: viewModel.soundName,
                soundPlayer: soundPlayer
            )
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePickerView(minutes: $viewModel.snoozeMinutes, count: $viewModel.snoozeCount)
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.wallpaperId)
        }
        .sheet(isPresented: $showTimeZonePicker) {
            TimeZonePickerView(
                selectedIdentifier: $viewModel.timeZoneIdentifier,
                selectedCity: $viewModel.timeZoneCity,
                selectedMode: $viewModel.timeZoneMode
            )
        }
        .sheet(isPresented: $showWakeUpCheck) {
            WakeUpCheckView(isEnabled: $viewModel.wakeUpCheckEnabled)
        }
        .sheet(isPresented: $showAccountabilityInfo) {
            AccountabilityInfoView()
        }
        .sheet(isPresented: $showMissionSelection) {
            MissionSelectionView { mission in
                showMissionSelection = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedMissionForConfig = mission
                }
            }
        }
        .sheet(item: $selectedMissionForConfig) { mission in
            if mission.type == .findColorTiles {
                FindColorTilesSettingsView { settings in
                    let updatedMission = AlarmMission(
                        type: .findColorTiles,
                        difficulty: settings.difficulty.rawValue,
                        rounds: settings.rounds
                    )
                    updateMission(updatedMission)
                }
            } else if mission.type == .typing {
                TypingMissionSettingsView { settings in
                    let updatedMission = AlarmMission(
                        type: .typing,
                        rounds: settings.repeatCount
                    )
                    updateMission(updatedMission)
                }
            } else if mission.type == .math {
                MathMissionSettingsView { config in
                    let updatedMission = AlarmMission(
                        type: .math,
                        difficulty: config.difficulty.rawValue,
                        rounds: config.repeatCount
                    )
                    updateMission(updatedMission)
                }
            } else if mission.type == .memoryMatch {
                MemoryMatchSettingsView { difficulty, rounds in
                    let updatedMission = AlarmMission(
                        type: .memoryMatch,
                        difficulty: difficulty.rows,
                        rounds: rounds
                    )
                    updateMission(updatedMission)
                }
            } else if mission.type == .ticTacToe {
                TicTacToeSettingsView { difficulty, size, rounds in
                    var updatedMission = AlarmMission(
                        type: .ticTacToe,
                        difficulty: difficulty.rawValue,
                        rounds: rounds
                    )
                    updatedMission.config = ["size": size.rawValue]
                    updateMission(updatedMission)
                }
            } else if mission.type == .step {
                StepsMissionSettingsView { steps in
                    var updatedMission = AlarmMission(
                        type: .step
                    )
                    updatedMission.config = ["steps": steps]
                    updateMission(updatedMission)
                }
            } else {
                // Fallback
                VStack {
                    Text(mission.title).font(.bold(.title)())
                    Text("Config coming soon")
                    Button("Done") {
                        updateMission(mission)
                    }
                }
                .padding()
                .background(Colors.bgPrimary.ignoresSafeArea())
            }
        }
        .sheet(isPresented: $showFrequencyPicker) {
            NumberPickerSheet(title: "How often", unit: "minutes", value: $viewModel.reminderIntervalMinutes, range: 1...360)
        }
        .sheet(isPresented: $showStartTimePicker) {
            TimePickerSheet(title: "Start from", date: $viewModel.reminderStartTime)
        }
        .sheet(isPresented: $showEndTimePicker) {
            TimePickerSheet(title: "End until", date: $viewModel.reminderEndTime)
        }
        .onDisappear {
            soundPlayer.stop()
        }
        .onChange(of: viewModel.hour) { _, _ in
            viewModel.updateRingInText()
        }
        .onChange(of: viewModel.minute) { _, _ in
            viewModel.updateRingInText()
        }
        .onChange(of: viewModel.second) { _, _ in
            viewModel.updateRingInText()
        }
        .onChange(of: viewModel.timeZoneIdentifier) { _, _ in
            syncTimeToSelectedTimeZone()
        }
        .onChange(of: viewModel.timeZoneMode) { _, _ in
            syncTimeToSelectedTimeZone()
        }
    }
    
    private func syncTimeToSelectedTimeZone() {
        let timezone: TimeZone
        if viewModel.timeZoneMode == .custom, let id = viewModel.timeZoneIdentifier {
            timezone = TimeZone(identifier: id) ?? .current
        } else {
            timezone = .current
        }
        
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        let now = Date()
        viewModel.hour = calendar.component(.hour, from: now)
        viewModel.minute = calendar.component(.minute, from: now)
        viewModel.updateRingInText()
    }
    
    private func updateMission(_ mission: AlarmMission) {
        if let index = editingMissionIndex {
            viewModel.missions[index] = mission
        } else {
            viewModel.addMission(mission)
        }
        selectedMissionForConfig = nil
    }
    
    private func saveAlarm() {
        Task { @MainActor in
            _ = await notificationManager.ensureAuthorization()
            var alarmPenaltyRules = settingsStore.penaltyRules
            // Alarm penalty in this mode is snooze-threshold based.
            alarmPenaltyRules.alarmMissionFailTriggersPenalty = false
            
            let alarm = Alarm(
                id: UUID(),
                type: .habit,
                name: viewModel.name,
                emoji: viewModel.emoji,
                hour: viewModel.hour,
                minute: viewModel.minute,
                second: viewModel.second,
                isDaily: viewModel.isDaily,
                repeatMask: viewModel.repeatMask(),
                enabled: true,
                wakeUpCheckEnabled: viewModel.wakeUpCheckEnabled,
                soundName: viewModel.soundName,
                soundVolume: viewModel.soundVolume,
                vibrateEnabled: viewModel.vibrateEnabled,
                gentleWakeUpSeconds: viewModel.gentleWakeUpSeconds,
                timeReminderEnabled: viewModel.timeReminderEnabled,
                weatherReminderEnabled: viewModel.weatherReminderEnabled,
                labelReminderEnabled: viewModel.labelReminderEnabled,
                extraLoudEnabled: viewModel.extraLoudEnabled,
                bypassSilentMode: viewModel.bypassSilentMode,
                timeZoneMode: viewModel.timeZoneMode,
                timeZoneIdentifier: viewModel.timeZoneIdentifier,
                timeZoneCity: viewModel.timeZoneCity,
                snoozeMinutes: viewModel.snoozeMinutes,
                snoozeCount: viewModel.snoozeCount,
                wallpaperId: viewModel.wallpaperId,
                createdAt: Date(),
                missions: viewModel.missions,
                enforcementMode: viewModel.accountabilityEnabled
                    ? (viewModel.blockAppsEnabled && viewModel.penaltyEnabled
                        ? .blockAppsAndPenalty
                        : (viewModel.blockAppsEnabled ? .blockApps : .penaltyOnly))
                    : .none,
                blockAppsEnabled: viewModel.accountabilityEnabled && viewModel.blockAppsEnabled,
                blockedSelectionData: settingsStore.blockedAppsSelectionData,
                penaltyEnabled: viewModel.accountabilityEnabled && viewModel.penaltyEnabled,
                penaltyAmountEuro: viewModel.penaltyAmountEuro,
                penaltyStrategy: .credits,
                penaltyRules: alarmPenaltyRules,
                habitReminderEnabled: viewModel.reminderEnabled,
                habitReminderInterval: viewModel.reminderIntervalMinutes,
                habitReminderDuration: viewModel.reminderDurationSeconds,
                habitReminderStartTime: viewModel.reminderStartTime,
                habitReminderEndTime: viewModel.reminderEndTime
            )
            
            print("[HabitAlarm] Saving habit: \(alarm.name) at \(alarm.hour):\(alarm.minute)")
            alarmStore.add(alarm)
            scheduler.schedule(alarm: alarm)
            onClose()
        }
    }
    
    private func weekdayLabel(_ day: Int) -> String {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return labels[day - 1]
    }
    
    // Helpers for display
    var timeZoneText: String {
        guard viewModel.timeZoneMode == .custom,
              let id = viewModel.timeZoneIdentifier,
              let tz = TimeZone(identifier: id) else {
            return "Local Time"
        }
        
        let targetFormatter = DateFormatter()
        targetFormatter.timeZone = tz
        targetFormatter.timeStyle = .short
        
        let localFormatter = DateFormatter()
        localFormatter.timeStyle = .short
        
        let now = Date()
        var targetCalendar = Calendar(identifier: .gregorian)
        targetCalendar.timeZone = tz
        
        var comps = DateComponents()
        comps.hour = viewModel.hour
        comps.minute = viewModel.minute
        comps.second = 0
        
        guard let nextDate = targetCalendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) else {
            return "Unknown time"
        }
        
        let targetStr = targetFormatter.string(from: nextDate)
        let localStr = localFormatter.string(from: nextDate)
        let dayDiff = CheckDay(date: nextDate, calendar: Calendar.current)
        
        let cityName = viewModel.timeZoneCity ?? id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
        return "\(targetStr) in \(cityName)\n(Local: \(localStr)\(dayDiff))"
    }

    func CheckDay(date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "" }
        if calendar.isDateInTomorrow(date) { return " Tomorrow" }
        return " (+Day)"
    }

    private var gentleWakeUpText: String {
        viewModel.gentleWakeUpSeconds == 0 ? "Off" : "\(viewModel.gentleWakeUpSeconds) seconds"
    }

    private var snoozeSummary: String {
        if viewModel.snoozeMinutes == 0 {
            return "Off"
        }
        return "\(viewModel.snoozeMinutes) min, \(viewModel.snoozeCount) times"
    }

    var resolvedWallpaperImage: Image? {
        let id = viewModel.wallpaperId
        
        for category in WallpaperConfig.categories {
            if id.hasPrefix(category.id + "-") {
                let filename = String(id.dropFirst(category.id.count + 1))
                if category.imageNames.contains(filename) {
                     let nameWithoutExt = (filename as NSString).deletingPathExtension
                     if let path = Bundle.main.path(forResource: nameWithoutExt, ofType: (filename as NSString).pathExtension) {
                         if let uiImage = UIImage(contentsOfFile: path) {
                             return Image(uiImage: uiImage)
                         }
                     }
                     if let path = Bundle.main.path(forResource: filename, ofType: nil, inDirectory: "BundledWallpapers/\(category.id)") {
                         if let uiImage = UIImage(contentsOfFile: path) {
                             return Image(uiImage: uiImage)
                         }
                     }
                }
            }
        }
        return nil
    }
}

// MARK: - Reminder Components

struct ReminderMiniCard: View {
    let title: String
    let value: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textTertiary)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Text(detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Colors.cardSurface.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
        }
    }
}

struct ScheduleCard: View {
    let from: String
    let until: String
    let onFromTap: () -> Void
    let onUntilTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active window")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Colors.textTertiary)

            HStack(spacing: 8) {
                Button(action: onFromTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                        Text(from)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onUntilTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Until")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                        Text(until)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Colors.cardSurface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }
}

struct PillValueButton: View {
    let value: String
    var icon: String? = "pencil"
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Colors.cardSurface.opacity(0.4))
            )
            .overlay(
                Capsule()
                    .stroke(Colors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct NumberPickerSheet: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: Spacing.xl) {
                    Text("\(value) \(unit)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                    
                    Picker(title, selection: $value) {
                        ForEach(range, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    
                    Spacer()
                    
                    PrimaryButton(title: "Done") {
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}

struct TimePickerSheet: View {
    let title: String
    @Binding var date: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: Spacing.xl) {
                    DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 200)
                    
                    Spacer()
                    
                    PrimaryButton(title: "Done") {
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}
