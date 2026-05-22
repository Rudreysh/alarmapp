import SwiftUI
import SwiftData

struct ProView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var alarmStore = AlarmStore.shared
    @ObservedObject private var overlapStore = OverlapStore.shared
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var preferences = AppPreferences()

    @Query private var planItems: [PlanItem]
    @Query private var appLists: [AppList]

    @State private var showUsageBreakdown = false

    private var activeAlarmsCount: Int {
        alarmStore.alarms.filter(\.enabled).count
    }

    private var premiumMissionAlarmCount: Int {
        alarmStore.alarms.filter { alarm in
            alarm.missions.contains { $0.type.isProFeature }
        }.count
    }

    private var spotifyAlarmCount: Int {
        let savedTracks = UserDefaults.standard.dictionary(forKey: "SavedSpotifyTracks") as? [String: [String: String]] ?? [:]
        let spotifyNames = Set(savedTracks.keys)
        guard !spotifyNames.isEmpty else { return 0 }
        return alarmStore.alarms.filter { spotifyNames.contains($0.soundName) }.count
    }

    private var habitCount: Int {
        planItems.filter { $0.type == .habit && !$0.isArchived && $0.parentTask == nil }.count
    }

    private var overlapCityCount: Int {
        overlapStore.cities.count
    }

    private var configuredBlockListCount: Int {
        appLists.filter {
            $0.type == .block &&
            (!$0.selectionData.isEmpty || !$0.mockAppIDs.isEmpty || !$0.mockCategoryIDs.isEmpty || $0.adultBlockingEnabled)
        }.count
    }

    private var protectedAlarmCount: Int {
        alarmStore.alarms.filter { $0.blockAppsEnabled || $0.penaltyEnabled || $0.shutdownProtectionEnabled }.count
    }

    private var focusTuned: Bool {
        preferences.pomoDurationMinutes != 25 ||
        preferences.shortBreakMinutes != 5 ||
        preferences.longBreakMinutes != 25 ||
        preferences.pomosPerLongBreak != 4 ||
        preferences.autoStartBreak ||
        preferences.autoStartNextPomo ||
        preferences.autoPomoCycle != 1
    }

    private var usageItems: [ProUsageItem] {
        [
            ProUsageItem(
                title: "Alarm Power",
                subtitle: "Active alarms running with Pro capabilities",
                icon: "alarm.fill",
                tint: .orange,
                usageText: "\(activeAlarmsCount) active",
                progress: progress(activeAlarmsCount, target: 6),
                isActive: activeAlarmsCount > 0,
                suggestion: "Keep at least one backup alarm enabled."
            ),
            ProUsageItem(
                title: "Premium Missions",
                subtitle: "Typing, QR, steps, squat, and advanced wake-up tasks",
                icon: "sparkles.rectangle.stack.fill",
                tint: .pink,
                usageText: "\(premiumMissionAlarmCount) configured",
                progress: progress(premiumMissionAlarmCount, target: 3),
                isActive: premiumMissionAlarmCount > 0,
                suggestion: "Assign a premium mission to at least one alarm."
            ),
            ProUsageItem(
                title: "Spotify Alarm Sounds",
                subtitle: "Custom music alarms mapped from Spotify",
                icon: "music.note.list",
                tint: .green,
                usageText: "\(spotifyAlarmCount) linked",
                progress: progress(spotifyAlarmCount, target: 2),
                isActive: spotifyAlarmCount > 0,
                suggestion: "Connect one Spotify track for your main alarm."
            ),
            ProUsageItem(
                title: "Habit Expansion",
                subtitle: "Active habit trackers in your Habit workspace",
                icon: "checklist.checked",
                tint: Colors.accentTeal,
                usageText: "\(habitCount) habits",
                progress: progress(habitCount, target: 5),
                isActive: habitCount > 2,
                suggestion: "Add more habits and turn reminders on for consistency."
            ),
            ProUsageItem(
                title: "Focus Tuning",
                subtitle: "Custom Pomodoro timings and auto-flow setup",
                icon: "timer.circle.fill",
                tint: Colors.accentBlue,
                usageText: focusTuned ? "Customized" : "Default profile",
                progress: focusTuned ? 1 : 0,
                isActive: focusTuned,
                suggestion: "Tune work/break durations to match your routine."
            ),
            ProUsageItem(
                title: "Distraction Blocking",
                subtitle: "Configured block lists for alarm/focus protection",
                icon: "shield.lefthalf.filled",
                tint: .purple,
                usageText: "\(configuredBlockListCount) lists ready",
                progress: progress(configuredBlockListCount, target: 2),
                isActive: configuredBlockListCount > 0 || settings.blockAppsEnabled,
                suggestion: "Create a block list and assign it to an alarm or focus flow."
            ),
            ProUsageItem(
                title: "Time Overlap Board",
                subtitle: "Global city planning for distributed routines",
                icon: "globe.europe.africa.fill",
                tint: .cyan,
                usageText: "\(overlapCityCount) cities",
                progress: progress(overlapCityCount, target: 5),
                isActive: overlapCityCount >= 2,
                suggestion: "Add at least two cities to unlock meaningful overlap analysis."
            ),
            ProUsageItem(
                title: "Penalty Shield",
                subtitle: "Anti-cheat enforcement and protection settings",
                icon: "lock.shield.fill",
                tint: .red,
                usageText: "\(protectedAlarmCount) protected alarms",
                progress: settings.accountabilityEnabled ? max(progress(protectedAlarmCount, target: 2), 0.35) : progress(protectedAlarmCount, target: 2),
                isActive: settings.accountabilityEnabled || protectedAlarmCount > 0,
                suggestion: "Enable accountability in Settings to harden critical alarms."
            )
        ]
    }

    private var activeUsageCount: Int {
        usageItems.filter(\.isActive).count
    }

    private var usageProgress: Double {
        guard !usageItems.isEmpty else { return 0 }
        return Double(activeUsageCount) / Double(usageItems.count)
    }

    private var usageStatusText: String {
        switch usageProgress {
        case 0..<0.25: return "Most Pro capabilities are still unused."
        case 0.25..<0.5: return "Good start — more power is available."
        case 0.5..<0.8: return "Strong setup. You are using Pro effectively."
        default: return "Excellent coverage across your Pro toolkit."
        }
    }

    var body: some View {
        ZStack {
            SettingsGlassBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                            }

                            Text(subManager.isPro ? "Pro Subscribed" : "Free Plan")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(.white)

                            Text(subManager.isPro ? "Renews at \(formattedDate(subManager.renewalDate))" : "Upgrade to unlock full feature set")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)

                            Text(subManager.planName)
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(SettingsPalette.accent.opacity(0.2))
                                .foregroundColor(SettingsPalette.accent)
                                .clipShape(Capsule())
                        }

                        Button {
                            showUsageBreakdown = true
                        } label: {
                            SettingsCard {
                                HStack(spacing: 20) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                            .frame(width: 88, height: 88)

                                        Circle()
                                            .trim(from: 0, to: max(0.03, usageProgress))
                                            .stroke(
                                                LinearGradient(
                                                    colors: [SettingsPalette.accentBright, SettingsPalette.accentDark],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                            )
                                            .frame(width: 88, height: 88)
                                            .rotationEffect(.degrees(-90))

                                        VStack(spacing: 2) {
                                            Text("\(activeUsageCount)/\(usageItems.count)")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("active")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(Colors.textSecondary)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Pro feature usage")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(usageStatusText)
                                            .font(.system(size: 14))
                                            .foregroundColor(Colors.textSecondary)
                                            .multilineTextAlignment(.leading)
                                        Text("Tap to view detailed breakdown")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(SettingsPalette.accent)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Colors.textTertiary)
                                }
                                .padding(20)
                            }
                        }
                        .buttonStyle(PressedScaleButtonStyle())

                        Button(action: {
                            UIApplication.shared.open(subManager.manageSubscriptionsURL)
                        }) {
                            Text("Manage Subscription")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 220)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)

