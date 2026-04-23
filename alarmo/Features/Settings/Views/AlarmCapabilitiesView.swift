import SwiftUI
import UserNotifications
import UIKit

struct AlarmCapabilitiesView: View {
    @State private var diagnostics: AlarmSchedulerDiagnostics?
    @State private var scheduledAlarms: [ScheduledAlarmDescriptor] = []
    @State private var deliveryStatus: AlarmDeliveryStatus?
    @State private var isWorking = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            SettingsGlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    capabilityCard
                    controlsCard
                    pendingCard
                    developerDiagnosticsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Alarm Compatibility")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refresh()
        }
        .alert(
            "Alarm Diagnostics",
            isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                statusMessage = nil
            }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private var capabilityCard: some View {
        infoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How alarm behavior works on this device")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                capabilityRow(
                    title: "Foreground sound",
                    body: "When Alarmo is open, AVAudioSession can play alarm audio."
                )
                capabilityRow(
                    title: "iOS 26+",
                    body: "AlarmKit path uses Apple system alarm APIs for best lock-screen alarm behavior."
                )
                capabilityRow(
                    title: "Older iOS",
                    body: "Falls back to local-notification alarms. This reminder-style path cannot always override Silent mode like system alarms."
                )

                Divider().background(Color.white.opacity(0.12))

                HStack {
                    Text("Detected path")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text(diagnostics?.schedulerPath.rawValue ?? "Loading…")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }

                HStack {
                    Text("AlarmKit support")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text((diagnostics?.alarmKitSupported ?? false) ? "Supported" : "Unsupported")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor((diagnostics?.alarmKitSupported ?? false) ? Colors.accentTeal : .red)
                }

                HStack {
                    Text("Notification status")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                    Text(readableAuthorization(diagnostics?.notificationAuthorization ?? .notDetermined))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                }

                if let deliveryStatus {
                    HStack {
                        Text("Lock Screen alerts")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Text(deliveryStatus.lockScreenEnabled ? "Enabled" : "Disabled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(deliveryStatus.lockScreenEnabled ? Colors.accentTeal : .red)
                    }
                    HStack {
                        Text("Time Sensitive")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Text(deliveryStatus.timeSensitiveEnabled ? "Enabled" : "Disabled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(deliveryStatus.timeSensitiveEnabled ? Colors.accentTeal : .red)
                    }
                    HStack {
                        Text("Scheduled Summary")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                        Spacer()
                        Text(deliveryStatus.scheduledDeliveryEnabled ? "On" : "Off")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(deliveryStatus.scheduledDeliveryEnabled ? .yellow : Colors.accentTeal)
                    }
                }
            }
        }
    }

    private var controlsCard: some View {
        infoCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Test Alarm Behavior")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                actionButton("Refresh Status") {
                    await refresh()
                }

                actionButton("Request Alarm Permission") {
                    await requestAlarmPermission()
                }

                actionButton("Schedule Alarm In 1 Minute") {
                    try await scheduleTestAlarm(minutes: 1)
                }

                actionButton("Schedule Alarm In 2 Minutes") {
                    try await scheduleTestAlarm(minutes: 2)
                }

                actionButton("Cancel All Scheduled Alarms", tint: .red) {
                    await cancelAllScheduledAlarms()
                }

                actionButton("Open App Settings") {
                    openAppSettings()
                }
            }
        }
    }

    private var pendingCard: some View {
        infoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pending Scheduled Alarms")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(scheduledAlarms.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textSecondary)
                }

                if scheduledAlarms.isEmpty {
                    Text("No pending alarms found.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                } else {
                    ForEach(scheduledAlarms) { alarm in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alarm.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(alarm.fireDate.map(Self.formatDate) ?? "No date")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var developerDiagnosticsCard: some View {
        #if DEBUG
        infoCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Developer Diagnostics")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("iOS: \(diagnostics?.iOSVersion ?? "Unknown")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                Text("Scheduler: \(diagnostics?.schedulerImplementation ?? "Unknown")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                Text("Notification permission: \(readableAuthorization(diagnostics?.notificationAuthorization ?? .notDetermined))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)

                if let pending = diagnostics?.pendingNotificationIdentifiers, !pending.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pending identifiers")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        ForEach(pending, id: \.self) { identifier in
                            Text(identifier)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Colors.textSecondary)
                        }
                    }
                }
            }
        }
        #endif
    }

    private func refresh() async {
        isWorking = true
        diagnostics = await AlarmManagerFacade.shared.diagnosticsSnapshot()
        scheduledAlarms = await AlarmManagerFacade.shared.listScheduledAlarms()
        deliveryStatus = await NotificationManager.shared.currentAlarmDeliveryStatus()
        isWorking = false
    }

    private func scheduleTestAlarm(minutes: Int) async throws {
        isWorking = true
        defer { isWorking = false }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral

        if !isAuthorized {
            let granted = await NotificationManager.shared.ensureAuthorization()
            guard granted else {
                throw AlarmSchedulingError.notificationsNotAuthorized
            }
        }

        let id = UUID()
        let fireDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        try await AlarmManagerFacade.shared.scheduleAlarm(
            id: id,
            title: "Test Alarm (+\(minutes)m)",
            date: fireDate,
            sound: "cockpitalert",
            snoozeEnabled: true
        )
        await refresh()
        statusMessage = "Scheduled test alarm for \(Self.formatDate(fireDate))."
    }

    private func cancelAllScheduledAlarms() async {
        isWorking = true
        let alarms = await AlarmManagerFacade.shared.listScheduledAlarms()
        for alarm in alarms {
            await AlarmManagerFacade.shared.cancelAlarm(id: alarm.id)
        }
        await refresh()
        isWorking = false
        statusMessage = alarms.isEmpty ? "No scheduled alarms to cancel." : "Cancelled \(alarms.count) scheduled alarm(s)."
    }

    private func requestAlarmPermission() async {
        isWorking = true
        defer { isWorking = false }

        let notificationsGranted = await NotificationManager.shared.ensureAuthorization()
        if !notificationsGranted {
            await refresh()
            statusMessage = "Notifications are disabled. Enable notifications for Alarmo first, then request Alarm permission."
            return
        }

        let granted = await AlarmManagerFacade.shared.requestAlarmAuthorizationIfNeeded()
        await refresh()

        if granted {
            statusMessage = "Alarm permission granted."
        } else {
            let details = AlarmKitSchedulingMessenger.shared.latestMessage()
            statusMessage = "\(details)\n\nIf Settings > Alarmo has no 'Alarms' row, reinstall the app on a real iPhone/iPad running iOS 26+ and request permission again."
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func capabilityRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(body)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
        }
    }

    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .background(Colors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
    }

    private func actionButton(
        _ title: String,
        tint: Color = Colors.accentTeal,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button {
            Task {
                do {
                    try await action()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        } label: {
            HStack {
                if isWorking {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tint.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isWorking)
        .opacity(isWorking ? 0.75 : 1)
    }

    private func readableAuthorization(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    nonisolated private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
