import SwiftUI
import UserNotifications
import UIKit

// MARK: - Quick Settings Panel

struct QuickSettingsPanel: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var alarmStore: AlarmStore
    @ObservedObject private var settingsStore = SettingsStore.shared

    // Persisted quick settings
    @AppStorage("qs_globalSnoozeEnabled") private var globalSnoozeEnabled = true
    @AppStorage("qs_snoozeMinutes") private var snoozeMinutes = 9
    @AppStorage("qs_vibrationEnabled") private var vibrationEnabled = true
    @AppStorage("qs_skipWeekends") private var skipWeekends = false
    @AppStorage("qs_alarmVolume") private var alarmVolume: Double = 0.8
    @AppStorage("qs_bedReminderEnabled") private var bedReminderEnabled = false
    @AppStorage("qs_bedReminderMinutes") private var bedReminderMinutes = 30
    @AppStorage("qs_smartWakeEnabled") private var smartWakeEnabled = false
    @AppStorage("qs_smartWakeWindow") private var smartWakeWindow = 20
    @AppStorage("qs_sleepGoalHours") private var sleepGoalHours = 8
    @AppStorage("qs_focusModeEnabled") private var focusModeEnabled = false
    @AppStorage("qs_sortOrder") private var sortOrder = 0
    @AppStorage("qs_streak") private var alarmStreak = 0
    @AppStorage("qs_alarmQuickPresets") private var quickPresetsData: Data = Data()

    @State private var selectedTab = 0
    @State private var showAllDisabledConfirm = false
    @State private var feedbackMessage: String? = nil
    @State private var quickPresets: [AlarmQuickPreset] = []
    @State private var selectedQuickPresetIDs: Set<UUID> = []
    @State private var isManagingPresets = false
    @State private var showPresetEditor = false
    @State private var editingPresetID: UUID? = nil
    @State private var presetDraft = AlarmQuickPresetDraft()

    private let tabs: [(title: String, icon: String)] = [
        ("Presets", "square.stack.3d.up.fill"),
        ("Global", "bolt.fill"),
        ("Sleep", "moon.zzz.fill"),
        ("Focus", "target")
    ]

    private var isLightMode: Bool {
        colorScheme == .light
    }

    private var isTiimoTheme: Bool {
        settingsStore.alarmThemeStyle.usesTiimoLayoutBranch
    }

    private var isClassicTiimoTheme: Bool {
        settingsStore.alarmThemeStyle == .tiimo
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    tabSelector
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 16)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            switch selectedTab {
                            case 0: quickPresetsSection
                            case 1: globalControlsSection
                            case 2: sleepIntelligenceSection
                            default: focusProductivitySection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }

                // Feedback toast
                if let msg = feedbackMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Colors.accentTeal))
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Quick Settings")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if !selectedQuickPresetIDs.isEmpty {
                            addSelectedPresetAlarms(showFeedback: false)
                        }
                        dismiss()
                    }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.fraction(0.75), .large])
        .onAppear {
            loadQuickPresets()
        }
        .sheet(isPresented: $showPresetEditor) {
            QuickAlarmPresetEditorSheet(
                draft: $presetDraft,
                isEditing: editingPresetID != nil,
                onCancel: { showPresetEditor = false },
                onSave: {
                    savePresetDraft()
                    showPresetEditor = false
                }
            )
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    let isSelected = selectedTab == index
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedTab = index }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(
                            isSelected
                                ? (isTiimoTheme ? (isClassicTiimoTheme ? .white : Colors.textPrimary) : Colors.textPrimary)
                                : (isTiimoTheme ? Colors.textTertiary : Colors.textSecondary)
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                        ? LinearGradient(
                                            colors: isTiimoTheme
                                                ? [Colors.saleBadgeStart, Colors.saleBadgeEnd]
                                                : (isLightMode
                                                    ? [Color.white, Color(red: 0.90, green: 0.96, blue: 1.0)]
                                                    : [Colors.accentTeal.opacity(0.9), Colors.accentTeal.opacity(0.75)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [
                                                isTiimoTheme
                                                    ? Colors.pillGreen
                                                    : (isLightMode ? Color(red: 0.93, green: 0.94, blue: 0.97) : Colors.cardSurface),
                                                isTiimoTheme
                                                    ? Colors.cardSurface
                                                    : (isLightMode ? Color(red: 0.88, green: 0.90, blue: 0.94) : Colors.cardSurface.opacity(0.95))
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                        ? (isTiimoTheme
                                            ? Colors.accentBlue
                                            : (isLightMode ? Color(red: 0.55, green: 0.76, blue: 0.96).opacity(0.7) : Color.white.opacity(0.18)))
                                        : (isTiimoTheme ? Colors.cardStroke : (isLightMode ? Colors.cardStroke : Color.white.opacity(0.08))),
                                    lineWidth: isTiimoTheme && isSelected ? 1.5 : 1
                                )
                        )
                        .shadow(color: isTiimoTheme && isSelected ? Colors.accentBlue.opacity(0.28) : .clear, radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                isLightMode ? Color.white.opacity(0.98) : Colors.cardSurface.opacity(0.95),
                                isLightMode ? Color(red: 0.94, green: 0.95, blue: 0.98).opacity(0.98) : Colors.cardSurface.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isLightMode ? Colors.cardStroke : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Tab 1: Global Alarm Controls

    private var globalControlsSection: some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "slider.horizontal.3", title: "Global Alarm Controls", subtitle: "Applied across all your alarms")

            // All On / All Off
            QSCard {
                VStack(spacing: 12) {
                    HStack {
                        Label("Alarm Power", systemImage: "alarm.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Spacer()
                        Button {
                            alarmStore.alarms.forEach { alarmStore.toggleEnabled(id: $0.id, enabled: true) }
                            showFeedback("All alarms enabled ✓")
                        } label: {
                            Text("All On")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Colors.accentTeal))
                        }
                        .buttonStyle(.plain)

                        Button { showAllDisabledConfirm = true } label: {
                            Text("All Off")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().background(Colors.cardStroke)

                    let activeCount = alarmStore.alarms.filter(\.enabled).count
                    let total = alarmStore.alarms.count
                    HStack {
                        Text("\(activeCount) of \(total) alarms active")
                            .font(.system(size: 13))
                            .foregroundColor(Colors.textTertiary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(0..<min(total, 8), id: \.self) { i in
                                Circle()
                                    .fill(i < activeCount ? Colors.accentTeal : Color.white.opacity(0.1))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
            }
            .alert("Disable All Alarms?", isPresented: $showAllDisabledConfirm) {
                Button("Disable All", role: .destructive) {
                    alarmStore.alarms.forEach { alarmStore.toggleEnabled(id: $0.id, enabled: false) }
                    showFeedback("All alarms disabled")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will turn off all \(alarmStore.alarms.count) alarms until you re-enable them.")
            }

            // Snooze Control — writes to all alarms
            QSCard {
                VStack(spacing: 12) {
                    QSToggleRow(
                        icon: "zzz", iconColor: .blue,
                        title: "Global Snooze",
                        subtitle: "Allow snoozing on all alarms",
                        isOn: Binding(
                            get: { globalSnoozeEnabled },
                            set: { newVal in
                                globalSnoozeEnabled = newVal
                                // When turning off, set snooze to 0 min (effectively disabled)
                                alarmStore.applyGlobalSnooze(minutes: newVal ? snoozeMinutes : 0)
                                showFeedback(newVal ? "Snooze enabled on all alarms" : "Snooze disabled on all alarms")
                            }
                        )
                    )

                    if globalSnoozeEnabled {
                        Divider().background(Colors.cardStroke)
                        HStack {
                            Text("Duration")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    if snoozeMinutes > 1 {
                                        snoozeMinutes -= 1
                                        alarmStore.applyGlobalSnooze(minutes: snoozeMinutes)
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                        .foregroundColor(Colors.textSecondary)
                                }

                                Text("\(snoozeMinutes) min")
                                    .font(.system(size: 15, weight: .black, design: .monospaced))
                                    .foregroundColor(Colors.accentTeal)
                                    .frame(minWidth: 55)

                                Button {
                                    if snoozeMinutes < 30 {
                                        snoozeMinutes += 1
                                        alarmStore.applyGlobalSnooze(minutes: snoozeMinutes)
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Colors.accentTeal))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                }
            }

            // Volume & Vibration & Skip Weekends
            QSCard {
                VStack(spacing: 12) {
                    // Volume
                    HStack {
                        Label {
                            Text("Alarm Volume")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                        } icon: {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text("\(Int(alarmVolume * 100))%")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(Colors.accentTeal)
                    }
                    Slider(value: $alarmVolume, in: 0...1)
                        .tint(Colors.accentTeal)
                        .onChange(of: alarmVolume) { _, newVal in
                            alarmStore.applyGlobalVolume(volume: Float(newVal))
                        }

                    Divider().background(Colors.cardStroke)

                    // Vibration
                    QSToggleRow(
                        icon: "iphone.radiowaves.left.and.right", iconColor: .purple,
                        title: "Haptic Feedback",
                        subtitle: "Vibrate when alarm rings",
                        isOn: Binding(
                            get: { vibrationEnabled },
                            set: { newVal in
                                vibrationEnabled = newVal
                                alarmStore.applyGlobalVibration(enabled: newVal)
                                showFeedback(newVal ? "Haptics enabled on all alarms" : "Haptics disabled on all alarms")
                            }
                        )
                    )

                    Divider().background(Colors.cardStroke)

                    // Skip Weekends
                    QSToggleRow(
                        icon: "calendar.badge.minus", iconColor: .red,
                        title: "Skip Weekends",
                        subtitle: "Remove Sat & Sun from all alarm schedules",
                        isOn: Binding(
                            get: { skipWeekends },
                            set: { newVal in
                                skipWeekends = newVal
                                alarmStore.applySkipWeekends(newVal)
                                showFeedback(newVal ? "Weekends removed from schedules" : "Weekend schedules restored")
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - Tab 2: Sleep Intelligence

    private var sleepIntelligenceSection: some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "moon.stars.fill", title: "Sleep Intelligence", subtitle: "Build smart wake-up habits")

            // Sleep Goal
            QSCard {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sleep Goal")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                            Text("Daily target for optimal performance")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        }
                        Spacer()
                        HStack(spacing: 0) {
                            Text("\(sleepGoalHours)")
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(Colors.accentTeal)
                            Text("H")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(Colors.textSecondary)
                                .padding(.leading, 1)
                        }
                    }

                    Slider(value: Binding(
                        get: { Double(sleepGoalHours) },
                        set: { sleepGoalHours = Int($0) }
                    ), in: 5...12, step: 1)
                    .tint(Colors.accentTeal)

                    HStack {
                        Text("5h").font(.system(size: 10, weight: .medium)).foregroundColor(Colors.textTertiary)
                        Spacer()
                        let quality: String = {
                            if sleepGoalHours >= 8 { return "Optimal 🌟" }
                            if sleepGoalHours >= 7 { return "Good 👍" }
                            if sleepGoalHours >= 6 { return "Fair ⚠️" }
                            return "Poor 😴"
                        }()
                        Text(quality)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(sleepGoalHours >= 8 ? Colors.accentTeal : sleepGoalHours >= 7 ? .yellow : .orange)
                        Spacer()
                        Text("12h").font(.system(size: 10, weight: .medium)).foregroundColor(Colors.textTertiary)
                    }
                }
            }

            // Bedtime Reminder — schedules a real UNUserNotificationCenter notification
            QSCard {
                VStack(spacing: 12) {
                    QSToggleRow(
                        icon: "bed.double.fill", iconColor: Colors.accentTeal,
                        title: "Bedtime Reminder",
                        subtitle: "Notification to wind down before sleep",
                        isOn: Binding(
                            get: { bedReminderEnabled },
                            set: { newVal in
                                bedReminderEnabled = newVal
                                if newVal {
                                    scheduleBedtimeReminder()
                                } else {
                                    cancelBedtimeReminder()
                                    showFeedback("Bedtime reminder cancelled")
                                }
                            }
                        )
                    )

                    if bedReminderEnabled {
                        Divider().background(Colors.cardStroke)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind me before earliest alarm")
                                    .font(.system(size: 13))
                                    .foregroundColor(Colors.textSecondary)
                                // Show calculated bedtime if we can
                                if let bedtime = computedBedtime() {
                                    Text("Bedtime at \(bedtime)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Colors.accentTeal)
                                }
                            }
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    if bedReminderMinutes > 15 {
                                        bedReminderMinutes -= 15
                                        scheduleBedtimeReminder()
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.white.opacity(0.08)))
                                        .foregroundColor(Colors.textSecondary)
                                }
                                Text("\(bedReminderMinutes)m")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(Colors.accentTeal)
                                Button {
                                    if bedReminderMinutes < 120 {
                                        bedReminderMinutes += 15
                                        scheduleBedtimeReminder()
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Colors.accentTeal))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                }
            }

            // Smart Wake Window
            QSCard {
                VStack(spacing: 12) {
                    QSToggleRow(
                        icon: "waveform.path.ecg", iconColor: .green,
                        title: "Smart Wake Window",
                        subtitle: "Alarm may ring early during light sleep",
                        isOn: Binding(
                            get: { smartWakeEnabled },
                            set: { newVal in
                                smartWakeEnabled = newVal
                                alarmStore.applySmartWake(enabled: newVal, windowMinutes: smartWakeWindow)
                                showFeedback(newVal ? "Smart Wake enabled — alarms will shift early" : "Smart Wake disabled")
                            }
                        )
                    )

                    if smartWakeEnabled {
                        Divider().background(Colors.cardStroke)
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.accentTeal)
                            Text("Alarm may ring up to \(smartWakeWindow)m early for lighter wake-up")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        }

                        HStack {
                            Text("Window")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)
                            Spacer()
                            HStack(spacing: 6) {
                                ForEach([10, 20, 30], id: \.self) { mins in
                                    Button {
                                        smartWakeWindow = mins
                                        alarmStore.applySmartWake(enabled: true, windowMinutes: mins)
                                    } label: {
                                        Text("\(mins)m")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(smartWakeWindow == mins ? .black : Colors.textSecondary)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(Capsule().fill(smartWakeWindow == mins ? Colors.accentTeal : Color.white.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: Focus & Productivity

    private var focusProductivitySection: some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "target", title: "Focus & Productivity", subtitle: "Build consistent wake habits")

            // Streak Counter (live from UserDefaults via @AppStorage)
            QSCard {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wake-Up Streak")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Colors.textPrimary)
                            Text("Days dismissed on first ring, no snooze")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(alarmStreak)")
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundColor(alarmStreak > 0 ? Colors.accentTeal : Colors.textTertiary)
                                Text("🔥")
                                    .font(.system(size: 22))
                            }
                            Text("days")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Colors.textTertiary)
                        }
                    }

                    if alarmStreak > 0 {
                        let nextMilestone = [3, 7, 14, 30, 60, 100].first(where: { $0 > alarmStreak }) ?? 100
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("→ \(nextMilestone) day milestone")
                                    .font(.system(size: 11))
                                    .foregroundColor(Colors.textTertiary)
                                Spacer()
                                Text("\(nextMilestone - alarmStreak) to go")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Colors.accentTeal)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Colors.accentTeal)
                                        .frame(width: geo.size.width * min(1, Double(alarmStreak) / Double(nextMilestone)))
                                }
                            }
                            .frame(height: 6)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.accentTeal)
                            Text("Dismiss your next alarm without snoozing to start your streak!")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        }
                    }

                    if alarmStreak > 0 {
                        Divider().background(Colors.cardStroke)
                        Button {
                            alarmStreak = 0
                            showFeedback("Streak reset")
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("Reset Streak")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Focus / DND Mode
            QSCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.indigo)
                            .frame(width: 28, height: 28)
                            .background(Color.indigo.opacity(0.12))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DND / Focus Setup")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text("Silence others, keep Alarmo loud.")
                                .font(.system(size: 12))
                                .foregroundColor(Colors.textTertiary)
                        }
                        
                        Spacer()
                        
                        Button {
                            if let url = URL(string: "App-Prefs:root=FOCUS") ?? URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Setup")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Colors.accentTeal))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider().background(Colors.cardStroke)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("iOS Precision Setup:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                        
                        setupStep(icon: "1.circle.fill", text: "Tap **Setup** to open iOS Focus settings.")
                        setupStep(icon: "2.circle.fill", text: "Select **Do Not Disturb** or a custom Focus.")
                        setupStep(icon: "3.circle.fill", text: "Under **Apps**, add **Alarmo** to Allowed.")
                        setupStep(icon: "4.circle.fill", text: "Ensure **Time Sensitive** togggle is ON.")
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Alarmo uses **Time Sensitive** alerts to break through DND automatically.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Colors.textTertiary)
                            .lineLimit(2)
                    }
                    .padding(.top, 4)
                }
            }

            // Sort Order
            QSCard {
                VStack(spacing: 12) {
                    HStack {
                        Label {
                            Text("Sort Alarms By")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                        } icon: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        SortOptionButton(title: "🕐 Time", isSelected: sortOrder == 0) {
                            withAnimation { sortOrder = 0 }
                            showFeedback("Sorting by time")
                        }
                        SortOptionButton(title: "✅ Active", isSelected: sortOrder == 1) {
                            withAnimation { sortOrder = 1 }
                            showFeedback("Active alarms first")
                        }
                        SortOptionButton(title: "🆕 New", isSelected: sortOrder == 2) {
                            withAnimation { sortOrder = 2 }
                            showFeedback("Newest alarms first")
                        }
                        SortOptionButton(title: "↕️ Manual", isSelected: sortOrder == 3) {
                            withAnimation { sortOrder = 3 }
                            showFeedback("Manual order enabled")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: Quick Presets

    private var quickPresetsSection: some View {
        VStack(spacing: 12) {
            HStack {
                sectionHeader(icon: "alarm.fill", title: "Quick Presets", subtitle: "Create, edit, and run your own templates")
                VStack(spacing: 8) {
                    Button {
                        openCreatePreset()
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Colors.accentTeal))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.25)) { isManagingPresets.toggle() }
                    } label: {
                        Text(isManagingPresets ? "Done" : "Manage")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isManagingPresets ? .black : Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isManagingPresets ? Colors.accentTeal : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if quickPresets.isEmpty {
                QSCard {
                    VStack(spacing: 10) {
                        Text("No presets yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text("Create a custom preset to quickly add alarms.")
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textTertiary)
                        Button("Add Preset") {
                            openCreatePreset()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Colors.accentTeal))
                    }
                }
            } else {
                if !selectedQuickPresetIDs.isEmpty {
                    HStack(spacing: 10) {
                        Label("\(selectedQuickPresetIDs.count) selected", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)

                        Spacer()

                        Button("Clear") {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                selectedQuickPresetIDs.removeAll()
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.accentTeal)

                        Button {
                            addSelectedPresetAlarms()
                        } label: {
                            Text("Add Selected")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Colors.accentTeal))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(quickPresets) { preset in
                        ZStack(alignment: .topTrailing) {
                            PresetAlarmButton(
                                icon: preset.icon,
                                iconColor: preset.iconColor,
                                name: preset.name,
                                hour: preset.hour,
                                minute: preset.minute,
                                isSelected: selectedQuickPresetIDs.contains(preset.id)
                            ) {
                                if isManagingPresets {
                                    openEditPreset(preset)
                                } else {
                                    togglePresetSelection(preset.id)
                                }
                            }
                            .contextMenu {
                                Button {
                                    togglePresetSelection(preset.id)
                                } label: {
                                    Label(
                                        selectedQuickPresetIDs.contains(preset.id) ? "Unselect" : "Select",
                                        systemImage: selectedQuickPresetIDs.contains(preset.id) ? "checkmark.circle.fill" : "circle"
                                    )
                                }
                                Button {
                                    openEditPreset(preset)
                                } label: {
                                    Label("Edit Preset", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deletePreset(preset)
                                } label: {
                                    Label("Delete Preset", systemImage: "trash")
                                }
                            }

                            if isManagingPresets {
                                HStack(spacing: 6) {
                                    Button {
                                        openEditPreset(preset)
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                            .frame(width: 26, height: 26)
                                            .background(Circle().fill(Colors.accentTeal))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        deletePreset(preset)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 26, height: 26)
                                            .background(Circle().fill(Color.red.opacity(0.85)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                            }
                        }
                    }
                }
            }

            QSCard {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.accentTeal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Custom presets create new alarms")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text("Tap Add Selected to create alarms for the next occurrence of each selected preset time.")
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers & Actions

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: resolvedSymbolName(icon))
                .font(.system(size: 20))
                .foregroundColor(Colors.accentTeal)
                .frame(width: 36, height: 36)
                .background(Colors.accentTeal.opacity(0.1))
                .cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private func resolvedSymbolName(_ name: String) -> String {
        UIImage(systemName: name) == nil ? "alarm.fill" : name
    }

    private func showFeedback(_ message: String) {
        withAnimation(.spring(response: 0.3)) { feedbackMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) { feedbackMessage = nil }
        }
    }

    // MARK: - Custom Presets Persistence

    private func loadQuickPresets() {
        if let decoded = try? JSONDecoder().decode([AlarmQuickPreset].self, from: quickPresetsData), !decoded.isEmpty {
            quickPresets = decoded
            return
        }
        quickPresets = AlarmQuickPreset.defaults
        saveQuickPresets()
    }

    private func saveQuickPresets() {
        if let data = try? JSONEncoder().encode(quickPresets) {
            quickPresetsData = data
        }
    }

    private func openCreatePreset() {
        editingPresetID = nil
        presetDraft = AlarmQuickPresetDraft()
        showPresetEditor = true
    }

    private func openEditPreset(_ preset: AlarmQuickPreset) {
        editingPresetID = preset.id
        presetDraft = AlarmQuickPresetDraft(preset: preset)
        showPresetEditor = true
    }

    private func savePresetDraft() {
        let preset = presetDraft.toPreset(id: editingPresetID ?? UUID())
        if let editingPresetID, let idx = quickPresets.firstIndex(where: { $0.id == editingPresetID }) {
            quickPresets[idx] = preset
            showFeedback("Preset updated")
        } else {
            quickPresets.insert(preset, at: 0)
            showFeedback("Preset created")
        }
        saveQuickPresets()
    }

    private func deletePreset(_ preset: AlarmQuickPreset) {
        quickPresets.removeAll(where: { $0.id == preset.id })
        selectedQuickPresetIDs.remove(preset.id)
        saveQuickPresets()
        showFeedback("Preset deleted")
    }

    // MARK: - Bedtime Reminder (Real UNUserNotificationCenter scheduling)

    /// Calculates bedtime: earliest enabled alarm time minus sleep goal and lead time.
    private func computedBedtime() -> String? {
        let enabled = alarmStore.alarms.filter(\.enabled)
        guard let earliest = enabled.min(by: { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }) else { return nil }

        let alarmMinutes = earliest.hour * 60 + earliest.minute
        let bedMinutes = alarmMinutes - sleepGoalHours * 60 - bedReminderMinutes
        let normalized = ((bedMinutes % 1440) + 1440) % 1440
        let h = normalized / 60
        let m = normalized % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func scheduleBedtimeReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            // Cancel old reminder
            center.removePendingNotificationRequests(withIdentifiers: [AppNotificationIdentifier.bedtimeReminder])

            // Find earliest enabled alarm
            let enabled = self.alarmStore.alarms.filter(\.enabled)
            guard let earliest = enabled.min(by: { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }) else { return }

            let alarmMinutes = earliest.hour * 60 + earliest.minute
            // bedtime = alarmTime - sleepGoal - lead
            let bedMinutes = alarmMinutes - self.sleepGoalHours * 60 - self.bedReminderMinutes
            let normalized = ((bedMinutes % 1440) + 1440) % 1440
            let h = normalized / 60
            let m = normalized % 60

            guard let reminderDate = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) else { return }
            let nextAlarmText = String(format: "%02d:%02d", earliest.hour, earliest.minute)
            NotificationOrchestrator.shared.scheduleBedtimeReminder(at: reminderDate, nextAlarmTimeText: nextAlarmText)
            DispatchQueue.main.async {
                self.showFeedback("Bedtime reminder set for \(String(format: "%02d:%02d", h, m))")
            }
        }
    }

    private func cancelBedtimeReminder() {
        NotificationOrchestrator.shared.cancel(identifiers: [AppNotificationIdentifier.bedtimeReminder])
    }

    private func setupStep(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Colors.accentTeal)
                .padding(.top, 2)
            
            let parts = text.components(separatedBy: "**")
            HStack(spacing: 0) {
                ForEach(0..<parts.count, id: \.self) { i in
                    Text(parts[i])
                        .font(.system(size: 12, weight: i % 2 == 1 ? .bold : .medium))
                        .foregroundColor(i % 2 == 1 ? Colors.textPrimary : Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Preset Alarm Creation

    private func addPresetAlarm(hour: Int, minute: Int, name: String, emoji: String, createdAt: Date = Date()) {
        let now = Date()
        let calendar = Calendar.current
        var target = DateComponents()
        target.hour = hour
        target.minute = minute
        target.second = 0

        let fireDate = calendar.nextDate(after: now, matching: target, matchingPolicy: .nextTime) ?? now.addingTimeInterval(60)
        let fire = calendar.dateComponents([.hour, .minute, .second], from: fireDate)

        let alarm = Alarm(
            id: UUID(),
            type: .wakeUp,
            name: name,
            emoji: emoji,
            hour: fire.hour ?? hour,
            minute: fire.minute ?? minute,
            second: fire.second ?? 0,
            isDaily: false,
            repeatMask: 0,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "Cockpit Alert",
            soundVolume: Float(alarmVolume),
            vibrateEnabled: vibrationEnabled,
            gentleWakeUpSeconds: 0,
            timeReminderEnabled: false,
            weatherReminderEnabled: false,
            labelReminderEnabled: false,
            extraLoudEnabled: false,
            snoozeMinutes: globalSnoozeEnabled ? snoozeMinutes : 0,
            snoozeCount: 0,
            wallpaperId: "default",
            createdAt: createdAt
        )
        alarmStore.add(alarm)
        AlarmManagerFacade.shared.schedule(alarm: alarm)
    }

    private func togglePresetSelection(_ id: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            if selectedQuickPresetIDs.contains(id) {
                selectedQuickPresetIDs.remove(id)
            } else {
                selectedQuickPresetIDs.insert(id)
            }
        }
    }

    private func addSelectedPresetAlarms(showFeedback: Bool = true) {
        let selected = quickPresets.filter { selectedQuickPresetIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        let now = Date()
        for (index, preset) in selected.enumerated() {
            addPresetAlarm(
                hour: preset.hour,
                minute: preset.minute,
                name: preset.name,
                emoji: preset.emoji,
                createdAt: now.addingTimeInterval(TimeInterval(index))
            )
        }

        if showFeedback {
            self.showFeedback(selected.count == 1 ? "1 preset alarm added!" : "\(selected.count) preset alarms added!")
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            selectedQuickPresetIDs.removeAll()
        }
    }
}

// MARK: - Reusable Sub-Components

struct QSCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Colors.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Colors.cardStroke, lineWidth: 1))
    }
}

struct QSToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Colors.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .scaleEffect(0.9)
        }
    }
}

struct SortOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .black : Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Colors.accentTeal : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

struct PresetAlarmButton: View {
    let icon: String
    let iconColor: Color
    let name: String
    let hour: Int
    let minute: Int
    let isSelected: Bool
    let action: () -> Void

    private var timeString: String { String(format: "%02d:%02d", hour, minute) }
    private var displayIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "alarm.fill" : trimmed
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: displayIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconColor.opacity(0.12))
                    .cornerRadius(12)

                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                    Text(timeString)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Colors.accentTeal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Colors.cardSurface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Colors.accentTeal : Colors.cardStroke, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AlarmQuickPreset: Identifiable, Codable {
    var id: UUID
    var icon: String
    var colorKey: String
    var name: String
    var emoji: String
    var hour: Int
    var minute: Int

    var iconColor: Color {
        Self.color(for: colorKey)
    }

    static func color(for key: String) -> Color {
        switch key {
        case "orange": return .orange
        case "yellow": return .yellow
        case "brown": return .brown
        case "teal": return .teal
        case "cyan": return .cyan
        case "indigo": return .indigo
        case "mint": return .mint
        case "blue": return .blue
        case "green": return .green
        case "pink": return .pink
        default: return Colors.accentTeal
        }
    }

    static let colorChoices: [(key: String, color: Color)] = [
        ("teal", .teal),
        ("yellow", .yellow),
        ("orange", .orange),
        ("cyan", .cyan),
        ("indigo", .indigo),
        ("blue", .blue),
        ("green", .green),
        ("pink", .pink),
        ("brown", .brown),
        ("mint", .mint)
    ]

    static let iconChoices: [String] = [
        "sunrise.fill",
        "sun.max.fill",
        "briefcase.fill",
        "cup.and.saucer.fill",
        "bolt.fill",
        "moon.stars.fill",
        "alarm.fill",
        "figure.run",
        "book.fill",
        "heart.fill",
        "graduationcap.fill",
        "dumbbell.fill"
    ]

    static let defaults: [AlarmQuickPreset] = [
        AlarmQuickPreset(id: UUID(), icon: "sunrise.fill", colorKey: "orange", name: "Early Bird", emoji: "🌅", hour: 5, minute: 30),
        AlarmQuickPreset(id: UUID(), icon: "sun.max.fill", colorKey: "yellow", name: "Morning", emoji: "☀️", hour: 7, minute: 0),
        AlarmQuickPreset(id: UUID(), icon: "briefcase.fill", colorKey: "brown", name: "Work Start", emoji: "💼", hour: 8, minute: 0),
        AlarmQuickPreset(id: UUID(), icon: "cup.and.saucer.fill", colorKey: "teal", name: "Lunch Break", emoji: "🍱", hour: 12, minute: 0),
        AlarmQuickPreset(id: UUID(), icon: "bolt.fill", colorKey: "cyan", name: "Power Nap", emoji: "⚡️", hour: 14, minute: 30),
        AlarmQuickPreset(id: UUID(), icon: "moon.stars.fill", colorKey: "indigo", name: "Night Owl", emoji: "🌙", hour: 23, minute: 0)
    ]
}

struct AlarmQuickPresetDraft {
    var name: String = ""
    var emoji: String = "⏰"
    var icon: String = "alarm.fill"
    var colorKey: String = "teal"
    var time: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()

    init() {}

    init(preset: AlarmQuickPreset) {
        self.name = preset.name
        self.emoji = preset.emoji
        self.icon = preset.icon
        self.colorKey = preset.colorKey
        self.time = Calendar.current.date(bySettingHour: preset.hour, minute: preset.minute, second: 0, of: Date()) ?? Date()
    }

    func toPreset(id: UUID) -> AlarmQuickPreset {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 7
        let minute = comps.minute ?? 0
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return AlarmQuickPreset(
            id: id,
            icon: icon,
            colorKey: colorKey,
            name: trimmed.isEmpty ? "Custom Alarm" : trimmed,
            emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "⏰" : emoji,
            hour: hour,
            minute: minute
        )
    }
}

struct QuickAlarmPresetEditorSheet: View {
    @Binding var draft: AlarmQuickPresetDraft
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        QSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Preset Name")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textTertiary)
                                TextField("e.g. Gym", text: $draft.name)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Colors.cardSurface))
                                    .foregroundColor(Colors.textPrimary)

                                Text("Emoji (optional)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textTertiary)
                                TextField("⏰", text: $draft.emoji)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Colors.cardSurface))
                                    .foregroundColor(Colors.textPrimary)
                            }
                        }

                        QSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Time")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textTertiary)
                                DatePicker("", selection: $draft.time, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, maxHeight: 170)
                            }
                        }

                        QSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Icon")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textTertiary)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                                    ForEach(AlarmQuickPreset.iconChoices, id: \.self) { icon in
                                        Button {
                                            draft.icon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(draft.icon == icon ? .black : Colors.textSecondary)
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(draft.icon == icon ? Colors.accentTeal : Colors.cardSurface)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        QSCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Color")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Colors.textTertiary)
                                HStack(spacing: 10) {
                                    ForEach(AlarmQuickPreset.colorChoices, id: \.key) { item in
                                        Button {
                                            draft.colorKey = item.key
                                        } label: {
                                            Circle()
                                                .fill(item.color)
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Circle()
                                                        .stroke(draft.colorKey == item.key ? Color.white : Color.clear, lineWidth: 2)
                                                        .padding(-4)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
    }
}
