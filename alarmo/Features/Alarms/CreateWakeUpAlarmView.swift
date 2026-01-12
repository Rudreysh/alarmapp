import SwiftUI

struct CreateWakeUpAlarmView: View {
    @ObservedObject var alarmStore: AlarmStore
    @EnvironmentObject private var notificationManager: NotificationManager
    let onClose: () -> Void
    @StateObject private var viewModel: CreateWakeUpAlarmViewModel
    @FocusState private var nameFocused: Bool
    @State private var showEmojiPicker = false
    @State private var showMissionAlert = false
    @State private var showWakeUpCheck = false
    @State private var showSoundPicker = false
    @State private var showGentleWakeUpPicker = false
    @State private var showSnoozePicker = false
    @State private var showWallpaperPicker = false
    private let soundPlayer = SoundPreviewPlayer()
    private let scheduler: AlarmSchedulerProtocol = AlarmScheduler()

    init(alarmStore: AlarmStore, onClose: @escaping () -> Void) {
        self.alarmStore = alarmStore
        self.onClose = onClose
        let defaults = AppPreferences()
        _viewModel = StateObject(wrappedValue: CreateWakeUpAlarmViewModel(
            defaultHour: defaults.onboardingAlarmHour,
            defaultMinute: defaults.onboardingAlarmMinute,
            defaultRepeatMask: defaults.onboardingRepeatMask,
            defaultSoundName: defaults.onboardingSoundName,
            defaultSoundVolume: defaults.onboardingSoundVolume
        ))
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
                        showAlert: $showMissionAlert,
                        wakeUpCheckText: viewModel.draft.wakeUpCheckEnabled ? "On" : "Off"
                    ) {
                        showWakeUpCheck = true
                    }
                    .padding(.horizontal, Spacing.l)

                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Alarm sound")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        AlarmSoundCard(
                            soundName: viewModel.draft.soundName,
                            onTap: { showSoundPicker = true },
                            onPreview: {
                                soundPlayer.play(resourceName: viewModel.draft.soundName, volume: viewModel.draft.soundVolume)
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

                    Spacer(minLength: 140)
                }
            }

            VStack {
                Spacer()
                PrimaryButton(title: "Save") {
                    Task { @MainActor in
                        _ = await notificationManager.ensureAuthorization()
                        let alarmName = viewModel.draft.name.isEmpty ? "Alarm" : viewModel.draft.name
                        let alarm = Alarm(
                            id: UUID(),
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
                            createdAt: Date()
                        )
                        alarmStore.add(alarm)
                        scheduler.schedule(alarm: alarm)
                        onClose()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
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
        .alert("Coming soon", isPresented: $showMissionAlert) {
            Button("OK", role: .cancel) {}
        }
        .onDisappear {
            soundPlayer.stop()
        }
    }

    private func weekdayLabel(_ day: Int) -> String {
        let labels = ["S", "M", "T", "W", "T", "F", "S"]
        return labels[day - 1]
    }
}

private struct MissionSectionView: View {
    @Binding var showAlert: Bool
    let wakeUpCheckText: String
    let onWakeUpCheck: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Mission")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text("0/5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    Button(action: { showAlert = true }) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Colors.cardStroke, lineWidth: 1)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(Colors.textSecondary)
                            )
                    }
                }
            }

            Button(action: onWakeUpCheck) {
                HStack {
                    Text("Wake up check")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text(wakeUpCheckText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .padding(Spacing.l)
        .background(Colors.cardSurface)
        .cornerRadius(22)
    }
}

private struct AlarmSoundCard: View {
    let soundName: String
    let onTap: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                Circle()
                    .fill(Colors.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "play.fill").foregroundColor(Colors.textPrimary))
            }
            .buttonStyle(.plain)

            Text(soundName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Colors.textSecondary)
        }
        .padding(Spacing.m)
        .background(Colors.cardSurface)
        .cornerRadius(22)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct SettingsRow: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                Image(systemName: "chevron.right")
                    .foregroundColor(Colors.textSecondary)
            }
            .padding(Spacing.m)
            .background(Colors.cardSurface)
            .cornerRadius(22)
        }
    }
}

private struct ReminderTogglesCard: View {
    @Binding var timeReminder: Bool
    @Binding var weatherReminder: Bool
    @Binding var labelReminder: Bool
    @Binding var extraLoud: Bool

    var body: some View {
        VStack(spacing: Spacing.m) {
            ReminderRow(title: "Time reminder", isOn: $timeReminder)
            ReminderRow(title: "Weather reminder", isOn: $weatherReminder)
            ReminderRow(title: "Label reminder", isOn: $labelReminder)
            ReminderRow(title: "Extra loud effect", isOn: $extraLoud)
        }
        .padding(Spacing.l)
        .background(Colors.cardSurface)
        .cornerRadius(22)
    }
}

private struct ReminderRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textPrimary)
            Spacer()
            Button(action: {}) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Sample")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Colors.bgSecondary)
                .cornerRadius(12)
                .foregroundColor(Colors.textSecondary)
            }
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct CustomSettingsCard: View {
    let snoozeText: String
    let onSnooze: () -> Void
    let wallpaperId: String
    let onWallpaper: () -> Void

    var body: some View {
        VStack(spacing: Spacing.m) {
            Button(action: onSnooze) {
                HStack {
                    Text("Snooze")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Text(snoozeText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Colors.textSecondary)
                }
            }
            Divider().background(Colors.cardStroke)
            Button(action: onWallpaper) {
                HStack {
                    Text("Alarm wallpaper")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 56)
                }
            }
        }
        .padding(Spacing.l)
        .background(Colors.cardSurface)
        .cornerRadius(22)
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