#if DEBUG
                        Toggle(isOn: $subManager.isPro) {
                            Text("Simulate Pro Status (Testing)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .tint(Colors.accentTeal)
                        .padding(.horizontal, 40)
                        .padding(.top, 12)
#endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showUsageBreakdown) {
            ProFeatureUsageDetailView(
                items: usageItems,
                activeCount: activeUsageCount,
                totalCount: usageItems.count
            )
        }
    }

    private func formattedDate(_ date: Date) -> String {
        guard date != Date.distantFuture else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func progress(_ value: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(1, Double(value) / Double(target))
    }
}

private struct ProUsageItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let usageText: String
    let progress: Double
    let isActive: Bool
    let suggestion: String
}

private struct ProFeatureUsageDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [ProUsageItem]
    let activeCount: Int
    let totalCount: Int

    private var usageProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(activeCount) / Double(totalCount)
    }

    private var suggestedItems: [ProUsageItem] {
        items.filter { !$0.isActive }.prefix(3).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        summaryCard

                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                usageRow(item: item)
                            }
                        }

                        if !suggestedItems.isEmpty {
                            SettingsCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Try next")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)

                                    ForEach(suggestedItems) { item in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "sparkles")
                                                .foregroundColor(SettingsPalette.accent)
                                                .padding(.top, 2)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Text(item.suggestion)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Colors.textSecondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(18)
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Pro feature usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SettingsPalette.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var summaryCard: some View {
        SettingsCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 84, height: 84)

                    Circle()
                        .trim(from: 0, to: max(0.03, usageProgress))
                        .stroke(
                            LinearGradient(
                                colors: [SettingsPalette.accentBright, SettingsPalette.accentDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(-90))

                    Text("\(activeCount)/\(totalCount)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Usage Coverage")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("This tracks how many Pro capabilities are configured and actively used in your app setup.")
                        .font(.system(size: 13))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(18)
        }
    }

    private func usageRow(item: ProUsageItem) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(item.tint.opacity(0.22))
                            .frame(width: 34, height: 34)
                        Image(systemName: item.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(item.tint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(item.subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(Colors.textSecondary)
                    }

                    Spacer()

                    Text(item.isActive ? "Active" : "Not set")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.isActive ? .green : Colors.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background((item.isActive ? Color.green : Color.white).opacity(item.isActive ? 0.2 : 0.08))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [item.tint.opacity(0.8), item.tint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * item.progress))
                        }
                    }
                    .frame(height: 8)

                    Text(item.usageText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
        }
    }
}
