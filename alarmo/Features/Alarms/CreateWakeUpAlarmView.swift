import SwiftUI

struct CreateWakeUpAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var notificationManager: NotificationManager
    let onClose: () -> Void
    private let existingAlarm: Alarm?
    @StateObject private var viewModel: CreateWakeUpAlarmViewModel
    @FocusState private var nameFocused: Bool
    @State private var showEmojiPicker = false
    @State private var showWakeUpCheck = false
    @State private var showGentleWakeUpPicker = false
    @State private var showSnoozePicker = false
    @State private var showWallpaperPicker = false
    @State private var showMissionSelection = false
    @State private var selectedMissionForConfig: AlarmMission?
    @State private var editingMissionIndex: Int?
    @State private var showTimeZonePicker = false
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    @ObservedObject private var settingsStore = SettingsStore.shared
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    @State private var showPenaltySettings = false

    init(alarmStore: AlarmStore, existingAlarm: Alarm? = nil, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        self.existingAlarm = existingAlarm
        let defaults = AppPreferences()
        if let alarm = existingAlarm {
            _viewModel = StateObject(wrappedValue: CreateWakeUpAlarmViewModel(alarm: alarm))
        } else {
            _viewModel = StateObject(wrappedValue: CreateWakeUpAlarmViewModel(
                defaultHour: defaults.onboardingAlarmHour,
                defaultMinute: defaults.onboardingAlarmMinute,
                defaultSecond: defaults.onboardingAlarmSecond,
                defaultRepeatMask: defaults.onboardingRepeatMask,
                defaultSoundName: defaults.onboardingSoundName,
                defaultSoundVolume: defaults.onboardingSoundVolume,
                defaultWallpaperId: defaults.onboardingWallpaperId
            ))
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Top Spacer for Header
                        Color.clear.frame(height: 12)

                        // 1. Digital Time Picker (Moved to Top)
                        DigitalTimeDisplay(
                            hour: $viewModel.draft.hour,
                            minute: $viewModel.draft.minute,
                            second: $viewModel.draft.second
                        )
                        .padding(.top, 20)
                        
                        // Interactive Location Badge
                        Button(action: { showTimeZonePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.draft.timeZoneMode == .custom ? "globe.americas.fill" : "location.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                
                                let cityName: String = {
                                    if viewModel.draft.timeZoneMode == .custom, let id = viewModel.draft.timeZoneIdentifier {
                                        return viewModel.draft.timeZoneCity ?? id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
                                    }
                                    return "Current Location"
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
                                    .fill(viewModel.draft.timeZoneMode == .custom ? Colors.accentTeal.opacity(0.12) : Colors.textSecondary.opacity(0.1))
                            )
                            .foregroundColor(viewModel.draft.timeZoneMode == .custom ? Colors.accentTeal : Colors.textPrimary)
                            .overlay(
                                Capsule()
                                    .stroke(viewModel.draft.timeZoneMode == .custom ? Colors.accentTeal.opacity(0.2) : Colors.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 10)

                        // 2. Name & Emoji (Moved Below Time)
                         HStack(spacing: Spacing.m) {
                            Button(action: { showEmojiPicker = true }) {
                                Text(viewModel.draft.emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 44, height: 44)
                            }

                            TextField("Please fill in the alarm name", text: $viewModel.draft.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .focused($nameFocused)

                            Button(action: { nameFocused = true }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                        
                        
                        // 4. SETTINGS GROUPS

                        // Group A: Schedule (Moved to Top)
                        SectionHeader(title: "Schedule")
                        GroupedSettingsCard {
                            // Repeat (Inline Day Selection)
                            DaySelectionRow(
                                isDaily: $viewModel.draft.isDaily,
                                selectedWeekdays: $viewModel.draft.selectedWeekdays
                            )

                            
                            Divider()
                                .background(Color(white: 0.25)) // Visible separator
                                .padding(.vertical, 4)
                            
                             // Snooze
                            MenuRow(
                                icon: "zzz",
                                title: "Snooze",
                                value: snoozeSummary
                            ) {
                                showSnoozePicker = true
                            }
                        }
                        
                        // Group B: Missions (Moved Below Schedule)
                        // Using a SectionHeader for consistency if desired, or just the component
                        SectionHeader(title: "Wake Up Missions")
                        MissionSlotsView(
                            missions: viewModel.draft.missions,
                            onAdd: {
                                editingMissionIndex = nil
                                showMissionSelection = true
                            },
                            onEdit: { index in
                                editingMissionIndex = index
                                showMissionSelection = true 
                            },
                            onRemove: { index in
                                viewModel.draft.missions.remove(at: index)
                            }
                        )
                        .padding(.horizontal, 4)

                        // Group C: Sound & Behavior
                        SectionHeader(title: "Sound & Behavior")
                        GroupedSettingsCard {
                             // Alarm Sound
                            MenuRow(
                                icon: "bell.fill",
                                title: "Alarm Sound",
                                value: viewModel.draft.soundName
                            ) {
                                showSoundEditor = true
                            }
                            
                            Divider().padding(.leading, 52).opacity(0.3)
                            
                            // Gentle Wake Up
                             MenuRow(
                                icon: "sun.max.fill",
                                title: "Gentle Wake-Up",
                                value: gentleWakeUpText
                            ) {
                                showGentleWakeUpPicker = true
                            }
                            
                             Divider().padding(.leading, 52).opacity(0.3)
                            
                            // Wake Up Check
                            MenuRow(
                                icon: "checkmark.shield.fill",
                                title: "Wake-Up Check",
                                value: viewModel.draft.wakeUpCheckEnabled ? "On" : "Off"
                            ) {
                                showWakeUpCheck = true
                            }
                        }

                        // Group D: Time Zone Anchor
                        SectionHeader(title: "Time Zone Anchor")
                        GroupedSettingsCard {
                            Toggle(isOn: Binding(
                                get: { viewModel.draft.timeZoneMode == .custom },
                                set: { isOn in
                                    viewModel.draft.timeZoneMode = isOn ? .custom : .local
                                    if isOn && viewModel.draft.timeZoneIdentifier == nil {
                                        viewModel.draft.timeZoneIdentifier = TimeZone.current.identifier
                                    }
                                }
                            )) {
                                Text("Anchor to Time Zone")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
                            
                            if viewModel.draft.timeZoneMode == .custom {
                                Divider().padding(.leading, 16).opacity(0.3)
                                
                                MenuRow(
                                    icon: "globe",
                                    title: "Time Zone",
                                    value: viewModel.draft.timeZoneCity ?? viewModel.draft.timeZoneIdentifier ?? "Select"
                                ) {
                                    showTimeZonePicker = true
                                }
                                
                                // Preview Text
                                Text("Alarm rings at \(timeZoneText)")
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                        }

                        // Group E: Accountability Shield
                        SectionHeader(title: "Accountability Shield")
                        GroupedSettingsCard {
                            Toggle(isOn: $viewModel.draft.penaltyEnabled) {
                                Text("Enable Penalty")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()

                            Divider().padding(.leading, 16).opacity(0.3)
                            MenuRow(
                                icon: "slider.horizontal.3",
                                title: "Edit Penalty Rules",
                                value: "Settings"
                            ) {
                                showPenaltySettings = true
                            }

                            Text("Penalty rules are global and apply only while this alarm is active.")
                                .font(.caption)
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }

                        // Group F: Wallpaper
                        SectionHeader(title: "Wallpaper")
                        GroupedSettingsCard {
                            // Wallpaper
                            MenuRow(
                                icon: "photo.fill",
                                title: "Wallpaper",
                                value: "Select",
                                thumbnail: resolvedWallpaperImage
                            ) {
                                showWallpaperPicker = true
                            }
                        }
                        // This background simulates the grouping in the image (or just clean background)
                        // The user image looks like a seamless black list.
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
        // Sheets calling Sub-Views
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                viewModel.draft.emoji = emoji
                showEmojiPicker = false
            }
        }
        .sheet(isPresented: $showNameEditor) {
            LabelSettingsView(
                name: $viewModel.draft.name,
                emoji: $viewModel.draft.emoji,
                showEmojiPicker: $showEmojiPicker
            )
        }
        .sheet(isPresented: $showRepeatEditor) {
            RepeatSettingsView(
                isDaily: $viewModel.draft.isDaily,
                selectedWeekdays: $viewModel.draft.selectedWeekdays
            )
        }
        .sheet(isPresented: $showSoundEditor) {
            SoundSettingsView(
                soundName: $viewModel.draft.soundName,
                volume: $viewModel.draft.soundVolume,
                vibrate: $viewModel.draft.vibrateEnabled,
                bypassSilentMode: $viewModel.draft.bypassSilentMode,
                soundPlayer: soundPlayer
            )
        }
        .sheet(isPresented: $showWakeUpCheck) {
            WakeUpCheckView(isEnabled: $viewModel.draft.wakeUpCheckEnabled)
        }

        .sheet(isPresented: $showGentleWakeUpPicker) {
            GentleWakeUpPickerView(
                selectedSeconds: $viewModel.draft.gentleWakeUpSeconds,
                maxVolume: $viewModel.draft.soundVolume,
                soundName: viewModel.draft.soundName,
                soundPlayer: soundPlayer
            )
        }
        .onChange(of: viewModel.draft.timeZoneIdentifier) { _, _ in
            syncTimeToSelectedTimeZone()
        }
        .onChange(of: viewModel.draft.timeZoneMode) { _, _ in
            syncTimeToSelectedTimeZone()
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePickerView(
                minutes: $viewModel.draft.snoozeMinutes,
                seconds: $viewModel.draft.snoozeSeconds,
                count: $viewModel.draft.snoozeCount
            )
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.draft.wallpaperId)
        }
        .sheet(isPresented: $showMissionSelection) {
            MissionSelectionView { mission in
                showMissionSelection = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedMissionForConfig = mission
                }
            }
        }
        .sheet(isPresented: $showTimeZonePicker) {
            TimeZonePickerView(
                selectedIdentifier: $viewModel.draft.timeZoneIdentifier,
                selectedCity: $viewModel.draft.timeZoneCity,
                selectedMode: $viewModel.draft.timeZoneMode
            )
        }
        .sheet(isPresented: $showPenaltySettings) {
            PreventPowerOffView()
        }
        // Mission Config Sheets (Existing Logic)
        .sheet(item: $selectedMissionForConfig) { mission in
            // ... (Existing Mission Config Logic kept same) ...
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
            } else if mission.type == .qrBarcode {
                 QRBarcodeSettingsView { config in
                    var updatedMission = AlarmMission(type: .qrBarcode)
                    if let id = config.selectedBarcodeId {
                        updatedMission.customData["barcodeId"] = id.uuidString
                    }
                    if let raw = config.selectedRawValueFallback {
                        updatedMission.customData["barcodeVal"] = raw
                    }
                    updateMission(updatedMission)
                }
            } else {
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
        .onDisappear {
            soundPlayer.stop()
        }
    }
    
    // MARK: - State properties for new sheets
    @State private var showNameEditor = false
    @State private var showRepeatEditor = false
    @State private var showSoundEditor = false

    // MARK: - Helpers
    private var repeatText: String {
        if viewModel.draft.isDaily { return "Daily" }
        if viewModel.draft.selectedWeekdays.isEmpty { return "Once" }
        if viewModel.draft.selectedWeekdays.count == 7 { return "Daily" }
        if viewModel.draft.selectedWeekdays == [2,3,4,5,6] { return "Weekdays" }
        if viewModel.draft.selectedWeekdays == [1,7] { return "Weekends" }
        return "Custom"
    }


    private func updateMission(_ mission: AlarmMission) {
        if let index = editingMissionIndex {
            viewModel.draft.missions[index] = mission
        } else {
            viewModel.addMission(mission)
        }
        selectedMissionForConfig = nil
    }

    private func weekdayLabel(_ day: Int) -> String {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return labels[day - 1]
    }
}


private extension CreateWakeUpAlarmView {
    var gentleWakeUpText: String {
        viewModel.draft.gentleWakeUpSeconds == 0 ? "Off" : "\(viewModel.draft.gentleWakeUpSeconds) seconds"
    }

    var snoozeSummary: String {
        if viewModel.draft.snoozeMinutes == 0 && viewModel.draft.snoozeSeconds == 0 {
            return "Off"
        }
        let durationText: String
        if viewModel.draft.snoozeSeconds > 0 {
            durationText = "\(viewModel.draft.snoozeMinutes)m \(viewModel.draft.snoozeSeconds)s"
        } else {
            durationText = "\(viewModel.draft.snoozeMinutes) min"
        }
        return "\(durationText), \(viewModel.draft.snoozeCount) times"
    }

    func saveAlarm() {
        Task { @MainActor in
            _ = await notificationManager.ensureAuthorization()
            let alarmName = viewModel.draft.name.isEmpty ? "Alarm" : viewModel.draft.name
            let alarmId = existingAlarm?.id ?? UUID()
            var alarmPenaltyRules = settingsStore.penaltyRules
            // Alarm penalty in this mode is snooze-threshold based.
            alarmPenaltyRules.alarmMissionFailTriggersPenalty = false
            let alarm = Alarm(
                id: alarmId,
                name: alarmName,
                emoji: viewModel.draft.emoji,
                hour: viewModel.draft.hour,
                minute: viewModel.draft.minute,
                second: viewModel.draft.second,
                isDaily: viewModel.draft.isDaily,
                repeatMask: viewModel.repeatMask(),
                enabled: true,
                wakeUpCheckEnabled: viewModel.draft.wakeUpCheckEnabled,
                soundName: viewModel.draft.soundName,
                soundVolume: viewModel.draft.soundVolume,
                vibrateEnabled: viewModel.draft.vibrateEnabled,
                gentleWakeUpSeconds: viewModel.draft.gentleWakeUpSeconds,
                timeReminderEnabled: viewModel.draft.timeReminderEnabled,
                weatherReminderEnabled: viewModel.draft.weatherReminderEnabled,
                labelReminderEnabled: viewModel.draft.labelReminderEnabled,
                extraLoudEnabled: viewModel.draft.extraLoudEnabled,
                bypassSilentMode: viewModel.draft.bypassSilentMode,
                timeZoneMode: viewModel.draft.timeZoneMode,
                timeZoneIdentifier: viewModel.draft.timeZoneIdentifier,
                timeZoneCity: viewModel.draft.timeZoneCity,
                snoozeMinutes: viewModel.draft.snoozeMinutes,
                snoozeSeconds: viewModel.draft.snoozeSeconds,
                snoozeCount: viewModel.draft.snoozeCount,
                wallpaperId: viewModel.draft.wallpaperId,
                createdAt: Date(),
                missions: viewModel.draft.missions,
                enforcementMode: viewModel.draft.penaltyEnabled ? .penaltyOnly : .none,
                blockAppsEnabled: false,
                blockedSelectionData: settingsStore.blockedAppsSelectionData,
                penaltyEnabled: viewModel.draft.penaltyEnabled,
                penaltyAmountEuro: settingsStore.penaltyAmountEuro,
                penaltyStrategy: .credits,
                penaltyRules: alarmPenaltyRules,
                shutdownProtectionEnabled: viewModel.draft.penaltyEnabled
            )
            if existingAlarm != nil {
                alarmStore.update(alarm)
            } else {
                alarmStore.add(alarm)
            }
            scheduler.schedule(alarm: alarm)
            onClose()
        }
    }
    
    func syncTimeToSelectedTimeZone() {
        let timezone: TimeZone
        if viewModel.draft.timeZoneMode == .custom, let id = viewModel.draft.timeZoneIdentifier {
            timezone = TimeZone(identifier: id) ?? .current
        } else {
            timezone = .current
        }
        
        var calendar = Calendar.current
        calendar.timeZone = timezone
        
        let now = Date()
        viewModel.draft.hour = calendar.component(.hour, from: now)
        viewModel.draft.minute = calendar.component(.minute, from: now)
        viewModel.draft.second = calendar.component(.second, from: now)
    }

    var timeZoneText: String {
        guard viewModel.draft.timeZoneMode == .custom,
              let id = viewModel.draft.timeZoneIdentifier,
              let tz = TimeZone(identifier: id) else {
            return "Local Time"
        }
        
        let targetFormatter = DateFormatter()
        targetFormatter.timeZone = tz
        targetFormatter.timeStyle = .short
        
        let localFormatter = DateFormatter()
        localFormatter.timeStyle = .short // Uses device local TZ by default
        
        let now = Date()
        var targetCalendar = Calendar(identifier: .gregorian)
        targetCalendar.timeZone = tz
        
        // Find component match in target TZ
        var comps = DateComponents()
        comps.hour = viewModel.draft.hour
        comps.minute = viewModel.draft.minute
        comps.second = 0
        
        guard let nextDate = targetCalendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) else {
            return "Unknown time"
        }
        
        let targetStr = targetFormatter.string(from: nextDate)
        let localStr = localFormatter.string(from: nextDate)
        
        let dayDiff = CheckDay(date: nextDate, calendar: Calendar.current)
        
        let cityName = viewModel.draft.timeZoneCity ?? id.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? id
        return "\(targetStr) in \(cityName)\n(Local: \(localStr)\(dayDiff))"
    }

    func CheckDay(date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "" }
        if calendar.isDateInTomorrow(date) { return " Tomorrow" }
        return " (+Day)"
    }

    var resolvedWallpaperImage: Image? {
        let id = viewModel.draft.wallpaperId
        
        // ID format: "category-filename"
        for category in WallpaperConfig.categories {
            if id.hasPrefix(category.id + "-") {
                let filename = String(id.dropFirst(category.id.count + 1))
                if category.imageNames.contains(filename) {
                     let nameWithoutExt = (filename as NSString).deletingPathExtension
                     // 1. Try Main Bundle
                     if let path = Bundle.main.path(forResource: nameWithoutExt, ofType: (filename as NSString).pathExtension) {
                         if let uiImage = UIImage(contentsOfFile: path) {
                             return Image(uiImage: uiImage)
                         }
                     }
                     // 2. Try BundledWallpapers dir
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
