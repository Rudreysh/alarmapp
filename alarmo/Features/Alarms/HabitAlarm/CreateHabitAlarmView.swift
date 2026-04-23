import SwiftUI
import Combine

struct CreateHabitAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var notificationManager: NotificationManager
    let onClose: () -> Void
    private let existingAlarm: Alarm?
    
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
    @State private var showingLocalTimePreview = true // Default to floating mode if custom TZ
    @State private var showAlarmAccessAlert = false
    @State private var alarmAccessAlertMessage = "Enable notification access for reliable alarm ringing."
    
    // Reminder Pickers
    @State private var showFrequencyPicker = false
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    
    // Services
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    @ObservedObject private var settingsStore = SettingsStore.shared
    private let scheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    
    init(alarmStore: AlarmStore, existingAlarm: Alarm? = nil, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        self.existingAlarm = existingAlarm
        let defaults = AppPreferences()
        if let alarm = existingAlarm {
            _viewModel = StateObject(wrappedValue: CreateHabitAlarmViewModel(alarm: alarm))
        } else {
            let now = Date()
            let calendar = Calendar.current
            _viewModel = StateObject(wrappedValue: CreateHabitAlarmViewModel(
                defaultHour: calendar.component(.hour, from: now),
                defaultMinute: calendar.component(.minute, from: now),
                defaultSecond: calendar.component(.second, from: now),
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

                        // 1. Digital Time Picker (Floating between TZ if enabled)
                        DigitalTimeDisplay(
                            hour: bindingForPicker.0,
                            minute: bindingForPicker.1,
                            second: bindingForPicker.2
                        )
                        .padding(.top, settingsStore.alarmClockStyle == .classicSunray ? 30 : 20)
                        
                        // Interactive Location Badge
                        Menu {
                            Button(action: { 
                                showTimeZonePicker = true 
                            }) {
                                Label("Change City", systemImage: "map")
                            }
                            
                            if viewModel.timeZoneMode == .custom {
                                Button(action: {
                                    withAnimation {
                                        viewModel.timeZoneMode = .local
                                        showingLocalTimePreview = false
                                        viewModel.stopCycling()
                                        triggerFeedback()
                                    }
                                }) {
                                    Label("Reset to Local Time", systemImage: "location.fill")
                                }
                                
                                Button(action: {
                                    toggleFloatingPreview()
                                }) {
                                    Label(showingLocalTimePreview ? "Stop Live Preview" : "Start Live Preview", 
                                          systemImage: showingLocalTimePreview ? "stop.fill" : "play.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.timeZoneMode == .custom ? (isShowingLocalInFloat ? "location.fill" : "globe.americas.fill") : "location.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                
                                Text(badgeDisplayText)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .kerning(1.0)
                                    .id("badge_text_\(isShowingLocalInFloat)") // Force update on toggle
                                
                                if viewModel.timeZoneMode == .custom {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .opacity(0.3)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Colors.cardSurface.opacity(0.6))
                                    .overlay(
                                        Capsule()
                                            .stroke(!isShowingLocalInFloat ? Colors.accentTeal.opacity(0.6) : Colors.cardStroke, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(!isShowingLocalInFloat ? Colors.accentTeal : Colors.textPrimary)
                            .animation(.easeInOut(duration: 0.3), value: isShowingLocalInFloat)
                        } primaryAction: {
                            // TAP now opens the picker, making it easy to change locations
                            showTimeZonePicker = true
                        }
                        .padding(.top, settingsStore.alarmClockStyle == .classicSunray ? 30 : 28)
                        .padding(.bottom, settingsStore.alarmClockStyle == .classicSunray ? 14 : 10)

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
                                .background(Colors.cardStroke)
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

                        // Group C2: Notes
                        SectionHeader(title: "Notes")
                        GroupedSettingsCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Add notes about this habit")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)

                                TextEditor(text: $viewModel.notes)
                                    .frame(minHeight: 110)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Colors.bgSecondary.opacity(0.7))
                                    .cornerRadius(12)
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding(16)
                        }

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

                        // Group F: Alarm Lock
                        SectionHeader(title: "Alarm Lock")
                        GroupedSettingsCard {
                            Toggle(isOn: $viewModel.blockAppsEnabled) {
                                Text("Prevent App Uninstall")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()

                            Divider().padding(.leading, 16).opacity(0.3)
                            Toggle(isOn: $viewModel.shutdownProtectionEnabled) {
                                Text("Prevent Switch Off")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
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
                        saveAlarm(ignoreDeliveryWarnings: true)
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
            SnoozePickerView(
                minutes: $viewModel.snoozeMinutes,
                seconds: $viewModel.snoozeSeconds,
                count: $viewModel.snoozeCount
            )
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
        .alert("Alarm Access Needed", isPresented: $showAlarmAccessAlert) {
            Button("Save Anyway") {
                saveAlarm(ignoreDeliveryWarnings: true)
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alarmAccessAlertMessage)
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
                    updatedMission.config = ["stepCount": steps]
                    updateMission(updatedMission)
                }
            } else if mission.type == .householdItemHunt {
                HouseholdItemHuntSettingsView(initialMission: mission) { config in
                    var updatedMission = AlarmMission(
                        type: .householdItemHunt,
                        difficulty: mission.difficulty,
                        rounds: mission.rounds,
                        config: mission.config,
                        customData: mission.customData
                    )
                    let selectedSet = Set(config.selectedItemIDs)
                    updatedMission.customData[HouseholdItemHuntCatalogStore.selectedItemIDsKey] = HouseholdItemHuntCatalogStore.serializedIDs(selectedSet)
                    if let legacyReference = config.referenceImageFilename, !legacyReference.isEmpty {
                        updatedMission.customData[HouseholdItemHuntCatalogStore.referenceImageFilenameKey] = legacyReference
                    }
                    if let customItemsJSON = config.customItemsJSON, !customItemsJSON.isEmpty {
                        updatedMission.customData[HouseholdItemHuntCatalogStore.customItemsKey] = customItemsJSON
                    } else {
                        updatedMission.customData.removeValue(forKey: HouseholdItemHuntCatalogStore.customItemsKey)
                    }
                    updateMission(updatedMission)
                }
            } else if mission.type == .qrBarcode {
                let initialBarcodeId = mission.customData["barcodeId"].flatMap(UUID.init(uuidString:))
                let initialRawValue = mission.customData["barcodeVal"]
                let initialSymbology = mission.customData["barcodeSym"]
                QRBarcodeSettingsView(
                    initialConfig: QRBarcodeMissionConfig(
                        selectedBarcodeId: initialBarcodeId,
                        selectedRawValueFallback: initialRawValue,
                        selectedSymbologyFallback: initialSymbology
                    )
                ) { config in
                    var updatedMission = AlarmMission(type: .qrBarcode)
                    if let id = config.selectedBarcodeId {
                        updatedMission.customData["barcodeId"] = id.uuidString
                    }
                    if let raw = config.selectedRawValueFallback ?? config.selectedBarcodeId.flatMap(QRBarcodeMissionViewModel.rawValue(for:)) {
                        updatedMission.customData["barcodeVal"] = raw
                    }
                    if let sym = config.selectedSymbologyFallback ?? config.selectedBarcodeId.flatMap({ QRBarcodeMissionViewModel.symbology(for: $0) }) {
                        updatedMission.customData["barcodeSym"] = sym
                    }
                    updateMission(updatedMission)
                }
            } else if mission.type == .shake {
                ShakeMissionSettingsView { shakeCount in
                    var updatedMission = AlarmMission(type: .shake)
                    updatedMission.config = ["shakeCount": shakeCount]
                    updateMission(updatedMission)
                }
            } else if mission.type == .squat {
                SquatMissionSettingsView(initialMission: mission) { updatedMission in
                    updateMission(updatedMission)
                }
            } else if mission.type == .pushups {
                PushupsMissionSettingsView(initialMission: mission) { updatedMission in
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                soundPlayer.stop()
            }
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
            showingLocalTimePreview = true
            syncTimeToSelectedTimeZone()
            viewModel.startCycling()
        }
        .onChange(of: viewModel.timeZoneMode) { old, new in
            if new == .custom {
                showingLocalTimePreview = true
                viewModel.startCycling()
            } else {
                showingLocalTimePreview = false
                viewModel.stopCycling()
            }
            syncTimeToSelectedTimeZone()
        }
        .onAppear {
            if viewModel.timeZoneMode == .custom {
                showingLocalTimePreview = true
                viewModel.startCycling()
            }
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
        viewModel.second = calendar.component(.second, from: now)
    }

    // MARK: - Time Projection
    private var projectedHour: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.hour, m: viewModel.minute, s: viewModel.second, from: tz, to: .current).h
                }
                return viewModel.hour
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: newValue, m: viewModel.minute, s: viewModel.second, from: .current, to: tz)
                    viewModel.hour = res.h
                    viewModel.minute = res.m
                    viewModel.second = res.s
                } else {
                    viewModel.hour = newValue
                }
            }
        )
    }

    private var projectedMinute: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.hour, m: viewModel.minute, s: viewModel.second, from: tz, to: .current).m
                }
                return viewModel.minute
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: viewModel.hour, m: newValue, s: viewModel.second, from: .current, to: tz)
                    viewModel.hour = res.h
                    viewModel.minute = res.m
                    viewModel.second = res.s
                } else {
                    viewModel.minute = newValue
                }
            }
        )
    }

    private var projectedSecond: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.hour, m: viewModel.minute, s: viewModel.second, from: tz, to: .current).s
                }
                return viewModel.second
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: viewModel.hour, m: viewModel.minute, s: newValue, from: .current, to: tz)
                    viewModel.hour = res.h
                    viewModel.minute = res.m
                    viewModel.second = res.s
                } else {
                    viewModel.second = newValue
                }
            }
        )
    }

    private func timeProjector(h: Int, m: Int, s: Int, from: TimeZone, to: TimeZone) -> (h: Int, m: Int, s: Int) {
        var cal = Calendar.current
        cal.timeZone = from
        
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = h
        comps.minute = m
        comps.second = s
        
        let sourceDate = cal.date(from: comps) ?? now
        
        cal.timeZone = to
        return (
            h: cal.component(.hour, from: sourceDate),
            m: cal.component(.minute, from: sourceDate),
            s: cal.component(.second, from: sourceDate)
        )
    }

    private func triggerFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Floating Logic Helpers
    private func toggleFloatingPreview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingLocalTimePreview.toggle()
            if showingLocalTimePreview {
                viewModel.startCycling()
            } else {
                viewModel.stopCycling()
            }
        }
        triggerFeedback()
    }

    private var isShowingLocalInFloat: Bool {
        showingLocalTimePreview && viewModel.timeZoneMode == .custom && viewModel.cycleToLocal
    }

    private var badgeDisplayText: String {
        if viewModel.timeZoneMode == .local {
            return "LOCAL TIME"
        }
        
        if showingLocalTimePreview {
            return isShowingLocalInFloat ? "LOCAL TIME" : (viewModel.timeZoneCity?.uppercased() ?? "TARGET TIME")
        } else {
            return viewModel.timeZoneCity?.uppercased() ?? "CUSTOM LOCATION"
        }
    }

    private var bindingForPicker: (Binding<Int>, Binding<Int>, Binding<Int>) {
        if isShowingLocalInFloat {
            return (projectedHour, projectedMinute, projectedSecond)
        } else {
            return ($viewModel.hour, $viewModel.minute, $viewModel.second)
        }
    }
    
    private func updateMission(_ mission: AlarmMission) {
        if let index = editingMissionIndex {
            viewModel.missions[index] = mission
        } else {
            viewModel.addMission(mission)
        }
        selectedMissionForConfig = nil
    }
    
    private func saveAlarm(ignoreDeliveryWarnings: Bool = false) {
        let blockAppsEnabled = viewModel.blockAppsEnabled
        let enforcementMode: EnforcementMode = blockAppsEnabled ? .blockApps : .none

        let alarm = Alarm(
            id: existingAlarm?.id ?? UUID(),
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
            snoozeSeconds: viewModel.snoozeSeconds,
            snoozeCount: viewModel.snoozeCount,
            wallpaperId: viewModel.wallpaperId,
            dailyMotivationEnabled: viewModel.dailyMotivationEnabled,
            visualOutputSettings: AlarmVisualOutputSettings.migratedFromLegacy(
                wallpaperId: viewModel.wallpaperId,
                dailyMotivationEnabled: viewModel.dailyMotivationEnabled
            ),
            createdAt: existingAlarm?.createdAt ?? Date(),
            missions: viewModel.missions,
            enforcementMode: enforcementMode,
            blockAppsEnabled: blockAppsEnabled,
            blockedSelectionData: settingsStore.blockedAppsSelectionData,
            penaltyEnabled: false,
            penaltyAmountEuro: settingsStore.penaltyAmountEuro,
            penaltyStrategy: .credits,
            penaltyRules: .default,
            shutdownProtectionEnabled: viewModel.shutdownProtectionEnabled,
            habitReminderEnabled: viewModel.reminderEnabled,
            habitReminderInterval: viewModel.reminderIntervalMinutes,
            habitReminderDuration: viewModel.reminderDurationSeconds,
            habitReminderStartTime: viewModel.reminderStartTime,
            habitReminderEndTime: viewModel.reminderEndTime,
            habitNotes: viewModel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        print("[HabitAlarm] Saving habit: \(alarm.name) at \(alarm.hour):\(alarm.minute)")

        // Dismiss first to keep Save interaction instant.
        onClose()

        // Delay model mutation slightly so full-screen dismissal animation can start cleanly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if existingAlarm != nil {
                alarmStore.update(alarm)
            } else {
                alarmStore.add(alarm)
            }
        }

        // Scheduling can be expensive (attachments + many notifications); keep it off MainActor.
        DispatchQueue.global(qos: .utility).async {
            scheduler.cancel(alarmId: alarm.id)
            scheduler.schedule(alarm: alarm)
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
        if viewModel.snoozeMinutes == 0 && viewModel.snoozeSeconds == 0 {
            return "Off"
        }
        let durationText: String
        if viewModel.snoozeSeconds > 0 {
            durationText = "\(viewModel.snoozeMinutes)m \(viewModel.snoozeSeconds)s"
        } else {
            durationText = "\(viewModel.snoozeMinutes) min"
        }
        return "\(durationText), \(viewModel.snoozeCount) times"
    }

    var resolvedWallpaperImage: Image? {
        guard let uiImage = WallpaperImageResolver.resolveImage(for: viewModel.wallpaperId) else {
            return nil
        }
        return Image(uiImage: uiImage)
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
