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
    @State private var showMissionSelection = false
    @State private var selectedMissionForConfig: AlarmMission?
    @State private var editingMissionIndex: Int?
    
    // Services
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()
    
    init(alarmStore: AlarmStore, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        let defaults = AppPreferences()
        _viewModel = StateObject(wrappedValue: CreateHabitAlarmViewModel(
            defaultHour: defaults.onboardingAlarmHour,
            defaultMinute: defaults.onboardingAlarmMinute,
            defaultSoundName: defaults.onboardingSoundName,
            defaultSoundVolume: defaults.onboardingSoundVolume,
            defaultWallpaperId: defaults.onboardingWallpaperId
        ))
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Spacing.l) {
                    
                    // Header
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                        Text("Habit alarm")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Spacer().frame(width: 44)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                    
                    // Goal Input
                    HStack(spacing: Spacing.m) {
                        Button(action: { showEmojiPicker = true }) {
                            Text(viewModel.emoji)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                        }
                        
                        TextField("Enter your habit goal", text: $viewModel.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .focused($nameFocused)
                        
                        Button(action: { nameFocused = true }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    // Ring Countdown
                    Text(viewModel.ringInText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    
                    // Time Picker
                    TimeWheelPickerView(
                        hour: $viewModel.hour,
                        minute: $viewModel.minute
                    )
                    .onChange(of: viewModel.hour) { _, _ in viewModel.updateRingInText() }
                    .onChange(of: viewModel.minute) { _, _ in viewModel.updateRingInText() }
                    
                    // Repeat Controls
                    HStack {
                        Text(viewModel.isDaily ? "Daily" : "Custom")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Button(action: { viewModel.toggleDaily() }) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.isDaily ? Colors.accentTeal : Colors.textTertiary, lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(viewModel.isDaily ? Colors.accentTeal : Color.clear)
                                    )
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(viewModel.isDaily ? 1 : 0)
                                    )
                                Text("Daily")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            WeekdayPill(
                                label: weekdayLabel(day),
                                isSelected: viewModel.selectedWeekdays.contains(day),
                                isInteractive: true // In Habit alarm, we allow toggling always, but logic handles Daily interaction
                            ) {
                                viewModel.toggleWeekday(day)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    // Mission Section
                    MissionSectionView(
                        missions: viewModel.missions,
                        onAddMission: {
                            editingMissionIndex = nil
                            showMissionSelection = true
                        },
                        onEditMission: { index in
                            editingMissionIndex = index
                            selectedMissionForConfig = viewModel.missions[index]
                        },
                        onRemoveMission: { index in
                            viewModel.removeMission(at: index)
                        },
                        wakeUpCheckText: viewModel.wakeUpCheckEnabled ? "On" : "Off",
                        onWakeUpCheck: { showWakeUpCheck = true }
                    )
                    .padding(.horizontal, Spacing.l)
                    
                    // Sound & Settings
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Alarm sound")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        
                        AlarmSoundCard(
                            soundName: viewModel.soundName,
                            isBuffering: soundPlayer.isBuffering,
                            onTap: { showSoundPicker = true },
                            onPreview: {
                                soundPlayer.play(resourceName: viewModel.soundName, volume: viewModel.soundVolume)
                            }
                        )
                        
                        HStack(spacing: Spacing.m) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(Colors.textSecondary)
                            Slider(value: $viewModel.soundVolume, in: 0...1)
                                .tint(.white)
                            
                            Button(action: { viewModel.vibrateEnabled.toggle() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .foregroundColor(Colors.textSecondary)
                                    Image(systemName: viewModel.vibrateEnabled ? "checkmark.square.fill" : "square")
                                        .foregroundColor(viewModel.vibrateEnabled ? Colors.accentTeal : Colors.textTertiary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    SettingsRow(title: "Gentle wake-up", value: gentleWakeUpText) {
                        showGentleWakeUpPicker = true
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    ReminderTogglesCard(
                        timeReminder: $viewModel.timeReminderEnabled,
                        weatherReminder: $viewModel.weatherReminderEnabled,
                        labelReminder: $viewModel.labelReminderEnabled,
                        extraLoud: $viewModel.extraLoudEnabled
                    )
                    .padding(.horizontal, Spacing.l)
                    
                    // Custom Settings (Snooze & Wallpaper)
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Custom setting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        
                        CustomSettingsCard(
                            snoozeText: snoozeSummary,
                            onSnooze: { showSnoozePicker = true },
                            wallpaperId: viewModel.wallpaperId,
                            onWallpaper: { showWallpaperPicker = true }
                        )
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    Spacer(minLength: 140)
                }
            }
            
            // Footer Save Button
            VStack {
                Spacer()
                PrimaryButton(title: "Save") {
                    saveAlarm()
                }
                .disabled(viewModel.name.isEmpty)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
                .background(
                    LinearGradient(
                        colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary, Colors.bgPrimary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
            GentleWakeUpPickerView(selectedSeconds: $viewModel.gentleWakeUpSeconds)
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePickerView(minutes: $viewModel.snoozeMinutes, count: $viewModel.snoozeCount)
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.wallpaperId)
        }
        .sheet(isPresented: $showWakeUpCheck) {
            WakeUpCheckView(isEnabled: $viewModel.wakeUpCheckEnabled)
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
        .onDisappear {
            soundPlayer.stop()
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
    
    private func saveAlarm() {
        Task { @MainActor in
            _ = await notificationManager.ensureAuthorization()
            
            let alarm = Alarm(
                id: UUID(),
                type: .habit,
                name: viewModel.name,
                emoji: viewModel.emoji,
                hour: viewModel.hour,
                minute: viewModel.minute,
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
                snoozeMinutes: viewModel.snoozeMinutes,
                snoozeCount: viewModel.snoozeCount,
                wallpaperId: viewModel.wallpaperId,
                createdAt: Date(),
                missions: viewModel.missions
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
    private var gentleWakeUpText: String {
        viewModel.gentleWakeUpSeconds == 0 ? "Off" : "\(viewModel.gentleWakeUpSeconds) seconds"
    }

    private var snoozeSummary: String {
        if viewModel.snoozeMinutes == 0 {
            return "Off"
        }
        return "\(viewModel.snoozeMinutes) min, \(viewModel.snoozeCount) times"
    }
}
