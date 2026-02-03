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
    @State private var showSoundPicker = false
    @State private var showGentleWakeUpPicker = false
    @State private var showSnoozePicker = false
    @State private var showWallpaperPicker = false
    @State private var showMissionSelection = false
    @State private var selectedMissionForConfig: AlarmMission?
    @State private var editingMissionIndex: Int?
    @StateObject private var soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()

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
                defaultRepeatMask: defaults.onboardingRepeatMask,
                defaultSoundName: defaults.onboardingSoundName,
                defaultSoundVolume: defaults.onboardingSoundVolume,
                defaultWallpaperId: defaults.onboardingWallpaperId
            ))
        }
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.l) {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                        Text("Wake-up alarm")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Spacer().frame(width: 44)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)

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

                    Text(viewModel.ringInText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)

                    TimeWheelPickerView(
                        hour: $viewModel.draft.hour,
                        minute: $viewModel.draft.minute
                    )

                    HStack {
                        Text(viewModel.draft.isDaily ? "Daily" : "One-time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Button(action: {
                            viewModel.toggleDaily()
                        }) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.draft.isDaily ? Colors.accentTeal : Colors.textTertiary, lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(viewModel.draft.isDaily ? Colors.accentTeal : Color.clear)
                                    )
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .opacity(viewModel.draft.isDaily ? 1 : 0)
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
                                isSelected: viewModel.draft.selectedWeekdays.contains(day),
                                isInteractive: !viewModel.draft.isDaily
                            ) {
                                viewModel.toggleWeekday(day)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)

                    MissionSectionView(
                        missions: viewModel.draft.missions,
                        onAddMission: {
                            editingMissionIndex = nil
                            showMissionSelection = true
                        },
                        onEditMission: { index in
                            editingMissionIndex = index
                            selectedMissionForConfig = viewModel.draft.missions[index]
                        },
                        onRemoveMission: { index in
                            viewModel.removeMission(at: index)
                        },
                        wakeUpCheckText: viewModel.draft.wakeUpCheckEnabled ? "On" : "Off",
                        onWakeUpCheck: { showWakeUpCheck = true }
                    )
                    .padding(.horizontal, Spacing.l)

                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Alarm sound")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        AlarmSoundCard(
                            soundName: viewModel.draft.soundName,
                            isBuffering: soundPlayer.isBuffering,
                            isPlaying: soundPlayer.isPlaying,
                            onTap: { showSoundPicker = true },
                            onPreview: {
                                if soundPlayer.isPlaying {
                                    soundPlayer.stop()
                                } else {
                                    soundPlayer.play(resourceName: viewModel.draft.soundName, volume: viewModel.draft.soundVolume)
                                }
                            }
                        )

                        ProgressView(value: viewModel.soundProgress)
                            .progressViewStyle(.linear)
                            .tint(Colors.textTertiary)

                        HStack(spacing: Spacing.m) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(Colors.textSecondary)
                            Slider(value: $viewModel.draft.soundVolume, in: 0...1)
                            Button(action: { viewModel.draft.vibrateEnabled.toggle() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                        .foregroundColor(Colors.textSecondary)
                                    Image(systemName: viewModel.draft.vibrateEnabled ? "checkmark.square.fill" : "square")
                                        .foregroundColor(viewModel.draft.vibrateEnabled ? Colors.accentTeal : Colors.textTertiary)
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
                        timeReminder: $viewModel.draft.timeReminderEnabled,
                        weatherReminder: $viewModel.draft.weatherReminderEnabled,
                        labelReminder: $viewModel.draft.labelReminderEnabled,
                        extraLoud: $viewModel.draft.extraLoudEnabled
                    )
                    .padding(.horizontal, Spacing.l)

                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Custom setting")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        CustomSettingsCard(
                            snoozeText: snoozeSummary,
                            onSnooze: { showSnoozePicker = true },
                            wallpaperId: viewModel.draft.wallpaperId,
                            onWallpaper: { showWallpaperPicker = true }
                        )
                    }
                    .padding(.horizontal, Spacing.l)
                }
            }
            .safeAreaInset(edge: .bottom) {
                 VStack(spacing: 0) {
                     LinearGradient(colors: [Colors.bgPrimary.opacity(0), Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                         .frame(height: 20)
                         .allowsHitTesting(false)
                     
                     PrimaryButton(title: "Save") {
                        Task { @MainActor in
                            _ = await notificationManager.ensureAuthorization()
                            let alarmName = viewModel.draft.name.isEmpty ? "Alarm" : viewModel.draft.name
                            let alarmId = existingAlarm?.id ?? UUID()
                            let alarm = Alarm(
                                id: alarmId,
                                name: alarmName,
                                emoji: viewModel.draft.emoji,
                                hour: viewModel.draft.hour,
                                minute: viewModel.draft.minute,
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
                                snoozeMinutes: viewModel.draft.snoozeMinutes,
                                snoozeCount: viewModel.draft.snoozeCount,
                                wallpaperId: viewModel.draft.wallpaperId,
                                createdAt: Date(),
                                missions: viewModel.draft.missions
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
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
                    .background(Colors.bgPrimary)
                 }
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                viewModel.draft.emoji = emoji
                showEmojiPicker = false
            }
        }
        .sheet(isPresented: $showWakeUpCheck) {
            WakeUpCheckView(isEnabled: $viewModel.draft.wakeUpCheckEnabled)
        }
        .sheet(isPresented: $showSoundPicker) {
            SoundPickerView(selectedSound: $viewModel.draft.soundName)
        }
        .sheet(isPresented: $showGentleWakeUpPicker) {
            GentleWakeUpPickerView(selectedSeconds: $viewModel.draft.gentleWakeUpSeconds)
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePickerView(minutes: $viewModel.draft.snoozeMinutes, count: $viewModel.draft.snoozeCount)
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPickerView(selectedId: $viewModel.draft.wallpaperId)
        }
        .sheet(isPresented: $showMissionSelection) {
            MissionSelectionView { mission in
                showMissionSelection = false
                // Small delay to ensure previous sheet is dismissed
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
                        difficulty: difficulty.rows, // Storing grid size for now
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
                // Fallback for other missions as empty pages for now
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
        if viewModel.draft.snoozeMinutes == 0 {
            return "Off"
        }
        return "\(viewModel.draft.snoozeMinutes) min, \(viewModel.draft.snoozeCount) times"
    }
}
