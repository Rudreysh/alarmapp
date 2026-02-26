import SwiftUI
import UserNotifications

// MARK: - Quick Settings Panel

struct QuickSettingsPanel: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var alarmStore: AlarmStore

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

    @State private var selectedTab = 0
    @State private var showAllDisabledConfirm = false
    @State private var feedbackMessage: String? = nil

    private let tabs: [(title: String, icon: String)] = [
        ("Presets", "square.stack.3d.up.fill"),
        ("Global", "bolt.fill"),
        ("Sleep", "moon.zzz.fill"),
        ("Focus", "target")
    ]

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
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.fraction(0.75), .large])
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedTab = index }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(selectedTab == index ? .black : Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selectedTab == index ? Colors.accentTeal : Colors.cardSurface))
                            .overlay(Capsule().stroke(selectedTab == index ? Color.clear : Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
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
                            Text("h")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .padding(.top, 8)
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
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: Quick Presets

    private var quickPresetsSection: some View {
        VStack(spacing: 12) {
            sectionHeader(icon: "clock.badge.plus", title: "Quick Presets", subtitle: "One-tap alarm templates")

            let presets: [(icon: String, color: Color, name: String, emoji: String, h: Int, m: Int)] = [
                ("sunrise.fill", .orange, "Early Bird", "🌅", 5, 30),
                ("sun.max.fill", .yellow, "Morning", "☀️", 7, 0),
                ("briefcase.fill", .brown, "Work Start", "💼", 8, 0),
                ("cup.and.saucer.fill", .teal, "Lunch Break", "🍱", 12, 0),
                ("bolt.fill", .cyan, "Power Nap", "⚡️", 14, 30),
                ("moon.stars.fill", .indigo, "Night Owl", "🌙", 23, 0),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets, id: \.name) { preset in
                    PresetAlarmButton(icon: preset.icon, iconColor: preset.color, name: preset.name, hour: preset.h, minute: preset.m) {
                        addPresetAlarm(hour: preset.h, minute: preset.m, name: preset.name, emoji: preset.emoji)
                        showFeedback("\(preset.name) alarm added!")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                    }
                }
            }

            QSCard {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Colors.accentTeal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Presets add a new alarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text("Enabled by default with daily repeat. Edit from your alarm list.")
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
            Image(systemName: icon)
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

    private func showFeedback(_ message: String) {
        withAnimation(.spring(response: 0.3)) { feedbackMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) { feedbackMessage = nil }
        }
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
            center.removePendingNotificationRequests(withIdentifiers: ["alarmo.bedtime.reminder"])

            // Find earliest enabled alarm
            let enabled = self.alarmStore.alarms.filter(\.enabled)
            guard let earliest = enabled.min(by: { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }) else { return }

            let alarmMinutes = earliest.hour * 60 + earliest.minute
            // bedtime = alarmTime - sleepGoal - lead
            let bedMinutes = alarmMinutes - self.sleepGoalHours * 60 - self.bedReminderMinutes
            let normalized = ((bedMinutes % 1440) + 1440) % 1440
            let h = normalized / 60
            let m = normalized % 60

            let content = UNMutableNotificationContent()
            content.title = "🌙 Time to Wind Down"
            content.body = "Your \(String(format: "%02d:%02d", earliest.hour, earliest.minute)) alarm rings in \(self.sleepGoalHours)h \(self.bedReminderMinutes)m. Get ready for sleep!"
            content.sound = .default
            content.interruptionLevel = .passive

            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "alarmo.bedtime.reminder", content: content, trigger: trigger)

            center.add(request) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.showFeedback("Bedtime reminder set for \(String(format: "%02d:%02d", h, m))")
                    }
                }
            }
        }
    }

    private func cancelBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarmo.bedtime.reminder"])
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

    private func addPresetAlarm(hour: Int, minute: Int, name: String, emoji: String) {
        let alarm = Alarm(
            id: UUID(),
            type: .wakeUp,
            name: name,
            emoji: emoji,
            hour: hour,
            minute: minute,
            isDaily: true,
            repeatMask: RepeatMask.allDays,
            enabled: true,
            wakeUpCheckEnabled: false,
            soundName: "default",
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
            createdAt: Date()
        )
        alarmStore.add(alarm)
        AlarmScheduler().schedule(alarm: alarm)
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
    let action: () -> Void

    private var timeString: String { String(format: "%02d:%02d", hour, minute) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
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
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Colors.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
