import SwiftUI
import UserNotifications
import UIKit

struct NotificationSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @StateObject var notificationManager = NotificationManager.shared
    @State private var systemSettings: UNNotificationSettings?
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 22) {
                    permissionBanner
                    alarmSection
                    focusSection
                    stopwatchSection
                    quietHoursSection
                    updatesSection
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notificationManager.checkStatus()
            refreshSystemSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            notificationManager.checkStatus()
            refreshSystemSettings()
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Permission")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: requestPermissionAction) {
                    Text(permissionStatusText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(SettingsPalette.accent)
                }
            }

            Text("Allow notifications and Time Sensitive alerts for reliable alarms and reminders.")
                .font(.system(size: 14))
                .foregroundColor(Colors.textSecondary)

            VStack(spacing: 8) {
                alarmAccessStatusRow(title: "Alarm notifications", enabled: notificationPermissionEnabled)
                alarmAccessStatusRow(title: "Sound enabled", enabled: soundEnabled)
                if showsTimeSensitiveRow {
                    alarmAccessStatusRow(title: "Time Sensitive", enabled: timeSensitiveEnabled)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var alarmSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Alarm Reliability")
            SettingsCard {
                SettingsCardToggleRow(
                    title: "Alarm notifications",
                    subtitle: "Allow alarm-related notifications.",
                    isOn: featureEnabledBinding(\.alarm),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Tomorrow alarm check",
                    subtitle: "Warn if no alarm is scheduled for tomorrow.",
                    isOn: binding(for: \.alarmReminderEnabled),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Bedtime reminder",
                    subtitle: "Reminder before sleep based on your next alarm.",
                    isOn: alarmRuleBinding(\.bedtimeReminderEnabled),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Missed alarm follow-up",
                    subtitle: "Follow-up if an alarm may have been missed.",
                    isOn: alarmRuleBinding(\.missedAlarmFollowUpEnabled),
                    isLast: true
                )
            }
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Focus & Pomodoro")
            SettingsCard {
                SettingsCardToggleRow(
                    title: "Pomodoro notifications",
                    subtitle: "Session start/end and break transitions.",
                    isOn: featureEnabledBinding(\.pomodoro),
                    isLast: false
                )
                cadenceRow(
                    title: "Pomodoro cadence",
                    binding: featureCadenceBinding(\.pomodoro),
                    isLast: false
                )
                capMenuRow(
                    title: "Pomodoro daily cap",
                    binding: featureMaxPerDayBinding(\.pomodoro),
                    range: 1...20,
                    isLast: true
                )
            }
        }
    }

    private var stopwatchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Stopwatch & Countdown")
            SettingsCard {
                SettingsCardToggleRow(
                    title: "Stopwatch / countdown alerts",
                    subtitle: "Target reached and countdown complete alerts.",
                    isOn: featureEnabledBinding(\.stopwatch),
                    isLast: false
                )
                cadenceRow(
                    title: "Alert cadence",
                    binding: featureCadenceBinding(\.stopwatch),
                    isLast: false
                )
                capMenuRow(
                    title: "Daily alert cap",
                    binding: featureMaxPerDayBinding(\.stopwatch),
                    range: 1...20,
                    isLast: true
                )
            }
        }
    }

    private var quietHoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Quiet Hours")
            SettingsCard {
                SettingsCardToggleRow(
                    title: "Enable quiet hours",
                    subtitle: "Reduce non-critical notifications overnight.",
                    isOn: quietHoursBinding(\.enabled),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Allow time-sensitive in quiet hours",
                    subtitle: "Still allow urgent alarm notifications.",
                    isOn: quietHoursBinding(\.allowTimeSensitive),
                    isLast: false
                )
                quietWindowRow(isLast: true)
            }
        }
    }

    @ViewBuilder
    private func capMenuRow(title: String, binding: Binding<Int>, range: ClosedRange<Int>, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Menu {
                    ForEach(Array(range), id: \.self) { value in
                        Button("\(value)/day") {
                            binding.wrappedValue = value
                        }
                    }
                } label: {
                    Text("\(binding.wrappedValue)/day")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(SettingsPalette.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func quietWindowRow(isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quiet window")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 8) {
                    hourMenu(binding: quietHoursHourBinding(\.startHour))
                    Text("to")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    hourMenu(binding: quietHoursHourBinding(\.endHour))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func hourMenu(binding: Binding<Int>) -> some View {
        Menu {
            ForEach(0..<24, id: \.self) { hour in
                Button(formattedHour(hour)) {
                    binding.wrappedValue = hour
                }
            }
        } label: {
            Text(formattedHour(binding.wrappedValue))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SettingsPalette.accent)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.08), in: Capsule())
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        String(format: "%02d:00", min(23, max(0, hour)))
    }

    private func featureMaxPerDayBinding(_ keyPath: WritableKeyPath<NotificationPrefs, NotificationFeaturePrefs>) -> Binding<Int> {
        Binding(
            get: { store.notificationPrefs[keyPath: keyPath].maxPerDay },
            set: { newValue in
                var prefs = store.notificationPrefs
                var feature = prefs[keyPath: keyPath]
                feature.maxPerDay = max(1, min(30, newValue))
                prefs[keyPath: keyPath] = feature
                store.notificationPrefs = prefs
            }
        )
    }

    private func quietHoursHourBinding(_ keyPath: WritableKeyPath<NotificationQuietHoursPrefs, Int>) -> Binding<Int> {
        Binding(
            get: { store.notificationPrefs.quietHours[keyPath: keyPath] },
            set: { newValue in
                var prefs = store.notificationPrefs
                prefs.quietHours[keyPath: keyPath] = min(23, max(0, newValue))
                store.notificationPrefs = prefs
            }
        )
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("News & Events")
            SettingsCard {
                SettingsCardToggleRow(
                    title: "Product news",
                    subtitle: "Release notes and feature announcements.",
                    isOn: binding(for: \.newsEnabled),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Events",
                    subtitle: "Limited-time campaigns and events.",
                    isOn: binding(for: \.eventEnabled),
                    isLast: false
                )
                SettingsCardToggleRow(
                    title: "Marketing notifications",
                    subtitle: "Promotional updates.",
                    isOn: featureEnabledBinding(\.marketing),
                    isLast: false
                )
                cadenceRow(
                    title: "Marketing cadence",
                    binding: featureCadenceBinding(\.marketing),
                    isLast: false
                )
                capMenuRow(
                    title: "Marketing daily cap",
                    binding: featureMaxPerDayBinding(\.marketing),
                    range: 1...6,
                    isLast: true
                )
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Colors.textSecondary)
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func cadenceRow(title: String, binding: Binding<AppNotificationCadence>, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Picker("", selection: binding) {
                    Text("Off").tag(AppNotificationCadence.off)
                    Text("Smart").tag(AppNotificationCadence.smart)
                    Text("Freq").tag(AppNotificationCadence.frequent)
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }

    private var permissionStatusText: String {
        if alarmAccessReady {
            return "Alarm Access On"
        }
        switch notificationManager.authorizationStatus {
        case .denied:
            return "Open Settings"
        case .authorized, .provisional, .ephemeral:
            return "Fix Access"
        case .notDetermined:
            return "Allow"
        @unknown default:
            return "Allow"
        }
    }

    private func requestPermissionAction() {
        if notificationManager.authorizationStatus == .denied {
            openNotificationSettings()
        } else {
            notificationManager.requestPermission { _ in
                refreshSystemSettings()
            }
        }
        if notificationManager.authorizationStatus == .authorized || notificationManager.authorizationStatus == .provisional || notificationManager.authorizationStatus == .ephemeral {
            if !alarmAccessReady {
                openNotificationSettings()
            }
        }
    }

    private var notificationPermissionEnabled: Bool {
        let status = notificationManager.authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    private var soundEnabled: Bool {
        guard let settings = systemSettings else { return false }
        return settings.soundSetting == .enabled
    }

    private var showsTimeSensitiveRow: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }

    private var timeSensitiveEnabled: Bool {
        guard let settings = systemSettings else { return false }
        if #available(iOS 15.0, *) {
            return settings.timeSensitiveSetting == .enabled
        }
        return true
    }

    private var alarmAccessReady: Bool {
        notificationPermissionEnabled && soundEnabled && (!showsTimeSensitiveRow || timeSensitiveEnabled)
    }

    @ViewBuilder
    private func alarmAccessStatusRow(title: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(enabled ? Colors.accentGreen : Colors.accentRed)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.textSecondary)
            Spacer()
            Text(enabled ? "On" : "Off")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? Colors.accentGreen : Colors.accentRed)
        }
    }

    private func refreshSystemSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.systemSettings = settings
            }
        }
    }

    private func openNotificationSettings() {
        let notificationURL = URL(string: UIApplication.openNotificationSettingsURLString)
        let appSettingsURL = URL(string: UIApplication.openSettingsURLString)
        if let url = notificationURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = appSettingsURL {
            UIApplication.shared.open(url)
        }
    }

    private func setPrefsWithPermission(_ shouldEnable: Bool, _ update: @escaping (inout NotificationPrefs) -> Void) {
        if shouldEnable && notificationManager.authorizationStatus != .authorized && notificationManager.authorizationStatus != .provisional && notificationManager.authorizationStatus != .ephemeral {
            notificationManager.requestPermission { granted in
                guard granted else { return }
                var prefs = store.notificationPrefs
                update(&prefs)
                store.notificationPrefs = prefs
            }
            return
        }
        var prefs = store.notificationPrefs
        update(&prefs)
        store.notificationPrefs = prefs
    }

    private func binding(for keyPath: WritableKeyPath<NotificationPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPrefs[keyPath: keyPath] },
            set: { newValue in
                setPrefsWithPermission(newValue) { prefs in
                    prefs[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func alarmRuleBinding(_ keyPath: WritableKeyPath<AlarmNotificationRulesPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPrefs.alarmRules[keyPath: keyPath] },
            set: { newValue in
                setPrefsWithPermission(newValue) { prefs in
                    prefs.alarmRules[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func quietHoursBinding(_ keyPath: WritableKeyPath<NotificationQuietHoursPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPrefs.quietHours[keyPath: keyPath] },
            set: { newValue in
                setPrefsWithPermission(newValue) { prefs in
                    prefs.quietHours[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func featureEnabledBinding(_ keyPath: WritableKeyPath<NotificationPrefs, NotificationFeaturePrefs>) -> Binding<Bool> {
        Binding(
            get: { store.notificationPrefs[keyPath: keyPath].enabled },
            set: { newValue in
                setPrefsWithPermission(newValue) { prefs in
                    var feature = prefs[keyPath: keyPath]
                    feature.enabled = newValue
                    if !newValue {
                        feature.cadence = .off
                    } else if feature.cadence == .off {
                        feature.cadence = .smart
                    }
                    prefs[keyPath: keyPath] = feature
                }
            }
        )
    }

    private func featureCadenceBinding(_ keyPath: WritableKeyPath<NotificationPrefs, NotificationFeaturePrefs>) -> Binding<AppNotificationCadence> {
        Binding(
            get: { store.notificationPrefs[keyPath: keyPath].cadence },
            set: { newValue in
                setPrefsWithPermission(newValue != .off) { prefs in
                    var feature = prefs[keyPath: keyPath]
                    feature.cadence = newValue
                    feature.enabled = (newValue != .off)
                    prefs[keyPath: keyPath] = feature
                }
            }
        )
    }
}
