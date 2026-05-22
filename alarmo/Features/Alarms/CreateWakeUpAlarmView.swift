import SwiftUI
import Combine

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
    private let scheduler: AlarmSchedulerProtocol = AlarmManagerFacade.shared
    @State private var showingLocalTimePreview = true // Default to floating mode if custom TZ
    @State private var showAlarmAccessAlert = false
    @State private var alarmAccessAlertMessage = "Enable notification access for reliable alarm ringing."
    @State private var isSaving = false
    
    // Onboarding Steps
    @State private var showTimeCoachMark = false
    @State private var showNameCoachMark = false
    @State private var showMissionCoachMark = false
    @State private var showSoundCoachMark = false
    @State private var showToggleCoachMark = false
    @State private var showPenaltyCoachMark = false
    @State private var showActionsCoachMark = false
    
    private var preferences = AppPreferences()

    init(alarmStore: AlarmStore, existingAlarm: Alarm? = nil, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        self.existingAlarm = existingAlarm
        let defaults = AppPreferences()
        if let alarm = existingAlarm {
            _viewModel = StateObject(wrappedValue: CreateWakeUpAlarmViewModel(alarm: alarm))
        } else {
            let now = Date()
            let calendar = Calendar.current
            _viewModel = StateObject(wrappedValue: CreateWakeUpAlarmViewModel(
                defaultHour: calendar.component(.hour, from: now),
                defaultMinute: calendar.component(.minute, from: now),
                defaultSecond: calendar.component(.second, from: now),
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
                    VStack(spacing: 8) {
                        // Top Spacer for Header
                        Color.clear.frame(height: 0)

                        // 1. Digital Time Picker (Floating between TZ)
                        DigitalTimeDisplay(
                            hour: bindingForPicker.0,
                            minute: bindingForPicker.1,
                            second: bindingForPicker.2,
                            sunrayScale: isClassicSunrayStyle ? 1.125 : 1.0
                        )
                        .offset(y: timeDisplayOffsetY)
                        .padding(.bottom, timeDisplayBottomPadding)
                        .coachMark(
                            title: "Set Time",
                            subtitle: "Tap to adjust.",
                            isVisible: $showTimeCoachMark,
                            alignment: .bottom,
                            pointDirection: .top,
                            arrowAlignment: .center,
                            arrowOffsetX: 0,
                            bubbleOffsetX: 0,
                            bubbleOffsetY: 12,
                            color: .red
                        )
        .onChange(of: viewModel.draft.hour) { _, _ in
            guard showTimeCoachMark else { return }
            showTimeCoachMark = false
            preferences.hasSeenEditAlarmTimeTooltip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showNameCoachMark = true }
        }
        .onChange(of: viewModel.draft.minute) { _, _ in
            guard showTimeCoachMark else { return }
            showTimeCoachMark = false
            preferences.hasSeenEditAlarmTimeTooltip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showNameCoachMark = true }
        }
        .onChange(of: viewModel.draft.second) { _, _ in
            guard showTimeCoachMark else { return }
            showTimeCoachMark = false
            preferences.hasSeenEditAlarmTimeTooltip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showNameCoachMark = true }
        }
                        
                        // Interactive Location Badge
                        Menu {
                            Button(action: { 
                                showTimeZonePicker = true 
                            }) {
                                Label("Change City", systemImage: "map")
                            }
                            
                            if viewModel.draft.timeZoneMode == .custom {
                                Button(action: {
                                    withAnimation {
                                        viewModel.draft.timeZoneMode = .local
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
                                Image(systemName: viewModel.draft.timeZoneMode == .custom ? (isShowingLocalInFloat ? "location.fill" : "globe.americas.fill") : "location.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                
                                Text(badgeDisplayText)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .kerning(1.0)
                                    .id("badge_text_wu_\(isShowingLocalInFloat)") // Force update on toggle
                                
                                if viewModel.draft.timeZoneMode == .custom {
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
                            // TAP now opens the picker
                            showTimeZonePicker = true
                        }
                        .padding(.top, locationBadgeTopPadding)
                        .padding(.bottom, locationBadgeBottomPadding)

                        // 2. Name & Emoji (Moved Below Time)
                        HStack(spacing: Spacing.m) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Colors.cardSurface.opacity(0.45))
                                    .frame(width: 44, height: 44)

                                TextField("🙂", text: $viewModel.draft.emoji)
                                    .font(.system(size: 30))
                                    .multilineTextAlignment(.center)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .frame(width: 40, height: 40)
                                    .onChange(of: viewModel.draft.emoji) { _, newValue in
                                        viewModel.draft.emoji = normalizedEmojiInput(newValue)
                                    }
                            }

                            TextField("Please fill in the alarm name", text: $viewModel.draft.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .focused($nameFocused)

                            Button(action: { showNameEditor = true }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, alarmNameTopPadding)
                        .coachMark(
                            title: "Name",
                            subtitle: "Label your alarm.",
                            isVisible: $showNameCoachMark,
                            alignment: .top,
                            pointDirection: .bottom,
                            arrowAlignment: .center,
                            arrowOffsetX: 0,
                            bubbleOffsetX: 0,
                            bubbleOffsetY: -80,
                            color: .red
                        )
                        .onChange(of: nameFocused) { _, isFocused in
                            if isFocused && showNameCoachMark {
                                showNameCoachMark = false
                                preferences.hasSeenEditAlarmNameTooltip = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showMissionCoachMark = true
                                }
                            }
                        }
                        
                        
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
                                .background(Colors.cardStroke)
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
                        .coachMark(
                            title: "Missions",
                            subtitle: "Add wake-up tasks.",
                            isVisible: $showMissionCoachMark,
                            alignment: .topLeading,
                            pointDirection: .bottom,
                            arrowAlignment: .leading,
                            arrowOffsetX: 24,
                            bubbleOffsetX: 14,
                            bubbleOffsetY: -10,
                            color: .red
                        )
                        .zIndex(showMissionCoachMark ? 100 : 0)
                        .onChange(of: viewModel.draft.missions.count) { _, newCount in
                            guard newCount > 0, showMissionCoachMark else { return }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showMissionCoachMark = false
                            }
                            preferences.hasSeenEditAlarmMissionTooltip = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showSoundCoachMark = true
                            }
                        }

                        // Group C: Sound & Behavior
                        SectionHeader(title: "Sound & Behavior")
                            .coachMark(
                                title: "Sound",
                                subtitle: "Pick a wake-up tone.",
                                isVisible: $showSoundCoachMark,
                                alignment: .bottom,
                                pointDirection: .bottom,
                                arrowAlignment: .center,
                                arrowOffsetX: -40,
                                bubbleOffsetX: 20,
                                bubbleOffsetY: 16,
                                color: .red
                            )
                            .zIndex(showSoundCoachMark ? 100 : 0)
                        GroupedSettingsCard {
                             // Alarm Sound
                            MenuRow(
                                icon: "bell.fill",
                                title: "Alarm Sound",
                                value: viewModel.draft.soundName
                            ) {
                                showSoundEditor = true
                            }
                            .onChange(of: showSoundEditor) { _, isOpen in
                                if isOpen && showSoundCoachMark {
                                    showSoundCoachMark = false
                                    preferences.hasSeenEditAlarmSoundTooltip = true
                                } else if !isOpen && preferences.hasSeenEditAlarmSoundTooltip && !preferences.hasSeenEditAlarmToggleTooltip {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showToggleCoachMark = true
                                    }
                                }
                            }
                            .onChange(of: showGentleWakeUpPicker) { _, isOpen in
                                if isOpen && showSoundCoachMark {
                                    showSoundCoachMark = false
                                    preferences.hasSeenEditAlarmSoundTooltip = true
                                } else if !isOpen && preferences.hasSeenEditAlarmSoundTooltip && !preferences.hasSeenEditAlarmToggleTooltip {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showToggleCoachMark = true
                                    }
                                }
                            }
                            .onChange(of: showWakeUpCheck) { _, isOpen in
                                if isOpen && showSoundCoachMark {
                                    showSoundCoachMark = false
                                    preferences.hasSeenEditAlarmSoundTooltip = true
                                } else if !isOpen && preferences.hasSeenEditAlarmSoundTooltip && !preferences.hasSeenEditAlarmToggleTooltip {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        showToggleCoachMark = true
                                    }
                                }
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
                            .onChange(of: showGentleWakeUpPicker) { _, isOpen in
                                guard isOpen, showSoundCoachMark else { return }
                                showSoundCoachMark = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showToggleCoachMark = true
                                }
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
                            .onChange(of: showWakeUpCheck) { _, isOpen in
                                guard isOpen, showSoundCoachMark else { return }
                                showSoundCoachMark = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showToggleCoachMark = true
                                }
                            }
                        }

                        // Group D: Time Zone Anchor
                        SectionHeader(title: "Time Zone Anchor")
                            .coachMark(
                                title: "Time Zone",
                                subtitle: "Lock to a city's time.",
                                isVisible: $showToggleCoachMark,
                                alignment: .bottom,
                                pointDirection: .bottom,
                                arrowAlignment: .center,
                                arrowOffsetX: 60,
                                bubbleOffsetX: -20,
                                bubbleOffsetY: 16,
                                color: .red
                            )
                            .zIndex(showToggleCoachMark ? 100 : 0)
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
                            .onChange(of: viewModel.draft.timeZoneMode) { _, _ in
                                guard showToggleCoachMark else { return }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showToggleCoachMark = false
                                }
                                preferences.hasSeenEditAlarmToggleTooltip = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showPenaltyCoachMark = true
                                }
                            }
                            
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

                        // Group E: Alarm Lock
                        SectionHeader(title: "Alarm Lock")
                            .coachMark(
                                title: "Features",
                                subtitle: "Alarm lock options.",
                                isVisible: $showPenaltyCoachMark,
                                alignment: .bottomTrailing,
                                pointDirection: .bottom,
                                arrowAlignment: .trailing,
                                arrowOffsetX: -32,
                                bubbleOffsetX: 0,
                                bubbleOffsetY: 16,
                                color: .red
                            )
                            .zIndex(showPenaltyCoachMark ? 100 : 0)
                        GroupedSettingsCard {
                            Toggle(isOn: $viewModel.draft.blockAppsEnabled) {
                                Text("Prevent App Uninstall")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
                            .onChange(of: viewModel.draft.blockAppsEnabled) { _, _ in
                                guard showPenaltyCoachMark else { return }
                                withAnimation {
                                    showPenaltyCoachMark = false
                                }
                                preferences.hasSeenEditAlarmActionsTooltip = true
                                // No more steps currently defined in the chain for this view
                            }

                            Divider().padding(.leading, 16).opacity(0.3)
                            Toggle(isOn: $viewModel.draft.shutdownProtectionEnabled) {
                                Text("Prevent Switch Off")
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding()
                        }

                        // Group F: Wallpaper
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
                            
                            Divider().padding(.leading, 16).opacity(0.3)
                            
                            Toggle(isOn: $viewModel.draft.dailyMotivationEnabled) {
                                HStack(spacing: 12) {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundColor(Colors.accentTeal)
                                    Text("Daily Motivation")
                                        .foregroundColor(Colors.textPrimary)
                                }
                            }
                            .padding()

                            if viewModel.draft.dailyMotivationEnabled {
                                Text("Displays a new motivational quote each day when the alarm rings.")
                                    .font(.caption)
                                    .foregroundColor(Colors.textSecondary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
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
                        guard !isSaving else { return }
                        saveAlarm(ignoreDeliveryWarnings: true)
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(Colors.accentTeal)
                    }
                    .disabled(isSaving)
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
            showingLocalTimePreview = true
            syncTimeToSelectedTimeZone()
            viewModel.startCycling()
        }
        .onChange(of: viewModel.draft.timeZoneMode) { old, new in
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
            if viewModel.draft.timeZoneMode == .custom {
                showingLocalTimePreview = true
                viewModel.startCycling()
            }
            
            // Trigger first relevant step
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if !preferences.hasSeenEditAlarmTimeTooltip {
                    showTimeCoachMark = true
                } else if !preferences.hasSeenEditAlarmNameTooltip {
                    showNameCoachMark = true
                } else if !preferences.hasSeenEditAlarmMissionTooltip {
                    showMissionCoachMark = true
                } else if !preferences.hasSeenEditAlarmSoundTooltip {
                    showSoundCoachMark = true
                } else if !preferences.hasSeenEditAlarmToggleTooltip {
                    showToggleCoachMark = true
                } else if !preferences.hasSeenEditAlarmActionsTooltip {
                    showPenaltyCoachMark = true
                }
            }
        }
        .onChange(of: showTimeCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmTimeTooltip {
                preferences.hasSeenEditAlarmTimeTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showNameCoachMark = true }
            }
        }
        .onChange(of: showNameCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmNameTooltip {
                preferences.hasSeenEditAlarmNameTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showMissionCoachMark = true }
            }
        }
        .onChange(of: showMissionCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmMissionTooltip {
                preferences.hasSeenEditAlarmMissionTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showSoundCoachMark = true }
            }
        }
        .onChange(of: showSoundCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmSoundTooltip {
                preferences.hasSeenEditAlarmSoundTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showToggleCoachMark = true }
            }
        }
        .onChange(of: showToggleCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmToggleTooltip {
                preferences.hasSeenEditAlarmToggleTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPenaltyCoachMark = true }
            }
        }
        .onChange(of: showPenaltyCoachMark) { _, isVisible in
            if !isVisible && !preferences.hasSeenEditAlarmActionsTooltip {
                preferences.hasSeenEditAlarmActionsTooltip = true
            }
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
            } else if mission.type == .bibleVerse ||
                        mission.type == .quranVerse ||
                        mission.type == .bhagavadGitaVerse ||
                        mission.type == .affirmation {
                ReligiousMissionSettingsView(initialMission: mission) { updatedMission in
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                soundPlayer.stop()
            }
        }
    }
    
    // MARK: - State properties for new sheets
    @State private var showNameEditor = false
    @State private var showRepeatEditor = false
    @State private var showSoundEditor = false

    // MARK: - Helpers
    private var isClassicSunrayStyle: Bool {
        settingsStore.alarmClockStyle == .classicSunray
    }

    private var timeDisplayOffsetY: CGFloat {
        isClassicSunrayStyle ? -34 : -44
    }

    private var timeDisplayBottomPadding: CGFloat {
        isClassicSunrayStyle ? 4 : -18
    }

    private var locationBadgeTopPadding: CGFloat {
        isClassicSunrayStyle ? -22 : -50
    }

    private var locationBadgeBottomPadding: CGFloat {
        isClassicSunrayStyle ? 0 : -2
    }

    private var alarmNameTopPadding: CGFloat {
        isClassicSunrayStyle ? -8 : -28
    }

    private func normalizedEmojiInput(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first)
    }

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

    func saveAlarm(ignoreDeliveryWarnings: Bool = false) {
        guard !isSaving else { return }
        isSaving = true
        let alarmName = viewModel.draft.name.isEmpty ? "Alarm" : viewModel.draft.name
        let alarmId = existingAlarm?.id ?? UUID()
        let blockAppsEnabled = viewModel.draft.blockAppsEnabled
        let enforcementMode: EnforcementMode = blockAppsEnabled ? .blockApps : .none

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
            dailyMotivationEnabled: viewModel.draft.dailyMotivationEnabled,
            visualOutputSettings: AlarmVisualOutputSettings.migratedFromLegacy(
                wallpaperId: viewModel.draft.wallpaperId,
                dailyMotivationEnabled: viewModel.draft.dailyMotivationEnabled
            ),
            createdAt: Date(),
            missions: viewModel.draft.missions,
            enforcementMode: enforcementMode,
            blockAppsEnabled: blockAppsEnabled,
            blockedSelectionData: settingsStore.blockedAppsSelectionData,
            penaltyEnabled: false,
            penaltyAmountEuro: settingsStore.penaltyAmountEuro,
            penaltyStrategy: .credits,
            penaltyRules: .default,
            shutdownProtectionEnabled: viewModel.draft.shutdownProtectionEnabled
        )

        let completeSave: () -> Void = {
            // Persist immediately so Save is deterministic even when opened via
            // rapid gestures like double-tap from Home alarm cards.
            if existingAlarm != nil {
                alarmStore.update(alarm)
            } else {
                alarmStore.add(alarm)
            }

            // Scheduling can perform heavy notification/asset work; keep it off main.
            DispatchQueue.global(qos: .utility).async {
                scheduler.cancel(alarmId: alarm.id)
                scheduler.schedule(alarm: alarm)
            }

            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isSaving = false
            }
        }

        guard !ignoreDeliveryWarnings else {
            completeSave()
            return
        }

        Task { @MainActor in
            let granted = await notificationManager.ensureAuthorization()
            let delivery = await notificationManager.currentAlarmDeliveryStatus()
            if !granted || !delivery.notificationsAuthorized {
                isSaving = false
                alarmAccessAlertMessage = "Alarm notifications are not authorized. Turn on notifications for Alarmo."
                showAlarmAccessAlert = true
                return
            }
            if !delivery.soundEnabled {
                isSaving = false
                alarmAccessAlertMessage = "Notification sounds are turned off for Alarmo. Turn sounds on so alarms ring audibly."
                showAlarmAccessAlert = true
                return
            }
            if !delivery.alertEnabled {
                isSaving = false
                alarmAccessAlertMessage = "Alert notifications are turned off for Alarmo. Enable Alerts so alarms appear on screen."
                showAlarmAccessAlert = true
                return
            }
            if !delivery.lockScreenEnabled {
                isSaving = false
                alarmAccessAlertMessage = "Lock Screen alerts are off for Alarmo. Enable Lock Screen notifications so alarms are visible while your phone is locked."
                showAlarmAccessAlert = true
                return
            }
            if delivery.scheduledDeliveryEnabled && !delivery.timeSensitiveEnabled {
                isSaving = false
                alarmAccessAlertMessage = "Scheduled Summary is on and Time Sensitive is off. Alarms may be delayed until you unlock the phone."
                showAlarmAccessAlert = true
                return
            }
            if !delivery.timeSensitiveEnabled {
                isSaving = false
                alarmAccessAlertMessage = "Time Sensitive notifications are off. Enable them to keep alarm alerts audible during Focus modes."
                showAlarmAccessAlert = true
                return
            }
            completeSave()
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

    // MARK: - Time Projection
    private var projectedHour: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.draft.hour, m: viewModel.draft.minute, s: viewModel.draft.second, from: tz, to: .current).h
                }
                return viewModel.draft.hour
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: newValue, m: viewModel.draft.minute, s: viewModel.draft.second, from: .current, to: tz)
                    viewModel.draft.hour = res.h
                    viewModel.draft.minute = res.m
                    viewModel.draft.second = res.s
                } else {
                    viewModel.draft.hour = newValue
                }
            }
        )
    }

    private var projectedMinute: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.draft.hour, m: viewModel.draft.minute, s: viewModel.draft.second, from: tz, to: .current).m
                }
                return viewModel.draft.minute
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: viewModel.draft.hour, m: newValue, s: viewModel.draft.second, from: .current, to: tz)
                    viewModel.draft.hour = res.h
                    viewModel.draft.minute = res.m
                    viewModel.draft.second = res.s
                } else {
                    viewModel.draft.minute = newValue
                }
            }
        )
    }

    private var projectedSecond: Binding<Int> {
        Binding(
            get: {
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    return timeProjector(h: viewModel.draft.hour, m: viewModel.draft.minute, s: viewModel.draft.second, from: tz, to: .current).s
                }
                return viewModel.draft.second
            },
            set: { newValue in
                if showingLocalTimePreview, let id = viewModel.draft.timeZoneIdentifier, let tz = TimeZone(identifier: id) {
                    let res = timeProjector(h: viewModel.draft.hour, m: viewModel.draft.minute, s: newValue, from: .current, to: tz)
                    viewModel.draft.hour = res.h
                    viewModel.draft.minute = res.m
                    viewModel.draft.second = res.s
                } else {
                    viewModel.draft.second = newValue
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
        showingLocalTimePreview && viewModel.draft.timeZoneMode == .custom && viewModel.cycleToLocal
    }

    private var badgeDisplayText: String {
        if viewModel.draft.timeZoneMode == .local {
            return "LOCAL TIME"
        }
        
        if showingLocalTimePreview {
            return isShowingLocalInFloat ? "LOCAL TIME" : (viewModel.draft.timeZoneCity?.uppercased() ?? "TARGET TIME")
        } else {
            return viewModel.draft.timeZoneCity?.uppercased() ?? "CUSTOM LOCATION"
        }
    }

    private var bindingForPicker: (Binding<Int>, Binding<Int>, Binding<Int>) {
        if isShowingLocalInFloat {
            return (projectedHour, projectedMinute, projectedSecond)
        } else {
            return ($viewModel.draft.hour, $viewModel.draft.minute, $viewModel.draft.second)
        }
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
        guard let uiImage = WallpaperImageResolver.resolveImage(for: viewModel.draft.wallpaperId) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}
